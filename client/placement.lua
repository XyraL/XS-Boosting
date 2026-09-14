Placement = {}

local active = false

-- Arrows do both jobs so that nothing competes with E for placing. Up/down
-- nudge, left/right turn.
local CONTROLS = {
    place   = 38,   -- E
    cancel  = 194,  -- Backspace
    ground  = 47,   -- G
    forward = 172,  -- Up
    back    = 173,  -- Down
    rotateL = 174,  -- Left
    rotateR = 175,  -- Right
    bigger  = 241,  -- Scroll up
    smaller = 242,  -- Scroll down
}

local function raycast(distance)
    local camCoords = GetGameplayCamCoord()
    local rotation = GetGameplayCamRot(2)
    local direction = vec3(
        -math.sin(math.rad(rotation.z)) * math.abs(math.cos(math.rad(rotation.x))),
        math.cos(math.rad(rotation.z)) * math.abs(math.cos(math.rad(rotation.x))),
        math.sin(math.rad(rotation.x))
    )

    local target = camCoords + (direction * distance)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(
        camCoords.x, camCoords.y, camCoords.z,
        target.x, target.y, target.z,
        1 + 16 + 256, cache.ped, 4)

    local _, hit, coords = GetShapeTestResult(ray)

    if hit == 1 then return coords end
    return target
end

function Placement.Active()
    return active
end

-- Returns coords, heading, radius — or nil if the admin backed out.
function Placement.Run(options)
    if active then return nil end
    active = true

    options = options or {}

    local heading = GetEntityHeading(cache.ped)
    local radius = options.radius or 10.0
    local snap = Config.Builder.snapToGround
    local offset = vec3(0.0, 0.0, 0.0)
    local result

    lib.showTextUI([[
**Placing**
[E] Put it here
[Left] / [Right] Turn it
[Up] / [Down] Nudge
[G] Ground snap
[Scroll] Size
[Backspace] Cancel]], { position = 'left-center' })

    while active do
        Wait(0)

        local coords = raycast(Config.Builder.placementRange) + offset

        if snap then
            local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
            if found then coords = vec3(coords.x, coords.y, z) end
        end

        DrawMarker(1, coords.x, coords.y, coords.z - 0.05,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            radius * 2, radius * 2, 0.5,
            options.r or 90, options.g or 210, options.b or 255, 90,
            false, false, 2, false)

        DrawMarker(20, coords.x, coords.y, coords.z + 1.2,
            0.0, 0.0, 0.0, 180.0, 0.0, heading,
            0.5, 0.5, 0.5,
            255, 255, 255, 160,
            true, false, 2, false)

        if IsControlJustPressed(0, CONTROLS.place) then
            result = { coords = coords, heading = heading, radius = radius }
            break
        end

        if IsControlJustPressed(0, CONTROLS.cancel) then break end
        if IsControlJustPressed(0, CONTROLS.ground) then snap = not snap end

        if IsControlPressed(0, CONTROLS.rotateL) then heading = (heading + 1.5) % 360 end
        if IsControlPressed(0, CONTROLS.rotateR) then heading = (heading - 1.5) % 360 end

        local step = Config.Builder.nudgeStep
        if IsControlPressed(0, CONTROLS.forward) then offset = offset + vec3(0.0, step, 0.0) end
        if IsControlPressed(0, CONTROLS.back) then offset = offset - vec3(0.0, step, 0.0) end

        if IsControlJustPressed(0, CONTROLS.bigger) then radius = math.min(200.0, radius + 1.0) end
        if IsControlJustPressed(0, CONTROLS.smaller) then radius = math.max(1.0, radius - 1.0) end
    end

    active = false
    lib.hideTextUI()

    return result
end

-- Vehicle spawn points want to be placed as a car, not as a circle, because
-- the heading is what decides whether the car ends up in a wall.
function Placement.Vehicle(model)
    if active then return nil end
    active = true

    local hash = joaat(model or 'sultan')
    local loaded = lib.requestModel(hash, 5000)
    local ghost

    -- A vehicle's origin sits in the middle of the chassis, so dropping that
    -- on the ground buries half the car. The model's own lowest point is how
    -- far it has to come back up.
    local lift = 0.0

    if loaded then
        local min = GetModelDimensions(hash)
        lift = math.abs(min.z)

        ghost = CreateVehicle(hash, GetEntityCoords(cache.ped), 0.0, false, false)
        SetEntityAlpha(ghost, 150, false)
        SetEntityCollision(ghost, false, false)
        SetVehicleDoorsLocked(ghost, 4)
        FreezeEntityPosition(ghost, true)
    end

    local heading = GetEntityHeading(cache.ped)
    local result

    lib.showTextUI([[
**Placing a spawn**
[E] Put it here
[Left] / [Right] Turn it
[Backspace] Cancel]], { position = 'left-center' })

    while active do
        Wait(0)

        local coords = raycast(Config.Builder.placementRange)
        local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
        if found then coords = vec3(coords.x, coords.y, z) end

        if ghost and DoesEntityExist(ghost) then
            SetEntityCoordsNoOffset(ghost, coords.x, coords.y, coords.z + lift, false, false, false)
            SetEntityHeading(ghost, heading)
        else
            DrawMarker(36, coords.x, coords.y, coords.z + 0.5,
                0.0, 0.0, 0.0, 0.0, 0.0, heading,
                1.0, 1.0, 1.0, 90, 210, 255, 140, false, false, 2, false)
        end

        if IsControlJustPressed(0, CONTROLS.place) then
            result = { coords = coords, heading = heading, radius = 5.0 }
            break
        end

        if IsControlJustPressed(0, CONTROLS.cancel) then break end
        if IsControlPressed(0, CONTROLS.rotateL) then heading = (heading + 1.5) % 360 end
        if IsControlPressed(0, CONTROLS.rotateR) then heading = (heading - 1.5) % 360 end
    end

    active = false
    lib.hideTextUI()

    if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    SetModelAsNoLongerNeeded(hash)

    return result
end
