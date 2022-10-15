local QBCore = exports["qb-core"]:GetCoreObject()

QBCore.Functions.CreateCallback('qb-garages:server:GetRecentlyImpounded',function(source, cb) 
    --https://overextended.github.io/docs/oxmysql/Usage/query
    MySQL.query('SELECT * FROM player_vehicles WHERE state = ? ORDER BY startdate ASC LIMIT 10', {2}, function(result)
        if next(result) then
            local vehicles = {}
            for i = 1, #result do
                vehicles[#vehicles + 1] = {
                    vehicle = result[i].vehicle,
                    plate = result[i].plate,
                    startDate = os.date("%Y/%m/%d %H:%M:%S", result[i].startdate),
                    reason = result[i].reason,
                }
            end
            cb(vehicles)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('qb-garages:server:GetPersonalVehicles',function(source,cb) 
--https://overextended.github.io/docs/oxmysql/Usage/query
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    MySQL.query('SELECT * FROM player_vehicles WHERE state = ? AND citizenid = ? ORDER BY startdate ASC', {2, Player.PlayerData.citizenid}, function(result)
        if next(result) then
            local vehicles = {}
            for i = 1, #result do
                vehicles[#vehicles + 1] = {
                    vehicle = result[i].vehicle,
                    plate = result[i].plate,
                    startDate = os.date("%Y/%m/%d %H:%M:%S", result[i].startdate),
                    endDate = os.date("%Y/%m/%d %H:%M:%S", result[i].enddate),
                    reason = result[i].reason,
                    price = result[i].depotprice,
                    worker = result[i].worker,
                }
            end
            cb(vehicles)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('qb-garages:server:GetVehicleByPlate',function(source,cb,plate) 
    --https://overextended.github.io/docs/oxmysql/Usage/query
    MySQL.query('SELECT * FROM player_vehicles WHERE state = ? AND plate = ?', {2, plate}, function(result)
        if next(result) then
            local vehicles = {}
            for i = 1, #result do
                vehicles[#vehicles + 1] = {
                    vehicle = result[i].vehicle,
                    plate = result[i].plate,
                    startDate = os.date("%Y/%m/%d %H:%M:%S", result[i].startdate),
                    reason = result[i].reason,
                }
            end
            cb(vehicles)
        else
            cb(false)
        end
    end)
end)

QBCore.Functions.CreateCallback('qb-garages:server:GetVehicleByOwner',function(source,cb,cid) 
    --https://overextended.github.io/docs/oxmysql/Usage/query
    MySQL.query('SELECT * FROM player_vehicles WHERE state = ? AND citizenid = ?', {2, cid}, function(result)
        if next(result) then
            local vehicles = {}
            for i = 1, #result do
                vehicles[#vehicles + 1] = {
                    vehicle = result[i].vehicle,
                    plate = result[i].plate,
                    startDate = os.date("%Y/%m/%d %H:%M:%S", result[i].startdate),
                    reason = result[i].reason,
                }
            end
            cb(vehicles)
        else
            cb(false)
        end
    end)
end)