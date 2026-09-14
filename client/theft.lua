Theft = {}

local alarmActive = false
local attempts = 0

-- Set the moment a hotwire lands, so the hold below lets go straight away
-- rather than waiting for the server to agree the stage has moved on.
local released = false

-- One entry point for every minigame in the resource, so a server owner
-- swapping Config.Minigames swaps all of them at once and nothing else in the
-- client has to know which one is running.
function Theft.Minigame(stage, difficulty)
    local won = Theft.RunMinigame(stage, difficulty)
    Sound.Play(won and 'win' or 'fail')
    return won
end

function Theft.RunMinigame(stage, difficulty)
    local choice = Config.Minigames[stage] or 'builtin'

    if choice == 'custom' then
        local ok, result = pcall(Config.Minigames.custom, difficulty, stage)
        return ok and result == true
    end

    if choice == 'ox_lib' then
        return lib.skillCheck(Config.Minigames.oxLib(difficulty, stage))
    end

    if choice == 'ps-ui' then
        if GetResourceState('ps-ui') ~= 'started' then return false end

        local done = promise.new()
        exports['ps-ui']:Circle(function(success)
            done:resolve(success and true or false)
        end, math.max(1, difficulty), math.max(6, 22 - (difficulty * 3)))

        return Citizen.Await(done)
    end

    return UI.Minigame(stage, difficulty)
end

function Theft.Reset()
    alarmActive = false
    attempts = 0
    released = false
end

local function alarmStart(vehicle)
    if alarmActive then return end

    alarmActive = true
    Sound.Play('alarm')
    TriggerServerEvent('XS-Boosting:server:alarm', true)
    UI.Alert('Alarm going off', 'Silence it at the car before somebody calls it in.', 'warn')

    if DoesEntityExist(vehicle) then
        SetVehicleAlarm(vehicle, true)
        StartVehicleAlarm(vehicle)
    end

    -- Peds nearby notice. This is the cost of a loud entry, separate from
    -- anything the police are told.
    local position = GetEntityCoords(vehicle)
    local radius = Config.Theft.alarm.pedReactRadius

    CreateThread(function()
        local handle, ped = FindFirstPed()
        local ok = true

        repeat
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) and #(GetEntityCoords(ped) - position) <= radius then
                TaskReactAndFleePed(ped, cache.ped)
            end
            ok, ped = FindNextPed(handle)
        until not ok

        EndFindPed(handle)
    end)
end

local function alarmStop(vehicle)
    if not alarmActive then return end

    alarmActive = false
    TriggerServerEvent('XS-Boosting:server:alarm', false)

    if DoesEntityExist(vehicle) then
        SetVehicleAlarm(vehicle, false)
        SetVehicleAlarmTimeLeft(vehicle, 0)
    end
end

function Theft.AlarmActive()
    return alarmActive
end

function Theft.Silence()
    local vehicle = Boost.Vehicle()
    if not vehicle or not alarmActive then return end

    Contract.SetBusy(true)

    local done = lib.progressBar({
        duration = Config.Theft.alarm.seconds * 1000,
        label = 'Killing the alarm',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    if done then
        alarmStop(vehicle)
        Boost.Notify('Quiet again.', 'success')
        UI.Alert('Alarm off', 'Nobody heard that one.', 'good')
    end

    Contract.SetBusy(false)
end

function Theft.Entry(method)
    local job = Boost.job
    local vehicle = Boost.Vehicle()
    if not job or not vehicle then return end

    local config = Config.Theft.entry
    if not config.enabled then
        TriggerServerEvent('XS-Boosting:server:entered', 'none')
        return
    end

    local settings = config.methods[method]
    if not settings or not settings.enabled then
        Boost.Notify('You cannot do it that way here.', 'error')
        return
    end

    Contract.SetBusy(true)

    if method == 'smash' then
        local done = lib.progressBar({
            duration = settings.seconds * 1000,
            label = 'Breaking the window',
            canCancel = true,
            disable = { move = true, car = true, combat = true },
        })

        if done then
            SmashVehicleWindow(vehicle, 0)
            SetVehicleDoorsLocked(vehicle, 1)

            if job.fitted.alarm and settings.alwaysAlarms then
                alarmStart(vehicle)
            end

            TriggerServerEvent('XS-Boosting:server:entered', 'smash')
            Sound.Play('stage')
        end

        Contract.SetBusy(false)
        return
    end

    if settings.item and settings.item ~= '' then
        local has = lib.callback.await('XS-Boosting:hasItem', false, settings.item)
        if not has then
            Boost.Notify('You need a lockpick for that.', 'error')
            Contract.SetBusy(false)
            return
        end
    end

    local started = lib.progressBar({
        duration = settings.seconds * 1000,
        label = 'Working the lock',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    if not started then
        Contract.SetBusy(false)
        return
    end

    local won = Theft.Minigame('entry', Tiers.Difficulty(job.tier, 'lock'))

    if won then
        SetVehicleDoorsLocked(vehicle, 1)
        Sound.Play('stage')
        TriggerServerEvent('XS-Boosting:server:entered', 'lockpick')
        TriggerServerEvent('XS-Boosting:server:toolUsed', 'lockpick')
    else
        Boost.Notify('It did not give.', 'error')

        if job.fitted.alarm and math.random(100) <= settings.failAlarmChance then
            alarmStart(vehicle)
        end

        TriggerServerEvent('XS-Boosting:server:toolUsed', 'lockpick')
        Wait(settings.failPenaltySeconds * 1000)
    end

    Contract.SetBusy(false)
end

-- Done from the driver's seat and over several goes, because one lucky press
-- should not be worth a car. Every round has to land.
function Theft.Hotwire()
    local job = Boost.job
    local vehicle = Boost.Vehicle()
    if not job or not vehicle then return end

    local settings = Config.Theft.hotwire

    if not settings.enabled then
        released = true
        SetVehicleEngineOn(vehicle, true, true, false)
        TriggerServerEvent('XS-Boosting:server:started')
        return
    end

    if settings.maxAttempts > 0 and attempts >= settings.maxAttempts then
        Boost.Notify('You have burnt it out.', 'error')
        return
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then
        Boost.Notify('Get behind the wheel first.', 'error')
        return
    end

    Contract.SetBusy(true)
    attempts = attempts + 1

    local rounds = math.max(1, settings.rounds or 1)
    local difficulty = Tiers.Difficulty(job.tier, 'lock')
    local won = true

    for round = 1, rounds do
        local label = rounds > 1
            and ('Hotwiring (%d/%d)'):format(round, rounds)
            or 'Hotwiring'

        local started = lib.progressBar({
            duration = math.floor((settings.seconds * 1000) / rounds),
            label = label,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
        })

        if not started then
            Contract.SetBusy(false)
            return
        end

        if not Theft.Minigame('hotwire', difficulty) then
            won = false
            break
        end

        -- A little feedback between rounds so progress is felt, not guessed.
        if round < rounds then
            Sound.Play('stage')
            Boost.Notify(('Got one. %d to go.'):format(rounds - round), 'inform')
        end
    end

    if won then
        released = true
        SetVehicleNeedsToBeHotwired(vehicle, false)
        SetVehicleEngineOn(vehicle, true, true, false)
        SetVehicleDoorsLocked(vehicle, 1)
        alarmStop(vehicle)
        Sound.Play('stage')
        Boost.Notify('It caught. Keys are yours.', 'success')
        TriggerServerEvent('XS-Boosting:server:started')
    else
        Boost.Notify('It would not catch. Start again.', 'error')
        Wait(settings.failPenaltySeconds * 1000)
    end

    Contract.SetBusy(false)
end

-- Nothing holds a stolen car shut on its own, and this is what made hotwiring
-- skippable: SetVehicleNeedsToBeHotwired only delays GTA's own start by a few
-- seconds and then the engine catches by itself, and a keys resource will hand
-- an unowned car to whoever sits in it. Either way you drive off without ever
-- hotwiring anything.
--
-- So until the hotwire lands the engine is held off every frame and the
-- throttle is dead. Local to each client, because each one is holding its own
-- copy of a car it may or may not own.
CreateThread(function()
    while true do
        local wait = 500
        local job = Boost.job

        if job and not job.heist and not released
            and (job.stage == 'search' or job.stage == 'entry') then
            local vehicle = Boost.Vehicle()

            if vehicle and GetPedInVehicleSeat(vehicle, -1) == cache.ped then
                wait = 0
                SetVehicleEngineOn(vehicle, false, true, true)
                SetVehicleNeedsToBeHotwired(vehicle, true)
                DisableControlAction(0, 71, true)
            end
        end

        Wait(wait)
    end
end)

-- The prompt only exists in the driver's seat of the right car, which is why
-- hotwiring is not a target option like everything else on the vehicle.
CreateThread(function()
    local showing = false

    local function prompt(text)
        if showing == text then return end
        showing = text

        if text then
            lib.showTextUI(text, { position = 'left-center' })
        else
            lib.hideTextUI()
        end
    end

    while true do
        local wait = 700
        local job = Boost.job

        if job and not job.heist and job.stage == 'entry' and not Contract.Busy() and not UI.IsOpen() then
            local vehicle = Boost.Vehicle()

            if vehicle and GetPedInVehicleSeat(vehicle, -1) == cache.ped then
                wait = 0
                prompt('[E]  Hotwire it')

                if IsControlJustReleased(0, 38) then
                    prompt(nil)
                    Theft.Hotwire()
                end
            else
                prompt(nil)
            end
        else
            prompt(nil)
        end

        Wait(wait)
    end
end)

