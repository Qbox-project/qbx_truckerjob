local config = require 'config.server'
local sharedConfig = require 'config.shared'
local bail = {}
local currentTruckers = {}

RegisterNetEvent('qbx_truckerjob:server:doBail', function(bool, vehInfo)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    if bool then
        if player.PlayerData.money.cash >= config.bailPrice then
            bail[player.PlayerData.citizenid] = config.bailPrice
            player.Functions.RemoveMoney('cash', config.bailPrice, "tow-received-bail")

            exports.qbx_core:Notify(player.PlayerData.source, locale("success.paid_with_cash", config.bailPrice), "success")
            TriggerClientEvent('qbx_truckerjob:client:spawnVehicle', src, vehInfo)
        elseif player.PlayerData.money.bank >= config.bailPrice then
            bail[player.PlayerData.citizenid] = config.bailPrice
            player.Functions.RemoveMoney('bank', config.bailPrice, "tow-received-bail")
            exports.qbx_core:Notify(player.PlayerData.source, locale("success.paid_with_bank", config.bailPrice), "success")

            TriggerClientEvent('qbx_truckerjob:client:spawnVehicle', src, vehInfo)
        else
            exports.qbx_core:Notify(player.PlayerData.source, locale("error.no_deposit", config.bailPrice), "error")
        end
    else
        if bail[player.PlayerData.citizenid] then
            player.Functions.AddMoney('cash', bail[player.PlayerData.citizenid], "trucker-bail-paid")
            bail[player.PlayerData.citizenid] = nil

            exports.qbx_core:Notify(player.PlayerData.source, locale("success.refund_to_cash", config.bailPrice), "success")
        end
    end
end)

RegisterNetEvent("qbx_truckerjob:server:doneJob", function ()
    local player = exports.qbx_core:GetPlayer(source)
    if not player or player.PlayerData.job.name ~= "trucker" then return end

    currentTruckers[player.PlayerData.source] = (currentTruckers[player.PlayerData.source] or 0) + 1

    local chance = math.random(1, 100)
    if chance > 26 then return end

    player.Functions.AddItem("cryptostick", 1, false)
end)

RegisterNetEvent('qbx_truckerjob:server:getPaid', function()
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    if not currentTruckers[player.PlayerData.source] or currentTruckers[player.PlayerData.source] == 0 then return end


    if player.PlayerData.job.name ~= "trucker" then return DropPlayer(player.PlayerData.source, locale('exploit_attempt')) end

    local drops = currentTruckers[player.PlayerData.source]
    currentTruckers[player.PlayerData.source] = nil
    local bonus = 0
    local dropPrice = math.random(100, 120)

    if drops >= 5 then
        bonus = math.ceil((dropPrice / 10) * 5) + 100
    elseif drops >= 10 then
        bonus = math.ceil((dropPrice / 10) * 7) + 300
    elseif drops >= 15 then
        bonus = math.ceil((dropPrice / 10) * 10) + 400
    elseif drops >= 20 then
        bonus = math.ceil((dropPrice / 10) * 12) + 500
    end

    local price = (dropPrice * drops) + bonus
    local taxAmount = math.ceil((price / 100) * config.paymentTax)
    local payment = price - taxAmount
    player.Functions.AddJobReputation(drops)
    player.Functions.AddMoney("bank", payment, "trucker-salary")
    exports.qbx_core:Notify(player.PlayerData.source, locale("success.you_earned", payment), "success")
end)

lib.callback.register('qbx_truckerjob:server:spawnVehicle', function(source, model)
    local netId = qbx.spawnVehicle({
        model = model,
        spawnSource = vec4(sharedConfig.locations.vehicle.coords.x, sharedConfig.locations.vehicle.coords.y, sharedConfig.locations.vehicle.coords.z, sharedConfig.locations.vehicle.rotation),
        warp = GetPlayerPed(source),
    })
    if not netId or netId == 0 then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end

    local plate = "TRUK"..tostring(math.random(1000, 9999))
    SetVehicleNumberPlateText(veh, plate)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
    return netId, plate
end)

RegisterNetEvent("QBCore:Server:OnPlayerUnload", function (client)
    currentTruckers[client] = nil
end)