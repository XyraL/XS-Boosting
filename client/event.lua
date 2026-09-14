EventClient = {}

local blip, radius

local function clear()
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    if radius and DoesBlipExist(radius) then RemoveBlip(radius) end
    blip, radius = nil, nil
end

-- Everyone gets the exact spot. The difficulty on these is the other people
-- going for it, not the finding, so hiding it would only waste time.
local function mark(event)
    clear()
    if not event then return end

    local at = event.taken and event.buyer or event.coords
    if not at then return end

    radius = AddBlipForRadius(at.x, at.y, at.z, 45.0)
    SetBlipColour(radius, 1)
    SetBlipAlpha(radius, 70)

    blip = AddBlipForCoord(at.x, at.y, at.z)
    SetBlipSprite(blip, 225)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Contested: %s'):format(event.label or 'Vehicle'))
    EndTextCommandSetBlipName(blip)
end

RegisterNetEvent('XS-Boosting:client:eventState', function(event)
    Boost.event = event

    if event and Boost.eventJoined then
        mark(event)
    else
        clear()
    end

    UI.Send('event', event)
end)

RegisterNetEvent('XS-Boosting:client:event', function(data, what)
    if what == 'started' then
        Boost.event = data
        UI.Send('event', data)

        if Boost.settings.alerts ~= false then
            Sound.Play('event')
            Boost.Notify(('A %s is up for grabs. Anyone can take it.'):format(data.label), 'inform')
            UI.Alert('Car up for grabs', ('A %s, and everybody has been told. First one home keeps it.'):format(data.label), 'warn')
        end

    elseif what == 'won' then
        Boost.eventJoined = false
        Boost.event = nil
        clear()
        UI.Send('event', nil)

        if data and data.winner then
            Boost.Notify(('%s got the %s.'):format(data.winner, data.label), 'inform')
        end

    elseif what == 'ended' then
        Boost.eventJoined = false
        Boost.event = nil
        clear()
        UI.Send('event', nil)

        if data and data.reason then Boost.Notify(data.reason, 'inform') end
    end
end)

function EventClient.Join()
    local ok, reason, event = lib.callback.await('XS-Boosting:eventJoin', false)

    if not ok then
        Boost.Notify(reason or 'Not right now.', 'error')
        return false
    end

    Boost.eventJoined = true
    Boost.event = event
    mark(event)
    Sound.Play('accept')
    Boost.Notify('You are in. It is on your map.', 'success')

    return true
end

RegisterNUICallback('eventJoin', function(_, cb)
    local ok = EventClient.Join()
    cb({ ok = ok, event = Boost.event })
end)

-- Handing a contested car in is its own thing: there is no contract behind it,
-- just the car and whoever got there first.
CreateThread(function()
    local prompt = false

    while true do
        local wait = 1000
        local event = Boost.event

        if Boost.eventJoined and event and not event.taken and not Boost.job then
            local ped = cache.ped
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= 0 then
                local plate = GetVehicleNumberPlateText(vehicle) or ''

                if plate:gsub('%s+', '') == (event.plate or ''):gsub('%s+', '') then
                    local buyer = vector3(event.buyer.x, event.buyer.y, event.buyer.z)

                    if #(GetEntityCoords(vehicle) - buyer) <= (event.buyerRadius or 12.0) then
                        wait = 250

                        if not prompt then
                            prompt = true
                            lib.showTextUI('[E] Hand it in', { position = 'left-center' })
                        end

                        if IsControlJustReleased(0, 38) then
                            lib.hideTextUI()
                            prompt = false

                            local ok, reason, amount = lib.callback.await('XS-Boosting:eventDeliver', false)

                            if ok then
                                Sound.Play('paid')
                                Boost.Notify(('It is yours. $%s.'):format(amount or 0), 'success')
                            else
                                Boost.Notify(reason or 'Not here.', 'error')
                            end

                            Wait(2000)
                        end
                    elseif prompt then
                        prompt = false
                        lib.hideTextUI()
                    end
                elseif prompt then
                    prompt = false
                    lib.hideTextUI()
                end
            elseif prompt then
                prompt = false
                lib.hideTextUI()
            end
        elseif prompt then
            prompt = false
            lib.hideTextUI()
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clear() end
end)
