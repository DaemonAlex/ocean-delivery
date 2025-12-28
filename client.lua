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
-- HEAVY LOAD PHYSICS & ENVIRONMENTAL HAZARDS
-- =============================================================================

-- Current physics modifiers (updated by weather and cargo)
local currentSpeedMult = 1.0
local currentHandlingMult = 1.0
local currentAccelMult = 1.0
local isHeavyLoad = false

-- Apply cargo-based physics to boat
local function ApplyCargoPhysics(boat, cargo)
    if not boat or not DoesEntityExist(boat) then return end
    if not Config.HeavyLoadPhysics or not Config.HeavyLoadPhysics.enabled then return end

    local speedMult = Config.HeavyLoadPhysics.defaultSpeedMult
    local handlingMult = Config.HeavyLoadPhysics.defaultHandlingMult
    local accelMult = 1.0

    -- Check if cargo is heavy load
    if cargo then
        -- Weight-based handling reduction
        if cargo.weight and cargo.weight > 1.0 then
            handlingMult = handlingMult / cargo.weight
            accelMult = accelMult / cargo.weight
        end

        -- Heavy load cargo (vehicle parts, military hardware, etc.)
        if cargo.heavyLoad then
            isHeavyLoad = true

            -- Use cargo-specific speed mult or default
            if Config.HeavyLoadPhysics.useCargoOverrides and cargo.heavyLoadSpeedMult then
                speedMult = cargo.heavyLoadSpeedMult
            else
                speedMult = Config.HeavyLoadPhysics.heavyLoadSpeedMult
            end

            handlingMult = handlingMult * Config.HeavyLoadPhysics.heavyLoadHandlingMult
            accelMult = accelMult * Config.HeavyLoadPhysics.heavyLoadAccelMult

            debugPrint(string.format("Heavy load physics applied: Speed %.0f%%, Handling %.0f%%", speedMult * 100, handlingMult * 100))
        end
    end

    -- Store current modifiers
    currentSpeedMult = speedMult
    currentHandlingMult = handlingMult
    currentAccelMult = accelMult

    -- Apply to vehicle
    SetVehicleEnginePowerMultiplier(boat, accelMult)
    ModifyVehicleTopSpeed(boat, speedMult)

    debugPrint(string.format("Cargo physics: Speed %.2f, Handling %.2f, Accel %.2f", speedMult, handlingMult, accelMult))
end

-- Get current weather ID for physics calculations
local function GetCurrentWeatherId()
    if not currentWeather then return "clear" end
    return currentWeather.id or "clear"
end

-- Apply weather-based handling penalties
local function ApplyWeatherPhysics(boat)
    if not boat or not DoesEntityExist(boat) then return end
    if not Config.EnvironmentalHazards or not Config.EnvironmentalHazards.enabled then return end

    local weatherId = GetCurrentWeatherId()
    local weatherHandling = Config.EnvironmentalHazards.weatherHandlingPenalty[weatherId] or 1.0

    -- Combine with cargo handling
    local finalHandling = currentHandlingMult * weatherHandling

    -- Apply combined modifiers
    SetVehicleEnginePowerMultiplier(boat, currentAccelMult * weatherHandling)

    return weatherHandling
end

-- Calculate weather-based damage multiplier for fragile cargo
local function GetWeatherDamageMultiplier()
    if not Config.EnvironmentalHazards or not Config.EnvironmentalHazards.enabled then
        return 1.0
    end

    local weatherId = GetCurrentWeatherId()
    return Config.EnvironmentalHazards.weatherDamageMultipliers[weatherId] or 1.0
end

-- Passive weather damage thread (fragile cargo takes damage over time in bad weather)
CreateThread(function()
    while true do
        Wait(1000)

        if isOnJob and currentBoat and selectedCargo and selectedCargo.fragile then
            if Config.EnvironmentalHazards and Config.EnvironmentalHazards.passiveDamageEnabled then
                local weatherId = GetCurrentWeatherId()
                local passiveRate = Config.EnvironmentalHazards.passiveDamageRates[weatherId] or 0

                if passiveRate > 0 then
                    -- Apply passive damage every interval
                    local interval = Config.EnvironmentalHazards.passiveDamageInterval or 30
                    Wait((interval - 1) * 1000) -- Wait for interval (minus the 1 second already waited)

                    if isOnJob and selectedCargo and selectedCargo.fragile then
                        cargoDamage = cargoDamage + passiveRate
                        if cargoDamage > 1.0 then cargoDamage = 1.0 end

                        if passiveRate >= 0.02 then -- Only notify for significant damage
                            lib.notify({
                                title = "Weather Damage",
                                description = string.format("Fragile cargo taking damage! (%.0f%% total)", cargoDamage * 100),
                                type = "warning"
                            })
                        end

                        debugPrint(string.format("Passive weather damage: +%.1f%% (Total: %.1f%%)", passiveRate * 100, cargoDamage * 100))
                    end
                end
            end
        end
    end
end)

-- Continuous physics update thread (weather effects on handling)
CreateThread(function()
    while true do
        Wait(5000) -- Update every 5 seconds

        if isOnJob and currentBoat and DoesEntityExist(currentBoat) then
            ApplyWeatherPhysics(currentBoat)
        end
    end
end)

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
        local baseMult = selectedCargo.damageMultiplier or 1.5

        -- Apply weather-based damage multiplier (thunderstorms = 2x damage!)
        local weatherMult = GetWeatherDamageMultiplier()
        newDamage = newDamage * baseMult * weatherMult

        if weatherMult > 1.0 then
            debugPrint(string.format("Weather damage multiplier: %.1fx (total fragile mult: %.1fx)", weatherMult, baseMult * weatherMult))
        end
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

    -- Apply handling modifiers based on cargo weight and heavy load physics
    ApplyCargoPhysics(boat, selectedCargo)

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

-- Starter boat granted notification
RegisterNetEvent('cargo:starterBoatGranted', function(data)
    lib.notify({
        title = "FREE BOAT!",
        description = data.message or "You received a free starter boat!",
        type = "success",
        duration = 8000
    })

    Wait(2000)

    lib.notify({
        title = data.name,
        description = "Check your fleet with /fleet to see your new boat!",
        type = "info",
        duration = 5000
    })
end)

-- NPC Coast Guard spawn (when no cops online - DPSRP optimization)
RegisterNetEvent('cargo:spawnCoastGuard', function(coords)
    if activeEncounter or not currentBoat then return end

    -- Get coast guard encounter config
    local coastGuardEncounter = nil
    for _, encounter in ipairs(Config.RandomEncounters.encounters) do
        if encounter.id == "coastguard" then
            coastGuardEncounter = encounter
            break
        end
    end

    if not coastGuardEncounter then
        -- Fallback default config
        coastGuardEncounter = {
            id = "coastguard",
            vehicleModel = "predator",
            pedModel = "s_m_y_uscg_01",
            attackerCount = 2
        }
    end

    spawnCoastGuardEncounter(coastGuardEncounter)
end)

-- =============================================================================
-- FLEET MANAGEMENT UI
-- =============================================================================

local function showFleetManagement()
    QBCore.Functions.TriggerCallback('cargo:getPlayerFleet', function(fleet)
        if not fleet or #fleet == 0 then
            -- Check if eligible for free starter boat
            QBCore.Functions.TriggerCallback('cargo:checkStarterBoatEligible', function(eligible, starterConfig)
                local options = {
                    {
                        title = 'No Boats Owned',
                        description = 'Get a boat to start making deliveries!',
                        icon = 'ship',
                        disabled = true
                    },
                }

                -- Show claim free boat option if eligible
                if eligible and starterConfig then
                    table.insert(options, {
                        title = 'Claim FREE Starter Boat!',
                        description = starterConfig.name .. ' - Start earning today!',
                        icon = 'gift',
                        iconColor = 'green',
                        onSelect = function()
                            QBCore.Functions.TriggerCallback('cargo:claimStarterBoat', function(success, message)
                                lib.notify({ title = success and "Boat Claimed!" or "Error", description = message, type = success and "success" or "error" })
                                if success then
                                    Wait(500)
                                    showFleetManagement()
                                end
                            end)
                        end
                    })
                end

                table.insert(options, {
                    title = 'Buy a Boat',
                    description = 'Browse boats for sale',
                    icon = 'shopping-cart',
                    onSelect = function()
                        showBoatShop()
                    end
                })

                lib.registerContext({
                    id = 'ocean_fleet_empty',
                    title = 'My Fleet',
                    options = options
                })
                lib.showContext('ocean_fleet_empty')
            end)
            return
        end

        local options = {}

        for _, ship in ipairs(fleet) do
            local conditionColor = ship.condition_percent >= 75 and 'green' or (ship.condition_percent >= 50 and 'yellow' or 'red')
            local insuredText = ship.insured == 1 and 'Insured' or 'Not Insured'

            -- Add starter boat badge
            local titlePrefix = ship.isStarter and '[FREE] ' or ''
            local starterDesc = ship.isStarter and ' | Starter Boat' or ''

            table.insert(options, {
                title = titlePrefix .. (ship.boat_name or ship.label),
                description = string.format("Tier %d | Condition: %.0f%% | %s%s", ship.tier or 1, ship.condition_percent, insuredText, starterDesc),
                icon = ship.isStarter and 'gift' or 'ship',
                iconColor = ship.isStarter and 'cyan' or conditionColor,
                metadata = {
                    { label = 'Fuel', value = string.format("%.0f%%", ship.fuel_level) },
                    { label = 'Deliveries', value = ship.total_deliveries },
                    { label = 'Distance', value = string.format("%.0f km", ship.total_distance / 1000) },
                },
                onSelect = function()
                    showBoatDetails(ship)
                end
            })
        end

        table.insert(options, {
            title = 'Buy Another Boat',
            description = 'Browse boats for sale',
            icon = 'plus',
            onSelect = function()
                showBoatShop()
            end
        })

        lib.registerContext({
            id = 'ocean_fleet_list',
            title = 'My Fleet (' .. #fleet .. '/' .. Config.FleetOwnership.maxShipsPerPlayer .. ')',
            options = options
        })

        lib.showContext('ocean_fleet_list')
    end)
end

local function showBoatDetails(ship)
    local boatData = Config.GetBoatByModel(ship.boat_model)
    local basePrice = boatData and boatData.price or ship.purchase_price
    local sellPrice = math.floor(basePrice * Config.FleetOwnership.sellBackPercent * (ship.condition_percent / 100))

    -- Starter boats have no resale value
    if ship.isStarter then
        sellPrice = 0
    end

    local titleSuffix = ship.isStarter and ' [FREE STARTER]' or ''

    local options = {
        {
            title = 'Boat Stats',
            description = ship.description or (ship.isStarter and 'Your free starter boat to begin your delivery career!' or 'No description'),
            icon = 'info-circle',
            metadata = {
                { label = 'Speed', value = (boatData and boatData.speed or '?') .. ' knots' },
                { label = 'Capacity', value = (boatData and boatData.capacity or '?') .. ' units' },
                { label = 'Fuel Efficiency', value = string.format("%.0f%%", (boatData and boatData.fuelEfficiency or 1) * 100) },
            },
            disabled = true
        },
    }

    -- Starter boat info
    if ship.isStarter then
        table.insert(options, {
            title = 'Starter Boat',
            description = 'This is your free starter boat. Use it to earn money for upgrades!',
            icon = 'gift',
            iconColor = 'cyan',
            disabled = true
        })
    end

    -- Repair option
    if ship.condition_percent < 100 then
        local repairCost = math.floor(basePrice * Config.FleetOwnership.repairCostMultiplier * ((100 - ship.condition_percent) / 100))
        table.insert(options, {
            title = 'Repair Boat',
            description = string.format("Restore to 100%% condition - $%s", formatNumber(repairCost)),
            icon = 'wrench',
            iconColor = 'blue',
            onSelect = function()
                QBCore.Functions.TriggerCallback('cargo:repairBoat', function(success, message)
                    lib.notify({ title = success and "Repaired" or "Error", description = message, type = success and "success" or "error" })
                    if success then showFleetManagement() end
                end, ship.id)
            end
        })
    end

    -- Insurance option
    if ship.insured ~= 1 then
        local insuranceCost = boatData and boatData.insurance or math.floor(basePrice * 0.05)
        table.insert(options, {
            title = 'Add Insurance',
            description = string.format("Protect your investment - $%s", formatNumber(insuranceCost)),
            icon = 'shield-alt',
            iconColor = 'green',
            onSelect = function()
                QBCore.Functions.TriggerCallback('cargo:insureBoat', function(success, message)
                    lib.notify({ title = success and "Insured" or "Error", description = message, type = success and "success" or "error" })
                    if success then showFleetManagement() end
                end, ship.id)
            end
        })
    end

    -- Sell option (not available for starter boats)
    if ship.isStarter and not ship.canSell then
        table.insert(options, {
            title = 'Cannot Sell',
            description = 'Starter boats cannot be sold - they\'re a gift!',
            icon = 'ban',
            iconColor = 'gray',
            disabled = true
        })
    else
        table.insert(options, {
            title = 'Sell Boat',
            description = string.format("Sell for $%s (%.0f%% of value)", formatNumber(sellPrice), Config.FleetOwnership.sellBackPercent * 100),
            icon = 'dollar-sign',
            iconColor = 'red',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Confirm Sale',
                    content = 'Are you sure you want to sell ' .. (ship.boat_name or ship.label) .. ' for $' .. formatNumber(sellPrice) .. '?',
                    centered = true,
                    cancel = true
                })
                if confirm == 'confirm' then
                    QBCore.Functions.TriggerCallback('cargo:sellBoat', function(success, message)
                        lib.notify({ title = success and "Sold" or "Error", description = message, type = success and "success" or "error" })
                        if success then showFleetManagement() end
                    end, ship.id)
                end
            end
        })
    end

    -- Back button
    table.insert(options, {
        title = 'Back',
        icon = 'arrow-left',
        onSelect = function()
            showFleetManagement()
        end
    })

    lib.registerContext({
        id = 'ocean_boat_details',
        title = (ship.boat_name or ship.label) .. titleSuffix,
        options = options
    })

    lib.showContext('ocean_boat_details')
end

local function showBoatShop()
    QBCore.Functions.TriggerCallback('cargo:getBoatsForSale', function(boats, playerLevel)
        if not boats or #boats == 0 then
            lib.notify({ title = "No Boats", description = "No boats available for purchase", type = "error" })
            return
        end

        local options = {}

        for _, boat in ipairs(boats) do
            local tierName = Config.ShipTiers[boat.tier] and Config.ShipTiers[boat.tier].name or "Unknown"

            local option = {
                title = boat.label .. ' - $' .. formatNumber(boat.price),
                icon = boat.tier == 1 and 'sailboat' or (boat.tier == 2 and 'ship' or 'anchor'),
                metadata = {
                    { label = 'Tier', value = tierName },
                    { label = 'Speed', value = boat.speed .. ' knots' },
                    { label = 'Capacity', value = boat.capacity .. ' units' },
                    { label = 'Maintenance', value = '$' .. formatNumber(boat.maintenance) .. '/day' },
                },
            }

            if boat.canBuy then
                option.description = boat.description
                option.iconColor = 'green'
                option.onSelect = function()
                    local input = lib.inputDialog('Purchase ' .. boat.label, {
                        { type = 'input', label = 'Name your boat (optional)', placeholder = boat.label }
                    })
                    local boatName = input and input[1] or boat.label
                    QBCore.Functions.TriggerCallback('cargo:buyBoat', function(success, message)
                        lib.notify({ title = success and "Purchased!" or "Error", description = message, type = success and "success" or "error" })
                        if success then showFleetManagement() end
                    end, boat.model, boatName)
                end
            else
                option.description = 'LOCKED - ' .. boat.reason
                option.iconColor = 'gray'
                option.disabled = true
            end

            table.insert(options, option)
        end

        lib.registerContext({
            id = 'ocean_boat_shop',
            title = 'Boat Dealership (Level ' .. playerLevel .. ')',
            options = options
        })

        lib.showContext('ocean_boat_shop')
    end)
end

-- =============================================================================
-- REFUELING SYSTEM
-- =============================================================================

local fuelBlips = {}

local function createFuelBlips()
    if not Config.Refueling.enabled or not Config.Refueling.showBlips then return end

    for _, station in ipairs(Config.Refueling.stations) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, Config.Refueling.blipSprite)
        SetBlipColour(blip, Config.Refueling.blipColor)
        SetBlipScale(blip, Config.Refueling.blipScale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(station.name)
        EndTextCommandSetBlipName(blip)
        table.insert(fuelBlips, blip)
    end
end

local function removeFuelBlips()
    for _, blip in ipairs(fuelBlips) do
        RemoveBlip(blip)
    end
    fuelBlips = {}
end

local function showRefuelMenu()
    if not Config.Refueling.enabled then
        lib.notify({ title = "Unavailable", description = "Refueling is not available", type = "error" })
        return
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Check if near a fuel station
    local nearStation = nil
    for _, station in ipairs(Config.Refueling.stations) do
        if #(playerCoords - station.coords) < Config.Refueling.maxDistance then
            nearStation = station
            break
        end
    end

    if not nearStation then
        lib.notify({ title = "Too Far", description = "You're not near a fuel station", type = "error" })
        return
    end

    -- Check if in a boat
    if not IsPedInAnyVehicle(playerPed, false) then
        lib.notify({ title = "No Boat", description = "You must be in a boat to refuel", type = "error" })
        return
    end

    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if not IsThisModelABoat(GetEntityModel(vehicle)) then
        lib.notify({ title = "Not a Boat", description = "This vehicle cannot be refueled here", type = "error" })
        return
    end

    -- Calculate fuel needed
    local fuelNeeded = math.floor((1.0 - currentFuel) * 100)
    local costPerLiter = Config.Refueling.costPerLiter

    local options = {
        { value = 10, label = '10 Liters - $' .. (10 * costPerLiter) },
        { value = 25, label = '25 Liters - $' .. (25 * costPerLiter) },
        { value = 50, label = '50 Liters - $' .. (50 * costPerLiter) },
        { value = fuelNeeded, label = 'Fill Up (' .. fuelNeeded .. 'L) - $' .. (fuelNeeded * costPerLiter) },
    }

    local input = lib.inputDialog('Refuel at ' .. nearStation.name, {
        { type = 'select', label = 'Amount', options = options, required = true }
    })

    if input then
        local amount = input[1]
        QBCore.Functions.TriggerCallback('cargo:refuelBoat', function(success, cost, liters)
            if success then
                currentFuel = math.min(1.0, currentFuel + (liters / 100))
                lib.notify({ title = "Refueled", description = "Added " .. liters .. "L for $" .. cost, type = "success" })
            else
                lib.notify({ title = "Error", description = cost, type = "error" })
            end
        end, nil, amount)
    end
end

-- =============================================================================
-- RANDOM ENCOUNTERS
-- =============================================================================

local activeEncounter = nil
local encounterEntities = {}

local function cleanupEncounter()
    for _, entity in ipairs(encounterEntities) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    encounterEntities = {}
    activeEncounter = nil
end

local function spawnPirateEncounter(encounter)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Spawn pirate boat behind player
    local heading = GetEntityHeading(currentBoat)
    local spawnCoords = playerCoords - (GetEntityForwardVector(currentBoat) * 100)

    local boatModel = GetHashKey(encounter.vehicleModel)
    RequestModel(boatModel)
    while not HasModelLoaded(boatModel) do Wait(1) end

    local pirateBoat = CreateVehicle(boatModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false)
    SetEntityAsMissionEntity(pirateBoat, true, true)
    table.insert(encounterEntities, pirateBoat)

    -- Spawn pirates
    local pedModel = GetHashKey(encounter.pedModel)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(1) end

    for i = 1, encounter.attackerCount do
        local pirate = CreatePedInsideVehicle(pirateBoat, 4, pedModel, i == 1 and -1 or 0, true, false)
        SetEntityAsMissionEntity(pirate, true, true)

        -- Give weapons
        for _, weapon in ipairs(encounter.weapons) do
            GiveWeaponToPed(pirate, GetHashKey(weapon), 999, false, true)
        end

        -- Make hostile
        SetPedRelationshipGroupHash(pirate, GetHashKey("HATES_PLAYER"))
        TaskCombatPed(pirate, playerPed, 0, 16)

        table.insert(encounterEntities, pirate)
    end

    -- Make boat chase player
    TaskVehicleChase(GetPedInVehicleSeat(pirateBoat, -1), playerPed)

    lib.notify({
        title = "PIRATES!",
        description = "Hostile boats approaching! Defend yourself!",
        type = "error",
        duration = 7000
    })

    activeEncounter = {
        type = "pirates",
        data = encounter,
        startTime = GetGameTimer()
    }
end

local function spawnCoastGuardEncounter(encounter)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Spawn coast guard boat
    local heading = GetEntityHeading(currentBoat)
    local spawnCoords = playerCoords + (GetEntityForwardVector(currentBoat) * 150)

    local boatModel = GetHashKey(encounter.vehicleModel)
    RequestModel(boatModel)
    while not HasModelLoaded(boatModel) do Wait(1) end

    local cgBoat = CreateVehicle(boatModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading + 180, true, false)
    SetEntityAsMissionEntity(cgBoat, true, true)
    table.insert(encounterEntities, cgBoat)

    -- Spawn coast guard officers
    local pedModel = GetHashKey(encounter.pedModel)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(1) end

    for i = 1, encounter.attackerCount do
        local officer = CreatePedInsideVehicle(cgBoat, 4, pedModel, i == 1 and -1 or 0, true, false)
        SetEntityAsMissionEntity(officer, true, true)
        table.insert(encounterEntities, officer)
    end

    lib.notify({
        title = "COAST GUARD",
        description = "Coast Guard patrol approaching! Stop or flee!",
        type = "warning",
        duration = 7000
    })

    activeEncounter = {
        type = "coastguard",
        data = encounter,
        startTime = GetGameTimer(),
        canEscape = true
    }

    -- Alert police for illegal cargo
    if selectedCargo and selectedCargo.illegal then
        TriggerServerEvent('cargo:policeAlert', playerCoords, selectedCargo.id)
    end
end

local function spawnDistressEncounter(encounter)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Spawn distressed person in water
    local spawnCoords = playerCoords + vector3(math.random(-100, 100), math.random(-100, 100), 0)

    local pedModel = GetHashKey(encounter.pedModel)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(1) end

    local victim = CreatePed(4, pedModel, spawnCoords.x, spawnCoords.y, spawnCoords.z - 0.5, 0.0, true, false)
    SetEntityAsMissionEntity(victim, true, true)
    SetPedConfigFlag(victim, 32, false) -- Can't drown
    table.insert(encounterEntities, victim)

    -- Create blip for victim
    local blip = AddBlipForEntity(victim)
    SetBlipSprite(blip, 480) -- Life ring
    SetBlipColour(blip, 1) -- Red
    SetBlipScale(blip, 1.0)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Person in Distress")
    EndTextCommandSetBlipName(blip)

    lib.notify({
        title = "DISTRESS SIGNAL",
        description = "Someone is stranded in the water! Rescue them for a bonus!",
        type = "info",
        duration = 7000
    })

    activeEncounter = {
        type = "distress",
        data = encounter,
        startTime = GetGameTimer(),
        victim = victim,
        blip = blip
    }
end

local function checkEncounterCompletion()
    if not activeEncounter then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Distance-based entity culling - prevents entity leaking
    local CULL_DISTANCE = Config.RandomEncounters.entityCullDistance or 200.0
    local shouldCull = true
    for _, entity in ipairs(encounterEntities) do
        if DoesEntityExist(entity) then
            local entityCoords = GetEntityCoords(entity)
            if #(playerCoords - entityCoords) < CULL_DISTANCE then
                shouldCull = false
                break
            end
        end
    end

    if shouldCull and #encounterEntities > 0 then
        debugPrint("Culling encounter entities - player moved >200m away")
        TriggerServerEvent('cargo:logEncounter', activeEncounter.type, 'abandoned', 0, 0, selectedCargo and selectedCargo.id)
        cleanupEncounter()
        return
    end

    if activeEncounter.type == "pirates" then
        -- Check if all pirates are dead
        local allDead = true
        for _, entity in ipairs(encounterEntities) do
            if IsEntityAPed(entity) and not IsEntityDead(entity) then
                allDead = false
                break
            end
        end

        if allDead then
            lib.notify({ title = "Pirates Defeated!", description = "+" .. activeEncounter.data.xpBonus .. " XP", type = "success" })
            TriggerServerEvent('cargo:logEncounter', 'pirates', 'success', 0, activeEncounter.data.xpBonus, selectedCargo and selectedCargo.id)
            cleanupEncounter()
        end

    elseif activeEncounter.type == "coastguard" then
        -- Check if escaped
        local cgBoat = encounterEntities[1]
        if cgBoat and DoesEntityExist(cgBoat) then
            local cgCoords = GetEntityCoords(cgBoat)
            if #(playerCoords - cgCoords) > activeEncounter.data.escapeDistance then
                lib.notify({ title = "Escaped!", description = "You outran the Coast Guard!", type = "success" })
                TriggerServerEvent('cargo:logEncounter', 'coastguard', 'escaped', 0, 0, selectedCargo and selectedCargo.id)
                cleanupEncounter()
            end
        end

    elseif activeEncounter.type == "distress" then
        -- Check if victim is near player boat
        if activeEncounter.victim and DoesEntityExist(activeEncounter.victim) then
            local victimCoords = GetEntityCoords(activeEncounter.victim)
            if currentBoat and #(victimCoords - GetEntityCoords(currentBoat)) < 5.0 then
                lib.notify({
                    title = "Rescue Complete!",
                    description = "+$" .. formatNumber(activeEncounter.data.reward) .. " and +" .. activeEncounter.data.xpBonus .. " XP",
                    type = "success"
                })
                TriggerServerEvent('cargo:logEncounter', 'distress', 'success', activeEncounter.data.reward, activeEncounter.data.xpBonus, selectedCargo and selectedCargo.id)
                if activeEncounter.blip then RemoveBlip(activeEncounter.blip) end
                cleanupEncounter()
            end
        end
    end

    -- Timeout check
    if activeEncounter and GetGameTimer() - activeEncounter.startTime > 120000 then -- 2 minute timeout
        TriggerServerEvent('cargo:logEncounter', activeEncounter.type, 'failed', 0, 0, selectedCargo and selectedCargo.id)
        cleanupEncounter()
    end
end

local function rollForEncounter()
    if not Config.RandomEncounters.enabled or activeEncounter then return end
    if not isOnJob or not currentBoat then return end

    local playerCoords = GetEntityCoords(PlayerPedId())

    -- Check distance from all ports
    for _, port in ipairs(Config.Ports) do
        if #(playerCoords - port.coords) < Config.RandomEncounters.minDistanceFromPort then
            return -- Too close to port
        end
    end

    local tier = selectedBoat and selectedBoat.tier or 1

    for _, encounter in ipairs(Config.RandomEncounters.encounters) do
        if tier >= encounter.minTier then
            local chance = encounter.chance

            -- Bonus chance for illegal cargo
            if selectedCargo and selectedCargo.illegal and encounter.illegalCargoBonus then
                chance = chance + encounter.illegalCargoBonus
            end

            if math.random() < chance then
                debugPrint("Spawning encounter: " .. encounter.id)

                if encounter.id == "pirates" then
                    spawnPirateEncounter(encounter)
                elseif encounter.id == "coastguard" then
                    spawnCoastGuardEncounter(encounter)
                elseif encounter.id == "distress" then
                    spawnDistressEncounter(encounter)
                end

                return -- Only one encounter at a time
            end
        end
    end
end

-- Encounter check thread
CreateThread(function()
    while true do
        Wait(Config.RandomEncounters.checkInterval or 30000)

        if isOnJob and currentBoat then
            rollForEncounter()
        end

        if activeEncounter then
            checkEncounterCompletion()
        end
    end
end)

-- =============================================================================
-- COMMANDS
-- =============================================================================

RegisterCommand('startdelivery', function()
    showRouteSelection()
end, false)

RegisterCommand('fleet', function()
    showFleetManagement()
end, false)

RegisterCommand('buyboat', function()
    showBoatShop()
end, false)

RegisterCommand('refuel', function()
    showRefuelMenu()
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
    createFuelBlips()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('cargo:playerLoaded')
    createFuelBlips()
end)

RegisterNetEvent('qbx-core:client:PlayerLoaded', function()
    TriggerServerEvent('cargo:playerLoaded')
end)
