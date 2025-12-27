local QBCore = exports['qb-core']:GetCoreObject()

-- Store active jobs for persistence across server restarts
local activeJobs = {}
local activeBoats = {}
local playerStats = {} -- Cache for player stats

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

-- Function to handle payment with compatibility for both QS-Banking and Renewed Banking
local function AddMoneyToPlayer(player, amount, reason)
    local citizenid = player.PlayerData.citizenid

    -- Try Renewed Banking first
    if exports['renewed-banking'] then
        exports['renewed-banking']:addAccountMoney(citizenid, amount, reason)
        return true
    elseif exports['qs-banking'] then
        exports['qs-banking']:AddMoney(citizenid, amount, reason)
        return true
    else
        player.Functions.AddMoney("bank", amount, reason)
        return true
    end
end

-- Debug print function
local function debugPrint(message)
    if Config.Debug then
        print("[Ocean Delivery] " .. message)
    end
end

-- =============================================================================
-- DATABASE INITIALIZATION
-- =============================================================================

CreateThread(function()
    Wait(1000) -- Wait for MySQL to initialize

    -- Create table for player progression
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS ocean_delivery_players (
            citizenid VARCHAR(50) PRIMARY KEY,
            xp INT DEFAULT 0,
            level INT DEFAULT 1,
            total_deliveries INT DEFAULT 0,
            total_distance FLOAT DEFAULT 0,
            total_earnings INT DEFAULT 0,
            successful_deliveries INT DEFAULT 0,
            failed_deliveries INT DEFAULT 0,
            favorite_boat VARCHAR(50) DEFAULT NULL,
            current_streak INT DEFAULT 0,
            best_streak INT DEFAULT 0,
            last_delivery TIMESTAMP NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]], {}, function(success)
        if success then
            debugPrint("Player progression table initialized")
        end
    end)

    -- Create table for delivery history
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS ocean_delivery_history (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            boat_model VARCHAR(50),
            cargo_type VARCHAR(50),
            start_port VARCHAR(100),
            end_port VARCHAR(100),
            distance FLOAT,
            payout INT,
            xp_earned INT,
            weather VARCHAR(50),
            damage_percent FLOAT DEFAULT 0,
            completion_time INT,
            status ENUM('completed', 'failed', 'cancelled') DEFAULT 'completed',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_citizenid (citizenid),
            INDEX idx_status (status)
        )
    ]], {}, function(success)
        if success then
            debugPrint("Delivery history table initialized")
        end
    end)

    -- Create table for custom locations if it doesn't exist
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS cargo_locations (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            x FLOAT NOT NULL,
            y FLOAT NOT NULL,
            z FLOAT NOT NULL,
            tier INT DEFAULT 1,
            has_fuel BOOLEAN DEFAULT FALSE,
            enabled BOOLEAN DEFAULT TRUE,
            added_by VARCHAR(50),
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]], {}, function(success)
        if success then
            debugPrint("Cargo locations table initialized")
            LoadCustomLocations()
        end
    end)

    -- Legacy table for backwards compatibility
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS cargo_deliveries (
            id INT AUTO_INCREMENT PRIMARY KEY,
            player_id VARCHAR(50) NOT NULL,
            deliveries INT DEFAULT 0,
            distance FLOAT DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]], {})
end)

-- =============================================================================
-- PLAYER STATS FUNCTIONS
-- =============================================================================

-- Load player stats from database
local function LoadPlayerStats(citizenid)
    local result = MySQL.Sync.fetchAll('SELECT * FROM ocean_delivery_players WHERE citizenid = ?', {citizenid})

    if result and #result > 0 then
        playerStats[citizenid] = result[1]
        debugPrint("Loaded stats for " .. citizenid .. " - Level: " .. result[1].level .. ", XP: " .. result[1].xp)
    else
        -- Create new player record
        MySQL.Async.execute([[
            INSERT INTO ocean_delivery_players (citizenid, xp, level)
            VALUES (?, 0, 1)
        ]], {citizenid})

        playerStats[citizenid] = {
            citizenid = citizenid,
            xp = 0,
            level = 1,
            total_deliveries = 0,
            total_distance = 0,
            total_earnings = 0,
            successful_deliveries = 0,
            failed_deliveries = 0,
            current_streak = 0,
            best_streak = 0,
        }
        debugPrint("Created new player record for " .. citizenid)
    end

    return playerStats[citizenid]
end

-- Save player stats to database
local function SavePlayerStats(citizenid)
    local stats = playerStats[citizenid]
    if not stats then return end

    MySQL.Async.execute([[
        UPDATE ocean_delivery_players SET
            xp = ?,
            level = ?,
            total_deliveries = ?,
            total_distance = ?,
            total_earnings = ?,
            successful_deliveries = ?,
            failed_deliveries = ?,
            current_streak = ?,
            best_streak = ?,
            last_delivery = NOW()
        WHERE citizenid = ?
    ]], {
        stats.xp,
        stats.level,
        stats.total_deliveries,
        stats.total_distance,
        stats.total_earnings,
        stats.successful_deliveries,
        stats.failed_deliveries,
        stats.current_streak,
        stats.best_streak,
        citizenid
    })
end

-- Award XP to player
local function AwardXP(citizenid, amount, reason)
    if not playerStats[citizenid] then
        LoadPlayerStats(citizenid)
    end

    local stats = playerStats[citizenid]
    local oldLevel = stats.level
    stats.xp = stats.xp + amount

    -- Calculate new level
    local levelInfo = Config.GetLevelFromXP(stats.xp)
    stats.level = levelInfo.level

    -- Check for level up
    if stats.level > oldLevel then
        local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if Player then
            local src = Player.PlayerData.source
            TriggerClientEvent('cargo:levelUp', src, {
                newLevel = stats.level,
                title = levelInfo.title,
                tier = levelInfo.tier,
                xp = stats.xp
            })
            debugPrint(citizenid .. " leveled up to " .. stats.level .. " (" .. levelInfo.title .. ")")
        end
    end

    SavePlayerStats(citizenid)
    debugPrint(citizenid .. " earned " .. amount .. " XP (" .. reason .. "). Total: " .. stats.xp)

    return stats.xp, stats.level
end

-- Deduct XP from player (for failures)
local function DeductXP(citizenid, amount, reason)
    if not playerStats[citizenid] then
        LoadPlayerStats(citizenid)
    end

    local stats = playerStats[citizenid]
    stats.xp = math.max(0, stats.xp - amount)

    -- Recalculate level (can't delevel)
    -- stats.level stays the same

    SavePlayerStats(citizenid)
    debugPrint(citizenid .. " lost " .. amount .. " XP (" .. reason .. "). Total: " .. stats.xp)

    return stats.xp
end

-- =============================================================================
-- LOCATION FUNCTIONS
-- =============================================================================

function LoadCustomLocations()
    MySQL.Async.fetchAll('SELECT * FROM cargo_locations WHERE enabled = 1', {}, function(result)
        if result and #result > 0 then
            Config.CustomLocations = {}

            for i=1, #result do
                local location = result[i]
                table.insert(Config.CustomLocations, {
                    id = location.id,
                    name = location.name,
                    coords = vector3(location.x, location.y, location.z),
                    tier = location.tier or 1,
                    hasFuel = location.has_fuel == 1
                })
            end

            debugPrint("Loaded " .. #Config.CustomLocations .. " custom locations")
        else
            Config.CustomLocations = {}
            debugPrint("No custom locations found in database")
        end

        MergeCustomAndDefaultLocations()
    end)
end

function MergeCustomAndDefaultLocations()
    Config.AllLocations = {}

    -- Add default ports
    for i=1, #Config.Ports do
        table.insert(Config.AllLocations, Config.Ports[i])
    end

    -- Add custom locations
    for i=1, #Config.CustomLocations do
        table.insert(Config.AllLocations, Config.CustomLocations[i])
    end

    debugPrint("Total available locations: " .. #Config.AllLocations)

    -- Sync to all clients
    TriggerClientEvent('cargo:syncLocations', -1, Config.AllLocations)
end

function AddCustomLocation(name, coords, tier, hasFuel, addedBy)
    MySQL.Async.execute('INSERT INTO cargo_locations (name, x, y, z, tier, has_fuel, added_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {name, coords.x, coords.y, coords.z, tier or 1, hasFuel or false, addedBy}, function(rowsChanged)
        if rowsChanged > 0 then
            debugPrint("Added new location: " .. name)
            LoadCustomLocations()
        end
    end)
end

function RemoveCustomLocation(id)
    MySQL.Async.execute('UPDATE cargo_locations SET enabled = 0 WHERE id = ?', {id}, function(rowsChanged)
        if rowsChanged > 0 then
            debugPrint("Removed location with ID: " .. id)
            LoadCustomLocations()
        end
    end)
end

-- =============================================================================
-- ROUTE GENERATION
-- =============================================================================

function GenerateRoutes(source, tier)
    local routes = {}
    local locations = Config.AllLocations
    tier = tier or 1

    -- Get tier settings
    local tierSettings = Config.ShipTiers[tier]
    if not tierSettings then
        tierSettings = Config.ShipTiers[1]
    end

    -- Need at least 2 locations to create routes
    if #locations < 2 then
        TriggerClientEvent('QBCore:Notify', source, "Not enough delivery locations available", "error")
        return nil
    end

    -- Generate route options
    for i = 1, math.min(Config.RouteOptions, (#locations * (#locations - 1) / 2)) do
        local routeFound = false
        local attempts = 0
        local start, finish

        while not routeFound and attempts < 50 do
            attempts = attempts + 1

            start = math.random(1, #locations)
            finish = math.random(1, #locations)

            if start ~= finish then
                local startCoords = locations[start].coords
                local finishCoords = locations[finish].coords
                local distance = #(startCoords - finishCoords)

                -- Check if distance is within tier range
                if distance >= tierSettings.minDistance and distance <= tierSettings.maxDistance then
                    local isDuplicate = false
                    for j = 1, #routes do
                        if (routes[j].start == start and routes[j].finish == finish) or
                           (routes[j].start == finish and routes[j].finish == start) then
                            isDuplicate = true
                            break
                        end
                    end

                    if not isDuplicate then
                        routeFound = true
                    end
                end
            end
        end

        if routeFound then
            local distance = #(locations[start].coords - locations[finish].coords)
            local basePay = math.floor(distance * Config.BasePayoutPerDistance * tierSettings.payMultiplier)

            table.insert(routes, {
                start = start,
                finish = finish,
                startName = locations[start].name,
                finishName = locations[finish].name,
                distance = distance,
                basePay = basePay,
                tier = tier,
                label = locations[start].name .. " → " .. locations[finish].name
            })
        end
    end

    return routes
end

-- =============================================================================
-- DELIVERY COMPLETION
-- =============================================================================

local function CompleteDelivery(src, Player, deliveryData)
    local citizenid = Player.PlayerData.citizenid

    -- Load stats if not cached
    if not playerStats[citizenid] then
        LoadPlayerStats(citizenid)
    end

    local stats = playerStats[citizenid]
    local distance = deliveryData.distance or 0
    local cargoType = deliveryData.cargoType or { payMultiplier = 1.0, xpMultiplier = 1.0 }
    local boatData = deliveryData.boat or {}
    local damagePercent = deliveryData.damagePercent or 0
    local weatherBonus = deliveryData.weatherBonus or 0
    local tier = deliveryData.tier or 1

    -- Get tier multiplier
    local tierSettings = Config.ShipTiers[tier] or Config.ShipTiers[1]

    -- Calculate base payout
    local basePay = math.floor(distance * Config.BasePayoutPerDistance)

    -- Apply multipliers
    local payout = basePay * tierSettings.payMultiplier * cargoType.payMultiplier

    -- Apply streak bonus
    stats.current_streak = stats.current_streak + 1
    if stats.current_streak > stats.best_streak then
        stats.best_streak = stats.current_streak
    end

    local streakBonus = 0
    if stats.current_streak > 1 then
        streakBonus = stats.current_streak * Config.BonusPayout
        payout = payout + streakBonus
    end

    -- Series bonus (every 4 deliveries)
    local seriesBonus = 0
    if stats.current_streak % 4 == 0 then
        seriesBonus = Config.SeriesBonus
        payout = payout + seriesBonus
    end

    -- Weather bonus
    if weatherBonus > 0 then
        payout = payout * (1 + weatherBonus)
    end

    -- Damage penalty
    local damagePenalty = 0
    if Config.DamagePenalty.enabled and damagePercent > 0 then
        for _, threshold in ipairs(Config.DamagePenalty.thresholds) do
            if damagePercent >= threshold.damage then
                damagePenalty = threshold.penalty
            end
        end
        -- Apply damage multiplier from cargo type
        if cargoType.damageMultiplier then
            damagePenalty = damagePenalty * cargoType.damageMultiplier
        end
        damagePenalty = math.min(damagePenalty, Config.DamagePenalty.maxPenalty)
        payout = payout * (1 - damagePenalty)
    end

    payout = math.floor(payout)

    -- Calculate XP
    local baseXP = Config.XPPerDelivery + (distance * Config.XPPerDistance)
    local xpEarned = math.floor(baseXP * cargoType.xpMultiplier)

    -- Bonus XP for series completion
    if stats.current_streak % 4 == 0 then
        xpEarned = math.floor(xpEarned * Config.XPBonusMultiplier)
    end

    -- Award XP
    local newXP, newLevel = AwardXP(citizenid, xpEarned, "Delivery completed")

    -- Update stats
    stats.total_deliveries = stats.total_deliveries + 1
    stats.successful_deliveries = stats.successful_deliveries + 1
    stats.total_distance = stats.total_distance + distance
    stats.total_earnings = stats.total_earnings + payout
    stats.favorite_boat = boatData.model or stats.favorite_boat

    -- Add money to player's account
    local success = AddMoneyToPlayer(Player, payout, 'Ocean Delivery Payment')

    if success then
        -- Send detailed notification
        TriggerClientEvent('cargo:deliveryPayout', src, {
            payout = payout,
            basePay = basePay,
            streakBonus = streakBonus,
            seriesBonus = seriesBonus,
            weatherBonus = math.floor(basePay * weatherBonus),
            damagePenalty = math.floor(basePay * damagePenalty),
            xpEarned = xpEarned,
            totalXP = newXP,
            level = newLevel,
            streak = stats.current_streak
        })
    end

    -- Log delivery to history
    MySQL.Async.execute([[
        INSERT INTO ocean_delivery_history
        (citizenid, boat_model, cargo_type, start_port, end_port, distance, payout, xp_earned, damage_percent, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'completed')
    ]], {
        citizenid,
        boatData.model,
        cargoType.id,
        deliveryData.startName,
        deliveryData.finishName,
        distance,
        payout,
        xpEarned,
        damagePercent
    })

    SavePlayerStats(citizenid)

    -- Clear job data
    activeJobs[citizenid] = nil
    activeBoats[citizenid] = nil

    debugPrint("Delivery completed for " .. citizenid .. " - Payout: $" .. payout .. ", XP: " .. xpEarned)
end

local function FailDelivery(src, Player, reason)
    local citizenid = Player.PlayerData.citizenid

    if not playerStats[citizenid] then
        LoadPlayerStats(citizenid)
    end

    local stats = playerStats[citizenid]

    -- Reset streak
    stats.current_streak = 0
    stats.failed_deliveries = stats.failed_deliveries + 1
    stats.total_deliveries = stats.total_deliveries + 1

    -- Deduct XP
    DeductXP(citizenid, Config.XPPenaltyFailed, reason)

    -- Log failure
    MySQL.Async.execute([[
        INSERT INTO ocean_delivery_history (citizenid, status) VALUES (?, 'failed')
    ]], {citizenid})

    SavePlayerStats(citizenid)

    -- Clear job data
    activeJobs[citizenid] = nil
    activeBoats[citizenid] = nil

    TriggerClientEvent('QBCore:Notify', src, "Delivery failed: " .. reason, "error")
    debugPrint("Delivery failed for " .. citizenid .. " - Reason: " .. reason)
end

-- =============================================================================
-- NETWORK EVENTS
-- =============================================================================

RegisterNetEvent('cargo:saveBoatEntity', function(boatNetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        activeBoats[Player.PlayerData.citizenid] = boatNetId
        debugPrint("Saved boat entity for player: " .. Player.PlayerData.citizenid)
    end
end)

RegisterNetEvent('cargo:jobStarted', function(jobData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        activeJobs[Player.PlayerData.citizenid] = jobData
        debugPrint("Started job for player: " .. Player.PlayerData.citizenid)
    end
end)

RegisterNetEvent('cargo:jobCompleted', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData.citizenid then
        activeJobs[Player.PlayerData.citizenid] = nil
        activeBoats[Player.PlayerData.citizenid] = nil
        debugPrint("Completed job for player: " .. Player.PlayerData.citizenid)
    end
end)

RegisterNetEvent('cargo:jobFailed', function(reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        FailDelivery(src, Player, reason or "Unknown")
    end
end)

RegisterNetEvent('cargo:deliveryComplete', function(deliveryData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        -- Validate delivery data
        if not deliveryData or type(deliveryData) ~= "table" then
            debugPrint("Invalid delivery data from " .. Player.PlayerData.citizenid)
            return
        end

        local distance = deliveryData.distance or 0

        -- Sanity checks
        if distance > 15000 then
            debugPrint("Suspicious: Distance too large (" .. distance .. ") for " .. Player.PlayerData.citizenid)
            return
        end

        CompleteDelivery(src, Player, deliveryData)
    end
end)

RegisterNetEvent('cargo:startDelivery', function(routeData, boatData, cargoData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player then
        local citizenid = Player.PlayerData.citizenid

        -- Check if player already has an active job
        if activeJobs[citizenid] then
            TriggerClientEvent('QBCore:Notify', src, "You already have an active delivery job.", "error")
            return
        end

        -- Load player stats
        if not playerStats[citizenid] then
            LoadPlayerStats(citizenid)
        end

        local stats = playerStats[citizenid]

        -- Validate boat access
        if boatData and boatData.requiredLevel then
            if stats.level < boatData.requiredLevel then
                TriggerClientEvent('QBCore:Notify', src, "You need level " .. boatData.requiredLevel .. " to use this boat.", "error")
                return
            end
        end

        -- Validate cargo type access
        if cargoData and cargoData.minTier then
            local playerTier = Config.GetUnlockedTier(stats.level)
            if playerTier < cargoData.minTier then
                TriggerClientEvent('QBCore:Notify', src, "You need tier " .. cargoData.minTier .. " to transport this cargo.", "error")
                return
            end
        end

        -- Check job start cost
        local jobStartCost = Config.JobStartCost or 0
        if jobStartCost > 0 then
            if Player.PlayerData.money.cash >= jobStartCost then
                Player.Functions.RemoveMoney('cash', jobStartCost, "Delivery Job Fee")
                TriggerClientEvent('QBCore:Notify', src, "You paid $" .. jobStartCost .. " to start the delivery job.", "info")
            else
                TriggerClientEvent('QBCore:Notify', src, "You need $" .. jobStartCost .. " to start a delivery job", "error")
                return
            end
        end

        -- Start the job
        TriggerClientEvent('cargo:spawnBoatAndPallet', src, routeData, boatData, cargoData)
    end
end)

RegisterNetEvent('cargo:addLocationAtPosition', function(name, position, tier, hasFuel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player.PlayerData.permission or (Player.PlayerData.permission ~= "admin" and Player.PlayerData.permission ~= "god") then
        TriggerClientEvent('QBCore:Notify', src, "Permission denied", "error")
        return
    end

    AddCustomLocation(name, position, tier or 1, hasFuel or false, Player.PlayerData.citizenid)
    TriggerClientEvent('QBCore:Notify', src, "Added delivery location: " .. name, "success")
end)

-- =============================================================================
-- PLAYER LOAD EVENTS
-- =============================================================================

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        -- Load player stats
        LoadPlayerStats(citizenid)

        -- Sync locations
        Wait(1000)
        TriggerClientEvent('cargo:syncLocations', src, Config.AllLocations)

        -- Restore active job if exists
        if activeJobs[citizenid] then
            Wait(2000)
            TriggerClientEvent('cargo:restoreJob', src, activeJobs[citizenid])
            debugPrint("Restored job for player: " .. citizenid)
        end
    end
end)

RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        if playerStats[citizenid] then
            SavePlayerStats(citizenid)
        end
        debugPrint("Player unloaded, saving stats for: " .. citizenid)
    end
end)

RegisterNetEvent('cargo:playerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        LoadPlayerStats(Player.PlayerData.citizenid)
        TriggerClientEvent('cargo:syncLocations', src, Config.AllLocations)
    end
end)

-- =============================================================================
-- CALLBACKS
-- =============================================================================

-- Get player stats
QBCore.Functions.CreateCallback('cargo:getPlayerStats', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        if not playerStats[citizenid] then
            LoadPlayerStats(citizenid)
        end

        local stats = playerStats[citizenid]
        local levelInfo = Config.GetLevelFromXP(stats.xp)
        local nextLevelXP = Config.GetXPForNextLevel(stats.xp)
        local xpProgress = Config.GetXPProgress(stats.xp)
        local unlockedTier = Config.GetUnlockedTier(stats.level)

        cb({
            xp = stats.xp,
            level = stats.level,
            title = levelInfo.title,
            tier = unlockedTier,
            nextLevelXP = nextLevelXP,
            xpProgress = xpProgress,
            totalDeliveries = stats.total_deliveries,
            successfulDeliveries = stats.successful_deliveries,
            failedDeliveries = stats.failed_deliveries,
            totalDistance = stats.total_distance,
            totalEarnings = stats.total_earnings,
            currentStreak = stats.current_streak,
            bestStreak = stats.best_streak,
            favoriteBoat = stats.favorite_boat
        })
    else
        cb(nil)
    end
end)

-- Get available boats for player
QBCore.Functions.CreateCallback('cargo:getAvailableBoats', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        if not playerStats[citizenid] then
            LoadPlayerStats(citizenid)
        end

        local stats = playerStats[citizenid]
        local tier = Config.GetUnlockedTier(stats.level)
        local boats = Config.GetBoatsForTier(tier, stats.level)

        cb(boats, tier, stats.level)
    else
        cb({}, 1, 1)
    end
end)

-- Get available cargo types for player
QBCore.Functions.CreateCallback('cargo:getAvailableCargo', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        if not playerStats[citizenid] then
            LoadPlayerStats(citizenid)
        end

        local stats = playerStats[citizenid]
        local tier = Config.GetUnlockedTier(stats.level)
        local cargo = Config.GetCargoForTier(tier)

        cb(cargo, tier)
    else
        cb({}, 1)
    end
end)

-- Get routes for player's tier
QBCore.Functions.CreateCallback('cargo:getRoutes', function(source, cb, tier)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        if not playerStats[citizenid] then
            LoadPlayerStats(citizenid)
        end

        local stats = playerStats[citizenid]
        local playerTier = tier or Config.GetUnlockedTier(stats.level)

        local routes = GenerateRoutes(source, playerTier)
        cb(routes)
    else
        cb(nil)
    end
end)

-- Get delivery count (legacy)
QBCore.Functions.CreateCallback('cargo:getDeliveryCount', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        if not playerStats[citizenid] then
            LoadPlayerStats(citizenid)
        end

        cb(playerStats[citizenid].total_deliveries or 0)
    else
        cb(0)
    end
end)

-- Get total earnings (legacy)
QBCore.Functions.CreateCallback('cargo:getTotalEarnings', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        if not playerStats[citizenid] then
            LoadPlayerStats(citizenid)
        end

        cb(playerStats[citizenid].total_earnings or 0)
    else
        cb(0)
    end
end)

-- =============================================================================
-- COMMANDS
-- =============================================================================

QBCore.Commands.Add('deliverystats', 'Check your delivery job statistics', {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player then
        local citizenid = Player.PlayerData.citizenid

        if not playerStats[citizenid] then
            LoadPlayerStats(citizenid)
        end

        local stats = playerStats[citizenid]
        local levelInfo = Config.GetLevelFromXP(stats.xp)
        local tier = Config.GetUnlockedTier(stats.level)

        TriggerClientEvent('QBCore:Notify', src, "Level " .. stats.level .. " " .. levelInfo.title .. " (Tier " .. tier .. ")", "success")
        TriggerClientEvent('QBCore:Notify', src, "XP: " .. stats.xp .. " | Deliveries: " .. stats.successful_deliveries, "success")
        TriggerClientEvent('QBCore:Notify', src, "Earnings: $" .. stats.total_earnings .. " | Best Streak: " .. stats.best_streak, "success")
    end
end)

QBCore.Commands.Add('resetdelivery', 'Reset a player\'s delivery job (Admin Only)', {{name = 'id', help = 'Player ID'}}, true, function(source, args)
    local src = source
    local adminPlayer = QBCore.Functions.GetPlayer(src)

    if not adminPlayer.PlayerData.permission or (adminPlayer.PlayerData.permission ~= "admin" and adminPlayer.PlayerData.permission ~= "god") then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to use this command", "error")
        return
    end

    if args[1] then
        local targetId = tonumber(args[1])
        local targetPlayer = QBCore.Functions.GetPlayer(targetId)

        if targetPlayer then
            local citizenid = targetPlayer.PlayerData.citizenid
            activeJobs[citizenid] = nil
            activeBoats[citizenid] = nil
            TriggerClientEvent('cargo:resetDeliveryCount', targetId)
            TriggerClientEvent('QBCore:Notify', src, "Reset delivery job for player ID: " .. targetId, "success")
            TriggerClientEvent('QBCore:Notify', targetId, "Your delivery job has been reset by an admin", "info")
        else
            TriggerClientEvent('QBCore:Notify', src, "Player not found", "error")
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "Please specify a player ID", "error")
    end
end)

QBCore.Commands.Add('adddeliverylocation', 'Add a delivery location (Admin Only)', {
    {name = 'name', help = 'Location name'},
    {name = 'tier', help = 'Tier (1-3)'},
    {name = 'fuel', help = 'Has fuel (true/false)'}
}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player.PlayerData.permission or (Player.PlayerData.permission ~= "admin" and Player.PlayerData.permission ~= "god") then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to use this command", "error")
        return
    end

    if not args[1] then
        TriggerClientEvent('QBCore:Notify', src, "Please specify a location name", "error")
        return
    end

    local tier = tonumber(args[2]) or 1
    local hasFuel = args[3] == "true"

    TriggerClientEvent('cargo:getPlayerPosition', src, args[1], tier, hasFuel)
end)

QBCore.Commands.Add('listdeliverylocations', 'List all delivery locations (Admin Only)', {}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player.PlayerData.permission or (Player.PlayerData.permission ~= "admin" and Player.PlayerData.permission ~= "god") then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to use this command", "error")
        return
    end

    TriggerClientEvent('cargo:showLocationsList', src, Config.AllLocations)
end)

QBCore.Commands.Add('removedeliverylocation', 'Remove a delivery location (Admin Only)', {{name = 'id', help = 'Location ID'}}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player.PlayerData.permission or (Player.PlayerData.permission ~= "admin" and Player.PlayerData.permission ~= "god") then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to use this command", "error")
        return
    end

    if not args[1] or not tonumber(args[1]) then
        TriggerClientEvent('QBCore:Notify', src, "Please specify a valid location ID", "error")
        return
    end

    RemoveCustomLocation(tonumber(args[1]))
    TriggerClientEvent('QBCore:Notify', src, "Removed delivery location with ID: " .. args[1], "success")
end)

QBCore.Commands.Add('setdeliverylevel', 'Set a player\'s delivery level (Admin Only)', {
    {name = 'id', help = 'Player ID'},
    {name = 'level', help = 'Level (1-10)'}
}, true, function(source, args)
    local src = source
    local adminPlayer = QBCore.Functions.GetPlayer(src)

    if not adminPlayer.PlayerData.permission or (adminPlayer.PlayerData.permission ~= "admin" and adminPlayer.PlayerData.permission ~= "god") then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to use this command", "error")
        return
    end

    local targetId = tonumber(args[1])
    local newLevel = tonumber(args[2])

    if not targetId or not newLevel then
        TriggerClientEvent('QBCore:Notify', src, "Usage: /setdeliverylevel [playerID] [level]", "error")
        return
    end

    if newLevel < 1 or newLevel > 10 then
        TriggerClientEvent('QBCore:Notify', src, "Level must be between 1 and 10", "error")
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if targetPlayer then
        local citizenid = targetPlayer.PlayerData.citizenid

        if not playerStats[citizenid] then
            LoadPlayerStats(citizenid)
        end

        -- Set XP to match level
        local targetXP = Config.Levels[newLevel].xp
        playerStats[citizenid].xp = targetXP
        playerStats[citizenid].level = newLevel

        SavePlayerStats(citizenid)

        TriggerClientEvent('QBCore:Notify', src, "Set level to " .. newLevel .. " for player ID: " .. targetId, "success")
        TriggerClientEvent('QBCore:Notify', targetId, "Your delivery level has been set to " .. newLevel, "info")
    else
        TriggerClientEvent('QBCore:Notify', src, "Player not found", "error")
    end
end)

-- =============================================================================
-- RESOURCE LIFECYCLE
-- =============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end

    debugPrint('Resource started')

    local allDependenciesAvailable = true

    if not exports['qb-core'] then
        debugPrint('ERROR: qb-core dependency missing!')
        allDependenciesAvailable = false
    end

    if not exports['oxmysql'] then
        debugPrint('ERROR: oxmysql dependency missing!')
        allDependenciesAvailable = false
    end

    if exports['renewed-banking'] then
        debugPrint('Using Renewed Banking for payments')
    elseif exports['qs-banking'] then
        debugPrint('Using QS-Banking for payments')
    else
        debugPrint('Using basic QBCore money functions')
    end

    if not allDependenciesAvailable then
        debugPrint('WARNING: Some dependencies are missing!')
    else
        debugPrint('All required dependencies are available')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end

    debugPrint('Resource stopped')

    -- Save all player stats
    for citizenid, _ in pairs(playerStats) do
        SavePlayerStats(citizenid)
    end

    local activeJobCount = 0
    for _ in pairs(activeJobs) do activeJobCount = activeJobCount + 1 end

    debugPrint('Resource stopping with ' .. activeJobCount .. ' active delivery jobs')
end)
