Bridge._impl = Bridge._impl or {}

-- Core object fetched on first use, so this file is safe to load before qb-core.
local QBCore
local function core()
    QBCore = QBCore or exports['qb-core']:GetCoreObject()
    return QBCore
end

Bridge._impl.qbcore = {
    client = {
        IsPlayerLoaded = function()
            local data = core().Functions.GetPlayerData()
            return data and data.citizenid ~= nil
        end,

        GetLocalCitizenId = function()
            local data = core().Functions.GetPlayerData()
            return data and data.citizenid or nil
        end,
    },

    server = {
        GetPlayerIdentifierFromSource = function(source)
            local player = core().Functions.GetPlayer(source)
            if not player then return nil end
            return player.PlayerData and player.PlayerData.citizenid or nil
        end,

        GetSourceFromIdentifier = function(identifier)
            local player = core().Functions.GetPlayerByCitizenId(identifier)
            if not player then return nil end
            return player.PlayerData and player.PlayerData.source or nil
        end,
    },
}
