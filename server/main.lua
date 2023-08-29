local QBCore = exports['qbx-core']:GetCoreObject()
local PaymentTax = 15
local Bail = {}

RegisterNetEvent('qb-trucker:server:DoBail', function(bool, vehInfo)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if bool then
        if Player.PlayerData.money.cash >= Config.BailPrice then
            Bail[Player.PlayerData.citizenid] = Config.BailPrice
            Player.Functions.RemoveMoney('cash', Config.BailPrice, "tow-received-bail")
            TriggerClientEvent('ox_lib:notify', src, { title = 'Paid With Cash', description = Lang:t("success.paid_with_cash", {value = Config.BailPrice}), duration = 5000, type = 'success'})
            TriggerClientEvent('qb-trucker:client:SpawnVehicle', src, vehInfo)
        elseif Player.PlayerData.money.bank >= Config.BailPrice then
            Bail[Player.PlayerData.citizenid] = Config.BailPrice
            Player.Functions.RemoveMoney('bank', Config.BailPrice, "tow-received-bail")
            TriggerClientEvent('ox_lib:notify', src, { title = 'Paid With Bank', description = Lang:t("success.paid_with_bank", {value = Config.BailPrice}), duration = 5000, type = 'success'})
            TriggerClientEvent('qb-trucker:client:SpawnVehicle', src, vehInfo)
        else
            TriggerClientEvent('ox_lib:notify', src, { title = 'No Deposit', description = Lang:t("error.no_deposit", {value = Config.BailPrice}), duration = 5000, type = 'error'})
        end
    else
        if Bail[Player.PlayerData.citizenid] then
            Player.Functions.AddMoney('cash', Bail[Player.PlayerData.citizenid], "trucker-bail-paid")
            Bail[Player.PlayerData.citizenid] = nil
            TriggerClientEvent('ox_lib:notify', src, { title = 'Refund To Cash', description = Lang:t("success.refund_to_cash", {value = Config.BailPrice}), duration = 5000, type = 'success'})
        end
    end
end)

RegisterNetEvent('qb-trucker:server:01101110', function(drops)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    drops = tonumber(drops)
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
    local taxAmount = math.ceil((price / 100) * PaymentTax)
    local payment = price - taxAmount
    Player.Functions.AddJobReputation(drops)
    Player.Functions.AddMoney("bank", payment, "trucker-salary")
    TriggerClientEvent('ox_lib:notify', src, { title = 'You Earned', description = Lang:t("success.you_earned", {value = payment}), duration = 5000, type = 'success'})
end)

RegisterNetEvent('qb-trucker:server:nano', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local chance = math.random(1, 100)
    if chance > 26 then return end
    Player.Functions.AddItem("cryptostick", 1, false)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["cryptostick"], "add")
end)

lib.callback.register('qb-trucker:server:spawnVehicle', function(source, model)
    local netId = QBCore.Functions.CreateVehicle(source, model, vec4(Config.Locations['vehicle'].coords.x, Config.Locations['vehicle'].coords.y, Config.Locations['vehicle'].coords.z, Config.Locations['vehicle'].rotation), true)
    if not netId or netId == 0 then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end

    local plate = "TRUK"..tostring(math.random(1000, 9999))
    SetVehicleNumberPlateText(veh, plate)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
    return netId, plate
end)
