local config = require 'config.server'
local sharedConfig = require 'config.shared'
--- drops is the counter of packages for which payment is due
local bail, drops, locations, antiAbuse = {}, {}, {}, {}

---@alias NotificationPosition 'top' | 'top-right' | 'top-left' | 'bottom' | 'bottom-right' | 'bottom-left' | 'center-right' | 'center-left'
---@alias NotificationType 'info' | 'warning' | 'success' | 'error'

---Text box popup for player which dissappears after a set time.
---@param text table|string text of the notification
---@param notifyType? NotificationType informs default styling. Defaults to 'inform'
---@param duration? integer milliseconds notification will remain on screen. Defaults to 5000
---@param subTitle? string extra text under the title
---@param notifyPosition? NotificationPosition
---@param notifyStyle? table Custom styling. Please refer too https://coxdocs.dev/ox_lib/Modules/Interface/Client/notify#libnotify
---@param notifyIcon? string Font Awesome 6 icon name
---@param notifyIconColor? string Custom color for the icon chosen before
local function notify(player, text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
    return exports.qbx_core:Notify(player.PlayerData.source, text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
end

local function getPlayer(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    if player.PlayerData.job.name ~= 'trucker' then
        return DropPlayer(source, locale('exploit_attempt'))
    end

    return player
end

--- toggle anti spawn abuse flag
--- @param citizenid number
local function turnAntiSpawnAbuseOn(citizenid)
    CreateThread(function()
        if not antiAbuse[citizenid] then
            antiAbuse[citizenid] = true
            Wait(config.spawnBreakTime)
            antiAbuse[citizenid] = nil
        end
    end)
end

RegisterNetEvent('qbx_truckerjob:server:returnVehicle', function ()
    local player = getPlayer(source)

    if not player then return end

    local citizenid = player.PlayerData.citizenid

    if bail[citizenid] then
        player.Functions.AddMoney('cash', bail[citizenid], 'trucker-bail-paid')
        bail[citizenid] = nil

        notify(player, locale('success.refund_to_cash', config.bailPrice), 'success')
    end
end)

RegisterNetEvent('qbx_truckerjob:server:doBail', function(veh)
    local player = getPlayer(source)

    if not player then return end

    local citizenid = player.PlayerData.citizenid

    turnAntiSpawnAbuseOn(citizenid)
    if antiAbuse[citizenid] then
        return notify(player, locale('error.too_many_rents', config.bailPrice), 'error')
    end

    local money = player.PlayerData.money

    if money.cash < config.bailPrice then
        if money.bank < config.bailPrice then
            return notify(player, locale('error.no_deposit', config.bailPrice), 'error')
        end

        player.Functions.RemoveMoney('bank', config.bailPrice, 'tow-received-bail')
        notify(player, locale('success.paid_with_bank', config.bailPrice), 'success')
    else
        player.Functions.RemoveMoney('cash', config.bailPrice, 'tow-received-bail')
        notify(player, locale('success.paid_with_cash', config.bailPrice), 'success')
    end

    bail[citizenid] = config.bailPrice
    TriggerClientEvent('qbx_truckerjob:client:spawnVehicle', player.PlayerData.source, veh)
end)

RegisterNetEvent('qbx_truckerjob:server:getPaid', function()
    local player = getPlayer(source)

    if not player then return end

    local citizenid = player.PlayerData.citizenid

    local playerDrops = drops[citizenid] or 0

    if playerDrops == 0 then
        return notify(player, locale('error.no_work_done'), 'error')
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
    drops[citizenid] = nil

    player.Functions.AddMoney('bank', payment, 'trucker-salary')
    notify(player, locale('success.you_earned', payment), 'success')
end)

lib.callback.register('qbx_truckerjob:server:spawnVehicle', function(source, model)
    local player = getPlayer(source)

    if not player then return end

    local vehicleLocation = sharedConfig.locations.vehicle

    local plate = 'TRUK' .. lib.string.random('1111')
    local netId, veh = qbx.spawnVehicle({
        model = model,
        spawnSource = vec4(vehicleLocation.coords.x, vehicleLocation.coords.y, vehicleLocation.coords.z, vehicleLocation.rotation),
        warp = GetPlayerPed(source),
        props = {
            plate = plate,
            modLivery = 1,
            color1 = 122,
            color2 = 122,
        }
    })

    if not netId or netId == 0 then return end
    if not veh or veh == 0 then return end

    lib.print.debug('spawn vehicle with plate: ', GetVehicleNumberPlateText(veh))
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
    return netId, plate
end)

AddEventHandler('playerDropped', function (source)
    locations[source] = nil
end)

--- Checks if location is in done table
--- @param doneLocations table
--- @param current number
--- @return boolean? `true` when location is not in the table, nil otherwise
local function isNotLocationDone(doneLocations, current)
    for _, location in ipairs(doneLocations) do
        if location == current then return end
    end

    return true
end

--- deprecated in the current version, cryptosticks have no value
--- gives cryptostick
--- param player any `Player`
-- local function giveReward(player)
--     if math.random() < 0.74 then
--         player.Functions.AddItem('cryptostick', 1, false)
--     end
-- end

--- selection of a new delivery destination
--- @param source number player id
--- @param init boolean
--- @return integer? `shop index` if any route to do, 0 otherwise
--- @return integer boxes per location
lib.callback.register('qbx_truckerjob:server:getNewTask', function(source, init)
    local player = getPlayer(source)
    if not player then return nil, 0 end

    local citizenid = player.PlayerData.citizenid

    if init then
        local randPositionIndex = math.random(#sharedConfig.locations.stores)
        locations[source] = { done = {}, current = randPositionIndex }

        return randPositionIndex, math.random(config.drops.min, config.drops.max)
    end

    drops[citizenid] = (drops[citizenid] or 0) + 1

    local doneLocations = locations[source].done
    locations[source].done[#doneLocations + 1] = locations[source].current
    if #doneLocations == config.maxLocations then
        locations[source].current = nil
        return 0, 0
    end

    -- giveReward(player)

    local index = 0
    local minDist = 0
    local stores = sharedConfig.locations.stores

    local currentCoords = sharedConfig.locations.stores[locations[source].current].coords.xyz

    for i = 1, #stores do
        local store = stores[i]
        if isNotLocationDone(locations[source].done, i) then
            local storeLocation = store.coords.xyz
            local distance = #(currentCoords - storeLocation)
            if minDist == 0 or (distance ~= 0 and distance < minDist) then
                index = i
                minDist = distance
            end
        end
    end

    locations[source].current = index

    return index, math.random(config.drops.min, config.drops.max)
end)
