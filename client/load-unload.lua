local config = require 'config.client'

---Initialize health and armor settings on the player's ped
---@param ped number
---@param playerId number
---@param playerMetadata any
local function initHealthAndArmor(ped, playerId, playerMetadata)
    if not playerMetadata then return end

    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, playerMetadata.health)
    SetPlayerHealthRechargeMultiplier(playerId, 0.0)
    SetPlayerHealthRechargeLimit(playerId, 0.0)
    SetPedArmour(ped, playerMetadata.armor)
end

---starts death or last stand based off of player's metadata
---@param metadata any
local function initDeathAndLastStand(metadata)
    if metadata.isdead then
        local doctorCount = lib.callback.await('qbx_ambulancejob:server:getNumDoctors', false)

        if doctorCount < 2 then
            DeathTime = 30
        else
            DeathTime = config.laststandReviveInterval
        end
        OnDeath()
        AllowRespawn()
    elseif metadata.inlaststand then
        StartLastStand()
    end
end

---initialize settings from player object
local function onPlayerLoaded()
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    CreateThread(function()
        Wait(1000)
        initHealthAndArmor(cache.ped, cache.playerId, QBX.PlayerData.metadata)
        initDeathAndLastStand(QBX.PlayerData.metadata)
    end)
end

lib.onCache('ped', function(value)
    if not QBX?.PlayerData?.metadata then return end

    initHealthAndArmor(value, cache.playerId, QBX.PlayerData.metadata)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', onPlayerLoaded)

AddEventHandler('onResourceStart', function(resourceName)
    if cache.resource ~= resourceName then return end
    onPlayerLoaded()
end)
