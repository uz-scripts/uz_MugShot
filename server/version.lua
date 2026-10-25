local resourceName = GetCurrentResourceName()
local currentVersion = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0'
local RELEASE_API = 'https://api.github.com/repos/uz-scripts/uz_MugShot/releases/latest'
local RELEASE_URL = 'https://github.com/uz-scripts/uz_MugShot/releases/latest'

-- 'v1.2.10' -> { 1, 2, 10 }
local function parse(v)
    local t = {}
    for n in tostring(v):gmatch('%d+') do t[#t + 1] = tonumber(n) end
    return t
end

local function isNewer(a, b)
    local x, y = parse(a), parse(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end

CreateThread(function()
    Wait(1400)
    if resourceName ~= 'uz_MugShot' then
        print(('^1[uz_MugShot] The resource folder must be named "uz_MugShot" (current: "%s"). Rename it and restart the server.^0')
            :format(resourceName))
        StopResource(resourceName)
        return
    end

    PerformHttpRequest(RELEASE_API, function(status, body)
        local ok, data = pcall(json.decode, body or '')
        local latest = status == 200 and ok and type(data) == 'table' and data.tag_name
        if type(latest) ~= 'string' then
            if Config.Debug then
                print(('[uz_MugShot] version check failed (HTTP %s)'):format(tostring(status)))
            end
            return
        end
        if isNewer(latest, currentVersion) then
            print(('^3[uz_MugShot] New version available: %s (current: v%s) %s^0')
                :format(latest, currentVersion, RELEASE_URL))
        else
            print(('^2[uz_MugShot] Up to date (v%s)^0'):format(currentVersion))
        end
    end, 'GET', '', { ['User-Agent'] = 'uz_MugShot', ['Accept'] = 'application/vnd.github+json' })
end)
