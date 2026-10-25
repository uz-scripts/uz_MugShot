Bridge._impl = Bridge._impl or {}

-- exports are looked up per call, so this file is safe to load before qbx_core.
Bridge._impl.qbox = {
    client = {
        IsPlayerLoaded = function()
            local data = exports.qbx_core:GetPlayerData()
            return data and data.citizenid ~= nil
        end,

        GetLocalCitizenId = function()
            local data = exports.qbx_core:GetPlayerData()
            return data and data.citizenid or nil
        end,
    },

    server = {
        GetPlayerIdentifierFromSource = function(source)
            local player = exports.qbx_core:GetPlayer(source)
            if not player then return nil end
            return player.PlayerData and player.PlayerData.citizenid or nil
        end,

        GetSourceFromIdentifier = function(identifier)
            local player = exports.qbx_core:GetPlayerByCitizenId(identifier)
            if not player then return nil end
            return player.PlayerData and player.PlayerData.source or nil
        end,
    },
}
