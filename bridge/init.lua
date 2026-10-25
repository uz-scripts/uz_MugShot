Bridge = Bridge or {}
Bridge._framework = 'none'
Bridge._impl = Bridge._impl or {}

local function detect()
    if Config and Config.Framework and Config.Framework ~= 'auto' then
        return Config.Framework
    end

    if GetResourceState('qbx_core') == 'started' then
        return 'qbox'
    elseif GetResourceState('qb-core') == 'started' then
        return 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then
        return 'esx'
    end

    return 'none'
end

-- Lazy: we can start before the framework, so 'none' is retried on the next call.
function Bridge.Resolve()
    if Bridge._framework ~= 'none' then return true end

    local framework = detect()
    local impl = Bridge._impl[framework]
    if not impl then return false end

    for name, fn in pairs(IsDuplicityVersion() and impl.server or impl.client) do
        Bridge[name] = fn
    end
    Bridge._framework = framework

    if Config and Config.Debug then
        print(('[uz_mugshot][bridge] detected framework: %s'):format(framework))
    end
    return true
end
