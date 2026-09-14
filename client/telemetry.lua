Telemetry = {}

local running = false

function Telemetry.Sync(state)
    if not state or not Config.UI.telemetry then
        Telemetry.Stop()
        return
    end

    if state.stage == 'transit' or (state.heist and state.stage == 'running') then
        Telemetry.Start()
    else
        Telemetry.Stop()
    end
end

function Telemetry.Stop()
    running = false
end

function Telemetry.Start()
    if running then return end
    running = true

    CreateThread(function()
        while running and Boost.HasJob() do
            local ped = cache.ped
            local vehicle = GetVehiclePedIsIn(ped, false)
            local speed = 0

            if vehicle and vehicle ~= 0 then
                speed = GetEntitySpeed(vehicle) * (Config.UI.units == 'imperial' and 2.236936 or 3.6)
            end

            local job = Boost.job

            UI.Send('telemetry', {
                speed     = math.floor(speed),
                units     = Config.UI.units == 'imperial' and 'mph' or 'km/h',
                condition = job and job.condition or 100,
                remaining = job and job.deadline and math.max(0, job.deadline - GetCloudTimeAsInt()) or nil,
                tracker   = job and job.tracker or nil,
                inVehicle = vehicle ~= 0,
            })

            Wait(500)
        end

        running = false
    end)
end
