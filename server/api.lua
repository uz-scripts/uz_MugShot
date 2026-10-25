local resourceName = GetCurrentResourceName()
local inflight = {}

-- photos are ~0.2-0.3 MB, send them latent
local PHOTO_RESULT_BPS = 2000000

local function encodePhotoNode(relativePath)
    local p = promise.new()
    exports[resourceName]:EncodePhoto(relativePath, function(err, b64)
        if err then
            if Config.Debug then
                print('[uz_mugshot] EncodePhoto error: ' .. tostring(err))
            end
            p:resolve(nil)
        else
            p:resolve(b64)
        end
    end)
    return Citizen.Await(p)
end

local function fileExistsNode(relativePath)
    local p = promise.new()
    exports[resourceName]:FileExists(relativePath, function(exists)
        p:resolve(exists == true)
    end)
    return Citizen.Await(p)
end

-- Raw identifier (ESX ids contain ':'), normalized only for paths and cache keys.
local function resolveIdentifier(identifier)
    if type(identifier) == 'string' and identifier ~= '' then
        return identifier
    end
    if type(identifier) == 'number' then
        return Bridge.GetPlayerIdentifierFromSource(identifier)
    end
    return nil
end

local function photoDataUri(citizenid, variant)
    if type(variant) ~= 'string' or not Config.Variants[variant] then
        variant = 'mugshot'
    end
    local cid = Storage.NormalizeCid(citizenid)
    if not cid then return nil end
    local key = cid .. ':' .. variant
    local prefix = 'data:image/png;base64,'

    local cached = Cache.Get(key)
    if cached and cached.data then
        return prefix .. cached.data
    end

    if inflight[key] then
        local b64 = Citizen.Await(inflight[key])
        if not b64 or b64 == '' then return nil end
        return prefix .. b64
    end

    local p = promise.new()
    inflight[key] = p
    local version = Cache.Version(key)

    -- clear inflight even if this throws
    local ok, b64 = pcall(encodePhotoNode, Storage.PathFor(cid, variant))
    if not ok then
        print(('[uz_mugshot] EncodePhoto call failed for %s: %s'):format(key, tostring(b64)))
        b64 = nil
    end
    inflight[key] = nil
    p:resolve(b64)

    if not b64 or b64 == '' then return nil end

    -- a newer capture landed during the read
    if Cache.Version(key) == version then
        Cache.Set(key, b64)
    else
        local newer = Cache.Get(key)
        if newer and newer.data then b64 = newer.data end
    end
    return prefix .. b64
end

_UZ_MUGSHOT_SERVER = _UZ_MUGSHOT_SERVER or {}
_UZ_MUGSHOT_SERVER.photoDataUri = photoDataUri

exports('GetPhotoDataURI', function(identifier, variant)
    local id = resolveIdentifier(identifier)
    if not id then return nil end
    return photoDataUri(id, variant)
end)

exports('ForceRecapture', function(identifier, opts)
    local id = resolveIdentifier(identifier)
    if not id then return false end
    local src = Bridge.GetSourceFromIdentifier(id)
    if not src then return false end

    if type(opts) == 'string' then opts = { variant = opts } end
    opts = opts or {}

    local variant = opts.variant or 'mugshot'
    if not Config.Variants[variant] then return false end

    Limits.MarkPending(Storage.NormalizeCid(id))
    TriggerClientEvent('uz_mugshot:forceCapture', src, {
        variant = variant,
        forceCurtain = true,
    })
    return true
end)

exports('HasPhoto', function(identifier, variant)
    local cid = Storage.NormalizeCid(resolveIdentifier(identifier))
    if not cid then return false end
    variant = variant or 'mugshot'
    if not Config.Variants[variant] then return false end

    local key = cid .. ':' .. variant
    if Cache.Get(key) then return true end
    return fileExistsNode(Storage.PathFor(cid, variant))
end)

local captureWaiters = {}

AddEventHandler('uz_mugshot:captured', function(cid, variant)
    local key = cid .. ':' .. variant
    local waiters = captureWaiters[key]
    if not waiters then return end
    captureWaiters[key] = nil
    local uri = photoDataUri(cid, variant)
    for _, waiter in ipairs(waiters) do
        waiter(uri)
    end
end)

local function sendPhotoResult(src, nonce, uri)
    if uri and uri ~= '' then
        TriggerLatentClientEvent('uz_mugshot:client:photoResult', src, PHOTO_RESULT_BPS, nonce, uri)
    else
        TriggerClientEvent('uz_mugshot:client:photoResult', src, nonce, '')
    end
end

RegisterNetEvent('uz_mugshot:client:requestPhoto', function(nonce, targetServerId, variant)
    local src = source
    if type(nonce) ~= 'number' then return end
    if not Limits.TakeRequest(src) then
        sendPhotoResult(src, nonce, nil)
        return
    end
    local cid = type(targetServerId) == 'number' and Bridge.GetPlayerIdentifierFromSource(targetServerId) or nil
    sendPhotoResult(src, nonce, cid and photoDataUri(cid, variant))
end)

RegisterNetEvent('uz_mugshot:client:requestPhotoByCitizenId', function(nonce, citizenid, variant)
    local src = source
    if type(nonce) ~= 'number' then return end
    if not Limits.TakeRequest(src) then
        sendPhotoResult(src, nonce, nil)
        return
    end
    sendPhotoResult(src, nonce, photoDataUri(citizenid, variant))
end)

exports('CaptureAndReturn', function(identifier, opts, timeoutMs)
    local id = resolveIdentifier(identifier)
    local cid = Storage.NormalizeCid(id)
    if not cid then return nil end
    local src = Bridge.GetSourceFromIdentifier(id)
    if not src then return nil end

    if type(opts) == 'string' then opts = { variant = opts } end
    opts = opts or {}

    local variant = opts.variant or 'mugshot'
    if not Config.Variants[variant] then return nil end

    local key = cid .. ':' .. variant
    timeoutMs = timeoutMs or 15000

    local p = promise.new()
    local settled = false
    local function settle(uri)
        if settled then return end
        settled = true
        p:resolve(uri)
    end

    -- notify every waiter
    captureWaiters[key] = captureWaiters[key] or {}
    table.insert(captureWaiters[key], settle)

    Limits.MarkPending(cid)
    TriggerClientEvent('uz_mugshot:forceCapture', src, {
        variant = variant,
        forceCurtain = opts.curtain ~= false,
    })

    SetTimeout(timeoutMs, function()
        if settled then return end
        local waiters = captureWaiters[key]
        if waiters then
            for i, waiter in ipairs(waiters) do
                if waiter == settle then
                    table.remove(waiters, i)
                    break
                end
            end
            if #waiters == 0 then captureWaiters[key] = nil end
        end
        settle(nil)
    end)

    return Citizen.Await(p)
end)
