local QBCore = exports['qb-core']:GetCoreObject()
local lib = exports['ox_lib']:GetLibObject()

local deliveryCount = 0
local currentRoute = nil
local palletProp = nil
local palletDelivered = false
local forklift = nil
local forkliftSpawnLocation = nil
local jobTimer = nil
local deliverySiteTimer = nil
local deliverySitePalletProp = nil
local startLocation = nil
local endLocation = nil

local function resetDeliveryCount()
    deliveryCount = 0
end

local function showRouteSelection()
    -- Code to show route selection UI using ox_lib
    local routes = {
        {label = "Route 1", value = "Route 1"},
        {label = "Route 2", value = "Route 2"},
        {label = "Route 3", value = "Route 3"}
    }

    local input = lib.inputDialog("Select a Route", {
        {type = "select", label = "Route", options = routes}
    })

    if input then
        local selectedRoute = input[1]
        print("Selected route: " .. selectedRoute)
        return selectedRoute
    else
        print("No route selected")
        return nil
    end
end

local function getRandomLocation()
    local ports = Config.Ports
    return ports[math.random(#ports)].coords
end

local function spawnBoat(route)
    -- Code to spawn a boat at a specified location based on the route
    local boats = Config.Boats
    local randomBoat = boats[math.random(#boats)]
    local boatModel = GetHashKey(randomBoat.model)
    RequestModel(boatModel)
    while not HasModelLoaded(boatModel) do
        Wait(1)
    end

    -- Placeholder random location for boat spawning
    startLocation = getRandomLocation()
    local heading = math.random(0, 360)

    local playerPed = PlayerPedId()
    local boat = CreateVehicle(boatModel, startLocation.x, startLocation.y, startLocation.z, heading, true, false)
    TaskWarpPedIntoVehicle(playerPed, boat, -1)
end

local function spawnPallet()
    -- Code to spawn a pallet prop at a placeholder location
    local palletModel = GetHashKey("prop_boxpile_07d")
    RequestModel(palletModel)
    while not HasModelLoaded(palletModel) do
        Wait(1)
    end

    local spawnLocation = vector3(math.random(-2000, 2000), math.random(-2000, 2000), 0.0)
    palletProp = CreateObject(palletModel, spawnLocation.x, spawnLocation.y, spawnLocation.z, true, true, false)
end

local function startDeliveryJob(route)
    -- Code to start the delivery job
    spawnBoat(route)
    spawnPallet()
    deliveryCount = deliveryCount + 1
    currentRoute = route
    palletDelivered = false

    -- Set waypoints based on the selected route
    endLocation = getRandomLocation()
    SetNewWaypoint(endLocation.x, endLocation.y)

    lib.notify({
        title = "Delivery Job Started",
        description = "Follow the waypoint to complete the delivery.",
        type = "success"
    })
    lib.notify({
        title = "Delivery Job Started",
        description = "Follow the waypoint to complete the delivery.",
        type = "success"
    })

    -- Start job timer
    jobTimer = GetGameTimer() + 15 * 60 * 1000 -- 15 minutes
end

local function endDeliveryJob()
    -- Code to end the delivery job
    if palletProp then
        DeleteObject(palletProp)
        palletProp = nil
    end
    if forklift then
        DeleteVehicle(forklift)
        forklift = nil
        forkliftSpawnLocation = nil
    end
    if deliverySitePalletProp then
        if deliverySitePalletProp then
            if deliverySitePalletProp then
                if deliverySitePalletProp then
                    if deliverySitePalletProp then
                        if deliverySitePalletProp then
                            if deliverySitePalletProp then
                                if deliverySitePalletProp then
                                    if deliverySitePalletProp then
                                        DeleteObject(deliverySitePalletProp)
                                        deliverySitePalletProp = nil
                                    end
                                end
                            end
                        end
                    end
                    deliverySitePalletProp = nil
                end
            end
        end
    end
    currentRoute = nil
    palletDelivered = false
    jobTimer = nil
    deliverySiteTimer = nil
    startLocation = nil
    endLocation = nil

    lib.notify({
        title = "Delivery Job Ended",
        description = "The delivery job has ended.",
        type = "error"
    })
end

local function spawnDeliverySitePallet()
    -- Code to spawn a pallet prop at the delivery site
    local palletModel = GetHashKey("prop_boxpile_07d")
    RequestModel(palletModel)
    while not HasModelLoaded(palletModel) do
        Wait(1)
    end

    local spawnLocation = vector3(math.random(-2000, 2000), math.random(-2000, 2000), 0.0)
    deliverySitePalletProp = CreateObject(palletModel, spawnLocation.x, spawnLocation.y, spawnLocation.z, true, true, false)
end

local function startDeliverySiteJob()
    -- Code to start the delivery site job
    spawnDeliverySitePallet()
    deliverySiteTimer = GetGameTimer() + 15 * 60 * 1000 -- 15 minutes

    lib.notify({
        title = "Delivery Site Job Started",
        description = "Move the pallets off the boat and into the delivery site.",
        type = "success"
    })
end

RegisterNetEvent('cargo:startDelivery', function()
    -- Code to start the delivery job
    local selectedRoute = showRouteSelection()
    if selectedRoute then
        TriggerServerEvent('cargo:startDelivery', selectedRoute)
    else
        print("Delivery job cancelled")
    end
end)

RegisterNetEvent('cargo:spawnBoatAndPallet', function(route)
    startDeliveryJob(route)
end)

RegisterNetEvent('cargo:completeDelivery', function()
    -- Code to complete the delivery job
    if palletDelivered then
        local distance = #(startLocation - endLocation)
        TriggerServerEvent('cargo:deliveryComplete', GetPlayerServerId(PlayerId()), deliveryCount, distance)
        
        -- Additional code to complete delivery
        lib.notify({
            title = "Delivery Completed",
            description = "You have successfully completed the delivery.",
            type = "success"
        })
        print("Delivery completed. Total deliveries: " .. deliveryCount)
        -- Reset delivery count if needed
        resetDeliveryCount()
    else
        lib.notify({
            title = "Delivery Incomplete",
            description = "You must deliver the pallet to the boat first.",
            type = "error"
        })
    end
end)

RegisterNetEvent('cargo:resetDeliveryCount', function()
    resetDeliveryCount()
end)

-- Function to handle moving the pallet with a forklift
local function movePalletToDock()
    local forkliftModel = GetHashKey("forklift")
    RequestModel(forkliftModel)
    while not HasModelLoaded(forkliftModel) do
        Wait(1)
    end

    local playerPed = PlayerPedId()
    forkliftSpawnLocation = vector3(math.random(-2000, 2000), math.random(-2000, 2000), 0.0)
    forklift = CreateVehicle(forkliftModel, forkliftSpawnLocation.x, forkliftSpawnLocation.y, forkliftSpawnLocation.z, math.random(0, 360), true, false)
    TaskWarpPedIntoVehicle(playerPed, forklift, -1)

    -- Placeholder destination location on the dock
    local destination = vector3(math.random(-2000, 2000), math.random(-2000, 2000), 0.0)
    SetNewWaypoint(destination.x, destination.y)

    lib.notify({
        title = "Move Pallet",
        description = "Use the forklift to move the pallet to the dock.",
        type = "info"
    })
end

RegisterNetEvent('cargo:movePallet', function()
    movePalletToDock()
end)

-- Function to check if the pallet is delivered to the boat
local function checkPalletDelivery()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local palletCoords = palletProp and GetEntityCoords(palletProp) or nil

    -- Placeholder check for proximity to the boat
    if #(playerCoords - palletCoords) < 5.0 then
        palletDelivered = true
        lib.notify({
            title = "Pallet Delivered",
            description = "The pallet has been successfully delivered to the boat.",
            type = "success"
        })

        -- Start the delivery site job
        startDeliverySiteJob()
    end
end

-- Function to check if the forklift is returned to the spawn location
local function checkForkliftReturn()
    if forklift and forkliftSpawnLocation then
        local forkliftCoords = GetEntityCoords(forklift)
        if #(forkliftCoords - forkliftSpawnLocation) < 5.0 then
            DeleteVehicle(forklift)
            forklift = nil
            forkliftSpawnLocation = nil
            lib.notify({
                title = "Forklift Returned",
                description = "The forklift has been successfully returned.",
                type = "success"
            })
        else
            lib.notify({
                title = "Return Forklift",
                description = "You must return the forklift to the spawn location to get paid.",
                type = "error"
            })
        end
    end
end

-- Function to check if the pallet is delivered to the delivery site
local function checkDeliverySitePalletDelivery()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local deliverySitePalletCoords = deliverySitePalletProp and GetEntityCoords(deliverySitePalletProp) or nil

    -- Placeholder check for proximity to the delivery site
    if #(playerCoords - deliverySitePalletCoords) < 5.0 then
        DeleteObject(deliverySitePalletProp)
        deliverySitePalletProp = nil
        lib.notify({
            title = "Pallet Delivered",
            description = "The pallet has been successfully delivered to the delivery site.",
            type = "success"
        })
    end
end

-- Periodically check if the pallet is delivered, if the forklift is returned, and if the job timer has expired
CreateThread(function()
    while true do
        Wait(1000)
        if palletProp then
            checkPalletDelivery()
        end
        if forklift then
            checkForkliftReturn()
        end
        if deliverySitePalletProp then
            checkDeliverySitePalletDelivery()
        end
        if jobTimer and GetGameTimer() > jobTimer then
            endDeliveryJob()
        end
        if deliverySiteTimer and GetGameTimer() > deliverySiteTimer then
            endDeliveryJob()
        end
    end
end)
