Config = {}

-- 'auto' | 'qbox' | 'qbcore' | 'esx'
Config.Framework = 'auto'

Config.Studio = {
    coords = vector3(0.0, 0.0, -150.0),
    heading = 0.0,
}

-- Studio lights, offsets from the ped (-Y camera side, +Y behind, +Z up)
Config.Lighting = {
    { offset = vector3(-0.7, -0.5, 1.9), range = 1.4, intensity = 10.0, r = 255, g = 225, b = 180 },
    { offset = vector3(0.8, -0.4, 0.9),  range = 1.1, intensity = 3.5,  r = 200, g = 220, b = 255 },
    { offset = vector3(0.4, 0.6, 1.8),   range = 1.0, intensity = 6.0,  r = 255, g = 200, b = 140 },
    { offset = vector3(0.0, -0.9, 1.55), range = 0.9, intensity = 2.0,  r = 255, g = 250, b = 240 },
}

Config.Variants = {
    mugshot = {
        fov = 22.0,
        zPos = 0.72,
        dist = 1.15,
        angleH = 0.0,
        roll = 0.0,
        facialMood = 'mood_normal_1',
    },
}

Config.OutputSize = { width = 512, height = 512 }

-- Optional, the fingerprint watch already catches changes. A listed event just
-- runs the check right away. Client events:
Config.NaturalTriggers = {}

-- Server events (relayed to the client that fired them):
Config.ServerNaturalTriggers = {
    'illenium-appearance:server:saveAppearance',
    'fivem-appearance:server:saveAppearance',
    'qb-clothing:saveSkin',
    'esx_skin:save',
}

Config.NaturalTriggerCurtain = true

-- Catches appearance changes from any clothing/barber/skin script.
-- Changes outside a menu must hold for settleMs. enabled = false = triggers only.
Config.FingerprintWatch = {
    enabled = true,
    intervalMs = 1000,
    settleMs = 4000,
    retryMs = 15000,
}

-- Captures wait while a menu, camera, fade, pause menu or cutscene is active.
-- settleMs = extra wait after it closes, timeoutMs = give up (the watch retries).
Config.CaptureGuard = {
    settleMs = 0,
    timeoutMs = 60000,
}

-- Optional: exports['uz_MugShot']:TriggerInitialCapture(source) from your spawn
-- hook (uz_Multicharacter does this). Safe to call on every login.
Config.InitialCapture = {
    enabled = true,
    delaySeconds = 1,
}

Config.Timing = {
    streamingWait = 30,
    stabilizationFrames = 1,
    hatSettleFrames = 8,   -- extra frames when wearing a hat
    curtainFadeIn = 50,    -- NUI CSS transition 30ms + buffer
    captureTimeout = 10000,
}

Config.Queue = {
    maxConcurrent = 2,
}

Config.RateLimitMs = 5000

-- Photo cache budget in megabytes (one 512x512 photo is roughly 0.2-0.3 MB).
Config.CacheMaxMB = 64

-- Per-player rate limit (burst covers a char select or MDT list loading at once).
Config.RequestLimit = {
    burst = 20,
    perSecond = 4,
}

-- Uploaded screenshots above these limits are rejected before decoding.
Config.InputLimits = {
    maxBase64Length = 12 * 1024 * 1024,
    maxWidth = 7680,
    maxHeight = 4320,
    maxPixels = 3840 * 2160 * 2,
}

-- threshold: distance to pure magenta that becomes transparent
-- feather: edge band width (x20), matteSoftenRadius: edge blur (0 = off)
-- edgeResidual: cleans the magenta tint on the outer edge (0 = off)
Config.ChromaProcessing = {
    threshold = 60,
    feather = 2,
    matteSoftenRadius = 1,
    edgeResidual = 16,
}

-- exports['MugShotBase64']:GetMugShotBase64 returns the photo at this size
-- (old scripts store it in item metadata). 512 = full size.
Config.Compat = {
    size = 128,
}

Config.AdminCommand = 'remugshot'

Config.Debug = false
