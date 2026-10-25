Bridge = Bridge or {}
Bridge._naturalCallbacks = Bridge._naturalCallbacks or {}

-- Defaults until Bridge.Resolve() finds the framework.
local function deferred(name, fallback)
    local wrapper
    wrapper = function(...)
        if Bridge.Resolve() and Bridge[name] ~= wrapper then
            return Bridge[name](...)
        end
        return fallback
    end
    Bridge[name] = wrapper
end

deferred('IsPlayerLoaded', false)
deferred('GetLocalCitizenId', nil)
deferred('GetPlayerIdentifierFromSource', nil)
deferred('GetSourceFromIdentifier', nil)

function Bridge.RegisterNaturalTriggers(callback)
    if IsDuplicityVersion() then return end

    table.insert(Bridge._naturalCallbacks, callback)

    if not Config or not Config.NaturalTriggers then return end

    for _, trigger in ipairs(Config.NaturalTriggers) do
        AddEventHandler(trigger, function()
            for _, cb in ipairs(Bridge._naturalCallbacks) do
                local ok, err = pcall(cb, trigger)
                if not ok and Config.Debug then
                    print('[uz_mugshot][bridge] natural cb err: ' .. tostring(err))
                end
            end
        end)
    end
end

function Bridge.GetFramework()
    Bridge.Resolve()
    return Bridge._framework
end

-- warn loudly, nothing works without a framework
if IsDuplicityVersion() then
    CreateThread(function()
        Wait(10000)
        if Bridge.GetFramework() == 'none' then
            print(('^3[uz_mugshot] WARNING: no framework detected (Config.Framework = %s). '
                .. 'Photos cannot be captured or served. Start qbx_core, qb-core or es_extended, '
                .. 'or set Config.Framework explicitly.^0'):format(tostring(Config.Framework)))
        end
    end)
end
