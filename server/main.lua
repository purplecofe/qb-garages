local QBCore = exports['qb-core']:GetCoreObject()
local OutsideVehicles = {}
local VehicleSpawnerVehicles = {}

local function TableContains (tab, val)
    if type(val) == "table" then
        for _, value in ipairs(tab) do
            if TableContains(val, value) then
                return true
            end
        end
        return false
    else
        for _, value in ipairs(tab) do
            if value == val then
                return true
            end
        end
    end
    return false
end

local function IsPlayerVehicle(plate, citizenid)
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, citizenid})
    if result[1] then
        return true
    else
        return false
    end
end

local function IsJobVehicle(plate, job)
    local result = MySQL.query.await('SELECT * FROM job_vehicles WHERE plate = ? AND job = ?', {plate, job})
    if result[1] then
        return true
    else
        return false
    end
end

QBCore.Functions.CreateCallback('qb-garage:server:spawnvehicle', function (source, cb, vehInfo, coords, warp, garageType)
    local veh = QBCore.Functions.SpawnVehicle(source, vehInfo.vehicle, coords, warp)

    if not veh or not NetworkGetNetworkIdFromEntity(veh) then
        print('ISSUE HERE', veh, NetworkGetNetworkIdFromEntity(veh))
    end
    local vehProps = {}
    local plate = vehInfo.plate
    local query = 'SELECT mods FROM player_vehicles WHERE plate = ?'
    if garageType == 'job' and not vehInfo.citizenid then
        query = 'SELECT mods FROM job_vehicles WHERE plate = ?'
    end
    local result = MySQL.query.await(query, {plate})
    if result[1] then vehProps = json.decode(result[1].mods) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    OutsideVehicles[plate] = {netID = netId, entity = veh}
    cb(netId, vehProps)
end)

QBCore.Functions.CreateCallback("qb-garage:server:GetGarageVehicles", function(source, cb, garage, garageType, category)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if garageType == "public" then        --Public garages give player cars in the garage only
         MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ?', {pData.PlayerData.citizenid, garage, 1}, function(result)
            local vehs = {}
            if result[1] then
                for _, vehicle in pairs(result) do
                    if vehicle.parkingspot then
                        local spot = json.decode(vehicle.parkingspot)
                        if spot and spot.x then
                            vehicle.parkingspot = vector3(spot.x, spot.y, spot.z)
                        end
                    end
                    if vehicle.damage then
                        vehicle.damage = json.decode(vehicle.damage)
                    end
                    vehs[#vehs + 1] = vehicle
                end
                cb(vehs)
            else
                cb(nil)
            end
        end)
    elseif garageType == "depot" then    --Depot give player cars that are not in garage only
         MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND (state = ? OR garage = ? OR garage IS NULL)', {pData.PlayerData.citizenid, 2, garage}, function(result)
            local tosend = {}
            if result[1] then
                if type(category) == 'table' then
                    if TableContains(category, {'car'}) then
                        category = 'car'
                    elseif TableContains(category, {'plane', 'helicopter'}) then
                        category = 'air'
                    elseif TableContains(category, 'boat') then
                        category = 'sea'
                    end
                end
                for _, vehicle in pairs(result) do
                    if vehicle.depotprice == 0 then
                        vehicle.depotprice = DepotPrice
                    end
                    
                    vehicle.canTakeout = os.time() >= vehicle.enddate
                    vehicle.startdate = os.date("%Y/%m/%d %H:%M:%S", vehicle.startdate)
                    vehicle.enddate = os.date("%Y/%m/%d %H:%M:%S", vehicle.enddate)
                    vehicle.parkingspot = nil

                    if vehicle.damage then
                        vehicle.damage = json.decode(vehicle.damage)
                    end

                    if category == "air" and ( QBCore.Shared.Vehicles[vehicle.vehicle].category == "helicopters" or QBCore.Shared.Vehicles[vehicle.vehicle].category == "planes" ) then
                        tosend[#tosend + 1] = vehicle
                    elseif category == "sea" and QBCore.Shared.Vehicles[vehicle.vehicle].category == "boats" then
                        tosend[#tosend + 1] = vehicle
                    elseif category == "car" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "helicopters" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "planes" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "boats" then
                        tosend[#tosend + 1] = vehicle
                    end
                end
                cb(tosend)
            else
                cb(nil)
            end
        end)
    else                            --House give all cars in the garage, Job and Gang depend of config
        local shared = ''
        if not TableContains(SharedJobGarages, garage) and garageType ~= "house" then
            shared = " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        end
         MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ?'..shared, {garage, 1}, function(result)
            if result[1] then
                local vehs = {}
                for _, vehicle in pairs(result) do
                    local spot = json.decode(vehicle.parkingspot)
                    if vehicle.parkingspot then
                        vehicle.parkingspot = vector3(spot.x, spot.y, spot.z)
                    end
                    if vehicle.damage then
                        vehicle.damage = json.decode(vehicle.damage)
                    end
                    vehs[#vehs + 1] = vehicle
                end
                cb(vehs)
            else
                cb(nil)
            end
        end)
    end
end)

QBCore.Functions.CreateCallback("qb-garages:server:GetJobGarageVehicleCategories",function(source,cb, garage, category) 
    local src = source
    local pData = QBCore.Functions.GetPlayer(source)
    local job = pData.PlayerData.job.type
    
    --https://overextended.github.io/docs/oxmysql/Usage/query
    MySQL.query('SELECT COUNT(vehicle) AS numberOfVehicles, vehicle, vehiclename FROM job_vehicles WHERE job = ? AND garage = ? AND category = ? GROUP BY vehicle', {job, garage, category}, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)

QBCore.Functions.CreateCallback("qb-garages:server:GetJobGarageVehicles",function(source, cb, vehicle, garage) 
    local src = source
    --https://overextended.github.io/docs/oxmysql/Usage/query
    MySQL.query('SELECT * FROM job_vehicles WHERE vehicle = ? AND garage = ? ORDER BY vehiclename ASC', {vehicle, garage}, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)

QBCore.Functions.CreateCallback("qb-garages:server:GetJobGarageVehicle",function(source, cb, plate) 
    local src = source
    --https://overextended.github.io/docs/oxmysql/Usage/query
    MySQL.query('SELECT * FROM job_vehicles WHERE plate = ?', {plate}, function(result)
        if result[1] then
            local veh = {}
            for _, vehicle in pairs(result) do
                local spot = json.decode(vehicle.parkingspot)
                if vehicle.parkingspot then
                    vehicle.parkingspot = vector3(spot.x, spot.y, spot.z)
                end
                if vehicle.damage then
                    vehicle.damage = json.decode(vehicle.damage)
                end
                veh[#veh + 1] = vehicle
            end
            cb(veh)
        else
            cb(nil)
        end
    end)
end)

QBCore.Functions.CreateCallback("qb-garage:server:GetOutsideVehicles", function(source, cb)
    local ply = QBCore.Functions.GetPlayer(source)
    local citizenId = ply.PlayerData.citizenid
    if OutsideVehicles[citizenId] and next(OutsideVehicles[citizenId]) then
        cb(OutsideVehicles[citizenId])
    else
        cb({})
    end
end)

QBCore.Functions.CreateCallback('qb-garages:server:RetrieveVehicle',function(source, cb, plate) 
    MySQL.update('UPDATE job_vehicles SET state = 1 WHERE state = 2 and plate = ?', {plate}, function(affectedRows)
        if affectedRows then
            cb(true)
        end
    end)
end)

QBCore.Functions.CreateCallback("qb-garage:server:checkOwnership", function(source, cb, plate, garageType, garage, gang)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    local hasHouseKey = false

    if garageType == "public" then        --Public garages only for player cars
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    elseif garageType == "house" then     --House garages only for player cars that have keys of the house
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                hasHouseKey = exports['qb-houses']:hasKey(result[1].license, result[1].citizenid, garage)
                cb(hasHouseKey)
            else
                cb(false)
            end
        end)
    elseif garageType == "gang" then        --Gang garages only for gang members cars (for sharing)
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                local Player = QBCore.Functions.GetPlayer(source)
                local playerGang = Player.PlayerData.gang.name
                cb(playerGang == gang)
            else
                cb(false)
            end
        end)
    elseif garageType == "job" then --  職業車庫現在屬於共用車庫，只需檢查是不是有這台車就好
        if IsPlayerVehicle(plate, pData.PlayerData.citizenid) then
            cb(true)    --  是玩家擁有的車輛，包括工作車輛
        elseif IsJobVehicle(plate, pData.PlayerData.job.type) then
            cb(false)   --  是工作車輛，非玩家擁有
        else
            cb(nil) --  以上都不是
        end
    else                            --Job garages only for cars that are owned by someone (for sharing and service) or only by player depending of config
        local shared = ''
        if not TableContains(SharedJobGarages, garage) then
            shared = " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        end
         MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?'..shared, {plate}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    end
end)

RegisterNetEvent('qb-garage:server:updateVehicle', function(state, fuel, engine, body, plate, properties, garage, location, damage, garageType, owned)
    if location and type(location) == 'vector3' then
        if StoreDamageAccuratly then
            if garageType == 'job' then
                if owned then
                    MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, parkingspot = ?, damage = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(location), json.encode(damage), plate})
                else
                    MySQL.update('UPDATE job_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, parkingspot = ?, damage = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(location), json.encode(damage), plate})
                end
            else
                MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, parkingspot = ?, damage = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(location), json.encode(damage), plate})
            end
        else
            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, parkingspot = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(location), plate})
        end
    else
        if StoreDamageAccuratly then
            if garageType == 'job' then
                if owned then
                    MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, damage = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(damage), plate})
                else
                    MySQL.update('UPDATE job_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, damage = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(damage), plate})
                end
            else
                MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ?, damage = ? WHERE plate = ?',{state, garage, fuel, engine, body, json.encode(properties), json.encode(damage), plate})
            end
        else
            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ? WHERE plate = ?', {state, garage, fuel, engine, body, json.encode(properties), plate})
        end
    end
end)

RegisterNetEvent('qb-garage:server:updateVehicleState', function(state, plate, garage, garageType, owned)
    if garageType == 'job' and not owned then
        MySQL.update('UPDATE job_vehicles SET state = ?, garage = ? WHERE plate = ?',{state, garage, plate})
    else
        MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, depotprice = ? WHERE plate = ?',{state, garage, 0, plate})
    end
end)

RegisterNetEvent('qb-garages:server:UpdateOutsideVehicles', function(Vehicles)
    local src = source
    local ply = QBCore.Functions.GetPlayer(src)
    local citizenId = ply.PlayerData.citizenid
    OutsideVehicles[citizenId] = Vehicles
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(100)
        if AutoRespawn then
            MySQL.update('UPDATE player_vehicles SET state = 1 WHERE state = 0', {})
        else
            MySQL.update('UPDATE player_vehicles SET state = 2, garage = ? WHERE state = 0', {'impound'})
            MySQL.update('UPDATE job_vehicles SET state = 2 WHERE state = 0', {})
        end
    end
end)

RegisterNetEvent('qb-garage:server:PayDepotPrice', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cashBalance = Player.PlayerData.money["cash"]
    local bankBalance = Player.PlayerData.money["bank"]

    
    local vehicle = data.vehicle
    local depotPrice = vehicle.depotprice ~= 0 and vehicle.depotprice or DepotPrice
    if cashBalance >= depotPrice then
        Player.Functions.RemoveMoney("cash", depotPrice, "paid-depot")
    elseif bankBalance >= depotPrice then
        Player.Functions.RemoveMoney("bank", depotPrice, "paid-depot")
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_enough"), 'error')
    end
end)


--External Calls
--Call from qb-vehiclesales
QBCore.Functions.CreateCallback("qb-garage:server:checkVehicleOwner", function(source, cb, plate)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
     MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(result)
        if result[1] then
            cb(true, result[1].balance)
        else
            cb(false)
        end
    end)
end)

--Call from qb-phone
QBCore.Functions.CreateCallback('qb-garage:server:GetPlayerVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local Vehicles = {}

     MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result[1] then
            for k, v in pairs(result) do
                local VehicleData = QBCore.Shared.Vehicles[v.vehicle]
                if not VehicleData then goto continue end
                local VehicleGarage = Lang:t("error.no_garage")
                if v.garage ~= nil then
                    if Garages[v.garage] ~= nil then
                        VehicleGarage = Garages[v.garage].label
                    elseif HouseGarages[v.garage] then
                        VehicleGarage = HouseGarages[v.garage].label
                    end
                end

                if v.state == 0 then
                    v.state = Lang:t("status.out")
                elseif v.state == 1 then
                    v.state = Lang:t("status.garaged")
                elseif v.state == 2 then
                    v.state = Lang:t("status.impound")
                end
                
                local fullname 
                if VehicleData["brand"] ~= nil then
                    fullname = VehicleData["brand"] .. " " .. VehicleData["name"]
                else
                    fullname = VehicleData["name"]
                end
                local spot = json.decode(v.parkingspot)
                Vehicles[#Vehicles+1] = {
                    fullname = fullname,
                    brand = VehicleData["brand"],
                    model = VehicleData["name"],
                    plate = v.plate,
                    garage = VehicleGarage,
                    state = v.state,
                    fuel = v.fuel,
                    engine = v.engine,
                    body = v.body,
                    parkingspot = spot and vector3(spot.x, spot.y, spot.z) or nil,
                    damage = json.decode(v.damage)
                }
                ::continue::
            end
            cb(Vehicles)
        else
            cb(nil)
        end
    end)
end)

local function GetRandomPublicGarage()
    for garageName, garage in pairs(Garages)do
        if garage.type == 'public' then
            return garageName -- return the first garageName
        end
    end
end


-- Command to restore lost cars (garage: 'None' or something similar)
QBCore.Commands.Add("restorelostcars", "Restores cars that were parked in a grage that no longer exists in the config or is invalid (name change or removed).", {{name = "destination_garage", help = "(Optional) Garage where the cars are being sent to."}}, false,
function(source, args)
    local src = source
    if next(Garages) ~= nil then
        local destinationGarage = args[1] and args[1] or GetRandomPublicGarage()
        if Garages[destinationGarage] == nil then
            TriggerClientEvent('QBCore:Notify', src, 'Invalid garage name provided', 'error', 4500)
            return
        end

        local invalidGarages = {}
         MySQL.query('SELECT garage FROM player_vehicles', function(result)
            if result[1] then
                for _,v in ipairs(result) do
                    if Garages[v.garage] == nil then
                        if v.garage then
                            invalidGarages[v.garage] = true
                        end
                    end
                end
                for garage,_ in pairs(invalidGarages) do
                    MySQL.update('UPDATE player_vehicles set garage = ? WHERE garage = ?',{destinationGarage, garage})
                end
                MySQL.update('UPDATE player_vehicles set garage = ? WHERE garage IS NULL OR garage = \'\'',{destinationGarage})
            end
        end)
    end
end, RestoreCommandPermissionLevel)
