local QBCore = nil
local isQBX = false

-- Try to get QBX Core first
local success, error = pcall(function()
    QBCore = exports['qbx-core']:GetCoreObject()
    isQBX = true
end)

-- Fall back to QBCore if QBX Core is not available
if not success then
    QBCore = exports['qb-core']:GetCoreObject()
    isQBX = false
end

local lib = exports['ox_lib']:GetLibObject()

-- =============================================================================
-- STATE VARIABLES
-- =============================================================================

local isOnJob = false
local deliveryCount = 0
local currentRoute = nil
local selectedBoat = nil
local selectedCargo = nil
local palletProp = nil
local palletDelivered = false
local forklift = nil
local forkliftSpawnLocation = nil
local jobTimer = nil
local deliverySiteTimer = nil
local deliverySitePalletProp = nil
local startLocation = nil
local endLocation = nil
local currentBoat = nil
local allLocations = {}
local currentWeather = nil
local currentFuel = 1.0
local cargoDamage = 0
local lastDamageCheck = 0

-- Player stats cache
local playerStats = {
    xp = 0,
    level = 1,
    tier = 1,
    title = "Deckhand"
}

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

local function debugPrint(message)
    if Config.Debug then
        print("[Ocean Delivery] " .. message)
    end
end

local function formatNumber(num)
    local formatted = tostring(math.floor(num))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- =============================================================================
-- WEATHER DETECTION
-- =============================================================================

local function getCurrentWeather()
    if not Config.WeatherEffects.enabled then
        return Config.WeatherEffects.types[1] -- Clear
    end

    local weatherHash = GetPrevWeatherTypeHashName()

    -- Map GTA weather to our weather types
    local weatherMap = {
        [GetHashKey("CLEAR")] = "clear",
        [GetHashKey("EXTRASUNNY")] = "clear",
        [GetHashKey("CLOUDS")] = "cloudy",
        [GetHashKey("OVERCAST")] = "cloudy",
        [GetHashKey("RAIN")] = "rain",
        [GetHashKey("CLEARING")] = "rain",
        [GetHashKey("THUNDER")] = "thunder",
        [GetHashKey("FOGGY")] = "fog",
        [GetHashKey("SMOG")] = "fog",
    }

    local weatherId = weatherMap[weatherHash] or "clear"

    for _, weather in ipairs(Config.WeatherEffects.types) do
        if weather.id == weatherId then
            return weather
        end
    end

    return Config.WeatherEffects.types[1]
end

-- =============================================================================
-- FUEL SYSTEM
-- =============================================================================

local function updateFuel(boat, deltaTime)
    if not Config.FuelSystem.enabled or not boat then return end

    local speed = GetEntitySpeed(boat) * 3.6 -- Convert to km/h
    local boatData = selectedBoat or {}
    local efficiency = boatData.fuelEfficiency or 1.0
    local tierSettings = Config.ShipTiers[boatData.tier or 1] or Config.ShipTiers[1]

    -- Calculate fuel consumption
    local consumption = (speed / 100) * (tierSettings.fuelConsumption / efficiency) * (deltaTime / 1000)
    currentFuel = math.max(0, currentFuel - consumption)

    -- Fuel warnings
    if currentFuel <= Config.FuelSystem.criticalFuelWarning and currentFuel > 0 then
        if math.floor(GetGameTimer() / 5000) % 2 == 0 then
            lib.notify({
                title = "CRITICAL: Low Fuel!",
                description = "Find a fuel station immediately!",
                type = "error"
            })
        end
    elseif currentFuel <= Config.FuelSystem.lowFuelWarning then
        if math.floor(GetGameTimer() / 10000) % 2 == 0 then
            lib.notify({
                title = "Low Fuel",
                description = string.format("Fuel at %.0f%%", currentFuel * 100),
                type = "warning"
            })
        end
    end

    -- Out of fuel
    if currentFuel <= 0 then
        lib.notify({
            title = "Out of Fuel!",
            description = "Your boat has run out of fuel.",
            type = "error"
        })
        TriggerServerEvent('cargo:jobFailed', "Ran out of fuel")
        endDeliveryJob()
    end
end

-- =============================================================================
-- CARGO DAMAGE SYSTEM
-- =============================================================================

local function checkCargoDamage()
    if not currentBoat or not selectedCargo then return end

    local currentHealth = GetEntityHealth(currentBoat)
    local maxHealth = GetEntityMaxHealth(currentBoat)
    local healthPercent = currentHealth / maxHealth

    -- Calculate damage based on boat health
    local newDamage = 1.0 - healthPercent

    -- Fragile cargo takes more damage
    if selectedCargo.fragile then
        newDamage = newDamage * 1.5
    end

    -- Weight affects damage (heavier = more momentum damage)
    local weight = selectedCargo.weight or 1.0
    if weight > 1.5 then
        newDamage = newDamage * 1.2
    end

    cargoDamage = math.min(1.0, math.max(cargoDamage, newDamage))

    -- Hazmat explosion risk
    if selectedCargo.explosionRisk and cargoDamage > 0.7 then
        if math.random() < 0.1 then -- 10% chance per check
            lib.notify({
                title = "HAZMAT WARNING!",
                description = "Cargo is becoming unstable!",
                type = "error"
            })
        end
    end
end

-- =============================================================================
-- STATS UI
-- =============================================================================

local function showPlayerStats()
    QBCore.Functions.TriggerCallback('cargo:getPlayerStats', function(stats)
        if not stats then
            lib.notify({ title = "Error", description = "Could not load stats", type = "error" })
            return
        end

        playerStats = stats

        local tierName = Config.ShipTiers[stats.tier] and Config.ShipTiers[stats.tier].name or "Coastal"

        lib.registerContext({
            id = 'ocean_delivery_stats',
            title = 'Ocean Delivery - ' .. stats.title,
            options = {
                {
                    title = 'Level ' .. stats.level .. ' - ' .. stats.title,
                    description = 'Tier ' .. stats.tier .. ' (' .. tierName .. ')',
                    icon = 'anchor',
                    progress = stats.xpProgress,
                    colorScheme = 'blue',
                },
                {
                    title = 'Experience',
                    description = formatNumber(stats.xp) .. ' / ' .. formatNumber(stats.nextLevelXP) .. ' XP',
                    icon = 'star',
                },
                {
                    title = 'Deliveries',
                    description = stats.successfulDeliveries .. ' successful, ' .. stats.failedDeliveries .. ' failed',
                    icon = 'truck',
                },
                {
                    title = 'Total Earnings',
                    description = '$' .. formatNumber(stats.totalEarnings),
                    icon = 'dollar-sign',
                },
                {
                    title = 'Distance Traveled',
                    description = formatNumber(math.floor(stats.totalDistance)) .. ' units',
                    icon = 'route',
                },
                {
                    title = 'Current Streak',
                    description = stats.currentStreak .. ' deliveries (Best: ' .. stats.bestStreak .. ')',
                    icon = 'fire',
                },
            }
        })

        lib.showContext('ocean_delivery_stats')
    end)
end

-- =============================================================================
-- SHIP SELECTION UI
-- =============================================================================

local function showBoatSelection(onSelect)
    QBCore.Functions.TriggerCallback('cargo:getAvailableBoats', function(boats, tier, level)
        if not boats or #boats == 0 then
            lib.notify({ title = "No Boats", description = "No boats available at your level", type = "error" })
            return
        end

        playerStats.tier = tier
        playerStats.level = level

        local options = {}

        -- Show all boats, but mark locked ones
        for _, boat in ipairs(Config.Boats) do
            local isUnlocked = false
            for _, availableBoat in ipairs(boats) do
                if availableBoat.model == boat.model then
                    isUnlocked = true
                    break
                end
            end

            local tierName = Config.ShipTiers[boat.tier] and Config.ShipTiers[boat.tier].name or "Unknown"
            local requiredLevel = boat.requiredLevel or 1

            local option = {
                title = boat.label,
                icon = boat.tier == 1 and 'sailboat' or (boat.tier == 2 and 'ship' or 'anchor'),
                iconColor = isUnlocked and 'green' or 'gray',
            }

            if isUnlocked then
                option.description = string.format("Tier %d (%s) | Speed: %d | Capacity: %d",
                    boat.tier, tierName, boat.speed, boat.capacity)
                option.metadata = {
                    { label = 'Handling', value = string.format("%.0f%%", boat.handling * 100) },
                    { label = 'Fuel Efficiency', value = string.format("%.0f%%", boat.fuelEfficiency * 100) },
                }
                option.onSelect = function()
                    selectedBoat = boat
                    if onSelect then onSelect(boat) end
                end
            else
                option.description = string.format("LOCKED - Requires Level %d", requiredLevel)
                option.disabled = true
            end

            table.insert(options, option)
        end

        lib.registerContext({
            id = 'ocean_delivery_boats',
            title = 'Select Your Vessel (Tier ' .. tier .. ')',
            options = options
        })

        lib.showContext('ocean_delivery_boats')
    end)
end

-- =============================================================================
-- CARGO SELECTION UI
-- =============================================================================

local function showCargoSelection(onSelect)
    QBCore.Functions.TriggerCallback('cargo:getAvailableCargo', function(cargoTypes, tier)
        if not cargoTypes or #cargoTypes == 0 then
            lib.notify({ title = "No Cargo", description = "No cargo types available", type = "error" })
            return
        end

        local options = {}

        for _, cargo in ipairs(cargoTypes) do
            local tags = {}
            if cargo.fragile then table.insert(tags, 'Fragile') end
            if cargo.illegal then table.insert(tags, 'Illegal') end
            if cargo.perishable then table.insert(tags, 'Perishable') end

            local tagStr = #tags > 0 and (' [' .. table.concat(tags, ', ') .. ']') or ''

            local option = {
                title = cargo.label .. tagStr,
                description = cargo.description,
                icon = cargo.illegal and 'mask' or (cargo.fragile and 'wine-glass' or 'box'),
                iconColor = cargo.illegal and 'red' or (cargo.fragile and 'yellow' or 'blue'),
                metadata = {
                    { label = 'Pay Multiplier', value = string.format("%.1fx", cargo.payMultiplier) },
                    { label = 'XP Multiplier', value = string.format("%.1fx", cargo.xpMultiplier) },
                    { label = 'Weight', value = string.format("%.1fx", cargo.weight) },
                },
                onSelect = function()
                    selectedCargo = cargo
                    if onSelect then onSelect(cargo) end
                end
            }

            table.insert(options, option)
        end

        lib.registerContext({
            id = 'ocean_delivery_cargo',
            title = 'Select Cargo Type',
            options = options
        })

        lib.showContext('ocean_delivery_cargo')
    end)
end

-- =============================================================================
-- ROUTE SELECTION UI
-- =============================================================================

local function showRouteSelection()
    if isOnJob then
        lib.notify({ title = "Job Active", description = "You already have an active delivery job.", type = "error" })
        return
    end

    -- Step 1: Select boat
    showBoatSelection(function(boat)
        debugPrint("Selected boat: " .. boat.label)

        -- Step 2: Select cargo
        showCargoSelection(function(cargo)
            debugPrint("Selected cargo: " .. cargo.label)

            -- Step 3: Get routes based on boat tier
            QBCore.Functions.TriggerCallback('cargo:getRoutes', function(routes)
                if not routes or #routes == 0 then
                    lib.notify({ title = "No Routes", description = "No routes available for your tier.", type = "error" })
                    return
                end

                -- Get current weather
                currentWeather = getCurrentWeather()
                local weatherBonus = currentWeather.payBonus or 0

                local options = {}

                for i, route in ipairs(routes) do
                    local estimatedPay = math.floor(route.basePay * cargo.payMultiplier * (1 + weatherBonus))

                    table.insert(options, {
                        title = route.label,
                        description = string.format("Distance: %d units | Est. Pay: $%s",
                            math.floor(route.distance), formatNumber(estimatedPay)),
                        icon = 'route',
                        metadata = {
                            { label = 'Tier', value = route.tier },
                            { label = 'Weather', value = currentWeather.label },
                            { label = 'Weather Bonus', value = string.format("+%.0f%%", weatherBonus * 100) },
                        },
                        onSelect = function()
                            debugPrint("Selected route: " .. route.label)
                            TriggerServerEvent('cargo:startDelivery', route, boat, cargo)
                        end
                    })
                end

                lib.registerContext({
                    id = 'ocean_delivery_routes',
                    title = 'Select Route (' .. currentWeather.label .. ')',
                    options = options
                })

                lib.showContext('ocean_delivery_routes')
            end, boat.tier)
        end)
    end)
end

-- =============================================================================
-- JOB MANAGEMENT
-- =============================================================================

local function spawnBoat(routeData, boatData)
    local startCoords = allLocations[routeData.start].coords

    local boatModel = GetHashKey(boatData.model)
    RequestModel(boatModel)
    while not HasModelLoaded(boatModel) do
        Wait(1)
    end

    local heading = math.random(0, 360)
    local playerPed = PlayerPedId()
    local boat = CreateVehicle(boatModel, startCoords.x, startCoords.y, startCoords.z, heading, true, false)
    TaskWarpPedIntoVehicle(playerPed, boat, -1)

    SetEntityAsMissionEntity(boat, true, true)
    currentBoat = boat

    -- Set initial fuel
    currentFuel = Config.FuelSystem.startingFuel

    -- Apply handling modifiers based on cargo weight
    if selectedCargo and selectedCargo.weight then
        local weight = selectedCargo.weight
        if weight > 1.0 then
            -- Heavier cargo = slower acceleration, worse handling
            SetVehicleEnginePowerMultiplier(boat, 1.0 / weight)
        end
    end

    TriggerServerEvent('cargo:saveBoatEntity', NetworkGetNetworkIdFromEntity(boat))

    return boat
end

local function spawnPallet()
    local palletModel = GetHashKey("prop_boxpile_07d")
    RequestModel(palletModel)
    while not HasModelLoaded(palletModel) do
        Wait(1)
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local spawnLocation = vector3(
        playerCoords.x + math.random(-30, 30),
        playerCoords.y + math.random(-30, 30),
        playerCoords.z
    )

    local ground, groundZ = GetGroundZFor_3dCoord(spawnLocation.x, spawnLocation.y, spawnLocation.z + 10.0, 0)
    if ground then
        spawnLocation = vector3(spawnLocation.x, spawnLocation.y, groundZ)
    end

    palletProp = CreateObject(palletModel, spawnLocation.x, spawnLocation.y, spawnLocation.z, true, true, false)
    SetEntityAsMissionEntity(palletProp, true, true)

    if exports.ox_target then
        exports.ox_target:addLocalEntity(palletProp, {
            {
                name = 'pick_up_pallet',
                icon = 'fas fa-box',
                label = 'Pick Up ' .. (selectedCargo and selectedCargo.label or 'Cargo'),
                onSelect = function()
                    if IsPedInAnyVehicle(PlayerPedId(), false) then
                        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                        if GetEntityModel(vehicle) == GetHashKey("forklift") then
                            AttachEntityToEntity(palletProp, vehicle, 0, 0.0, 0.6, 0.8, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
                            lib.notify({
                                title = "Pallet Picked Up",
                                description = "Take the " .. (selectedCargo and selectedCargo.label or 'cargo') .. " to the boat.",
                                type = "success"
                            })
                        else
                            lib.notify({ title = "Wrong Vehicle", description = "You need a forklift.", type = "error" })
                        end
                    else
                        lib.notify({ title = "Vehicle Required", description = "Get in a forklift first.", type = "error" })
                    end
                end
            }
        })
    end

    SetNewWaypoint(spawnLocation.x, spawnLocation.y)

    lib.notify({
        title = "Cargo Spawned",
        description = "Find the " .. (selectedCargo and selectedCargo.label or 'cargo') .. " and load it onto your boat.",
        type = "info"
    })
end

local function startDeliveryJob(routeData, boatData, cargoData)
    if isOnJob then
        lib.notify({ title = "Job Active", description = "You already have an active delivery job.", type = "error" })
        return
    end

    if #allLocations == 0 and #Config.Ports == 0 then
        lib.notify({ title = "No Locations", description = "No delivery locations available.", type = "error" })
        return
    end

    isOnJob = true
    selectedBoat = boatData
    selectedCargo = cargoData
    cargoDamage = 0
    currentWeather = getCurrentWeather()

    startLocation = allLocations[routeData.start].coords
    endLocation = allLocations[routeData.finish].coords

    local boat = spawnBoat(routeData, boatData)
    spawnPallet()
    deliveryCount = deliveryCount + 1
    currentRoute = routeData
    palletDelivered = false

    SetNewWaypoint(startLocation.x, startLocation.y)

    -- Show job info
    local cargoInfo = cargoData and (' (' .. cargoData.label .. ')') or ''
    lib.notify({
        title = "Delivery Started",
        description = "Pickup at " .. allLocations[routeData.start].name .. cargoInfo,
        type = "success"
    })

    if currentWeather.payBonus > 0 then
        lib.notify({
            title = currentWeather.label,
            description = string.format("+%.0f%% bonus pay for weather conditions!", currentWeather.payBonus * 100),
            type = "info"
        })
    end

    jobTimer = GetGameTimer() + Config.PickupTimer

    -- Apply perishable time reduction
    if cargoData and cargoData.perishable and cargoData.perishTime then
        jobTimer = GetGameTimer() + (Config.PickupTimer * cargoData.perishTime)
        lib.notify({
            title = "Perishable Cargo",
            description = "Time limit reduced! Deliver quickly!",
            type = "warning"
        })
    end

    local jobData = {
        route = routeData,
        boat = boatData,
        cargo = cargoData,
        deliveryCount = deliveryCount,
        startLocationIndex = routeData.start,
        endLocationIndex = routeData.finish,
        jobTimer = jobTimer,
        boatNetId = NetworkGetNetworkIdFromEntity(boat)
    }
    TriggerServerEvent('cargo:jobStarted', jobData)

    return boat
end

local function endDeliveryJob()
    isOnJob = false

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
    selectedBoat = nil
    selectedCargo = nil
    palletDelivered = false
    jobTimer = nil
    deliverySiteTimer = nil
    startLocation = nil
    endLocation = nil
    cargoDamage = 0
    currentFuel = 1.0

    TriggerServerEvent('cargo:jobCompleted')
end

local function spawnDeliverySitePallet()
    local palletModel = GetHashKey("prop_boxpile_07d")
    RequestModel(palletModel)
    while not HasModelLoaded(palletModel) do
        Wait(1)
    end

    local spawnLocation = vector3(
        endLocation.x + math.random(-10, 10),
        endLocation.y + math.random(-10, 10),
        endLocation.z
    )

    local ground, groundZ = GetGroundZFor_3dCoord(spawnLocation.x, spawnLocation.y, spawnLocation.z + 10.0, 0)
    if ground then
        spawnLocation = vector3(spawnLocation.x, spawnLocation.y, groundZ)
    end

    deliverySitePalletProp = CreateObject(palletModel, spawnLocation.x, spawnLocation.y, spawnLocation.z, true, true, false)
    SetEntityAsMissionEntity(deliverySitePalletProp, true, true)

    if exports.ox_target then
        exports.ox_target:addLocalEntity(deliverySitePalletProp, {
            {
                name = 'deliver_pallet',
                icon = 'fas fa-box-open',
                label = 'Complete Delivery',
                onSelect = function()
                    if palletDelivered then
                        DeleteObject(deliverySitePalletProp)
                        deliverySitePalletProp = nil

                        local distance = #(startLocation - endLocation)
                        local weatherBonus = currentWeather and currentWeather.payBonus or 0

                        TriggerServerEvent('cargo:deliveryComplete', {
                            distance = distance,
                            cargoType = selectedCargo,
                            boat = selectedBoat,
                            damagePercent = cargoDamage,
                            weatherBonus = weatherBonus,
                            tier = selectedBoat and selectedBoat.tier or 1,
                            startName = currentRoute.startName,
                            finishName = currentRoute.finishName
                        })

                        endDeliveryJob()
                    else
                        lib.notify({ title = "Not Ready", description = "Load the pallet onto the boat first.", type = "error" })
                    end
                end
            }
        })
    end

    SetNewWaypoint(spawnLocation.x, spawnLocation.y)
end

local function startDeliverySiteJob()
    spawnDeliverySitePallet()

    local baseTime = Config.DeliveryTimer
    if selectedCargo and selectedCargo.perishable and selectedCargo.perishTime then
        baseTime = Config.DeliveryTimer * selectedCargo.perishTime
    end

    deliverySiteTimer = GetGameTimer() + baseTime

    lib.notify({
        title = "Destination Reached",
        description = "Unload the cargo at the delivery site.",
        type = "success"
    })
end

-- =============================================================================
-- PALLET CHECKS
-- =============================================================================

local function checkPalletDelivery()
    if not palletProp or not currentBoat then return end

    local palletCoords = GetEntityCoords(palletProp)
    local boatCoords = GetEntityCoords(currentBoat)

    if #(palletCoords - boatCoords) < Config.PalletProximity then
        palletDelivered = true
        lib.notify({
            title = "Cargo Loaded",
            description = "Cargo loaded onto the boat. Head to " .. currentRoute.finishName,
            type = "success"
        })

        startDeliverySiteJob()
    end
end

local function checkDeliverySitePalletDelivery()
    if not deliverySitePalletProp then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local deliverySitePalletCoords = GetEntityCoords(deliverySitePalletProp)

    if #(playerCoords - deliverySitePalletCoords) < Config.DeliverySiteProximity then
        if exports.ox_target then
            exports.ox_target:removeLocalEntity(deliverySitePalletProp)
        end
        DeleteObject(deliverySitePalletProp)
        deliverySitePalletProp = nil

        local distance = #(startLocation - endLocation)
        local weatherBonus = currentWeather and currentWeather.payBonus or 0

        TriggerServerEvent('cargo:deliveryComplete', {
            distance = distance,
            cargoType = selectedCargo,
            boat = selectedBoat,
            damagePercent = cargoDamage,
            weatherBonus = weatherBonus,
            tier = selectedBoat and selectedBoat.tier or 1,
            startName = currentRoute.startName,
            finishName = currentRoute.finishName
        })

        endDeliveryJob()
    end
end

-- =============================================================================
-- NETWORK EVENTS
-- =============================================================================

RegisterNetEvent('cargo:syncLocations', function(locations)
    allLocations = locations
    debugPrint("Received " .. #allLocations .. " delivery locations from server")
end)

RegisterNetEvent('cargo:startDelivery', function()
    showRouteSelection()
end)

RegisterNetEvent('cargo:spawnBoatAndPallet', function(routeData, boatData, cargoData)
    startDeliveryJob(routeData, boatData or selectedBoat, cargoData or selectedCargo)
end)

RegisterNetEvent('cargo:resetDeliveryCount', function()
    deliveryCount = 0
    endDeliveryJob()
    lib.notify({ title = "Reset", description = "Your delivery job has been reset.", type = "info" })
end)

RegisterNetEvent('cargo:levelUp', function(data)
    lib.notify({
        title = "LEVEL UP!",
        description = "You are now Level " .. data.newLevel .. " - " .. data.title,
        type = "success",
        duration = 7000
    })

    if data.tier > playerStats.tier then
        local tierName = Config.ShipTiers[data.tier] and Config.ShipTiers[data.tier].name or "Unknown"
        Wait(2000)
        lib.notify({
            title = "New Tier Unlocked!",
            description = "Tier " .. data.tier .. " (" .. tierName .. ") ships are now available!",
            type = "success",
            duration = 7000
        })
    end

    playerStats.level = data.newLevel
    playerStats.tier = data.tier
    playerStats.xp = data.xp
    playerStats.title = data.title
end)

RegisterNetEvent('cargo:deliveryPayout', function(data)
    local message = string.format("$%s paid", formatNumber(data.payout))

    if data.streakBonus > 0 then
        message = message .. string.format(" (+$%s streak)", formatNumber(data.streakBonus))
    end
    if data.seriesBonus > 0 then
        message = message .. string.format(" (+$%s series!)", formatNumber(data.seriesBonus))
    end
    if data.damagePenalty > 0 then
        message = message .. string.format(" (-$%s damage)", formatNumber(data.damagePenalty))
    end

    lib.notify({
        title = "Delivery Complete!",
        description = message,
        type = "success",
        duration = 5000
    })

    Wait(1000)

    lib.notify({
        title = "+" .. data.xpEarned .. " XP",
        description = "Total: " .. formatNumber(data.totalXP) .. " XP (Level " .. data.level .. ")",
        type = "info"
    })
end)

RegisterNetEvent('cargo:restoreJob', function(jobData)
    if jobData then
        isOnJob = true
        deliveryCount = jobData.deliveryCount
        currentRoute = jobData.route
        selectedBoat = jobData.boat
        selectedCargo = jobData.cargo

        if allLocations[jobData.startLocationIndex] and allLocations[jobData.endLocationIndex] then
            startLocation = allLocations[jobData.startLocationIndex].coords
            endLocation = allLocations[jobData.endLocationIndex].coords
            jobTimer = jobData.jobTimer

            if jobData.boatNetId then
                local boatEntity = NetworkGetEntityFromNetworkId(jobData.boatNetId)
                if DoesEntityExist(boatEntity) then
                    currentBoat = boatEntity
                    local playerPed = PlayerPedId()
                    SetEntityCoords(playerPed, startLocation.x, startLocation.y, startLocation.z + 1.0)
                    TaskWarpPedIntoVehicle(playerPed, boatEntity, -1)

                    lib.notify({ title = "Job Restored", description = "Your delivery job has been restored.", type = "success" })
                else
                    lib.notify({ title = "Boat Lost", description = "Spawning a new boat...", type = "info" })
                    startDeliveryJob(currentRoute, selectedBoat, selectedCargo)
                end
            end
        else
            lib.notify({ title = "Error", description = "Could not restore job locations.", type = "error" })
            isOnJob = false
        end
    end
end)

RegisterNetEvent('cargo:getPlayerPosition', function(locationName, tier, hasFuel)
    local playerPed = PlayerPedId()
    local pos = GetEntityCoords(playerPed)

    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if IsThisModelABoat(GetEntityModel(vehicle)) then
            pos = GetEntityCoords(vehicle)
        end
    end

    TriggerServerEvent('cargo:addLocationAtPosition', locationName, pos, tier, hasFuel)
end)

RegisterNetEvent('cargo:showLocationsList', function(locations)
    if not locations or #locations == 0 then
        lib.notify({ title = "No Locations", description = "No delivery locations found.", type = "error" })
        return
    end

    local options = {}

    for i, location in ipairs(locations) do
        local coords = location.coords
        local id = location.id or i
        local tierBadge = location.tier and (' [Tier ' .. location.tier .. ']') or ''
        local fuelBadge = location.hasFuel and ' [Fuel]' or ''

        table.insert(options, {
            title = location.name .. tierBadge .. fuelBadge,
            description = string.format("ID: %d | Coords: %.1f, %.1f, %.1f", id, coords.x, coords.y, coords.z),
            onSelect = function()
                SetNewWaypoint(coords.x, coords.y)
                lib.notify({ title = "Waypoint Set", description = "Waypoint set to " .. location.name, type = "success" })
            end
        })
    end

    lib.registerContext({
        id = 'delivery_locations_list',
        title = 'Delivery Locations',
        options = options
    })

    lib.showContext('delivery_locations_list')
end)

-- =============================================================================
-- COMMANDS
-- =============================================================================

RegisterCommand('startdelivery', function()
    showRouteSelection()
end, false)

RegisterCommand('enddelivery', function()
    if isOnJob then
        lib.notify({ title = "Cancelled", description = "Delivery job cancelled.", type = "error" })
        TriggerServerEvent('cargo:jobFailed', "Job cancelled by player")
        endDeliveryJob()
    else
        lib.notify({ title = "No Job", description = "You don't have an active delivery job.", type = "error" })
    end
end, false)

RegisterCommand('deliverystats', function()
    showPlayerStats()
end, false)

-- =============================================================================
-- MAIN LOOP
-- =============================================================================

CreateThread(function()
    local lastUpdate = GetGameTimer()

    while true do
        Wait(1000)

        if isOnJob then
            local currentTime = GetGameTimer()
            local deltaTime = currentTime - lastUpdate
            lastUpdate = currentTime

            -- Update fuel
            if currentBoat and IsPedInAnyVehicle(PlayerPedId(), false) then
                local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                if vehicle == currentBoat then
                    updateFuel(currentBoat, deltaTime)
                end
            end

            -- Check boat status
            local playerPed = PlayerPedId()
            if currentBoat and not IsPedInAnyVehicle(playerPed, false) then
                if (math.floor(currentTime / 1000) % 10) == 0 then
                    if IsEntityDead(currentBoat) then
                        lib.notify({ title = "Job Failed", description = "Your boat was destroyed.", type = "error" })
                        TriggerServerEvent('cargo:jobFailed', "Boat destroyed")
                        endDeliveryJob()
                    end
                end
            end

            -- Check cargo damage
            if (math.floor(currentTime / 1000) % 5) == 0 then
                checkCargoDamage()
            end

            -- Pallet checks
            if palletProp and not palletDelivered then
                checkPalletDelivery()
            end

            if deliverySitePalletProp then
                checkDeliverySitePalletDelivery()
            end

            -- Timer checks
            if jobTimer and currentTime > jobTimer then
                lib.notify({ title = "Time's Up", description = "You took too long to complete the delivery.", type = "error" })
                TriggerServerEvent('cargo:jobFailed', "Timed out")
                endDeliveryJob()
            end

            if deliverySiteTimer and currentTime > deliverySiteTimer then
                lib.notify({ title = "Time's Up", description = "Delivery site time expired.", type = "error" })
                TriggerServerEvent('cargo:jobFailed', "Delivery timed out")
                endDeliveryJob()
            end
        end
    end
end)

-- =============================================================================
-- RESOURCE LIFECYCLE
-- =============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end

    if palletProp then DeleteObject(palletProp) end
    if forklift then DeleteVehicle(forklift) end
    if deliverySitePalletProp then DeleteObject(deliverySitePalletProp) end
    if currentBoat then SetEntityAsNoLongerNeeded(currentBoat) end
end)

CreateThread(function()
    Wait(1000)
    debugPrint("Ocean Delivery client initialized")
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('cargo:playerLoaded')
end)

RegisterNetEvent('qbx-core:client:PlayerLoaded', function()
    TriggerServerEvent('cargo:playerLoaded')
end)
