-- Driving targets. The server owns the ped; whichever client owns the entity
-- gives it something to do. Ownership can move mid-chase, so the task is
-- re-applied rather than set once.

local watched = {}

local function taskDriver(ped, data)
    if not DoesEntityExist(ped) then return end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return end

    SetEntityAsMissionEntity(ped, true, true)
    SetPedFleeAttributes(ped, 0, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)

    TaskVehicleDriveWander(ped, vehicle, data.speed or 18.0, data.style or 786603)
end

-- Once they are out they are not getting back in, so the ped stops being our
-- problem and becomes ordinary traffic running away.
local function bail(ped)
    if not DoesEntityExist(ped) then return end

    watched[ped] = nil

    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedKeepTask(ped, false)

    TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
    Wait(900)

    if DoesEntityExist(ped) then
        TaskSmartFleePed(ped, cache.ped, 180.0, -1, false, false)
        SetPedAsNoLongerNeeded(ped)
    end
end

AddStateBagChangeHandler('xsBoostDriver', nil, function(bagName, _, value)
    if not value then return end

    local ped = GetEntityFromStateBagName(bagName)
    if not ped or ped == 0 then return end

    CreateThread(function()
        local waited = 0
        while not DoesEntityExist(ped) and waited < 4000 do
            Wait(150)
            waited = waited + 150
        end

        if not DoesEntityExist(ped) then return end

        watched[ped] = { data = value, still = 0 }
        taskDriver(ped, value)
    end)
end)

-- Watching the car rather than the ped: the driver gives up when it has taken
-- a beating, or when it has been stopped long enough that they know it is
-- over. Either way they get out and run.
CreateThread(function()
    while true do
        Wait(500)

        for ped, entry in pairs(watched) do
            if not DoesEntityExist(ped) then
                watched[ped] = nil
                goto continue
            end

            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle == 0 then
                watched[ped] = nil
                goto continue
            end

            -- Only the owner may task it, and ownership moves around.
            if NetworkHasControlOfEntity(ped) then
                if GetScriptTaskStatus(ped, 0x1DC2B1C4) ~= 1 then
                    taskDriver(ped, entry.data)
                end
            end

            if IsPedDeadOrDying(ped, true) then
                watched[ped] = nil
                goto continue
            end

            local speed = GetEntitySpeed(vehicle)
            entry.still = speed < 1.2 and entry.still + 0.5 or 0

            local hurt = (1000.0 - GetVehicleBodyHealth(vehicle))
            local done = hurt >= (entry.data.bailAtDamage or 250)
                or entry.still >= (entry.data.stoppedSeconds or 4)

            if done and NetworkHasControlOfEntity(ped) then
                local target = ped
                watched[ped] = nil
                CreateThread(function() bail(target) end)
            end

            ::continue::
        end
    end
end)

-- Guards on a contested car. Same handover as the driver: the server makes
-- them, the owning client gives them a weapon and an attitude.
AddStateBagChangeHandler('xsBoostGuard', nil, function(bagName, _, value)
    if not value then return end

    local ped = GetEntityFromStateBagName(bagName)
    if not ped or ped == 0 then return end

    CreateThread(function()
        local waited = 0
        while not DoesEntityExist(ped) and waited < 4000 do
            Wait(150)
            waited = waited + 150
        end

        if not DoesEntityExist(ped) then return end

        local tries = 0
        while not NetworkHasControlOfEntity(ped) and tries < 20 do
            NetworkRequestControlOfEntity(ped)
            Wait(100)
            tries = tries + 1
        end

        if not DoesEntityExist(ped) then return end

        SetEntityAsMissionEntity(ped, true, true)
        GiveWeaponToPed(ped, joaat(value.weapon or 'WEAPON_PISTOL'), 250, false, true)
        SetPedArmour(ped, value.armour or 0)
        SetPedAccuracy(ped, value.accuracy or 40)
        SetPedCombatAbility(ped, 2)
        SetPedCombatRange(ped, 2)
        SetPedCombatMovement(ped, 2)
        SetPedFleeAttributes(ped, 0, false)
        SetPedDropsWeaponsWhenDead(ped, false)
        SetBlockingOfNonTemporaryEvents(ped, true)

        -- Hostile to players generally, not to whoever gets there first.
        SetPedRelationshipGroupHash(ped, joaat('HATES_PLAYER'))
        SetRelationshipBetweenGroups(5, joaat('HATES_PLAYER'), joaat('PLAYER'))

        TaskGuardCurrentPosition(ped, 25.0, 25.0, true)
    end)
end)
