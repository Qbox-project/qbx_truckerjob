local config = require 'config.server'
local sharedConfig = require 'config.shared'
--- drops is the counter of packages for which payment is due
local bail, drops, locations, antiAbuse = {}, {}, {}, {}

local function getPlayer(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    if player.PlayerData.job.name ~= "trucker" then
        return DropPlayer(source, locale('exploit_attempt'))
    end

    return player
end

local function turnAntiSpawnAbuseOn(source)
    CreateThread(function ()
        if not antiAbuse[source] then
            antiAbuse[source] = true
            Wait(config.spawnBreakTime)
            antiAbuse[source] = nil
        end
    end)
end

RegisterNetEvent('qbx_truckerjob:server:doBail', function(bool, vehInfo)
    local player = getPlayer(source)
    if not player then return end

    if bool then
        turnAntiSpawnAbuseOn(source)
        if antiAbuse[source] then
            return exports.qbx_core:Notify(source, locale("error.too_many_rents", config.bailPrice), "error")
        end

        if player.PlayerData.money.cash >= config.bailPrice then
            bail[player.PlayerData.citizenid] = config.bailPrice
            player.Functions.RemoveMoney('cash', config.bailPrice, "tow-received-bail")

            exports.qbx_core:Notify(source, locale("success.paid_with_cash", config.bailPrice), "success")
            TriggerClientEvent('qbx_truckerjob:client:spawnVehicle', source, vehInfo)
        elseif player.PlayerData.money.bank >= config.bailPrice then
            bail[player.PlayerData.citizenid] = config.bailPrice
            player.Functions.RemoveMoney('bank', config.bailPrice, "tow-received-bail")
            exports.qbx_core:Notify(source, locale("success.paid_with_bank", config.bailPrice), "success")

            TriggerClientEvent('qbx_truckerjob:client:spawnVehicle', source, vehInfo)
        else
            exports.qbx_core:Notify(source, locale("error.no_deposit", config.bailPrice), "error")
        end
    else
        if bail[player.PlayerData.citizenid] then
            player.Functions.AddMoney('cash', bail[player.PlayerData.citizenid], "trucker-bail-paid")
            bail[player.PlayerData.citizenid] = nil

            exports.qbx_core:Notify(source, locale("success.refund_to_cash", config.bailPrice), "success")
        end
    end
end)

RegisterNetEvent('qbx_truckerjob:server:getPaid', function()
    local player = getPlayer(source)
    if not player then return end

    local playerDrops = drops[source] or 0

    if playerDrops == 0 then
        return exports.qbx_core:Notify(locale('error.no_work_done'), 'error')
    end

    local dropPrice, bonus = math.random(100, 120), 0

    if playerDrops >= 5 then
        bonus = math.ceil((dropPrice / 10) * 5) + 100
    elseif playerDrops >= 10 then
        bonus = math.ceil((dropPrice / 10) * 7) + 300
    elseif playerDrops >= 15 then
        bonus = math.ceil((dropPrice / 10) * 10) + 400
    elseif playerDrops >= 20 then
        bonus = math.ceil((dropPrice / 10) * 12) + 500
    end

    local price = (dropPrice * playerDrops) + bonus
    local taxAmount = math.ceil((price / 100) * config.paymentTax)
    local payment = price - taxAmount
    player.Functions.AddJobReputation(playerDrops)
    drops[source] = nil

    player.Functions.AddMoney("bank", payment, "trucker-salary")
    exports.qbx_core:Notify(source, locale("success.you_earned", payment), "success")
end)

lib.callback.register('qbx_truckerjob:server:spawnVehicle', function(source, model)
    local netId = qbx.spawnVehicle({
        model = model,
        spawnSource = vec4(sharedConfig.locations.vehicle.coords.x, sharedConfig.locations.vehicle.coords.y, sharedConfig.locations.vehicle.coords.z, sharedConfig.locations.vehicle.rotation),
        warp = GetPlayerPed(source),
    })
    if not netId or netId == 0 then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 then return end

    local plate = "TRUK"..lib.string.random('1111')
    SetVehicleNumberPlateText(vehicle, plate)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
    return netId, plate
end)

RegisterNetEvent("QBCore:Server:OnPlayerUnload", function (client)
    locations[client] = nil
end)

local function isNotLocationDone(location, current)
    for i=1,#location.done do
        if location.done[i] == current then
            return false
        end
    end

    return true
end

local function giveReward(player)
    if math.random() < 0.74 then
        player.Functions.AddItem("cryptostick", 1, false)
    end
end

--- selection of a new delivery destination
--- @param source number player id
--- @param init boolean
--- @return integer? `shop index` if any route to do, 0 otherwise
--- @return integer boxes per location
lib.callback.register('qbx_truckerjob:server:getNewTask', function (source, init)
    local player = getPlayer(source)
    if not player then return nil, 0 end

    if init then
        local randPositionIndex = math.random(#sharedConfig.locations.stores)
        locations[source] = {done = {}, current = randPositionIndex}

        return randPositionIndex, math.random(config.drops.min, config.drops.max)
    end

    drops[source] = (drops[source] or 0) + 1

    local doneLocations = locations[source].done
    if #doneLocations == (config.maxDrops - 1) then
        locations[source].done[#doneLocations + 1] = locations[source].current
        locations[source].current = nil
        return 0, 0
    end

    giveReward(player)

    locations[source].done[#locations[source].done + 1]
        = locations[source].current

    local index = 0
    local minDist = 0
    local stores = sharedConfig.locations.stores

    local currentCoords = sharedConfig.locations.stores[locations[source].current].coords.xyz

    for i=1,#stores do
        local store = stores[i]
        if isNotLocationDone(locations[source], i) then
            local storeLocation = store.coords.xyz
            local distance = #(currentCoords - storeLocation)
            if  minDist == 0 or (distance ~= 0 and distance < minDist) then
                index = i
                minDist = distance
            end
        end
    end

    locations[source].current = index

    return index, math.random(config.drops.min, config.drops.max)
end)
