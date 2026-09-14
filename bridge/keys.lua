Keys = { name = nil }

if not Config then return end

local IS_SERVER = IsDuplicityVersion()

do
    local forced = Config.Bridges and Config.Bridges.keys or 'auto'
    if forced ~= 'auto' then
        Keys.name = forced ~= 'none' and forced or nil
    elseif GetResourceState('qbx_vehiclekeys') == 'started' then
        Keys.name = 'qbx'
    elseif GetResourceState('qb-vehiclekeys') == 'started' then
        Keys.name = 'qb-vehiclekeys'
    elseif GetResourceState('qs-vehiclekeys') == 'started' then
        Keys.name = 'qs-vehiclekeys'
    end
end

if IS_SERVER then
    function Keys.Give(src, netId, plate)
        if not Keys.name then return end

        if Keys.name == 'qbx' then
            exports.qbx_vehiclekeys:GiveKeys(src, NetworkGetEntityFromNetworkId(netId), true)
            return
        end

        TriggerClientEvent('XS-Boosting:client:giveKeys', src, netId, plate)
    end
else
    RegisterNetEvent('XS-Boosting:client:giveKeys', function(netId, plate)
        if not Keys.name then return end

        if Keys.name == 'qb-vehiclekeys' then
            TriggerEvent('vehiclekeys:client:SetOwner', plate)
        elseif Keys.name == 'qs-vehiclekeys' then
            exports['qs-vehiclekeys']:GiveKeys(plate)
        elseif Keys.name == 'custom' then
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            exports['XS-Boosting']:OnGiveKeys(vehicle, plate)
        end
    end)
end
