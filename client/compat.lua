-- Same native headshot MugShotBase64 uses, for peds we have no photo of.
local function nativeHeadshot(ped)
    if not DoesEntityExist(ped) then return '' end
    local handle = RegisterPedheadshot(ped)
    local waited = 0
    while not (IsPedheadshotReady(handle) and IsPedheadshotValid(handle)) and waited < 2000 do
        Wait(10)
        waited = waited + 10
    end

    local uri = ''
    if IsPedheadshotReady(handle) and IsPedheadshotValid(handle) then
        local txd = GetPedheadshotTxdString(handle)
        uri = NUI.ToDataUri(('https://nui-img/%s/%s?t=%d'):format(txd, txd, GetGameTimer()))
    end
    UnregisterPedheadshot(handle)
    return uri
end

-- Never nil, like the original: old scripts use the result without checking.
local function getMugShotBase64(ped, _transparent)
    ped = (ped and ped ~= 0) and ped or PlayerPedId()

    local uri = _UZ_MUGSHOT.resolvePhoto(ped, 'mugshot')
    if uri then
        -- old scripts often store it in item metadata, keep it headshot sized
        local size = Config.Compat.size
        if size and size < Config.OutputSize.width then
            local small = NUI.ToDataUri(uri, size)
            if small ~= '' then return small end
        end
        return uri
    end

    -- NPC, preview ped or no photo yet
    if Config.Debug then
        print(('[uz_mugshot][compat] no photo for ped=%s, using the native headshot'):format(tostring(ped)))
    end
    return nativeHeadshot(ped)
end

exports('GetMugShotBase64', getMugShotBase64)

-- provide alone doesn't route exports, hook the internal __cfx_export_ events.
AddEventHandler('__cfx_export_MugShotBase64_GetMugShotBase64', function(setCB)
    setCB(getMugShotBase64)
end)
