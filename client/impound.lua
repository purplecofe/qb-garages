local QBCore = exports['qb-core']:GetCoreObject()

local Targets = {}
local PlayerJob = {}

CreateThread(function()
    Targets["impoundFrontDesk"] =
        exports['qb-target']:AddBoxZone("impoundFrontDesk", vector3(-192.58, -1161.92, 23.67), 0.5, 1, {name = "impoundFrontDesk", heading = 270, debugPoly = false, minZ = 21.47, maxZ = 23.67},
            {options = {{event = "qb-garages:client:ImpoundFrontDeskMenu", label = "櫃台"}, }, distance = 2.5, })
end)

-- Event
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.GetPlayerData(function(PlayerData)
        PlayerJob = PlayerData.job
    end)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerJob = job
end)

RegisterNetEvent('qb-garages:client:ImpoundFrontDeskMenu', function()
    local Menu = {}
    if PlayerJob.type == "leo" then
        Menu[#Menu + 1] = {header = "近期扣押", txt = "顯示近十筆扣押車輛", params = {event = 'qb-garages:client:RecentlyImpounded'}}
        Menu[#Menu + 1] = {header = "個人車輛", txt = "顯示你目前被扣押的車輛", params = {event = 'qb-garages:client:PersonalVehicles'}}
        Menu[#Menu + 1] = {header = "以車牌搜尋", txt = "用車牌搜尋", params = {event = 'qb-garages:client:BrowseByPlate'}}
        Menu[#Menu + 1] = {header = "以車主搜尋", txt = "用 State ID 搜尋", params = {event = 'qb-garages:client:BrowseByOwner'}}
    else
        Menu[#Menu + 1] = {header = "個人車輛", txt = "顯示你目前被扣押的車輛", params = {event = 'qb-garages:client:PersonalVehicles'}}
    end
    exports['ps-ui']:openMenu(Menu)
end)

RegisterNetEvent('qb-garages:client:RecentlyImpounded', function()
    local Menu = {}
    Menu[#Menu + 1] = {header = "← 返回", txt = "", params = {event = "qb-garages:client:ImpoundFrontDeskMenu"}}
    QBCore.Functions.TriggerCallback('qb-garages:server:GetRecentlyImpounded', function(result)
        if result then
            for i = 1, #result do
                local vehicle = result[i].vehicle
                local plate = result[i].plate
                local startDate = result[i].startDate
                local reason = result[i].reason
                Menu[#Menu + 1] = {
                    header = QBCore.Shared.Vehicles[vehicle].name .. ' | ' .. plate,
                    txt = "扣押日期: " .. startDate .. "<br>" .. "扣押原因: " .. reason,
                    params = {event = ''}
                }
            end
        else
            Menu[#Menu + 1] = {header = "尚無扣押車輛", txt = ""}
        end
        exports['ps-ui']:openMenu(Menu)
    end)
end)

RegisterNetEvent('qb-garages:client:PersonalVehicles', function()
    local Menu = {}
    Menu[#Menu + 1] = {header = "← 返回", txt = "", params = {event = "qb-garages:client:ImpoundFrontDeskMenu"}}
    QBCore.Functions.TriggerCallback('qb-garages:server:GetPersonalVehicles', function(result)
        if result then
            for i = 1, #result do
                local vehicle = result[i].vehicle
                local plate = result[i].plate
                local startDate = result[i].startDate
                local reason = result[i].reason
                Menu[#Menu + 1] = {
                    header = QBCore.Shared.Vehicles[vehicle].name .. ' | ' .. plate,
                    txt = "扣押日期: " .. startDate .. "<br>" .. "扣押原因: " .. reason,
                    params = {event = 'qb-garages:client:PersonalVehicleDetail', args = {vehicle = result[i]}}
                }
            end
        else
            Menu[#Menu + 1] = {header = "尚無扣押車輛", txt = ""}
        end
        exports['ps-ui']:openMenu(Menu)
    end)
end)

RegisterNetEvent('qb-garages:client:PersonalVehicleDetail', function(data)
    local Menu = {}
    Menu[#Menu + 1] = {header = "← 返回", txt = "", params = {event = "qb-garages:client:PersonalVehicles"}}
    Menu[#Menu + 1] = {header = "車輛資訊", isMenuHeader = true, txt = "車牌: " .. data.vehicle.plate, params = {event = ""}}
    Menu[#Menu + 1] = {header = "扣押資訊", isMenuHeader = true, txt = "原因: " .. data.vehicle.reason .. " | " .. "執行者: " .. data.vehicle.worker, params = {event = ""}}
    Menu[#Menu + 1] = {header = "留置資訊", isMenuHeader = true, txt = "記點: " .. data.vehicle.reason .. " | " .. "留置至: " .. data.vehicle.endDate, params = {event = ""}}
    Menu[#Menu + 1] = {header = "留置費", isMenuHeader = true, txt = "總金額: " .. data.vehicle.price, params = {event = ""}}
    -- Menu[#Menu + 1] = {header = "取回扣押車輛", txt = "", params = {event = ""}}
    exports['ps-ui']:openMenu(Menu)
end)

RegisterNetEvent('qb-garages:client:BrowseByPlate', function()
    local input = exports['qb-input']:ShowInput({
        header = '車牌',
        submitText = '確定',
        inputs = {
            {type = 'text', isRequired = true, name = 'plate', text = '輸入車牌'}
        }
    })
    local Menu = {}
    Menu[#Menu + 1] = {header = "關閉", txt = "", params = {event = ''}}
    if not input then return end
    QBCore.Functions.TriggerCallback('qb-garages:server:GetVehicleByPlate', function(result)
        if result then
            for i = 1, #result do
                local vehicle = result[i].vehicle
                local plate = result[i].plate
                local startDate = result[i].startDate
                local reason = result[i].reason
                Menu[#Menu + 1] = {
                    header = QBCore.Shared.Vehicles[vehicle].name .. ' | ' .. plate,
                    txt = "扣押日期: " .. startDate .. "<br>" .. "扣押原因: " .. reason,
                    params = {event = 'qb-garages:client:'}
                }
            end
        else
            Menu[#Menu + 1] = {header = "尚無扣押車輛", txt = ""}
        end
        exports['ps-ui']:openMenu(Menu)
    end, input.plate)
end)

RegisterNetEvent('qb-garages:client:BrowseByOwner', function()
    local input = exports['qb-input']:ShowInput({
        header = 'State ID',
        submitText = '確定',
        inputs = {
            {type = 'text', isRequired = true, name = 'cid', text = '輸入 State ID'}
        }
    })
    local Menu = {}
    Menu[#Menu + 1] = {header = "關閉", txt = "", params = {event = ''}}
    if not input then return end
    QBCore.Functions.TriggerCallback('qb-garages:server:GetVehicleByOwner', function(result)
        if result then
            for i = 1, #result do
                local vehicle = result[i].vehicle
                local plate = result[i].plate
                local startDate = result[i].startDate
                local reason = result[i].reason
                Menu[#Menu + 1] = {
                    header = QBCore.Shared.Vehicles[vehicle].name .. ' | ' .. plate,
                    txt = "扣押日期: " .. startDate .. "<br>" .. "扣押原因: " .. reason,
                    params = {event = 'qb-garages:client:'}
                }
            end
        else
            Menu[#Menu + 1] = {header = "尚無扣押車輛", txt = ""}
        end
        exports['ps-ui']:openMenu(Menu)
    end, input.cid)
end)

AddEventHandler('onResourceStart', function(resource) if GetCurrentResourceName() ~= resource then return end
    QBCore.Functions.GetPlayerData(function(PlayerData)
        PlayerJob = PlayerData.job
    end)
end)

AddEventHandler('onResourceStop', function(r) if r ~= GetCurrentResourceName() then return end
    for k in pairs(Targets) do exports['qb-target']:RemoveZone(k) end
end)
