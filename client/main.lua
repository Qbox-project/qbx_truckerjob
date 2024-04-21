local config = require 'config.client'
local sharedConfig = require 'config.shared'
local currentZones = {}
local currentLocation = {}
local currentBlip = 0
local hasBox = false
local isWorking = false
local currentCount = 0
local currentPlate = nil
local selectedVeh = nil
local truckVehBlip = 0
local truckerBlip = 0
local delivering = false
local showMarker = false
local markerLocation
local returningToStation = false

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
end

local function openMenuGarage()
    local truckMenu = {}
    for k in pairs(config.vehicles) do
        truckMenu[#truckMenu + 1] = {
            title = config.vehicles[k],
            event = "qbx_truckerjob:client:takeOutVehicle",
            args = {
                vehicle = k
            }
        }
    end

    lib.registerContext({
        id = 'trucker_veh_menu',
        title = locale("menu.header"),
        options = truckMenu
    })

    lib.showContext('trucker_veh_menu')
end

local function setShowMarker(active)
    if QBX.PlayerData.job.name ~= 'trucker' then return end
    showMarker = active
end

local function setShowMarkerWithDelivering(isMarker, isDelivering)
    if QBX.PlayerData.job.name ~= 'trucker' then return end
    showMarker = isMarker
    delivering = isDelivering
end

local function createZone(type, number)
    if QBX.PlayerData.job.name ~= 'trucker' then return end

    local coords, size, rotation, boxName, icon, debug

    for k, v in pairs(sharedConfig.locations) do
        if k == type then
            if type == 'stores' then
                coords = v[number].coords
                size = v[number].size
                rotation = v[number].rotation
                boxName = v[number].label
                debug = v[number].debug
            else
                coords = v.coords
                size = v.size
                rotation = v.rotation
                boxName = v.label
                icon = v.icon
                debug = v.debug
            end
        end
    end

    if config.useTarget and type == 'main' then
        exports.ox_target:addBoxZone({
            coords = coords,
            size = size,
            rotation = rotation,
            debug = debug,
            options = {
                {
                    name = boxName,
                    event = 'qbx_truckerjob:client:paycheck',
                    icon = icon,
                    label = boxName,
                    distance = 2,
                    canInteract = function()
                        return QBX.PlayerData.job.name == 'trucker'
                    end
                }
            }
        })
    else
        local boxZone = lib.zones.box({
            name = boxName,
            coords = coords,
            size = size,
            rotation = rotation,
            debug = debug,
            onEnter = function()
                if QBX.PlayerData.job.name ~= 'trucker' then return end

                if type == 'main' then
                    lib.showTextUI(locale('info.pickup_paycheck'))
                elseif type == 'vehicle' then
                    if cache.vehicle then
                        lib.showTextUI(locale('info.store_vehicle'))
                    else
                        lib.showTextUI(locale('info.vehicles'))
                    end
                    markerLocation = coords
                    setShowMarker(true)
                elseif type == 'stores' then
                    markerLocation = coords
                    exports.qbx_core:Notify(locale('mission.store_reached'), 'info')
                    setShowMarkerWithDelivering(true, true)
                end
            end,
            inside = function()
                if QBX.PlayerData.job.name ~= 'trucker' then return end

                if type == 'main' then
                    if IsControlJustReleased(0, 38) then
                        TriggerEvent('qbx_truckerjob:client:paycheck')
                    end
                elseif type == 'vehicle' then
                    if IsControlJustReleased(0, 38) then
                        TriggerEvent('qbx_truckerjob:client:vehicle')
                    end
                end
            end,
            onExit = function()
                if QBX.PlayerData.job.name ~= 'trucker' then return end

                if type == 'main' then
                    lib.hideTextUI()
                elseif type == 'vehicle' then
                    setShowMarker(false)
                    lib.hideTextUI()
                elseif type == 'stores' then
                    setShowMarkerWithDelivering(false, false)
                end
            end
        })

        if type == 'stores' then
            currentLocation.zoneCombo = boxZone
        else
            currentZones[#currentZones + 1] = boxZone
        end
    end
end

local function getNewLocation(location, drop)
    if location ~= 0 then
        currentLocation = {
            id = location,
            dropcount = drop,
            store = sharedConfig.locations.stores[location].label,
            coords = sharedConfig.locations.stores[location].coords
        }

        createZone('stores', location)

        currentBlip = AddBlipForCoord(currentLocation.coords.x, currentLocation.coords.y, currentLocation.coords.z)
        SetBlipColour(currentBlip, 3)
        SetBlipRoute(currentBlip, true)
        SetBlipRouteColour(currentBlip, 3)
    else
        exports.qbx_core:Notify(locale('success.payslip_time'), 'success')
        if DoesBlipExist(currentBlip) then
            RemoveBlip(currentBlip)
            ClearAllBlipRoutes()
            currentBlip = 0
        end
    end
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
    truckVehBlip = createElement(sharedConfig.locations.vehicle, 326)
    truckerBlip = createElement(sharedConfig.locations.main, 479)

    createZone('main')
    createZone('vehicle')
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

    local pedCoords = GetEntityCoords(cache.ped, true)
    local vehicle = GetVehiclePedIsIn(cache.ped, true)
    if not isTruckerVehicle(vehicle) or currentPlate ~= qbx.getVehiclePlate(vehicle) then
        return exports.qbx_core:Notify(locale('error.vehicle_not_correct'), 'error')
    end

    if not areBackDoorsOpen(vehicle) then
        return exports.qbx_core:Notify(locale('error.backdoors_not_open'), 'error')
    end

    local trunkCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0, -2.5, 0)
    if #(pedCoords - trunkCoords) > 1.5 then
        return exports.qbx_core:Notify(locale('error.too_far_from_trunk'), 'error')
    end

    if isWorking then return end

    isWorking = true

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
    isWorking = false
end

local function deliver()
    isWorking = true
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
        currentCount += 1
        if currentCount == currentLocation.dropcount then
            delivering = false
            showMarker = false
            if DoesBlipExist(currentBlip) then
                RemoveBlip(currentBlip)
                ClearAllBlipRoutes()
                currentBlip = 0
            end
            currentLocation.zoneCombo:remove()
            currentLocation = {}
            currentCount = 0
            local location, drop = lib.callback.await('qbx_truckerjob:server:completeJob', false)
            if not location then return
            elseif location == 0 then
                exports.qbx_core:Notify(locale('mission.return_to_station'), 'info')
                returnToStation()
            else
                exports.qbx_core:Notify(locale('mission.goto_next_point'), 'info')
                getNewLocation(location, drop)
            end
        elseif currentCount ~= currentLocation.dropcount then
            exports.qbx_core:Notify(locale('mission.another_box'), 'info')
        else
            ClearPedTasks(cache.ped)
            StopAnimTask(cache.ped, "anim@gangops@facility@servers@", "hotwire", 1.0)
            exports.scully_emotemenu:cancelEmote()
            exports.qbx_core:Notify(locale('error.cancelled'), 'error')
        end
    end
    isWorking = false
end

-- Events

local function setInitState()
    removeElements()
    currentLocation = {}
    currentBlip = 0
    isWorking, hasBox = false, false
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    setInitState()

    if QBX.PlayerData.job.name ~= 'trucker' then return end

    createElements()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    setInitState()

    if QBX.PlayerData.job.name ~= 'trucker' then return end

    createElements()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    setInitState()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    removeElements()

    if next(currentLocation) and currentLocation.zoneCombo then
        currentLocation.zoneCombo:remove()
        delivering = false
        showMarker = false
    end

    if QBX.PlayerData.job.name ~= 'trucker' then return end

    createElements()
end)

RegisterNetEvent('qbx_truckerjob:client:spawnVehicle', function()
    local netId, plate = lib.callback.await('qbx_truckerjob:server:spawnVehicle', false, selectedVeh)
    if not netId then return end
    local vehicle = NetToVeh(netId)
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleLivery(vehicle, 1)
    SetVehicleColours(vehicle, 122, 122)
    SetVehicleEngineOn(vehicle, true, true, false)
    currentPlate = qbx.getVehiclePlate(vehicle)
    local location, drop = lib.callback.await('qbx_truckerjob:server:completeJob', false, true)
    if not location then return end
    getNewLocation(location, drop)
end)

RegisterNetEvent('qbx_truckerjob:client:takeOutVehicle', function(data)
    local vehicleInfo = data.vehicle
    TriggerServerEvent('qbx_truckerjob:server:doBail', true, vehicleInfo)
    selectedVeh = vehicleInfo
end)

RegisterNetEvent('qbx_truckerjob:client:vehicle', function()
    if not cache.vehicle then
        return openMenuGarage()
    end

    if cache.seat ~= -1 then
        return exports.qbx_core:Notify(locale('error.no_driver'), 'error')
    end

    if not isTruckerVehicle(cache.vehicle) then
        return exports.qbx_core:Notify(locale('error.vehicle_not_correct'), 'error')
    end

    DeleteVehicle(cache.vehicle)
    TriggerServerEvent('qbx_truckerjob:server:doBail', false)

    if DoesBlipExist(currentBlip) then
        RemoveBlip(currentBlip)
        ClearAllBlipRoutes()
        currentBlip = 0
    end

    if not returningToStation and not next(currentLocation) then return end

    ClearAllBlipRoutes()
    returningToStation = false
    exports.qbx_core:Notify(locale('mission.job_completed'), 'success')
end)

RegisterNetEvent('qbx_truckerjob:client:paycheck', function()
    TriggerServerEvent("qbx_truckerjob:server:getPaid")

    if not DoesBlipExist(currentBlip) then return end

    RemoveBlip(currentBlip)
    ClearAllBlipRoutes()
    currentBlip = 0
end)

-- Threads

CreateThread(function()
    local sleep
    while true do
        sleep = 1000
        if showMarker then
            sleep = 0
            ---@diagnostic disable-next-line: param-type-mismatch
            DrawMarker(2, markerLocation.x, markerLocation.y, markerLocation.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, 0, true, nil, nil, false)
        end
        if delivering then
            sleep = 0
            if IsControlJustReleased(0, 38) then
                if not hasBox then
                    getInTrunk()
                else
                    if #(GetEntityCoords(cache.ped) - markerLocation) < 5 then
                        deliver()
                    else
                        exports.qbx_core:Notify(locale('error.too_far_from_delivery'), 'error')
                    end
                end
            end
        end
        Wait(sleep)
    end
end)