local config = require 'config.client'
local sharedConfig = require 'config.shared'
local WEAPONS = exports.qbx_core:GetWeapons()

---blocks until ped is no longer moving
function WaitForPlayerToStopMoving()
    Wait(500) -- Maybe I have to wait a tiny bit, sometimes the death state doesn't commit, and people can walk around while dead
    local timeOut = 10000
    while GetEntitySpeed(cache.ped) > 1.0 or IsPedRagdoll(cache.ped) and (GetEntitySpeed(cache.ped) > 0.1) and timeOut > 1 do
        timeOut -= 10
        Wait(10)
    end
end

--- low level GTA resurrection
function ResurrectPlayer()
    local pos = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)

    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, heading, 99999, false)
    if cache.vehicle then
        SetPedIntoVehicle(cache.ped, cache.vehicle, cache.seat)
    else
        SetEntityCoords(cache.ped, pos.x, pos.y, pos.z)
    end

    --ClearPedTasksImmediately(cache.ped)
end

---remove last stand mode from player.
function EndLastStand()
    TaskPlayAnim(cache.ped, LastStandDict, 'exit', 8.0, 8.0, -1, 1, -1, false, false, false)
    LaststandTime = 0
    TriggerServerEvent('qbx_medical:server:onPlayerLaststandEnd')
end

local function logPlayerKiller()
    local killer_2, killerWeapon = NetworkGetEntityKillerOfPlayer(cache.playerId)
    local killer = GetPedSourceOfDeath(cache.ped)

    if killer_2 ~= 0 and killer_2 ~= -1 then
        killer = killer_2
    end

    local killerId = NetworkGetPlayerIndexFromPed(killer)
    local killerName = killerId ~= -1 and (' %s (%d)'):format(GetPlayerName(killerId), GetPlayerServerId(killerId)) or
        Lang:t('info.self_death')
    local weaponItem = WEAPONS[killerWeapon]
    local weaponLabel = Lang:t('info.wep_unknown') or (weaponItem and weaponItem.label)
    local weaponName = Lang:t('info.wep_unknown') or (weaponItem and weaponItem.name)
    local message = Lang:t('logs.death_log_message',
        {
            killername = killerName,
            playername = GetPlayerName(cache.playerId),
            weaponlabel = weaponLabel,
            weaponname =
                weaponName
        })

    lib.callback.await('qbx_medical:server:log', false, 'playerKiller', message)
end

---count down last stand, if last stand is over, put player in death mode and log the killer.
local function countdownLastStand()
    if LaststandTime - 1 > 0 then
        LaststandTime -= 1
    else
        exports.qbx_core:Notify(Lang:t('error.bled_out'), 'error')
        EndLastStand()
        --logPlayerKiller()
        DeathTime = 0
        OnDeath()
        AllowRespawn()
    end
end

---put player in last stand mode and notify EMS.
function StartLastStand()
    if exports["lb-phone"]?.IsOpen and exports["lb-phone"]:IsOpen() then
        exports["lb-phone"]:ToggleOpen(false)
    end

    if lib.progressActive() then
        lib.cancelProgress()
    end

    --Wait(1000)
    WaitForPlayerToStopMoving()

    TriggerEvent('InteractSound_CL:PlayOnOne', 'demo', 0.1)
    LaststandTime = config.laststandReviveInterval
    ResurrectPlayer()
    SetEntityHealth(cache.ped, 150)
    SetDeathState(sharedConfig.deathState.LAST_STAND)

    LocalPlayer.state:set('invBusy', true, false)

    CreateThread(function()
        PlayUnescortedLastStandAnimation(cache.ped)
    end)
    TriggerEvent('qbx_medical:client:onPlayerLaststand')
    TriggerServerEvent('qbx_medical:server:onPlayerLaststand')
    CreateThread(function()
        while DeathState == sharedConfig.deathState.LAST_STAND do
            countdownLastStand()
            Wait(1000)
        end
    end)

    CreateThread(function()
        while DeathState == sharedConfig.deathState.LAST_STAND do
            DisableControls()
            Wait(0)
        end
    end)
end
