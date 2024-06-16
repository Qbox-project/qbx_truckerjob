local config = require 'config.client'
local sharedConfig = require 'config.shared'
local currentZones = {}
local currentLocation = {}
local currentBlip = 0
local hasBox = false
local truckVehBlip = 0
local truckerBlip = 0
local returningToStation = false
local currentPlate

-- Functions
local function returnToStation()
    SetBlipRoute(truckVehBlip, true)
    returningToStation = true
end

local function isTruckerVehicle(vehicle)
    return config.vehicles[GetEntityModel(vehicle)]
end

local function removeElements()
    ClearAllBlipRoutes()
    if DoesBlipExist(truckVehBlip) then
        RemoveBlip(truckVehBlip)
        truckVehBlip = 0
    end

    if DoesBlipExist(truckerBlip) then
        RemoveBlip(truckerBlip)
        truckerBlip = 0
    end

    if DoesBlipExist(currentBlip) then
        RemoveBlip(currentBlip)
        currentBlip = 0
    end

    for _, zone in ipairs(currentZones) do
        zone:remove()
    end

    currentZones = {}
end

local function getPaid()
    TriggerServerEvent("qbx_truckerjob:server:getPaid")

    if DoesBlipExist(currentBlip) then
        RemoveBlip(currentBlip)
        ClearAllBlipRoutes()
        currentBlip = 0
    end
end

local function returnVehicle()
    if cache.seat ~= -1 then
        return exports.qbx_core:Notify(locale('error.no_driver'), 'error')
    end

    if not isTruckerVehicle(cache.vehicle) then
        return exports.qbx_core:Notify(locale('error.vehicle_not_correct'), 'error')
    end

    DeleteVehicle(cache.vehicle)
    TriggerServerEvent('qbx_truckerjob:server:returnVehicle')

    if DoesBlipExist(currentBlip) then
        RemoveBlip(currentBlip)
        ClearAllBlipRoutes()
        currentBlip = 0
    end

    if not returningToStation and not next(currentLocation) then return end

    ClearAllBlipRoutes()
    returningToStation = false
    exports.qbx_core:Notify(locale('mission.job_completed'), 'success')
end

local function openMenuGarage()
    local truckMenu = {}
    for k in pairs(config.vehicles) do
        truckMenu[#truckMenu + 1] = {
            title = config.vehicles[k],
            serverEvent = 'qbx_truckerjob:server:doBail',
            args = k
        }
    end

    lib.registerContext({
        id = 'trucker_veh_menu',
        title = locale("menu.header"),
        options = truckMenu
    })

    lib.showContext('trucker_veh_menu')
end

local function createMainTarget()
    local location = sharedConfig.locations.main;
    currentZones[#currentZones + 1] = exports.ox_target:addBoxZone({
        coords = location.coords,
        size = location.size,
        rotation = location.rotation,
        debug = debug,
        options = {
            {
                name = location.label,
                onSelect = function()
                    getPaid()
                end,
                icon = location.icon,
                label = location.label,
                distance = 2,
                canInteract = function()
                    return QBX.PlayerData.job.name == 'trucker'
                end
            }
        }
    })
end

local function createMainZone()
    local location = sharedConfig.locations.main;

    local zone = lib.zones.sphere({
        coords = location.coords,
        radius = location.markerRadius,
        debug = location.debug
    })

    local innerZone = lib.zones.sphere({
        coords = location.coords,
        radius = location.interactionsRadius,
        debug = location.debug
    })

    local marker = lib.marker.new({
        coords = location.coords,
        type = location.markerType,
        height = 0.2,
        width = 0.3
    })

    function zone:inside()
        marker:draw()
    end

    function innerZone:onEnter()
        if not lib.isTextUIOpen() then
            lib.showTextUI(locale('info.pickup_paycheck'))
        end
    end

    function innerZone:inside()
        if IsControlJustPressed(0, 38) then
            getPaid()
        end
    end

    function innerZone:onExit()
        local isOpen, currentText = lib.isTextUIOpen()
        if isOpen and currentText == locale('info.pickup_paycheck') then
            lib.hideTextUI()
        end
    end

    currentZones[#currentZones + 1] = zone
    currentZones[#currentZones + 1] = innerZone
end

local createMain = config.useTarget and createMainTarget or createMainZone

local function createVehicleZone()
    local location = sharedConfig.locations.vehicle;

    local zone = lib.zones.sphere({
        coords = location.coords,
        radius = location.markerRadius,
        debug = location.debug
    })

    local innerZone = lib.zones.sphere({
        coords = location.coords,
        radius = location.interactionsRadius,
        debug = location.debug
    })

    local marker = lib.marker.new({
        coords = location.coords,
        type = location.markerType,
        height = 0.2,
        width = 0.3
    })

    local function hideTextUI()
        local isOpen, currentText = lib.isTextUIOpen()
        if isOpen and (currentText == locale('info.store_vehicle') or currentText == locale('info.vehicles')) then
            lib.hideTextUI()
        end
    end

    function zone:inside()
        marker:draw()
    end

    function innerZone:onEnter()
        if not lib.isTextUIOpen() then
            lib.showTextUI(locale(cache.vehicle and 'info.store_vehicle' or 'info.vehicles'))
        end
    end

    local isChangeTextAllowed = false
    function innerZone:inside()
        ---This section updates the textui when the client uses the garage.
        if isChangeTextAllowed then
            local _, currentText = lib.isTextUIOpen()
            local expectedText = locale(cache.vehicle and 'info.store_vehicle' or 'info.vehicles')
            if currentText ~= expectedText and not lib.getOpenContextMenu() then
                isChangeTextAllowed = false
                CreateThread(function()
                    Wait(1000)
                    lib.showTextUI(locale(cache.vehicle and 'info.store_vehicle' or 'info.vehicles'))
                end)
            end
        end
        ---

        if IsControlJustPressed(0, 38) then
            if cache.vehicle then
                returnVehicle()
            else
                openMenuGarage()
            end

            hideTextUI()
            isChangeTextAllowed = true
        end
    end

    function innerZone:onExit()
        hideTextUI()
    end

    currentZones[#currentZones + 1] = zone
    currentZones[#currentZones + 1] = innerZone
end

local function areBackDoorsOpen(vehicle) -- This is hardcoded for the rumpo currently
    return GetVehicleDoorAngleRatio(vehicle, 5) > 0.0
        or GetVehicleDoorAngleRatio(vehicle, 2) > 0.0
        and GetVehicleDoorAngleRatio(vehicle, 3) > 0.0
end

local function getInTrunk()
    if cache.vehicle then
        return exports.qbx_core:Notify(locale('error.get_out_vehicle'), 'error')
    end

    local vehicle = GetVehiclePedIsIn(cache.ped, true)
    if not isTruckerVehicle(vehicle) or currentPlate ~= qbx.getVehiclePlate(vehicle) then
        return exports.qbx_core:Notify(locale('error.vehicle_not_correct'), 'error')
    end

    if not areBackDoorsOpen(vehicle) then
        return exports.qbx_core:Notify(locale('error.backdoors_not_open'), 'error')
    end

    local pedCoords = GetEntityCoords(cache.ped, true)
    local trunkCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0, -2.5, 0)
    if #(pedCoords - trunkCoords) > 1.5 then
        return exports.qbx_core:Notify(locale('error.too_far_from_trunk'), 'error')
    end

    if lib.progressCircle({
        duration = 2000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            mouse = false,
            combat = true,
            move = true,
        },
        anim = {
            dict = 'anim@gangops@facility@servers@',
            clip = 'hotwire'
        },
    }) then
        exports.scully_emotemenu:playEmoteByCommand('box')
        hasBox = true
        exports.qbx_core:Notify(locale('info.deliver_to_store'), 'info')
    else
        exports.qbx_core:Notify(locale('error.cancelled'), 'error')
    end
end

local function deliver()
    if lib.progressCircle({
        duration = 3000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            mouse = false,
            combat = true,
            move = true,
        },
        anim = {
            dict = 'anim@gangops@facility@servers@',
            clip = 'hotwire'
        },
    }) then
        exports.scully_emotemenu:cancelEmote()
        ClearPedTasks(cache.ped)
        hasBox = false
        currentLocation.currentCount += 1
        lib.print.debug('count: '..currentLocation.currentCount..'/'..currentLocation.dropCount)
        if currentLocation.currentCount == currentLocation.dropCount then
            if DoesBlipExist(currentBlip) then
                RemoveBlip(currentBlip)
                ClearAllBlipRoutes()
                currentBlip = 0
            end
            currentLocation.zoneCombo:remove()
            currentLocation = {}
            local location, drop = lib.callback.await('qbx_truckerjob:server:getNewTask', false)
            if not location or QBX.PlayerData.job.name ~= 'trucker' then return
            elseif location == 0 then
                exports.qbx_core:Notify(locale('mission.return_to_station'), 'info')
                returnToStation()
            else
                exports.qbx_core:Notify(locale('mission.goto_next_point'), 'info')
                GetNewLocation(location, drop)
            end
        elseif currentLocation.currentCount ~= currentLocation.dropCount then
            exports.qbx_core:Notify(locale('mission.another_box'), 'info')
        else
            ClearPedTasks(cache.ped)
            StopAnimTask(cache.ped, "anim@gangops@facility@servers@", "hotwire", 1.0)
            exports.scully_emotemenu:cancelEmote()
            exports.qbx_core:Notify(locale('error.cancelled'), 'error')
        end
    end
end

local function createShopZone(location)
    local marker = lib.marker.new({
        coords = location.coords,
        type = location.markerType or 2,
        height = 0.2,
        width = 0.3
    })

    local zone = lib.zones.box({
        name = location.label,
        coords = location.coords,
        size = location.size,
        rotation = location.rotation,
        debug = location.debug,
        onEnter = function()
            exports.qbx_core:Notify(locale('mission.store_reached'), 'info')
        end,
        inside = function ()
            marker:draw()

            if IsControlJustReleased(0, 38) then
                if cache.vehicle then
                    return exports.qbx_core:Notify(locale('error.get_out_vehicle'), 'error')
                elseif not hasBox then
                    getInTrunk()
                elseif #(GetEntityCoords(cache.ped) - location.coords) < 5 then
                    deliver()
                else
                    exports.qbx_core:Notify(locale('error.too_far_from_delivery'), 'error')
                end
            end
        end,
    })

    return zone
end

function GetNewLocation(locationIndex, drop)
    local location = sharedConfig.locations.stores[locationIndex]
    currentLocation = { dropCount = drop, currentCount = 0 }

    currentLocation.zoneCombo = createShopZone(location)

    currentBlip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
    SetBlipColour(currentBlip, 3)
    SetBlipRoute(currentBlip, true)
    SetBlipRouteColour(currentBlip, 3)
end

local function createElement(location, sprinteId)
    local element = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
    SetBlipSprite(element, sprinteId)
    SetBlipDisplay(element, 4)
    SetBlipScale(element, 0.6)
    SetBlipAsShortRange(element, true)
    SetBlipColour(element, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(location.label)
    EndTextCommandSetBlipName(element)

    return element
end

local function createElements()
    if QBX.PlayerData.job.name ~= 'trucker' then return end

    truckVehBlip = createElement(sharedConfig.locations.vehicle, 326)
    truckerBlip = createElement(sharedConfig.locations.main, 479)

    createMain()
    createVehicleZone()
end

-- Events

local function setInitState()
    removeElements()
    currentLocation = {}
    currentBlip = 0
    hasBox = false
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    setInitState()
    createElements()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    setInitState()
    createElements()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    setInitState()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    removeElements()

    if next(currentLocation) and currentLocation.zoneCombo then
        currentLocation.zoneCombo:remove()
    end

    createElements()
end)

RegisterNetEvent('qbx_truckerjob:client:spawnVehicle', function(veh)
    local netId, plate = lib.callback.await('qbx_truckerjob:server:spawnVehicle', false, veh)
    if not netId then return end
    currentPlate = plate
    local vehicle = NetToVeh(netId)
    SetVehicleLivery(vehicle, 1)
    SetVehicleColours(vehicle, 122, 122)
    SetVehicleEngineOn(vehicle, true, true, false)

    local location, drop = lib.callback.await('qbx_truckerjob:server:getNewTask', false, true)

    if not location then return end
    GetNewLocation(location, drop)
end)
