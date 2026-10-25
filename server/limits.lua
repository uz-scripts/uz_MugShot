Limits = Limits or {}

-- not os.clock, that's CPU time on Linux
local captureAt = {}

function Limits.CaptureCooling(citizenid)
    local last = captureAt[citizenid]
    return last ~= nil and GetGameTimer() - last < Config.RateLimitMs
end

function Limits.MarkCapture(citizenid)
    captureAt[citizenid] = GetGameTimer()
end

-- Pending from dispatch until the upload is processed, so one save = one capture.
local pendingUntil = {}
local PENDING_MS = Config.Timing.captureTimeout + 10000

function Limits.MarkPending(citizenid)
    if not citizenid then return end
    pendingUntil[citizenid] = GetGameTimer() + PENDING_MS
end

function Limits.ClearPending(citizenid)
    if not citizenid then return end
    pendingUntil[citizenid] = nil
end

function Limits.IsPending(citizenid)
    local untilMs = pendingUntil[citizenid]
    return untilMs ~= nil and GetGameTimer() < untilMs
end

-- Token bucket per player source for photo requests and natural checks.
local buckets = {}

function Limits.TakeRequest(src)
    local cfg = Config.RequestLimit
    local now = GetGameTimer()
    local bucket = buckets[src]
    if not bucket then
        bucket = { tokens = cfg.burst, at = now }
        buckets[src] = bucket
    else
        bucket.tokens = math.min(cfg.burst, bucket.tokens + (now - bucket.at) * cfg.perSecond / 1000)
        bucket.at = now
    end
    if bucket.tokens < 1 then return false end
    bucket.tokens = bucket.tokens - 1
    return true
end

AddEventHandler('playerDropped', function()
    buckets[source] = nil
end)
