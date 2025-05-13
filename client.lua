local QBCore = exports['qb-core']:GetCoreObject()
local lib = exports['ox_lib']:GetLibObject()

-- Variables
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
local isOnJob = false -- State management to prevent multiple jobs
local currentBoat = nil -- Track current boat entity

-- Functions
local function resetDeliveryCount()
    deliveryCount = 0
end

local function debugPrint(message)
    if Config.Debug then
        print("[Ocean Delivery] " .. message)
    end
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
        debugPrint("Selected route: " .. selectedRoute)
        return selectedRoute
    else
        debugPrint("No route selected")
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
    
    -- Set this boat as a mission entity so it doesn't get deleted
    SetEntityAsMissionEntity(boat, true, true)
    currentBoat = boat
    
    -- Save the boat entity for later reference
    TriggerServerEvent('cargo:saveBoatEntity', NetworkGetNetworkIdFromEntity(boat))
    
    return boat
end

local function spawnPallet()
    -- Code to spawn a pallet prop at a location near the player
    local palletModel = GetHashKey("prop_boxpile_07d")
    RequestModel(palletModel)
    while not HasModelLoaded(palletModel) do
        Wait(1)
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Spawn pallet within visible distance of the player
    local spawnLocation = vector3(
        playerCoords.x + math.random(-30, 30), 
        playerCoords.y + math.random(-30, 30), 
        playerCoords.z
    )
    
    -- Ensure pallet is spawned on the ground
    local ground, groundZ = GetGroundZFor_3dCoord(spawnLocation.x, spawnLocation.y, spawnLocation.z + 10.0, 0)
    if ground then
        spawnLocation = vector3(spawnLocation.x, spawnLocation.y, groundZ)
    end
    
    palletProp = CreateObject(palletModel, spawnLocation.x, spawnLocation.y, spawnLocation.z, true, true, false)
    SetEntityAsMissionEntity(palletProp, true, true)
    
    -- Add target interaction if ox_target is available
    if exports.ox_target then
        exports.ox_target:addLocalEntity(palletProp, {
            {
                name = 'pick_up_pallet',
                icon = 'fas fa-box',
                label = 'Pick Up Pallet',
                onSelect = function()
                    -- Code to attach pallet to forklift
                    if IsPedInAnyVehicle(PlayerPedId(), false) then
                        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                        if GetEntityModel(vehicle) == GetHashKey("forklift") then
                            -- Attach pallet to forklift
                            AttachEntityToEntity(palletProp, vehicle, 0, 0.0, 0.6, 0.8, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
                            lib.notify({
                                title = "Pallet Picked Up",
                                description = "Take the pallet to the boat.",
                                type = "success"
                            })
                        else
                            lib.notify({
                                title = "Wrong Vehicle",
                                description = "You need a forklift to pick up the pallet.",
                                type = "error"
                            })
                        end
                    else
                        lib.notify({
                            title = "Vehicle Required",
                            description = "You need to be in a forklift to pick up the pallet.",
                            type = "error"
                        })
                    end
                end
            }
        })
    end
    
    -- Set waypoint to the pallet
    SetNewWaypoint(spawnLocation.x, spawnLocation.y)
    
    lib.notify({
        title = "Pallet Spawned",
        description = "Find the pallet and move it to the boat using the forklift.",
        type = "info"
    })
end

local function startDeliveryJob(route)
    -- Prevent starting multiple jobs
    if isOnJob then
        lib.notify({
            title = "Job in Progress",
            description = "You already have an active delivery job.",
            type = "error"
        })
        return
    end
    
    isOnJob = true
    
    -- Code to start the delivery job
    local boatEntity = spawnBoat(route)
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

    -- Start job timer
    jobTimer = GetGameTimer() + 15 * 60 * 1000 -- 15 minutes
    
    -- Save job data for persistence
    local jobData = {
        route = route,
        deliveryCount = deliveryCount,
        startLocation = startLocation,
        endLocation = endLocation,
        jobTimer = jobTimer,
        boatNetId = NetworkGetNetworkIdFromEntity(boatEntity)
    }
    TriggerServerEvent('cargo:jobStarted', jobData)
end

local function spawnDeliverySitePallet()
    -- Code to spawn a pallet prop at the delivery site near the end location
    local palletModel = GetHashKey("prop_boxpile_07d")
    RequestModel(palletModel)
    while not HasModelLoaded(palletModel) do
        Wait(1)
    end

    -- Use the end location with a small offset for the delivery site
    local spawnLocation = vector3(
        endLocation.x + math.random(-10, 10), 
        endLocation.y + math.random(-10, 10), 
        endLocation.z
    )
    
    -- Ensure pallet is spawned on the ground
    local ground, groundZ = GetGroundZFor_3dCoord(spawnLocation.x, spawnLocation.y, spawnLocation.z + 10.0, 0)
    if ground then
        spawnLocation = vector3(spawnLocation.x, spawnLocation.y, groundZ)
    end
    
    deliverySitePalletProp = CreateObject(palletModel, spawnLocation.x, spawnLocation.y, spawnLocation.z, true, true, false)
    SetEntityAsMissionEntity(deliverySitePalletProp, true, true)
    
    -- Add target interaction if ox_target is available
    if exports.ox_target then
        exports.ox_target:addLocalEntity(deliverySitePalletProp, {
            {
                name = 'deliver_pallet',
                icon = 'fas fa-box-open',
                label = 'Deliver Pallet',
                onSelect = function()
                    -- Complete the delivery
                    if palletDelivered then
                        DeleteObject(deliverySitePalletProp)
                        deliverySitePalletProp = nil
                        local distance = #(startLocation - endLocation)
                        TriggerServerEvent('cargo:deliveryComplete', deliveryCount, distance)
                        
                        lib.notify({
                            title = "Delivery Completed",
                            description = "You have successfully completed the delivery.",
                            type = "success"
                        })
                        debugPrint("Delivery completed. Total deliveries: " .. deliveryCount)
                        
                        endDeliveryJob()
                    else
                        lib.notify({
                            title = "Not Ready",
                            description = "You need to first deliver the pallet to the boat.",
                            type = "error"
                        })
                    end
                end
            }
        })
    end
    
    -- Set waypoint to the delivery site
    SetNewWaypoint(spawnLocation.x, spawnLocation.y)
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

local function endDeliveryJob()
    -- Reset job state
    isOnJob = false
    
    -- Code to end the delivery job
    if palletProp then
        if exports.ox_target then
            exports.ox_target:removeLocalEntity(palletProp)
        end
        DeleteObject(palletProp)
        palletProp = nil
    end
    
    if forklift then
        DeleteVehicle(forklift)
        forklift = nil
        forkliftSpawnLocation = nil
    end
    
    if deliverySitePalletProp then
        if exports.ox_target then
            exports.ox_target:removeLocalEntity(deliverySitePalletProp)
        end
        DeleteObject(deliverySitePalletProp)
        deliverySitePalletProp = nil
    end
    
    if currentBoat then
        SetEntityAsNoLongerNeeded(currentBoat)
        currentBoat = nil
    end
    
    currentRoute = nil
    palletDelivered = false
    jobTimer = nil
    deliverySiteTimer = nil
    startLocation = nil
    endLocation = nil

    -- Notify server that job is completed
    TriggerServerEvent('cargo:jobCompleted')

    lib.notify({
        title = "Delivery Job Ended",
        description = "The delivery job has ended.",
        type = "error"
    })
end

local function movePalletToDock()
    local forkliftModel = GetHashKey("forklift")
    RequestModel(forkliftModel)
    while not HasModelLoaded(forkliftModel) do
        Wait(1)
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Spawn forklift near the player instead of random coordinates
    forkliftSpawnLocation = vector3(
        playerCoords.x + math.random(-20, 20), 
        playerCoords.y + math.random(-20, 20), 
        playerCoords.z
    )
    
    -- Ensure forklift is spawned on the ground
    local ground, groundZ = GetGroundZFor_3dCoord(forkliftSpawnLocation.x, forkliftSpawnLocation.y, forkliftSpawnLocation.z + 10.0, 0)
    if ground then
        forkliftSpawnLocation = vector3(forkliftSpawnLocation.x, forkliftSpawnLocation.y, groundZ)
    end
    
    forklift = CreateVehicle(forkliftModel, forkliftSpawnLocation.x, forkliftSpawnLocation.y, forkliftSpawnLocation.z, math.random(0, 360), true, false)
    SetEntityAsMissionEntity(forklift, true, true)
    TaskWarpPedIntoVehicle(playerPed, forklift, -1)

    -- Set destination to dock area near the boat
    local boatCoords = startLocation
    local destination = vector3(
        boatCoords.x + math.random(-10, 10), 
        boatCoords.y + math.random(-10, 10), 
        boatCoords.z
    )
    
    SetNewWaypoint(destination.x, destination.y)

    lib.notify({
        title = "Move Pallet",
        description = "Use the forklift to move the pallet to the dock.",
        type = "info"
    })
end

-- Function to check if the pallet is delivered to the boat
local function checkPalletDelivery()
    if not palletProp or not currentBoat then return end
    
    local palletCoords = GetEntityCoords(palletProp)
    local boatCoords = GetEntityCoords(currentBoat)
    
    -- Check if the pallet is near the boat (rather than checking if player is near pallet)
    if #(palletCoords - boatCoords) < 7.0 then
        palletDelivered = true
        lib.notify({
            title = "Pallet Loaded",
            description = "The pallet has been successfully loaded onto the boat.",
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
    if not deliverySitePalletProp then return end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local deliverySitePalletCoords = GetEntityCoords(deliverySitePalletProp)

    -- Check for proximity to the delivery site
    if #(playerCoords - deliverySitePalletCoords) < 5.0 then
        if exports.ox_target then
            exports.ox_target:removeLocalEntity(deliverySitePalletProp)
        end
        DeleteObject(deliverySitePalletProp)
        deliverySitePalletProp = nil
        
        -- Complete the delivery
        local distance = #(startLocation - endLocation)
        TriggerServerEvent('cargo:deliveryComplete', deliveryCount, distance)
        
        lib.notify({
            title = "Delivery Completed",
            description = "The pallet has been successfully delivered to the delivery site.",
            type = "success"
        })
        
        -- End the delivery job
        endDeliveryJob()
    end
end

-- Network Events
RegisterNetEvent('cargo:startDelivery', function()
    -- Code to start the delivery job
    local selectedRoute = showRouteSelection()
    if selectedRoute then
        TriggerServerEvent('cargo:startDelivery', selectedRoute)
    else
        debugPrint("Delivery job cancelled")
    end
end)

RegisterNetEvent('cargo:spawnBoatAndPallet', function(route)
    startDeliveryJob(route)
end)

RegisterNetEvent('cargo:completeDelivery', function()
    -- Code to complete the delivery job
    if palletDelivered then
        local distance = #(startLocation - endLocation)
        TriggerServerEvent('cargo:deliveryComplete', deliveryCount, distance)
        
        -- Additional code to complete delivery
        lib.notify({
            title = "Delivery Completed",
            description = "You have successfully completed the delivery.",
            type = "success"
        })
        debugPrint("Delivery completed. Total deliveries: " .. deliveryCount)
        
        -- End the delivery job
        endDeliveryJob()
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
    endDeliveryJob()
    lib.notify({
        title = "Delivery Count Reset",
        description = "Your delivery count has been reset.",
        type = "info"
    })
end)

RegisterNetEvent('cargo:movePallet', function()
    movePalletToDock()
end)

-- Event to restore job state after player reconnection
RegisterNetEvent('cargo:restoreJob', function(jobData)
    if jobData then
        isOnJob = true
        deliveryCount = jobData.deliveryCount
        currentRoute = jobData.route
        startLocation = jobData.startLocation
        endLocation = jobData.endLocation
        jobTimer = jobData.jobTimer
        
        -- Restore boat entity if it exists
        if jobData.boatNetId then
            local boatEntity = NetworkGetEntityFromNetworkId(jobData.boatNetId)
            if DoesEntityExist(boatEntity) then
                -- Save the current boat entity
                currentBoat = boatEntity
                
                -- Teleport player to boat
                local playerPed = PlayerPedId()
                SetEntityCoords(playerPed, startLocation.x, startLocation.y, startLocation.z + 1.0)
                TaskWarpPedIntoVehicle(playerPed, boatEntity, -1)
                
                lib.notify({
                    title = "Job Restored",
                    description = "Your delivery job has been restored.",
                    type = "success"
                })
            else
                -- Boat doesn't exist anymore, restart the job
                lib.notify({
                    title = "Job Restarted",
                    description = "Your delivery boat was lost, spawning a new one.",
                    type = "info"
                })
                startDeliveryJob(currentRoute)
            end
        }
    end
end)

-- Commands
RegisterCommand('startdelivery', function()
    TriggerEvent('cargo:startDelivery')
end, false)

RegisterCommand('enddelivery', function()
    if isOnJob then
        lib.notify({
            title = "Job Cancelled",
            description = "You have cancelled your delivery job.",
            type = "error"
        })
        endDeliveryJob()
    else
        lib.notify({
            title = "No Active Job",
            description = "You don't have an active delivery job to cancel.",
            type = "error"
        })
    end
end, false)

-- Resource cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    
    -- Cleanup all entities when resource stops
    if palletProp then
        DeleteObject(palletProp)
    end
    
    if forklift then
        DeleteVehicle(forklift)
    end
    
    if deliverySitePalletProp then
        DeleteObject(deliverySitePalletProp)
    end
    
    if currentBoat then
        SetEntityAsNoLongerNeeded(currentBoat)
    end
end)

-- Periodically check if the pallet is delivered, if the forklift is returned, and if the job timer has expired
CreateThread(function()
    while true do
        Wait(1000)
        
        -- Only run checks if we're on a job
        if isOnJob then
            -- Check if the boat is destroyed
            local playerPed = PlayerPedId()
            if currentBoat and not IsPedInAnyVehicle(playerPed, false) then
                -- Only check every 10 seconds to save resources
                if (math.floor(GetGameTimer() / 1000) % 10) == 0 then
                    if IsEntityDead(currentBoat) then
                        lib.notify({
                            title = "Job Failed",
                            description = "The delivery boat has been destroyed.",
                            type = "error"
                        })
                        endDeliveryJob()
                    end
                end
            end
            
            -- Check for pallet delivery to boat
            if palletProp and not palletDelivered then
                checkPalletDelivery()
            end
            
            -- Check for forklift return
            if forklift then
                checkForkliftReturn()
            end
            
            -- Check for pallet delivery to delivery site
            if deliverySitePalletProp then
                checkDeliverySitePalletDelivery()
            end
            
            -- Check for job timeout
            if jobTimer and GetGameTimer() > jobTimer then
                lib.notify({
                    title = "Job Timed Out",
                    description = "You took too long to complete the delivery job.",
                    type = "error"
                })
                endDeliveryJob()
            end
            
            -- Check for delivery site timeout
            if deliverySiteTimer and GetGameTimer() > deliverySiteTimer then
                lib.notify({
                    title = "Delivery Timed Out",
                    description = "You took too long to deliver the pallet at the delivery site.",
                    type = "error"
                })
                endDeliveryJob()
            end
        end
    end
end)

-- Initialization
CreateThread(function()
    -- Wait for resource to initialize
    Wait(1000)
    
    debugPrint("Ocean Delivery initialized")
end)
