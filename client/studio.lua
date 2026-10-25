Studio = Studio or {}
Studio.active = false
Studio.cam = nil
Studio.pos = nil
Studio.ped = nil

local function drawQuad(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, r, g, b, a)
    DrawPoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, a)
    DrawPoly(x3, y3, z3, x4, y4, z4, x1, y1, z1, r, g, b, a)
    DrawPoly(x3, y3, z3, x2, y2, z2, x1, y1, z1, r, g, b, a)
    DrawPoly(x1, y1, z1, x4, y4, z4, x3, y3, z3, r, g, b, a)
end

local WEATHER_TYPES = {
    'CLEAR', 'EXTRASUNNY', 'CLOUDS', 'OVERCAST', 'RAIN', 'CLEARING', 'THUNDER',
    'SMOG', 'FOGGY', 'XMAS', 'SNOW', 'SNOWLIGHT', 'BLIZZARD', 'HALLOWEEN',
    'NEUTRAL', 'RAIN_HALLOWEEN', 'SNOW_HALLOWEEN',
}

local weatherNames = {}
for _, name in ipairs(WEATHER_TYPES) do
    weatherNames[GetHashKey(name) & 0xFFFFFFFF] = name
end

local STUDIO_HOUR = 12
local STUDIO_WEATHER = 'EXTRASUNNY'

local function holdStudioWorld()
    NetworkOverrideClockTime(STUDIO_HOUR, 0, 0)
    SetWeatherTypeNowPersist(STUDIO_WEATHER)
end

local function qbWeatherSyncRunning()
    return GetResourceState('qb-weathersync') == 'started' or GetResourceState('qbx_weathersync') == 'started'
end

local function renewedRunning()
    return GetResourceState('Renewed-Weathersync') == 'started'
end

-- qb/qbx weathersync keep `disable` local, track it from the events.
local qbSyncDisabled = false
local selfToggle = false

RegisterNetEvent('qb-weathersync:client:DisableSync', function()
    if not selfToggle then qbSyncDisabled = true end
end)

RegisterNetEvent('qb-weathersync:client:EnableSync', function()
    if not selfToggle then qbSyncDisabled = false end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if GetResourceState('qbx_weathersync') == 'started' then qbSyncDisabled = false end
end)

local function fireQbSyncEvent(eventName)
    selfToggle = true
    TriggerEvent(eventName)
    selfToggle = false
end

-- Pause the weathersync for the shot. Call after snapshotWorld.
local function pauseWeatherSync()
    if renewedRunning() then
        local state = LocalPlayer.state
        local paused = { kind = 'renewed', syncWeather = state.syncWeather, playerWeather = state.playerWeather }
        state.playerWeather = STUDIO_WEATHER
        if paused.syncWeather then state.syncWeather = false end
        return paused
    end

    if qbWeatherSyncRunning() and not qbSyncDisabled then
        fireQbSyncEvent('qb-weathersync:client:DisableSync')
        return { kind = 'qb' }
    end

    return nil
end

local function resumeWeatherSync(paused)
    if not paused then return end

    if paused.kind == 'renewed' then
        local state = LocalPlayer.state
        state.playerWeather = paused.playerWeather
        if paused.syncWeather then state.syncWeather = true end
    elseif paused.kind == 'qb' then
        fireQbSyncEvent('qb-weathersync:client:EnableSync')
    end
end

local function snapshotWorld()
    return {
        hour = GetClockHours(),
        minute = GetClockMinutes(),
        second = GetClockSeconds(),
        clockOverridden = NetworkIsClockTimeOverridden(),
        weather = weatherNames[GetNextWeatherTypeHashName() & 0xFFFFFFFF],
    }
end

-- Put clock/weather back, don't leave our override behind.
local function restoreWorld(snapshot)
    if snapshot.clockOverridden then
        NetworkOverrideClockTime(snapshot.hour, snapshot.minute, snapshot.second)
    else
        NetworkClearClockTimeOverride()
    end

    if qbWeatherSyncRunning() or renewedRunning() then
        if snapshot.weather then
            SetWeatherTypeNowPersist(snapshot.weather)
        end
    else
        -- no weathersync, clear persist or weather stops cycling
        if snapshot.weather then
            SetWeatherTypeNow(snapshot.weather)
        end
        ClearWeatherTypePersist()
    end
end

local WALL_HW = 4.0
local WALL_HD = 4.0
local WALL_HEIGHT = 8.5
local WALL_FLOOR_OFFSET = -3.0

local function drawChromaWallAndLights(pos)
    local r, g, b = 255, 0, 255

    local hw, hd = WALL_HW, WALL_HD
    local fz = pos.z + WALL_FLOOR_OFFSET
    local cz = fz + WALL_HEIGHT

    local x1, y1 = pos.x - hw, pos.y - hd
    local x2, y2 = pos.x + hw, pos.y - hd
    local x3, y3 = pos.x - hw, pos.y + hd
    local x4, y4 = pos.x + hw, pos.y + hd

    drawQuad(x1, y1, fz, x2, y2, fz, x2, y2, cz, x1, y1, cz, r, g, b, 255)
    drawQuad(x4, y4, fz, x3, y3, fz, x3, y3, cz, x4, y4, cz, r, g, b, 255)
    drawQuad(x3, y3, fz, x1, y1, fz, x1, y1, cz, x3, y3, cz, r, g, b, 255)
    drawQuad(x2, y2, fz, x4, y4, fz, x4, y4, cz, x2, y2, cz, r, g, b, 255)
    drawQuad(x1, y1, fz, x2, y2, fz, x4, y4, fz, x3, y3, fz, r, g, b, 255)
    drawQuad(x3, y3, cz, x4, y4, cz, x2, y2, cz, x1, y1, cz, r, g, b, 255)

    local cz_mid = fz + WALL_HEIGHT * 0.5
    DrawLightWithRange(pos.x,             pos.y + hd * 0.9, cz_mid, r, g, b, 2.2, 10.0)
    DrawLightWithRange(pos.x - hw * 0.9,  pos.y,            cz_mid, r, g, b, 2.2, 8.0)
    DrawLightWithRange(pos.x + hw * 0.9,  pos.y,            cz_mid, r, g, b, 2.2, 8.0)
    DrawLightWithRange(pos.x,             pos.y - hd * 0.9, cz_mid, r, g, b, 2.2, 6.0)
    DrawLightWithRange(pos.x, pos.y, cz - 0.3, r, g, b, 2.2, 6.0)
    DrawLightWithRange(pos.x, pos.y, fz + 0.3, r, g, b, 2.2, 6.0)

    -- weak white fill from all sides so nothing goes black
    DrawLightWithRange(pos.x,        pos.y,        pos.z + 2.0, 255, 250, 240, 1.4, 6.0)  -- top (head)
    DrawLightWithRange(pos.x,        pos.y + 0.8,  pos.z + 1.5, 255, 250, 240, 1.3, 4.0)  -- back-top
    DrawLightWithRange(pos.x - 1.0,  pos.y,        pos.z + 1.4, 255, 250, 240, 1.3, 3.0)  -- far left
    DrawLightWithRange(pos.x + 1.0,  pos.y,        pos.z + 1.4, 255, 250, 240, 1.3, 3.0)  -- far right
    DrawLightWithRange(pos.x,        pos.y - 0.2,  pos.z + 0.0, 255, 250, 240, 1.2, 3.0)  -- under chin

    for _, light in ipairs(Config.Lighting) do
        DrawLightWithRange(
            pos.x + light.offset.x,
            pos.y + light.offset.y,
            pos.z + light.offset.z,
            light.r or 255, light.g or 255, light.b or 255,
            light.range,
            light.intensity
        )
    end
end

CreateThread(function()
    while true do
        if Studio.active and Studio.pos then
            -- weathersync can still write once after pause, force noon every frame
            holdStudioWorld()
            drawChromaWallAndLights(Studio.pos)
            if Studio.ped and Studio.ped ~= 0 and DoesEntityExist(Studio.ped) then
                ClearPedTasksImmediately(Studio.ped)
            end
        end
        Wait(0)
    end
end)

function Studio.Enter(ped, variant)
    local v = Config.Variants[variant]
    if not v then error('unknown_variant: ' .. tostring(variant)) end

    local pos = Config.Studio.coords
    local aH = math.rad(v.angleH or 0.0)
    local dist = v.dist or 1.2
    local camX = pos.x + dist * math.sin(aH)
    local camY = pos.y - dist * math.cos(aH)
    local camZ = pos.z + (v.zPos or 0.65)
    local lookZ = pos.z + (v.zPos or 0.65)

    Studio.cam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        camX, camY, camZ,
        0.0, 0.0, 0.0,
        v.fov or 35.0,
        false, 0
    )

    local dx = pos.x - camX
    local dy = pos.y - camY
    local dz = lookZ - camZ
    local dist2d = math.sqrt(dx * dx + dy * dy)
    local pitch = math.deg(math.atan2(dz, dist2d))
    local heading = -math.deg(math.atan2(dx, dy))
    SetCamRot(Studio.cam, pitch, v.roll or 0.0, heading, 2)

    SetCamActive(Studio.cam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- snapshot before pausing
    if not Studio._world then
        Studio._world = snapshotWorld()
        Studio._sync = pauseWeatherSync()
    end
    ClearWeatherTypePersist()
    holdStudioWorld()

    Studio.pos = pos
    Studio.ped = ped
    Studio.active = true
end

function Studio.Exit()
    Studio.active = false
    Studio.pos = nil
    Studio.ped = nil

    if Studio.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(Studio.cam, false)
        Studio.cam = nil
    end

    -- Exit runs twice per capture
    if Studio._world then
        local snapshot, sync = Studio._world, Studio._sync
        Studio._world, Studio._sync = nil, nil
        restoreWorld(snapshot)
        resumeWeatherSync(sync)
    end
end
