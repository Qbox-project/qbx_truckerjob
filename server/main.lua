local Bail = {}
local currentTruckers = {}

RegisterNetEvent('qbx_truckerjob:server:DoBail', function(bool, vehInfo)
    local client = source
    local Player = exports.qbx_core:GetPlayer(client)
    if not Player then return end
    if bool then
        if Player.PlayerData.money.cash >= Config.BailPrice then
            Bail[Player.PlayerData.citizenid] = Config.BailPrice
            Player.Functions.RemoveMoney('cash', Config.BailPrice, "tow-received-bail")

            exports.qbx_core:Notify(client, Lang:t("success.paid_with_cash", {value = Config.BailPrice}), "success")
            TriggerClientEvent('qbx_truckerjob:client:SpawnVehicle', client, vehInfo)
        elseif Player.PlayerData.money.bank >= Config.BailPrice then
            Bail[Player.PlayerData.citizenid] = Config.BailPrice
            Player.Functions.RemoveMoney('bank', Config.BailPrice, "tow-received-bail")
            exports.qbx_core:Notify(client, Lang:t("success.paid_with_bank", {value = Config.BailPrice}), "success")

            TriggerClientEvent('qbx_truckerjob:client:SpawnVehicle', client, vehInfo)
        else
            exports.qbx_core:Notify(client, Lang:t("error.no_deposit", {value = Config.BailPrice}), "error")
        end
    else
        if Bail[Player.PlayerData.citizenid] then
            Player.Functions.AddMoney('cash', Bail[Player.PlayerData.citizenid], "trucker-bail-paid")
            Bail[Player.PlayerData.citizenid] = nil

            exports.qbx_core:Notify(client, Lang:t("success.refund_to_cash", {value = Config.BailPrice}), "success")
        end
    end
end)

RegisterNetEvent("qbx_truckerjob:server:doneJob", function ()
    local client = source
    local Player = exports.qbx_core:GetPlayer(client)
    if not Player then return end
    if Player.PlayerData.job.name ~= "trucker" then return end
    currentTruckers[client] = (currentTruckers[client] or 0 ) + 1
    local chance = math.random(1, 100)
    if chance > 26 then return end
    Player.Functions.AddItem("cryptostick", 1, false)
end)

RegisterNetEvent('qbx_truckerjob:server:getPaid', function()
    local client = source
    if not currentTruckers[client] or currentTruckers[client] == 0 then return end
    local Player = exports.qbx_core:GetPlayer(client)
    if not Player then return end
    if Player.PlayerData.job.name ~= "trucker" then return DropPlayer(client, locale('exploit_attempt')) end
    local drops = currentTruckers[client]
    currentTruckers[client] = nil
    local bonus = 0
    local DropPrice = math.random(100, 120)

    if drops >= 5 then
        bonus = math.ceil((DropPrice / 10) * 5) + 100
    elseif drops >= 10 then
        bonus = math.ceil((DropPrice / 10) * 7) + 300
    elseif drops >= 15 then
        bonus = math.ceil((DropPrice / 10) * 10) + 400
    elseif drops >= 20 then
        bonus = math.ceil((DropPrice / 10) * 12) + 500
    end

    local price = (DropPrice * drops) + bonus
    local taxAmount = math.ceil((price / 100) * Config.PaymentTax)
    local payment = price - taxAmount
    Player.Functions.AddJobReputation(drops)
    Player.Functions.AddMoney("bank", payment, "trucker-salary")
    exports.qbx_core:Notify(client, Lang:t("success.you_earned", {value = payment}), "success")
end)

lib.callback.register('qbx_truckerjob:server:spawnVehicle', function(source, model)
    local netId = SpawnVehicle(source, model, vec4(Config.Locations['vehicle'].coords.x, Config.Locations['vehicle'].coords.y, Config.Locations['vehicle'].coords.z, Config.Locations['vehicle'].rotation), true)
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