local waiters = {}
local nextNonce = 0

RegisterNetEvent('uz_mugshot:client:photoResult', function(nonce, uri)
    local p = waiters[nonce]
    if not p then return end
    waiters[nonce] = nil
    p:resolve(uri or '')
end)

local function awaitPhoto(serverId, variant)
    nextNonce = nextNonce + 1
    local nonce = nextNonce
    local p = promise.new()
    waiters[nonce] = p
    TriggerServerEvent('uz_mugshot:client:requestPhoto', nonce, serverId, variant)
    SetTimeout(10000, function()
        if waiters[nonce] then
            waiters[nonce] = nil
            p:resolve('')
        end
    end)
    return Citizen.Await(p)
end

local function awaitPhotoByCitizenId(citizenid, variant)
    nextNonce = nextNonce + 1
    local nonce = nextNonce
    local p = promise.new()
    waiters[nonce] = p
    TriggerServerEvent('uz_mugshot:client:requestPhotoByCitizenId', nonce, citizenid, variant)
    SetTimeout(10000, function()
        if waiters[nonce] then
            waiters[nonce] = nil
            p:resolve('')
        end
    end)
    return Citizen.Await(p)
end

local function localCitizenIdIfLocalPed(ped)
    if ped ~= PlayerPedId() then return nil end
    if not Bridge.GetLocalCitizenId then return nil end
    return Bridge.GetLocalCitizenId()
end

local function pedToServerId(ped)
    if type(ped) ~= 'number' or ped == 0 then return nil end
    if not DoesEntityExist(ped) then return nil end

    if ped == PlayerPedId() then
        return GetPlayerServerId(PlayerId())
    end

    local playerIdx = NetworkGetPlayerIndexFromPed(ped)
    if playerIdx ~= -1 then
        return GetPlayerServerId(playerIdx)
    end

    for _, id in ipairs(GetActivePlayers()) do
        if GetPlayerPed(id) == ped then
            return GetPlayerServerId(id)
        end
    end

    return nil
end

local function resolvePhoto(ped, variant)
    variant = variant or 'mugshot'

    local cid = localCitizenIdIfLocalPed(ped)
    if cid then
        local uri = awaitPhotoByCitizenId(cid, variant)
        return (uri ~= '' and uri) or nil
    end

    local serverId = pedToServerId(ped)
    if not serverId then return nil end

    local uri = awaitPhoto(serverId, variant)
    return (uri ~= '' and uri) or nil
end

_UZ_MUGSHOT = _UZ_MUGSHOT or {}
_UZ_MUGSHOT.awaitPhoto = awaitPhoto
_UZ_MUGSHOT.awaitPhotoByCitizenId = awaitPhotoByCitizenId
_UZ_MUGSHOT.pedToServerId = pedToServerId
_UZ_MUGSHOT.localCitizenIdIfLocalPed = localCitizenIdIfLocalPed
_UZ_MUGSHOT.resolvePhoto = resolvePhoto

exports('GetPhotoDataURI', function(ped, variant)
    return resolvePhoto(ped, variant)
end)

exports('GetPhotoByCitizenId', function(citizenid, variant)
    if type(citizenid) ~= 'string' or citizenid == '' then return nil end
    local uri = awaitPhotoByCitizenId(citizenid, variant or 'mugshot')
    if uri == '' then return nil end
    return uri
end)

