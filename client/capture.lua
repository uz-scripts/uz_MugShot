Capture = Capture or {}
Capture.inProgress = false

-- 2 decimals so float noise doesn't change the fingerprint.
local function round2(n)
    local s = ('%.2f'):format(tonumber(n) or 0)
    if s == '-0.00' then s = '0.00' end
    return s
end

local function mix(n)
    return round2(math.min(1, math.max(0, tonumber(n) or 0)))
end

-- GetPedHeadBlendData, read the same way illenium-appearance does.
local function headBlendKey(ped)
    local shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix =
        Citizen.InvokeNative(0x2746BD9D88C5C5D0, ped,
            Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueFloatInitialized(0), Citizen.PointerValueFloatInitialized(0),
            Citizen.PointerValueFloatInitialized(0))

    return table.concat({
        tostring(shapeFirst or 0), tostring(shapeSecond or 0), tostring(shapeThird or 0),
        tostring(skinFirst or 0), tostring(skinSecond or 0), tostring(skinThird or 0),
        mix(shapeMix), mix(skinMix), mix(thirdMix),
    }, ',')
end

-- Deterministic hash of ped features visible in the mugshot frame.
-- Legs, bag, shoes, ears, watch and bracelet are out of frame.
function Capture.ComputeMugshotFingerprint()
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end

    local parts = { 'm:' .. tostring(GetEntityModel(ped)) }

    parts[#parts + 1] = 'hb:' .. headBlendKey(ped)

    local features = {}
    for i = 0, 19 do
        features[#features + 1] = round2(GetPedFaceFeature(ped, i))
    end
    parts[#parts + 1] = 'ff:' .. table.concat(features, ',')

    parts[#parts + 1] = tostring(GetPedEyeColor(ped) or -1)
    parts[#parts + 1] = tostring(GetPedHairColor(ped) or -1)
        .. ':' .. tostring(GetPedHairHighlightColor(ped) or -1)

    for i = 0, 12 do
        local _, value, _, firstColor, secondColor, opacity = GetPedHeadOverlayData(ped, i)
        parts[#parts + 1] = ('o%d:%s,%s,%s,%s'):format(i,
            tostring(value or 255), tostring(firstColor or 0),
            tostring(secondColor or 0), round2(opacity))
    end

    for _, c in ipairs({ 0, 1, 2, 3, 7, 8, 9, 10, 11 }) do
        parts[#parts + 1] = ('c%d:%s,%s'):format(c,
            GetPedDrawableVariation(ped, c),
            GetPedTextureVariation(ped, c))
    end

    for _, p in ipairs({ 0, 1 }) do
        parts[#parts + 1] = ('p%d:%s,%s'):format(p,
            GetPedPropIndex(ped, p),
            GetPedPropTextureIndex(ped, p))
    end

    return table.concat(parts, '|')
end

-- Something else owns the screen (menu, camera, fade...), don't capture now.
function Capture.PlainGameplayBlocker()
    if IsNuiFocused() then return 'nui_focus' end
    if GetRenderingCam() ~= -1 then return 'script_camera' end
    if not IsScreenFadedIn() then return 'screen_fade' end
    if IsPauseMenuActive() then return 'pause_menu' end
    if IsPlayerSwitchInProgress() then return 'player_switch' end
    if IsCutsceneActive() then return 'cutscene' end
    if GetIsLoadingScreenActive() then return 'loading_screen' end
    if NetworkIsInSpectatorMode() then return 'spectating' end
    return nil
end

local plainSince = nil

CreateThread(function()
    while true do
        if Capture.PlainGameplayBlocker() then
            plainSince = nil
        elseif not plainSince then
            plainSince = GetGameTimer()
        end
        Wait(100)
    end
end)

-- Also checks live, the thread above only samples every 100 ms.
function Capture.IsPlain(settleMs)
    if Capture.PlainGameplayBlocker() then
        plainSince = nil
        return false
    end
    local now = GetGameTimer()
    plainSince = plainSince or now
    return now - plainSince >= (settleMs or 0)
end

local function waitPlainGameplay()
    local guard = Config.CaptureGuard
    local start = GetGameTimer()
    while not Capture.IsPlain(guard.settleMs) do
        if GetGameTimer() - start >= guard.timeoutMs then
            return false, Capture.PlainGameplayBlocker() or 'settling'
        end
        Wait(100)
    end
    return true
end

local function teardown(clone)
    Studio.Exit()
    if clone and clone ~= 0 and DoesEntityExist(clone) then
        DeleteEntity(clone)
    end
end

local function lockStaticPose(ped)
    SetPedCanPlayAmbientAnims(ped, false)
    SetPedCanPlayGestureAnims(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
end

local function waitScreenshot(timeoutMs)
    local done, result, err = false, nil, nil

    exports['screenshot-basic']:requestScreenshot({
        encoding = 'png',
        quality = 1.0,
    }, function(data)
        if not data or data == '' then
            err = 'empty_screenshot'
        else
            result = data
        end
        done = true
    end)

    local startTime = GetGameTimer()
    while not done and (GetGameTimer() - startTime) < timeoutMs do
        Wait(0)
    end

    if not done then return nil, 'screenshot_timeout' end
    if err then return nil, err end
    return result, nil
end

function Capture.Execute(opts)
    if Capture.inProgress then
        return false, 'in_progress'
    end
    Capture.inProgress = true

    opts = opts or {}
    local variant = opts.variant or 'mugshot'
    local forceShowCurtain = opts.forceCurtain == true

    if not Config.Variants[variant] then
        Capture.inProgress = false
        return false, 'unknown_variant'
    end

    local plain, blocker = waitPlainGameplay()
    if not plain then
        Capture.inProgress = false
        if Config.Debug then
            print('[uz_mugshot][capture] skipped, player not in plain gameplay: ' .. tostring(blocker))
        end
        return false, 'not_plain_gameplay'
    end

    local clone
    local success, result = pcall(function()
        local ped = PlayerPedId()
        if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
            error('ped_invalid')
        end

        if forceShowCurtain then
            NUI.ShowCurtain()
            Wait(Config.Timing.curtainFadeIn)
        end

        clone = ClonePed(ped, false, false, true)
        if not clone or clone == 0 then
            error('clone_failed')
        end

        NetworkSetEntityInvisibleToNetwork(clone, true)
        SetEntityInvincible(clone, true)
        SetEntityCollision(clone, false, false)
        SetEntityCoordsNoOffset(clone,
            Config.Studio.coords.x,
            Config.Studio.coords.y,
            Config.Studio.coords.z,
            false, false, false)
        SetEntityHeading(clone, Config.Studio.heading)
        FreezeEntityPosition(clone, true)

        local v = Config.Variants[variant]
        ClearPedTasksImmediately(clone)
        lockStaticPose(clone)
        if v.facialMood then
            SetFacialIdleAnimOverride(clone, v.facialMood, 0)
        end

        Studio.Enter(clone, variant)

        Wait(Config.Timing.streamingWait)
        for _ = 1, Config.Timing.stabilizationFrames do Wait(0) end

        -- hair under a hat needs a few more frames to get squeezed
        if GetPedPropIndex(clone, 0) ~= -1 then
            for _ = 1, Config.Timing.hatSettleFrames or 0 do Wait(0) end
        end

        local base64, err = waitScreenshot(Config.Timing.captureTimeout)
        if not base64 then error(err) end

        teardown(clone)
        clone = nil

        if forceShowCurtain then
            NUI.HideCurtain()
        end

        local fp = nil
        if variant == 'mugshot' then
            fp = Capture.ComputeMugshotFingerprint()
        end

        TriggerLatentServerEvent('uz_mugshot:processCapture', 2000000, {
            variant = variant,
            imageData = base64,
            fingerprint = fp,
        })
    end)

    teardown(clone)
    if forceShowCurtain then NUI.HideCurtain() end
    Capture.inProgress = false

    if not success then
        if Config.Debug then
            print('[uz_mugshot][capture] failed: ' .. tostring(result))
        end
        return false, result
    end
    return true
end
