Chop = {}

local function remaining()
    local job = Boost.job
    if not job then return {} end

    local taken = {}
    for _, id in ipairs(job.collected or {}) do taken[id] = true end

    local out = {}

    -- A chop contract asks for specific parts. Any other contract being
    -- stripped for a bail-out can give up anything on the car.
    local wanted = job.parts

    if wanted and #wanted > 0 then
        for _, part in ipairs(wanted) do
            if not taken[part.id] then out[#out + 1] = { id = part.id, label = part.label } end
        end
    else
        for _, part in ipairs(Config.Chop.parts) do
            if not taken[part.id] then out[#out + 1] = { id = part.id, label = part.label } end
        end
    end

    return out
end

function Chop.Strip()
    local job = Boost.job
    local vehicle = Boost.Vehicle()
    if not job or not vehicle then return end

    local left = remaining()

    if #left == 0 then
        Boost.Notify('There is nothing left on it they want.', 'inform')
        return
    end

    local tool = Config.Chop.tool

    if tool.item and tool.item ~= '' then
        local has = lib.callback.await('XS-Boosting:hasItem', false, tool.item)
        if not has then
            Boost.Notify('You need a toolkit for that.', 'error')
            return
        end
    end

    local options = {}
    for index, part in ipairs(left) do
        options[index] = { value = part.id, label = part.label }
    end

    local picked = lib.inputDialog('Strip', {
        { type = 'select', label = 'Part', options = options, required = true },
    })

    if not picked or not picked[1] then return end

    Contract.SetBusy(true)

    local done = lib.progressBar({
        duration = Config.Chop.partSeconds * 1000,
        label = 'Pulling it off',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    if not done then
        Contract.SetBusy(false)
        return
    end

    local won = Theft.Minigame('chop', Tiers.Difficulty(job.tier, 'lock'))

    if won then
        Sound.Play('part')
        TriggerServerEvent('XS-Boosting:server:partTaken', picked[1])
        Chop.Visual(vehicle, picked[1])
    else
        Boost.Notify('You made a mess of it.', 'error')
    end

    Contract.SetBusy(false)
end

-- The car should look stripped as it is stripped. Purely cosmetic; the server
-- holds the real list.
function Chop.Visual(vehicle, partId)
    if not DoesEntityExist(vehicle) then return end

    if partId == 'wheels' then
        for wheel = 0, 5 do SetVehicleTyreBurst(vehicle, wheel, true, 1000.0) end
    elseif partId == 'doors' then
        SetVehicleDoorBroken(vehicle, 0, true)
        SetVehicleDoorBroken(vehicle, 1, true)
    elseif partId == 'bonnet' then
        SetVehicleDoorBroken(vehicle, 4, true)
    elseif partId == 'seats' or partId == 'stereo' or partId == 'airbags' then
        SmashVehicleWindow(vehicle, 0)
        SmashVehicleWindow(vehicle, 1)
    end
end
