Bridge._impl = Bridge._impl or {}

-- Shared object fetched on first use, so this file is safe to load before es_extended.
local ESX
local function esx()
    ESX = ESX or exports['es_extended']:getSharedObject()
    return ESX
end

Bridge._impl.esx = {
    client = {
        IsPlayerLoaded = function()
            local obj = esx()
            if obj.IsPlayerLoaded then
                return obj.IsPlayerLoaded()
            end
            local data = obj.GetPlayerData and obj.GetPlayerData()
            return data and data.identifier ~= nil
        end,

        GetLocalCitizenId = function()
            local obj = esx()
            local data = obj.GetPlayerData and obj.GetPlayerData()
            return data and data.identifier or nil
        end,
    },

    server = {
        GetPlayerIdentifierFromSource = function(source)
            local xPlayer = esx().GetPlayerFromId(source)
            if not xPlayer then return nil end
            return xPlayer.identifier
        end,

        GetSourceFromIdentifier = function(identifier)
            local xPlayer = esx().GetPlayerFromIdentifier(identifier)
            if not xPlayer then return nil end
            return xPlayer.source
        end,
    },
}
