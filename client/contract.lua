Contract = {}

local busy = false
local boundVehicle
local placeIds = {}
local buyerId
local heistSiteId

local function stage()
    return Boost.job and Boost.job.stage or nil
end

function Contract.Busy()
    return busy
end

function Contract.SetBusy(value)
    busy = value and true or false
end

function Contract.OnStage(name)
    if name == 'transit' then
        Boost.Notify('It is running. Get it where it needs to go.', 'success')
    end
end

function Contract.ClearVehicle(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    SetVehicleDoorsLocked(entity, 1)

    -- The server deletes it a moment after this, and deleting a car out from
    -- under somebody still sat in it drops them through the world.
    if GetVehiclePedIsIn(cache.ped, false) == entity then
        TaskLeaveVehicle(cache.ped, entity, 16)
    end
end

local function nearestPlace(kinds, range)
    local position = GetEntityCoords(cache.ped)
    local best, bestKind, bestDistance

    for _, place in ipairs(Boost.locations) do
        if kinds[place.kind] then
            local coords = vector3(place.coords.x, place.coords.y, place.coords.z)
            local distance = #(position - coords)

            if distance <= (range or place.radius) and (not bestDistance or distance < bestDistance) then
                best, bestKind, bestDistance = place, place.kind, distance
            end
        end
    end

    return best, bestKind
end

-- Is the car itself close enough to a point to be handed over there? Standing
-- at the buyer without the car is not a delivery.
local function carAt(coords, radius)
    local vehicle = Boost.Vehicle()
    if not vehicle then return false end

    return #(GetEntityCoords(vehicle) - coords) <= (radius or 12.0)
end

function Contract.Deliver(route)
    if busy then return end
    Contract.SetBusy(true)

    local label = route == 'buyer' and 'Handing it over'
        or (route == 'chop' and 'Chopping it' or 'Making the call')
    local seconds = route == 'buyer' and Config.Disposal.buyer.handoverSeconds or 3

    local done = lib.progressBar({
        duration = seconds * 1000,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    if not done then
        Contract.SetBusy(false)
        return
    end

    local ok, reason = lib.callback.await('XS-Boosting:deliver', false, route)
    Contract.SetBusy(false)

    if not ok and reason then Boost.Notify(reason, 'error') end
end

-- ── The car ──────────────────────────────────────────────────────────────
-- Every interaction with the target vehicle is an option on the vehicle
-- itself, so it reads the same as anything else on the server.

local function vehicleOptions()
    return {
        {
            name = 'xsboost_lockpick',
            label = 'Force the lock',
            icon = 'fa-solid fa-key',
            distance = 2.5,
            canInteract = function()
                return not busy and stage() == 'search'
                    and not (Boost.job and Boost.job.driving)
                    and Config.Theft.entry.enabled
                    and Config.Theft.entry.methods.lockpick.enabled
            end,
            onSelect = function() Theft.Entry('lockpick') end,
        },
        {
            name = 'xsboost_smash',
            label = 'Break the window',
            icon = 'fa-solid fa-hammer',
            distance = 2.5,
            canInteract = function()
                return not busy and stage() == 'search'
                    and not (Boost.job and Boost.job.driving)
                    and Config.Theft.entry.enabled
                    and Config.Theft.entry.methods.smash.enabled
            end,
            onSelect = function() Theft.Entry('smash') end,
        },
        {
            name = 'xsboost_alarm',
            label = 'Silence the alarm',
            icon = 'fa-solid fa-bell-slash',
            distance = 3.0,
            canInteract = function()
                return not busy and Theft.AlarmActive()
            end,
            onSelect = function() Theft.Silence() end,
        },
        {
            name = 'xsboost_tracker',
            label = 'Pull the tracker',
            icon = 'fa-solid fa-satellite-dish',
            distance = 2.5,
            canInteract = function()
                local job = Boost.job
                return not busy and stage() == 'transit'
                    and job and job.fitted and job.fitted.tracker
                    and job.tracker and job.tracker.alive
            end,
            onSelect = function() Tracker.Kill(false) end,
        },
        {
            name = 'xsboost_strip',
            label = 'Strip a part',
            icon = 'fa-solid fa-screwdriver-wrench',
            distance = 3.0,
            canInteract = function()
                if busy or stage() ~= 'transit' then return false end
                return nearestPlace({ chop = true }) ~= nil
            end,
            onSelect = function() Chop.Strip() end,
        },
    }
end

function Contract.BindVehicle(vehicle)
    if boundVehicle == vehicle then return end

    Contract.UnbindVehicle()
    if not vehicle or not DoesEntityExist(vehicle) then return end

    boundVehicle = vehicle
    Target.AddEntity('xsboost_car', vehicle, vehicleOptions(), 3.0)
end

function Contract.UnbindVehicle()
    if not boundVehicle then return end

    Target.Remove('xsboost_car')
    boundVehicle = nil
end

-- ── Places ───────────────────────────────────────────────────────────────
-- Chop shops, fences and dead zones are fixed points, so they get their zone
-- once. What each one offers is decided when it is looked at.

function Contract.BindPlaces()
    for _, id in ipairs(placeIds) do Target.Remove(id) end
    placeIds = {}

    for _, place in ipairs(Boost.locations) do
        local coords = vector3(place.coords.x, place.coords.y, place.coords.z)
        local id = ('xsboost_place_%s'):format(place.id)
        local radius = place.radius
        local options

        if place.kind == 'chop' and Config.Disposal.chopShop.enabled then
            options = {
                {
                    name = id .. '_in',
                    label = 'Hand in the parts',
                    icon = 'fa-solid fa-box-open',
                    canInteract = function()
                        local job = Boost.job
                        return not busy and job and job.type == 'chop'
                            and job.stage == 'transit'
                            and carAt(coords, radius)
                    end,
                    onSelect = function() Contract.Deliver('chop') end,
                },
                {
                    name = id .. '_chop',
                    label = 'Chop the car',
                    icon = 'fa-solid fa-car-burst',
                    canInteract = function()
                        local job = Boost.job
                        return not busy and job and job.type ~= 'chop'
                            and job.stage == 'transit'
                            and carAt(coords, radius)
                    end,
                    onSelect = function() Contract.Deliver('chop') end,
                },
            }
        elseif place.kind == 'fence' and Config.Disposal.fence.enabled then
            options = {
                {
                    name = id .. '_fence',
                    label = 'Sell it on',
                    icon = 'fa-solid fa-hand-holding-dollar',
                    canInteract = function()
                        local job = Boost.job
                        return not busy and job and job.stage == 'transit'
                            and carAt(coords, radius)
                    end,
                    onSelect = function() Contract.Deliver('fence') end,
                },
            }
        elseif place.kind == 'lockup' and Config.Disposal.lockup.enabled then
            local lockup = Config.Disposal.lockup
            options = {}

            if lockup.stash.enabled then
                options[#options + 1] = {
                    name = id .. '_stash',
                    label = 'Park it here',
                    icon = 'fa-solid fa-warehouse',
                    canInteract = function()
                        local job = Boost.job
                        return not busy and job and not job.heist
                            and job.stage == 'transit' and carAt(coords, radius)
                    end,
                    onSelect = function() Contract.Stash() end,
                }

                options[#options + 1] = {
                    name = id .. '_take',
                    label = 'Take one out',
                    icon = 'fa-solid fa-key',
                    canInteract = function() return not busy and not Boost.job end,
                    onSelect = function() Contract.Retrieve(place.id) end,
                }
            end

            if lockup.keep.enabled then
                options[#options + 1] = {
                    name = id .. '_keep',
                    label = 'Keep it for yourself',
                    icon = 'fa-solid fa-file-signature',
                    canInteract = function()
                        local job = Boost.job
                        return not busy and job and not job.heist
                            and job.stage == 'transit' and carAt(coords, radius)
                    end,
                    onSelect = function() Contract.Keep() end,
                }
            end

        elseif place.kind == 'deadzone' and Config.Theft.tracker.deadZonesAllowed then
            options = {
                {
                    name = id .. '_wipe',
                    label = 'Wipe the tracker',
                    icon = 'fa-solid fa-tower-broadcast',
                    canInteract = function()
                        local job = Boost.job
                        return not busy and job and job.fitted and job.fitted.tracker
                            and job.tracker and job.tracker.alive
                    end,
                    onSelect = function() Tracker.Kill(true) end,
                },
            }
        end

        if options then
            Target.AddSphere(id, coords, radius, options)
            placeIds[#placeIds + 1] = id
        end
    end
end

-- ── The lockup ───────────────────────────────────────────────────────────

function Contract.Stash()
    if busy then return end
    Contract.SetBusy(true)

    local done = lib.progressBar({
        duration = Config.Disposal.lockup.stash.seconds * 1000,
        label = 'Putting it away',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    if not done then
        Contract.SetBusy(false)
        return
    end

    local ok, reason = lib.callback.await('XS-Boosting:stash', false)
    Contract.SetBusy(false)

    if not ok then
        Boost.Notify(reason or 'That did not work.', 'error')
    else
        Sound.Play('stage')
        Boost.Notify('Parked. The clock is stopped until you come back.', 'success')
    end
end

function Contract.Retrieve(locationId)
    if busy then return end

    local stored = lib.callback.await('XS-Boosting:stored', false, locationId)

    if not stored or #stored == 0 then
        Boost.Notify('You have nothing parked here.', 'inform')
        return
    end

    local options = {}
    for index, entry in ipairs(stored) do
        options[index] = {
            value = entry.id,
            label = ('%s · %s · %d%% · %s left'):format(
                entry.label, entry.plate, entry.condition,
                ('%d:%02d'):format(math.floor(entry.remaining / 60), entry.remaining % 60)),
        }
    end

    local picked = lib.inputDialog('Lockup', {
        { type = 'select', label = 'Which one', options = options, required = true },
    })

    if not picked or not picked[1] then return end

    Contract.SetBusy(true)

    local done = lib.progressBar({
        duration = 4000,
        label = 'Getting it out',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    if not done then
        Contract.SetBusy(false)
        return
    end

    local ok, reason = lib.callback.await('XS-Boosting:retrieve', false, picked[1])
    Contract.SetBusy(false)

    if not ok then
        Boost.Notify(reason or 'That did not work.', 'error')
    else
        Sound.Play('accept')
        Boost.Notify('Back on the clock.', 'success')
    end
end

function Contract.Keep()
    if busy then return end

    local keep = Config.Disposal.lockup.keep

    local confirm = lib.alertDialog({
        header = 'Keep it',
        content = ([[Cleaning the VIN costs **$%s** and loses you **%d rep**. Nobody who ordered it gets paid, and you get nothing for the job.

The car goes into your garage.]]):format(keep.fee, keep.repPenalty),
        centered = true,
        cancel = true,
        labels = { confirm = 'Keep it', cancel = 'Never mind' },
    })

    if confirm ~= 'confirm' then return end

    Contract.SetBusy(true)

    local done = lib.progressBar({
        duration = keep.seconds * 1000,
        label = 'Cleaning the VIN',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    if not done then
        Contract.SetBusy(false)
        return
    end

    local ok, reason = lib.callback.await('XS-Boosting:keep', false)
    Contract.SetBusy(false)

    if not ok then
        Boost.Notify(reason or 'That did not work.', 'error')
    else
        Sound.Play('paid')
        Boost.Notify('It is yours. Try not to park it outside a police station.', 'success')
    end
end

-- ── Points that belong to one job ────────────────────────────────────────

local buyerPed

local function clearBuyerPed()
    if buyerPed and DoesEntityExist(buyerPed) then DeleteEntity(buyerPed) end
    buyerPed = nil
end

-- Somebody has to take it off you. The buyer turns up at the handover point
-- while the job is running and is gone with it afterwards, so the drop is a
-- person you talk to rather than a circle you stand in.
local function bindBuyer(state)
    if buyerId then
        Target.Remove(buyerId)
        buyerId = nil
    end

    if not state or not state.buyer then
        clearBuyerPed()
        return
    end

    local coords = vector3(state.buyer.x, state.buyer.y, state.buyer.z)
    local radius = state.buyerRadius or 12.0
    local settings = Config.Disposal.buyer

    local options = {
        {
            name = 'xsboost_handover',
            label = 'Hand it over',
            icon = 'fa-solid fa-handshake',
            distance = 3.0,
            canInteract = function()
                return not busy and stage() == 'transit' and carAt(coords, radius)
            end,
            onSelect = function() Contract.Deliver('buyer') end,
        },
    }

    if settings.ped.enabled then
        CreateThread(function()
            clearBuyerPed()

            local model = joaat(settings.ped.model)
            if not lib.requestModel(model, 8000) then return end

            local ground = coords.z
            local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
            if found then ground = z end

            buyerPed = CreatePed(4, model, coords.x, coords.y, ground, 0.0, false, false)
            SetModelAsNoLongerNeeded(model)

            if not DoesEntityExist(buyerPed) then return end

            SetEntityInvincible(buyerPed, true)
            SetBlockingOfNonTemporaryEvents(buyerPed, true)
            FreezeEntityPosition(buyerPed, true)
            SetPedCanRagdoll(buyerPed, false)

            if settings.ped.scenario and settings.ped.scenario ~= '' then
                TaskStartScenarioInPlace(buyerPed, settings.ped.scenario, 0, true)
            end

            buyerId = 'xsboost_buyer'
            Target.AddEntity(buyerId, buyerPed, options, 3.0)
        end)

        return
    end

    buyerId = 'xsboost_buyer'
    Target.AddSphere(buyerId, coords, radius, options)
end

local function bindHeistSite(state)
    if heistSiteId then
        Target.Remove(heistSiteId)
        heistSiteId = nil
    end

    if not state or not state.heist or not state.site then return end

    local coords = vector3(state.site.x, state.site.y, state.site.z)
    heistSiteId = 'xsboost_heistsite'

    Target.AddSphere(heistSiteId, coords, state.siteRadius or 20.0, {
        {
            name = 'xsboost_heistgo',
            label = 'Start the job',
            icon = 'fa-solid fa-play',
            canInteract = function()
                local job = Boost.job
                return not busy and job and job.heist and job.stage == 'staging'
            end,
            onSelect = function()
                Contract.SetBusy(true)
                local ok, reason = lib.callback.await('XS-Boosting:heistBegin', false)
                if not ok and reason then Boost.Notify(reason, 'error') end
                Contract.SetBusy(false)
            end,
        },
    })
end

function Contract.Sync(state)
    bindBuyer(state)
    bindHeistSite(state)

    if not state then Contract.UnbindVehicle() end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearBuyerPed() end
end)

-- ── Threads ──────────────────────────────────────────────────────────────
-- Only two things still need a loop: keeping the car's target attached as it
-- spawns or changes owner, and the heist exit, which has to work from the
-- driver's seat and so cannot be a target at all.

CreateThread(function()
    while true do
        Wait(1000)

        if Boost.HasJob() and not Boost.job.heist then
            local vehicle = Boost.Vehicle()

            if vehicle then
                Contract.BindVehicle(vehicle)
            else
                Contract.UnbindVehicle()
            end
        else
            Contract.UnbindVehicle()
        end
    end
end)

CreateThread(function()
    local dwell = 0

    while true do
        local wait = 1000
        local job = Boost.job

        if job and job.heist and job.stage == 'running' and job.exit then
            local ped = cache.ped
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                local exit = vector3(job.exit.x, job.exit.y, job.exit.z)

                if #(GetEntityCoords(vehicle) - exit) <= (job.exitRadius or 15.0) then
                    wait = 250
                    dwell = dwell + 250

                    if dwell >= 1500 and not busy then
                        dwell = 0
                        Contract.SetBusy(true)

                        local ok, reason = lib.callback.await('XS-Boosting:heistDeliver', false)
                        if not ok and reason then Boost.Notify(reason, 'error') end

                        Contract.SetBusy(false)
                        Wait(2000)
                    end
                else
                    dwell = 0
                end
            else
                dwell = 0
            end
        end

        Wait(wait)
    end
end)
