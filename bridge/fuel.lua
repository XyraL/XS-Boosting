Fuel = { name = nil }

if not Config then return end

for _, resource in ipairs({ 'ox_fuel', 'LegacyFuel', 'ps-fuel', 'cdn-fuel' }) do
    if GetResourceState(resource) == 'started' then
        Fuel.name = resource
        break
    end
end

function Fuel.Set(vehicle, level)
    if not DoesEntityExist(vehicle) then return end

    SetVehicleFuelLevel(vehicle, level + 0.0)
    DecorSetFloat(vehicle, '_Fuel_Level', level + 0.0)

    if Fuel.name == 'ox_fuel' then
        Entity(vehicle).state.fuel = level
    elseif Fuel.name == 'LegacyFuel' or Fuel.name == 'cdn-fuel' then
        exports[Fuel.name]:SetFuel(vehicle, level)
    elseif Fuel.name == 'ps-fuel' then
        exports['ps-fuel']:SetFuel(vehicle, level)
    end
end
