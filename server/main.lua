local resourceName = GetCurrentResourceName()

local Queue = {}
Queue._running = 0
Queue._pending = {}

function Queue.Enqueue(fn)
    Queue._pending[#Queue._pending + 1] = fn
    Queue._pump()
end

function Queue._pump()
    while Queue._running < Config.Queue.maxConcurrent and #Queue._pending > 0 do
        local fn = table.remove(Queue._pending, 1)
        Queue._running = Queue._running + 1
        CreateThread(function()
            local ok, err = pcall(fn)
            if not ok then
                print('[uz_mugshot][queue] job error: ' .. tostring(err))
            end
            Queue._running = Queue._running - 1
            Queue._pump()
        end)
    end
end

local function processAndSaveImage(base64Png, options, savePath)
    local p = promise.new()
    exports[resourceName]:ProcessImage(base64Png, options, savePath, function(err, b64Out)
        if err then p:reject(err) else p:resolve(b64Out) end
    end)
    return Citizen.Await(p)
end

local function writeFingerprintAsync(relPath, fp)
    local p = promise.new()
    exports[resourceName]:WriteFingerprint(relPath, fp, function(err)
        p:resolve(err)
    end)
    return Citizen.Await(p)
end

local function readFingerprintAsync(fpRelPath, pngRelPath)
    local p = promise.new()
    exports[resourceName]:ReadFingerprint(fpRelPath, pngRelPath, function(fp)
        p:resolve(fp)
    end)
    return Citizen.Await(p)
end

local function processOptions()
    return {
        threshold = Config.ChromaProcessing.threshold,
        feather = Config.ChromaProcessing.feather,
        matteSoftenRadius = Config.ChromaProcessing.matteSoftenRadius,
        edgeResidual = Config.ChromaProcessing.edgeResidual,
        outputWidth = Config.OutputSize.width,
        outputHeight = Config.OutputSize.height,
        maxBase64Length = Config.InputLimits.maxBase64Length,
        maxWidth = Config.InputLimits.maxWidth,
        maxHeight = Config.InputLimits.maxHeight,
        maxPixels = Config.InputLimits.maxPixels,
        -- debug: keep the unkeyed screenshot for chroma tuning
        saveRaw = Config.Debug == true,
    }
end

RegisterNetEvent('uz_mugshot:processCapture', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end
    if type(payload.variant) ~= 'string' or not Config.Variants[payload.variant] then return end
    if type(payload.imageData) ~= 'string' or #payload.imageData < 100 then return end
    -- +64 for the data URI prefix
    if #payload.imageData > Config.InputLimits.maxBase64Length + 64 then
        print(('[uz_mugshot] oversized capture from source %s rejected (%d bytes)'):format(
            src, #payload.imageData))
        return
    end

    local citizenid = Storage.NormalizeCid(Bridge.GetPlayerIdentifierFromSource(src))
    if not citizenid then return end

    if Limits.CaptureCooling(citizenid) then
        Limits.ClearPending(citizenid)
        if Config.Debug then
            print(('[uz_mugshot] rate-limited capture from %s'):format(citizenid))
        end
        return
    end
    Limits.MarkCapture(citizenid)

    local incomingFp = nil
    if type(payload.fingerprint) == 'string'
        and #payload.fingerprint > 0
        and #payload.fingerprint <= 4096 then
        incomingFp = payload.fingerprint
    end

    Queue.Enqueue(function()
        local savePath = Storage.PathFor(citizenid, payload.variant)

        local ok, processedB64 = pcall(processAndSaveImage,
            payload.imageData, processOptions(), savePath)
        if not ok or not processedB64 or processedB64 == '' then
            Limits.ClearPending(citizenid)
            print(('[uz_mugshot] processing failed for %s: %s'):format(
                citizenid, tostring(processedB64)))
            return
        end

        if incomingFp and payload.variant == 'mugshot' then
            local fpPath = Storage.FingerprintPathFor(citizenid, payload.variant)
            local fpErr = writeFingerprintAsync(fpPath, incomingFp)
            if fpErr then
                if Config.Debug then
                    print(('[uz_mugshot] fingerprint write failed for %s: %s'):format(
                        citizenid, tostring(fpErr)))
                end
            else
                TriggerClientEvent('uz_mugshot:client:fingerprintStored', src, incomingFp)
            end
        end

        Cache.Set(citizenid .. ':' .. payload.variant, processedB64)

        -- clear only after the .fp is written
        Limits.ClearPending(citizenid)

        TriggerEvent('uz_mugshot:captured', citizenid, payload.variant)

        if Config.Debug then
            print(('[uz_mugshot] saved %s/%s'):format(citizenid, payload.variant))
        end
    end)
end)

RegisterNetEvent('uz_mugshot:client:naturalCheck', function(fp, curtain)
    local src = source
    if type(fp) ~= 'string' or #fp < 10 or #fp > 4096 then return end
    if not Limits.TakeRequest(src) then return end

    local citizenid = Storage.NormalizeCid(Bridge.GetPlayerIdentifierFromSource(src))
    if not citizenid then return end

    -- client + server trigger for the same save, capture once
    if Limits.IsPending(citizenid) then
        if Config.Debug then
            print(('[uz_mugshot] natural check: capture already pending for %s'):format(citizenid))
        end
        return
    end

    if Limits.CaptureCooling(citizenid) then
        if Config.Debug then
            print(('[uz_mugshot] natural check rate-limited for %s'):format(citizenid))
        end
        return
    end

    -- mark before the async read
    Limits.MarkPending(citizenid)

    local fpPath = Storage.FingerprintPathFor(citizenid, 'mugshot')
    local pngPath = Storage.PathFor(citizenid, 'mugshot')
    local storedFp = readFingerprintAsync(fpPath, pngPath)

    if storedFp and storedFp == fp then
        Limits.ClearPending(citizenid)
        TriggerClientEvent('uz_mugshot:client:fingerprintStored', src, fp)
        if Config.Debug then
            print(('[uz_mugshot] natural check: no change for %s, skipping'):format(citizenid))
        end
        return
    end

    if Config.Debug then
        print(('[uz_mugshot] natural check: mugshot-visible change for %s, capturing'):format(citizenid))
    end

    TriggerClientEvent('uz_mugshot:forceCapture', src, {
        variant = 'mugshot',
        forceCurtain = curtain == true,
    })
end)

for _, triggerName in ipairs(Config.ServerNaturalTriggers or {}) do
    RegisterNetEvent(triggerName, function()
        local src = source
        if not src or src == 0 then return end
        TriggerClientEvent('uz_mugshot:serverNaturalTrigger', src, triggerName)
    end)
end

-- Optional: multichar/spawn scripts can call TriggerInitialCapture(src) or
-- TriggerEvent('uz_mugshot:initialCapture', src) once the player is in the world.
-- The fingerprint watch covers login anyway, this just skips its settle time.
local initialChecked = {}
local initialCheckedBySource = {}

-- framework may have dropped the player already, use our own map (multichar = several cids)
AddEventHandler('playerDropped', function()
    local src = source
    for cid in pairs(initialCheckedBySource[src] or {}) do
        initialChecked[cid] = nil
    end
    initialCheckedBySource[src] = nil
end)

-- cid may not be ready right after a multichar load
local function resolveCidWithRetry(src, maxWaitMs)
    local waited = 0
    local step = 250
    while waited < maxWaitMs do
        if not GetPlayerName(src) then return nil end
        local cid = Bridge.GetPlayerIdentifierFromSource(src)
        if cid then return cid end
        Wait(step)
        waited = waited + step
    end
    return Bridge.GetPlayerIdentifierFromSource(src)
end

-- Same as a natural check: captures only if the stored fp differs or there is no photo.
local function runInitialCheck(src)
    if not Config.InitialCapture or not Config.InitialCapture.enabled then return end
    if not src or src == 0 then return end

    CreateThread(function()
        local cid = resolveCidWithRetry(src, 10000)
        if not cid then return end
        if initialChecked[cid] then return end
        initialChecked[cid] = true
        initialCheckedBySource[src] = initialCheckedBySource[src] or {}
        initialCheckedBySource[src][cid] = true

        Wait((Config.InitialCapture.delaySeconds or 1) * 1000)
        if not GetPlayerName(src) then
            initialChecked[cid] = nil
            if initialCheckedBySource[src] then
                initialCheckedBySource[src][cid] = nil
            end
            return
        end

        if Config.Debug then
            print(('[uz_mugshot] initial check dispatched for %s'):format(cid))
        end

        TriggerClientEvent('uz_mugshot:serverNaturalTrigger', src, 'initialCapture')
    end)
end

exports('TriggerInitialCapture', function(src)
    src = tonumber(src)
    if not src then return false end
    runInitialCheck(src)
    return true
end)

AddEventHandler('uz_mugshot:initialCapture', function(src)
    runInitialCheck(tonumber(src) or source)
end)

local function reply(src, msg)
    if src == 0 then
        print('[uz_mugshot] ' .. msg)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { '[mugshot]', msg } })
    end
end

-- /remugshot [id]
RegisterCommand(Config.AdminCommand, function(src, args)
    if args[1] and not tonumber(args[1]) then
        reply(src, 'Usage: /' .. Config.AdminCommand .. ' [id]')
        return
    end
    local targetId = tonumber(args[1]) or (src ~= 0 and src or nil)
    if not targetId then
        reply(src, 'Usage from console: ' .. Config.AdminCommand .. ' <id>')
        return
    end
    if not GetPlayerName(targetId) then
        reply(src, 'Player ' .. targetId .. ' is not online')
        return
    end

    Limits.MarkPending(Storage.NormalizeCid(Bridge.GetPlayerIdentifierFromSource(targetId)))
    TriggerClientEvent('uz_mugshot:forceCapture', targetId, {
        variant = 'mugshot',
        forceCurtain = true,
    })
end, true)
