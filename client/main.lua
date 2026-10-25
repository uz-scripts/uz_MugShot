RegisterNetEvent('uz_mugshot:forceCapture', function(opts)
    Capture.Execute(opts or {})
end)

-- Fingerprint watch, works with any clothing/barber script without hooking it.
-- Sent right away on a trigger or when a menu closes, otherwise after settleMs.
local watch = {
    cid = nil,
    confirmed = nil,    -- last fp the server stored
    candidate = nil,
    candidateSince = 0,
    nextPollAt = 0,
    sentFp = nil,
    nextSendAt = 0,     -- retry gate
    blocked = false,
    kicked = false,
}

RegisterNetEvent('uz_mugshot:client:fingerprintStored', function(fp)
    if type(fp) ~= 'string' then return end
    watch.confirmed, watch.nextSendAt = fp, 0
end)

local function sendCheck(fp, now)
    watch.kicked = false
    watch.sentFp = fp
    watch.candidate, watch.candidateSince = fp, now
    watch.nextSendAt = now + Config.FingerprintWatch.retryMs
    TriggerServerEvent('uz_mugshot:client:naturalCheck', fp, Config.NaturalTriggerCurtain == true)
end

local function watchTick()
    if Capture.inProgress or not Bridge.IsPlayerLoaded() then return end

    local cid = Bridge.GetLocalCitizenId()
    if cid ~= watch.cid then
        -- character switch
        watch.cid, watch.confirmed, watch.candidate, watch.nextSendAt = cid, nil, nil, 0
    end

    if not Capture.IsPlain(Config.CaptureGuard.settleMs) then
        watch.candidate, watch.blocked = nil, true
        return
    end

    local cfg = Config.FingerprintWatch
    local now = GetGameTimer()
    local unblocked = watch.blocked
    watch.blocked = false
    if not watch.kicked and not unblocked and now < watch.nextPollAt then return end
    watch.nextPollAt = now + cfg.intervalMs

    local fp = Capture.ComputeMugshotFingerprint()
    if not fp then return end

    if watch.kicked then
        watch.kicked = false
        -- illenium saves twice, skip the duplicate
        if fp == watch.sentFp and now < watch.nextSendAt then return end
        sendCheck(fp, now)
        return
    end

    if not cfg.enabled or fp == watch.confirmed then return end

    -- changed while a menu was open (login goes through settle instead)
    if unblocked and watch.confirmed and now >= watch.nextSendAt then
        sendCheck(fp, now)
        return
    end

    if fp ~= watch.candidate then
        watch.candidate, watch.candidateSince = fp, now
        return
    end
    if now - watch.candidateSince < cfg.settleMs or now < watch.nextSendAt then return end
    sendCheck(fp, now)
end

CreateThread(function()
    while true do
        watchTick()
        Wait(100)
    end
end)

local function requestCheck(triggerName)
    if Config.Debug then
        print('[uz_mugshot] natural trigger fired: ' .. tostring(triggerName))
    end
    SetTimeout(100, function() watch.kicked = true end)
end

CreateThread(function()
    while Bridge.GetFramework() == 'none' do Wait(250) end
    Bridge.RegisterNaturalTriggers(requestCheck)
end)

RegisterNetEvent('uz_mugshot:serverNaturalTrigger', requestCheck)
