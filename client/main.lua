local config = require 'config.client'
local sharedConfig = require 'config.shared'
local jobsDone = 0
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

    for i = 1, #currentZones do
        currentZones[i]:remove()
    end

    currentZones = {}
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

local function setDelivering(active)
    if QBX.PlayerData.job.name ~= 'trucker' then return end
    delivering = active
end

local function setShowMarker(active)
    if QBX.PlayerData.job.name ~= 'trucker' then return end
    showMarker = active
end

local function createZone(type, number)
    if QBX.PlayerData.job.name ~= 'trucker' then return end

    local coords
    local size
    local rotation
    local boxName
    local icon
    local debug

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
                    exports.qbx_core:Notify(locale('mission.store_reached'), 'info', 5000)
                    setShowMarker(true)
                    setDelivering(true)
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
                    setShowMarker(false)
                    setDelivering(false)
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
        exports.qbx_core:Notify(locale('success.payslip_time'), 'success', 5000)
        if DoesBlipExist(currentBlip) then
            RemoveBlip(currentBlip)
            ClearAllBlipRoutes()
            currentBlip = 0
        end
    end
end

local function createElements()
    truckVehBlip = AddBlipForCoord(sharedConfig.locations.vehicle.coords.x, sharedConfig.locations.vehicle.coords.y, sharedConfig.locations.vehicle.coords.z)
    SetBlipSprite(truckVehBlip, 326)
    SetBlipDisplay(truckVehBlip, 4)
    SetBlipScale(truckVehBlip, 0.6)
    SetBlipAsShortRange(truckVehBlip, true)
    SetBlipColour(truckVehBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(sharedConfig.locations.vehicle.label)
    EndTextCommandSetBlipName(truckVehBlip)

    truckerBlip = AddBlipForCoord(sharedConfig.locations.main.coords.x, sharedConfig.locations.main.coords.y, sharedConfig.locations.main.coords.z)
    SetBlipSprite(truckerBlip, 479)
    SetBlipDisplay(truckerBlip, 4)
    SetBlipScale(truckerBlip, 0.6)
    SetBlipAsShortRange(truckerBlip, true)
    SetBlipColour(truckerBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(sharedConfig.locations.main.label)
    EndTextCommandSetBlipName(truckerBlip)

    createZone('main')
    createZone('vehicle')
end

local function areBackDoorsOpen(vehicle) -- This is hardcoded for the rumpo currently
    return GetVehicleDoorAngleRatio(vehicle, 5) > 0.0 or GetVehicleDoorAngleRatio(vehicle, 2) > 0.0 and GetVehicleDoorAngleRatio(vehicle, 3) > 0.0
end

local function getInTrunk()
    if cache.vehicle then
        return exports.qbx_core:Notify(locale('error.get_out_vehicle'), 'error', 5000)
    end

    local pos = GetEntityCoords(cache.ped, true)
    local vehicle = GetVehiclePedIsIn(cache.ped, true)
    if not isTruckerVehicle(vehicle) or currentPlate ~= qbx.getVehiclePlate(vehicle) then
        return exports.qbx_core:Notify(locale('error.vehicle_not_correct'), 'error', 5000)
    end

    if not areBackDoorsOpen(vehicle) then
        return exports.qbx_core:Notify(locale('error.backdoors_not_open'), 'error', 5000)
    end

    local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0, -2.5, 0)
    if #(pos - trunkpos) > 1.5 then
        return exports.qbx_core:Notify(locale('error.too_far_from_trunk'), 'error', 5000)
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
        isWorking = false
        StopAnimTask(cache.ped, "anim@gangops@facility@servers@", "hotwire", 1.0)
        exports.scully_emotemenu:playEmoteByCommand('box')
        hasBox = true
        exports.qbx_core:Notify(locale('info.deliver_to_store'), 'info', 5000)
    else
        isWorking = false
        StopAnimTask(cache.ped, "anim@gangops@facility@servers@", "hotwire", 1.0)
        exports.qbx_core:Notify(locale('error.cancelled'), 'error', 5000)
    end
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
        isWorking = false
        StopAnimTask(cache.ped, "anim@gangops@facility@servers@", "hotwire", 1.0)
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
            jobsDone += 1
            local location, drop = lib.callback.await('qbx_truckerjob:server:doneJob', false)
            if location == 0 then
                exports.qbx_core:Notify(locale('mission.return_to_station'), 'info', 5000)
                returnToStation()
            else
                exports.qbx_core:Notify(locale('mission.goto_next_point'), 'info', 5000)
                getNewLocation(location, drop)
            end
        elseif currentCount ~= currentLocation.dropcount then
            exports.qbx_core:Notify(locale('mission.another_box'), 'info', 5000)
        else
            isWorking = false
            ClearPedTasks(cache.ped)
            StopAnimTask(cache.ped, "anim@gangops@facility@servers@", "hotwire", 1.0)
            exports.scully_emotemenu:cancelEmote()
            exports.qbx_core:Notify(locale('error.cancelled'), 'error', 5000)
        end
    end
end

-- Events

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    removeElements()
    currentLocation = {}
    currentBlip = 0
    hasBox = false
    isWorking = false
    jobsDone = 0

    if QBX.PlayerData.job.name ~= 'trucker' then return end

    createElements()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    removeElements()
    currentLocation = {}
    currentBlip = 0
    hasBox = false
    isWorking = false
    jobsDone = 0

    if QBX.PlayerData.job.name ~= 'trucker' then return end

    createElements()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    removeElements()
    currentLocation = {}
    currentBlip = 0
    hasBox = false
    isWorking = false
    jobsDone = 0
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
    local veh = NetToVeh(netId)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleLivery(veh, 1)
    SetVehicleColours(veh, 122, 122)
    SetVehicleEngineOn(veh, true, true, false)
    currentPlate = qbx.getVehiclePlate(veh)
    local location, drop = lib.callback.await('qbx_truckerjob:server:doneJob', false)
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
        return exports.qbx_core:Notify(locale('error.no_driver'), 'error', 5000)
    end

    if not isTruckerVehicle(cache.vehicle) then
        return exports.qbx_core:Notify(locale('error.vehicle_not_correct'), 'error', 5000)
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
    exports.qbx_core:Notify(locale('mission.job_completed'), 'success', 5000)
end)

RegisterNetEvent('qbx_truckerjob:client:paycheck', function()
    if jobsDone == 0 then
        return exports.qbx_core:Notify(locale('error.no_work_done'), 'error', 2500)
    end

    TriggerServerEvent("qbx_truckerjob:server:getPaid")
    jobsDone = 0

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
                        exports.qbx_core:Notify(locale('error.too_far_from_delivery'), 'error', 5000)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)