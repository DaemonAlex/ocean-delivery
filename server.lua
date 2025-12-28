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
            INDEX idx_status (status),
            INDEX idx_created_at (created_at)
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

    -- Fleet ownership table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS ocean_delivery_fleet (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            boat_model VARCHAR(50) NOT NULL,
            boat_name VARCHAR(100) DEFAULT NULL,
            condition_percent FLOAT DEFAULT 100.0,
            fuel_level FLOAT DEFAULT 100.0,
            total_deliveries INT DEFAULT 0,
            total_distance FLOAT DEFAULT 0,
            purchase_price INT DEFAULT 0,
            insured BOOLEAN DEFAULT FALSE,
            is_starter BOOLEAN DEFAULT FALSE,
            last_maintenance TIMESTAMP NULL,
            purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_citizenid (citizenid),
            INDEX idx_model (boat_model)
        )
    ]], {}, function(success)
        if success then
            debugPrint("Fleet ownership table initialized")
            -- Add is_starter column if it doesn't exist (for existing databases)
            MySQL.Async.execute([[
                ALTER TABLE ocean_delivery_fleet ADD COLUMN IF NOT EXISTS is_starter BOOLEAN DEFAULT FALSE
            ]], {})
        end
    end)

    -- Maintenance log table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS ocean_delivery_maintenance (
            id INT AUTO_INCREMENT PRIMARY KEY,
            fleet_id INT NOT NULL,
            citizenid VARCHAR(50) NOT NULL,
            maintenance_type ENUM('repair', 'insurance', 'routine') DEFAULT 'routine',
            cost INT DEFAULT 0,
            notes VARCHAR(255) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_fleet (fleet_id),
            INDEX idx_citizenid (citizenid)
        )
    ]], {}, function(success)
        if success then
            debugPrint("Maintenance log table initialized")
        end
    end)

    -- Encounters log table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS ocean_delivery_encounters (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            encounter_type VARCHAR(50) NOT NULL,
            outcome ENUM('success', 'failed', 'escaped', 'caught', 'abandoned') DEFAULT 'success',
            reward INT DEFAULT 0,
            xp_earned INT DEFAULT 0,
            cargo_type VARCHAR(50) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_citizenid (citizenid)
        )
    ]], {}, function(success)
        if success then
            debugPrint("Encounters log table initialized")
        end
    end)

    -- Boat loans/financing table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS ocean_delivery_loans (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            fleet_id INT NOT NULL,
            boat_model VARCHAR(50) NOT NULL,
            total_amount INT NOT NULL,
            down_payment INT NOT NULL,
            financed_amount INT NOT NULL,
            interest_rate FLOAT NOT NULL,
            weekly_payment INT NOT NULL,
            weeks_total INT NOT NULL,
            weeks_paid INT DEFAULT 0,
            amount_paid INT DEFAULT 0,
            amount_remaining INT NOT NULL,
            missed_payments INT DEFAULT 0,
            status ENUM('active', 'paid', 'defaulted', 'repossessed') DEFAULT 'active',
            next_payment_due TIMESTAMP NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            paid_off_at TIMESTAMP NULL,
            INDEX idx_citizenid (citizenid),
            INDEX idx_fleet (fleet_id),
            INDEX idx_status (status)
        )
    ]], {}, function(success)
        if success then
            debugPrint("Boat loans table initialized")
        end
    end)
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
-- STARTER BOAT FUNCTIONS
-- =============================================================================

-- Check if player has any boats (including starter)
local function PlayerHasBoats(citizenid)
    local count = MySQL.Sync.fetchScalar([[
        SELECT COUNT(*) FROM ocean_delivery_fleet WHERE citizenid = ?
    ]], {citizenid})
    return count and count > 0
end

-- Check if player already has a starter boat
local function PlayerHasStarterBoat(citizenid)
    local count = MySQL.Sync.fetchScalar([[
        SELECT COUNT(*) FROM ocean_delivery_fleet WHERE citizenid = ? AND is_starter = TRUE
    ]], {citizenid})
    return count and count > 0
end

-- Grant starter boat to player
local function GrantStarterBoat(citizenid, src)
    if not Config.StarterBoat.enabled then
        return false, "Starter boats are disabled"
    end

    -- Check if player already has a starter boat
    if PlayerHasStarterBoat(citizenid) then
        return false, "You already have a starter boat"
    end

    local boatModel = Config.StarterBoat.model
    local boatName = Config.StarterBoat.name
    local boatData = Config.GetBoatByModel(boatModel)

    if not boatData then
        debugPrint("ERROR: Starter boat model '" .. boatModel .. "' not found in Config.Boats")
        return false, "Invalid starter boat configuration"
    end

    -- Add starter boat to fleet (free, no cost)
    MySQL.Async.execute([[
        INSERT INTO ocean_delivery_fleet (citizenid, boat_model, boat_name, purchase_price, is_starter)
        VALUES (?, ?, ?, 0, TRUE)
    ]], {citizenid, boatModel, boatName}, function(rowsChanged)
        if rowsChanged > 0 then
            debugPrint(citizenid .. " received free starter boat: " .. boatName)

            if src then
                TriggerClientEvent('cargo:starterBoatGranted', src, {
                    model = boatModel,
                    name = boatName,
                    message = Config.StarterBoat.message
                })
            end
        end
    end)

    return true, "Starter boat granted!"
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

        -- Check for starter boat (auto-grant if enabled and player has no boats)
        if Config.StarterBoat.enabled and Config.StarterBoat.autoGrant then
            if not PlayerHasBoats(citizenid) then
                GrantStarterBoat(citizenid, src)
            end
        end

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
-- FLEET OWNERSHIP CALLBACKS
-- =============================================================================

-- Get player's fleet
QBCore.Functions.CreateCallback('cargo:getPlayerFleet', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        local fleet = MySQL.Sync.fetchAll([[
            SELECT * FROM ocean_delivery_fleet WHERE citizenid = ? ORDER BY is_starter DESC, purchased_at DESC
        ]], {citizenid})

        -- Enhance with config data
        for i, ship in ipairs(fleet) do
            local boatData = Config.GetBoatByModel(ship.boat_model)
            if boatData then
                fleet[i].label = boatData.label
                fleet[i].tier = boatData.tier
                fleet[i].speed = boatData.speed
                fleet[i].capacity = boatData.capacity
                fleet[i].description = boatData.description
                fleet[i].maintenance = boatData.maintenance
                fleet[i].insurance_cost = boatData.insurance
            end

            -- Mark if it's a starter boat
            fleet[i].isStarter = ship.is_starter == 1
            if fleet[i].isStarter then
                fleet[i].label = Config.StarterBoat.name or "Starter Boat"
                fleet[i].canSell = Config.StarterBoat.canSell or false
            else
                fleet[i].canSell = true
            end
        end

        cb(fleet)
    else
        cb({})
    end
end)

-- Buy a boat
QBCore.Functions.CreateCallback('cargo:buyBoat', function(source, cb, boatModel, boatName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, "Player not found")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local boatData = Config.GetBoatByModel(boatModel)

    if not boatData then
        cb(false, "Invalid boat model")
        return
    end

    -- Check player level
    if not playerStats[citizenid] then
        LoadPlayerStats(citizenid)
    end
    local stats = playerStats[citizenid]

    if boatData.requiredLevel and stats.level < boatData.requiredLevel then
        cb(false, "You need level " .. boatData.requiredLevel .. " to buy this boat")
        return
    end

    -- Check fleet limit
    local fleetCount = MySQL.Sync.fetchScalar([[
        SELECT COUNT(*) FROM ocean_delivery_fleet WHERE citizenid = ?
    ]], {citizenid})

    if fleetCount >= Config.FleetOwnership.maxShipsPerPlayer then
        cb(false, "You've reached the maximum fleet size of " .. Config.FleetOwnership.maxShipsPerPlayer)
        return
    end

    -- Check if player has enough money
    local price = boatData.price or 10000
    if Player.PlayerData.money.bank < price then
        cb(false, "You don't have enough money. Need $" .. price)
        return
    end

    -- Deduct money and add boat
    Player.Functions.RemoveMoney('bank', price, "Boat purchase: " .. boatData.label)

    MySQL.Async.execute([[
        INSERT INTO ocean_delivery_fleet (citizenid, boat_model, boat_name, purchase_price)
        VALUES (?, ?, ?, ?)
    ]], {citizenid, boatModel, boatName or boatData.label, price}, function(rowsChanged)
        if rowsChanged > 0 then
            debugPrint(citizenid .. " purchased " .. boatData.label .. " for $" .. price)
            cb(true, "Successfully purchased " .. boatData.label)
        else
            -- Refund if insert failed
            Player.Functions.AddMoney('bank', price, "Refund: Boat purchase failed")
            cb(false, "Failed to complete purchase")
        end
    end)
end)

-- Sell a boat
QBCore.Functions.CreateCallback('cargo:sellBoat', function(source, cb, fleetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, "Player not found")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Get boat info
    local boat = MySQL.Sync.fetchAll([[
        SELECT * FROM ocean_delivery_fleet WHERE id = ? AND citizenid = ?
    ]], {fleetId, citizenid})

    if not boat or #boat == 0 then
        cb(false, "Boat not found or you don't own it")
        return
    end

    boat = boat[1]

    -- Check if it's a starter boat
    if boat.is_starter == 1 and not Config.StarterBoat.canSell then
        cb(false, "You cannot sell your starter boat. It's a gift!")
        return
    end

    local boatData = Config.GetBoatByModel(boat.boat_model)
    local basePrice = boatData and boatData.price or boat.purchase_price
    local conditionMultiplier = boat.condition_percent / 100
    local sellPrice = math.floor(basePrice * Config.FleetOwnership.sellBackPercent * conditionMultiplier)

    -- Starter boats have no resale value
    if boat.is_starter == 1 then
        sellPrice = 0
    end

    -- Delete boat and give money
    MySQL.Async.execute([[
        DELETE FROM ocean_delivery_fleet WHERE id = ?
    ]], {fleetId}, function(rowsChanged)
        if rowsChanged > 0 then
            if sellPrice > 0 then
                Player.Functions.AddMoney('bank', sellPrice, "Boat sale: " .. (boatData and boatData.label or boat.boat_model))
            end
            debugPrint(citizenid .. " sold boat ID " .. fleetId .. " for $" .. sellPrice)
            cb(true, "Sold for $" .. sellPrice)
        else
            cb(false, "Failed to sell boat")
        end
    end)
end)

-- Repair a boat
QBCore.Functions.CreateCallback('cargo:repairBoat', function(source, cb, fleetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, "Player not found")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Get boat info
    local boat = MySQL.Sync.fetchAll([[
        SELECT * FROM ocean_delivery_fleet WHERE id = ? AND citizenid = ?
    ]], {fleetId, citizenid})

    if not boat or #boat == 0 then
        cb(false, "Boat not found")
        return
    end

    boat = boat[1]

    if boat.condition_percent >= 100 then
        cb(false, "Boat is already in perfect condition")
        return
    end

    local boatData = Config.GetBoatByModel(boat.boat_model)
    local basePrice = boatData and boatData.price or boat.purchase_price
    local damagePercent = (100 - boat.condition_percent) / 100
    local repairCost = math.floor(basePrice * Config.FleetOwnership.repairCostMultiplier * damagePercent)

    if Player.PlayerData.money.bank < repairCost then
        cb(false, "Repair costs $" .. repairCost .. ". You don't have enough.")
        return
    end

    Player.Functions.RemoveMoney('bank', repairCost, "Boat repair")

    MySQL.Async.execute([[
        UPDATE ocean_delivery_fleet SET condition_percent = 100.0, last_maintenance = NOW() WHERE id = ?
    ]], {fleetId})

    -- Log maintenance
    MySQL.Async.execute([[
        INSERT INTO ocean_delivery_maintenance (fleet_id, citizenid, maintenance_type, cost, notes)
        VALUES (?, ?, 'repair', ?, 'Full repair')
    ]], {fleetId, citizenid, repairCost})

    debugPrint(citizenid .. " repaired boat ID " .. fleetId .. " for $" .. repairCost)
    cb(true, "Boat repaired for $" .. repairCost)
end)

-- Add insurance to a boat
QBCore.Functions.CreateCallback('cargo:insureBoat', function(source, cb, fleetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, "Player not found")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    local boat = MySQL.Sync.fetchAll([[
        SELECT * FROM ocean_delivery_fleet WHERE id = ? AND citizenid = ?
    ]], {fleetId, citizenid})

    if not boat or #boat == 0 then
        cb(false, "Boat not found")
        return
    end

    boat = boat[1]

    if boat.insured == 1 then
        cb(false, "Boat is already insured")
        return
    end

    local boatData = Config.GetBoatByModel(boat.boat_model)
    local insuranceCost = boatData and boatData.insurance or math.floor(boat.purchase_price * 0.05)

    if Player.PlayerData.money.bank < insuranceCost then
        cb(false, "Insurance costs $" .. insuranceCost)
        return
    end

    Player.Functions.RemoveMoney('bank', insuranceCost, "Boat insurance")

    MySQL.Async.execute([[
        UPDATE ocean_delivery_fleet SET insured = TRUE WHERE id = ?
    ]], {fleetId})

    MySQL.Async.execute([[
        INSERT INTO ocean_delivery_maintenance (fleet_id, citizenid, maintenance_type, cost, notes)
        VALUES (?, ?, 'insurance', ?, 'Insurance purchased')
    ]], {fleetId, citizenid, insuranceCost})

    cb(true, "Boat insured for $" .. insuranceCost)
end)

-- Claim starter boat manually
QBCore.Functions.CreateCallback('cargo:claimStarterBoat', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, "Player not found")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    if not Config.StarterBoat.enabled then
        cb(false, "Starter boats are not available")
        return
    end

    -- Check if player already has boats
    if PlayerHasBoats(citizenid) then
        cb(false, "You already have a boat in your fleet!")
        return
    end

    local success, message = GrantStarterBoat(citizenid, src)
    cb(success, message)
end)

-- Check if player is eligible for starter boat
QBCore.Functions.CreateCallback('cargo:checkStarterBoatEligible', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    if not Config.StarterBoat.enabled then
        cb(false, nil)
        return
    end

    local hasBoats = PlayerHasBoats(citizenid)
    cb(not hasBoats, Config.StarterBoat)
end)

-- Get boats available for purchase
QBCore.Functions.CreateCallback('cargo:getBoatsForSale', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        if not playerStats[citizenid] then
            LoadPlayerStats(citizenid)
        end

        local stats = playerStats[citizenid]
        local playerLevel = stats.level

        local boatsForSale = {}
        for _, boat in ipairs(Config.Boats) do
            local canBuy = true
            local reason = nil

            if boat.requiredLevel and playerLevel < boat.requiredLevel then
                canBuy = false
                reason = "Requires Level " .. boat.requiredLevel
            end

            table.insert(boatsForSale, {
                model = boat.model,
                label = boat.label,
                tier = boat.tier,
                speed = boat.speed,
                capacity = boat.capacity,
                handling = boat.handling,
                fuelEfficiency = boat.fuelEfficiency,
                description = boat.description,
                price = boat.price,
                insurance = boat.insurance,
                maintenance = boat.maintenance,
                requiredLevel = boat.requiredLevel or 1,
                canBuy = canBuy,
                reason = reason
            })
        end

        cb(boatsForSale, playerLevel)
    else
        cb({}, 1)
    end
end)

-- =============================================================================
-- FINANCING CALLBACKS
-- =============================================================================

-- Get player's active loans
QBCore.Functions.CreateCallback('cargo:getPlayerLoans', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        local loans = MySQL.Sync.fetchAll([[
            SELECT l.*, f.boat_name FROM ocean_delivery_loans l
            LEFT JOIN ocean_delivery_fleet f ON l.fleet_id = f.id
            WHERE l.citizenid = ? AND l.status = 'active'
            ORDER BY l.next_payment_due ASC
        ]], {citizenid})

        -- Enhance with boat data
        for i, loan in ipairs(loans) do
            local boatData = Config.GetBoatByModel(loan.boat_model)
            if boatData then
                loans[i].boat_label = boatData.label
            end
        end

        cb(loans)
    else
        cb({})
    end
end)

-- Finance a boat purchase
QBCore.Functions.CreateCallback('cargo:financeBoat', function(source, cb, boatModel, boatName, weeks)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, "Player not found")
        return
    end

    if not Config.Financing.enabled then
        cb(false, "Financing is not available")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local boatData = Config.GetBoatByModel(boatModel)

    if not boatData then
        cb(false, "Invalid boat model")
        return
    end

    -- Check player level
    if not playerStats[citizenid] then
        LoadPlayerStats(citizenid)
    end
    local stats = playerStats[citizenid]

    if boatData.requiredLevel and stats.level < boatData.requiredLevel then
        cb(false, "You need level " .. boatData.requiredLevel .. " to buy this boat")
        return
    end

    -- Check fleet limit
    local fleetCount = MySQL.Sync.fetchScalar([[
        SELECT COUNT(*) FROM ocean_delivery_fleet WHERE citizenid = ?
    ]], {citizenid})

    if fleetCount >= Config.FleetOwnership.maxShipsPerPlayer then
        cb(false, "You've reached the maximum fleet size")
        return
    end

    -- Check for existing active loans (limit to 2)
    local activeLoans = MySQL.Sync.fetchScalar([[
        SELECT COUNT(*) FROM ocean_delivery_loans WHERE citizenid = ? AND status = 'active'
    ]], {citizenid})

    if activeLoans >= 2 then
        cb(false, "You already have 2 active loans. Pay one off first.")
        return
    end

    -- Calculate financing
    local price = boatData.price
    local downPayment = math.floor(price * Config.Financing.downPaymentPercent)

    -- Find interest multiplier for term
    local interestMult = 1.0
    for _, term in ipairs(Config.Financing.terms) do
        if term.weeks == weeks then
            interestMult = term.interestMult
            break
        end
    end

    local financedAmount = price - downPayment
    local interest = math.floor(financedAmount * Config.Financing.interestRate * interestMult)
    local totalFinanced = financedAmount + interest
    local weeklyPayment = math.ceil(totalFinanced / weeks)

    -- Check if player has down payment
    if Player.PlayerData.money.bank < downPayment then
        cb(false, "You need $" .. downPayment .. " for the down payment")
        return
    end

    -- Process down payment
    Player.Functions.RemoveMoney('bank', downPayment, "Boat down payment: " .. boatData.label)

    -- Add boat to fleet
    MySQL.Async.execute([[
        INSERT INTO ocean_delivery_fleet (citizenid, boat_model, boat_name, purchase_price)
        VALUES (?, ?, ?, ?)
    ]], {citizenid, boatModel, boatName or boatData.label, price}, function(rowsChanged)
        if rowsChanged > 0 then
            -- Get the fleet ID
            local fleetId = MySQL.Sync.fetchScalar([[
                SELECT id FROM ocean_delivery_fleet WHERE citizenid = ? ORDER BY id DESC LIMIT 1
            ]], {citizenid})

            -- Create loan record
            MySQL.Async.execute([[
                INSERT INTO ocean_delivery_loans
                (citizenid, fleet_id, boat_model, total_amount, down_payment, financed_amount,
                 interest_rate, weekly_payment, weeks_total, amount_remaining, next_payment_due)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))
            ]], {
                citizenid, fleetId, boatModel, price, downPayment, totalFinanced,
                Config.Financing.interestRate * interestMult, weeklyPayment, weeks, totalFinanced
            })

            debugPrint(citizenid .. " financed " .. boatData.label .. " - Down: $" .. downPayment .. ", Weekly: $" .. weeklyPayment .. " x " .. weeks)

            cb(true, "Boat financed! Down payment: $" .. downPayment .. ". Weekly payment: $" .. weeklyPayment, {
                downPayment = downPayment,
                weeklyPayment = weeklyPayment,
                weeks = weeks,
                totalFinanced = totalFinanced
            })
        else
            Player.Functions.AddMoney('bank', downPayment, "Refund: Financing failed")
            cb(false, "Failed to complete financing")
        end
    end)
end)

-- Make a loan payment
QBCore.Functions.CreateCallback('cargo:makeLoanPayment', function(source, cb, loanId, payExtra)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, "Player not found")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Get loan info
    local loan = MySQL.Sync.fetchAll([[
        SELECT * FROM ocean_delivery_loans WHERE id = ? AND citizenid = ? AND status = 'active'
    ]], {loanId, citizenid})

    if not loan or #loan == 0 then
        cb(false, "Loan not found")
        return
    end

    loan = loan[1]

    local paymentAmount = payExtra and loan.amount_remaining or loan.weekly_payment
    paymentAmount = math.min(paymentAmount, loan.amount_remaining)

    if Player.PlayerData.money.bank < paymentAmount then
        cb(false, "You need $" .. paymentAmount .. " to make this payment")
        return
    end

    Player.Functions.RemoveMoney('bank', paymentAmount, "Boat loan payment")

    local newAmountPaid = loan.amount_paid + paymentAmount
    local newAmountRemaining = loan.amount_remaining - paymentAmount
    local newWeeksPaid = loan.weeks_paid + 1

    if newAmountRemaining <= 0 then
        -- Loan paid off!
        MySQL.Async.execute([[
            UPDATE ocean_delivery_loans SET
                amount_paid = ?, amount_remaining = 0, weeks_paid = ?,
                status = 'paid', paid_off_at = NOW()
            WHERE id = ?
        ]], {newAmountPaid, newWeeksPaid, loanId})

        debugPrint(citizenid .. " paid off loan #" .. loanId)
        cb(true, "Loan paid off! The boat is now fully yours!", { paidOff = true })
    else
        -- Regular payment
        MySQL.Async.execute([[
            UPDATE ocean_delivery_loans SET
                amount_paid = ?, amount_remaining = ?, weeks_paid = ?,
                missed_payments = 0, next_payment_due = DATE_ADD(NOW(), INTERVAL 7 DAY)
            WHERE id = ?
        ]], {newAmountPaid, newAmountRemaining, newWeeksPaid, loanId})

        cb(true, "Payment of $" .. paymentAmount .. " received. Remaining: $" .. newAmountRemaining, {
            paidOff = false,
            remaining = newAmountRemaining,
            weeksLeft = loan.weeks_total - newWeeksPaid
        })
    end
end)

-- Pay off entire loan
QBCore.Functions.CreateCallback('cargo:payoffLoan', function(source, cb, loanId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, "Player not found")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    local loan = MySQL.Sync.fetchAll([[
        SELECT * FROM ocean_delivery_loans WHERE id = ? AND citizenid = ? AND status = 'active'
    ]], {loanId, citizenid})

    if not loan or #loan == 0 then
        cb(false, "Loan not found")
        return
    end

    loan = loan[1]

    if Player.PlayerData.money.bank < loan.amount_remaining then
        cb(false, "You need $" .. loan.amount_remaining .. " to pay off this loan")
        return
    end

    Player.Functions.RemoveMoney('bank', loan.amount_remaining, "Boat loan payoff")

    MySQL.Async.execute([[
        UPDATE ocean_delivery_loans SET
            amount_paid = total_amount, amount_remaining = 0,
            status = 'paid', paid_off_at = NOW()
        WHERE id = ?
    ]], {loanId})

    debugPrint(citizenid .. " paid off loan #" .. loanId .. " early for $" .. loan.amount_remaining)
    cb(true, "Loan paid off for $" .. loan.amount_remaining .. "! The boat is fully yours!")
end)

-- =============================================================================
-- REFUELING CALLBACKS
-- =============================================================================

-- Refuel boat
QBCore.Functions.CreateCallback('cargo:refuelBoat', function(source, cb, fleetId, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, "Player not found")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local costPerLiter = Config.Refueling.costPerLiter or 3
    local totalCost = math.floor(amount * costPerLiter)

    if Player.PlayerData.money.cash < totalCost then
        cb(false, "You need $" .. totalCost .. " cash to refuel")
        return
    end

    Player.Functions.RemoveMoney('cash', totalCost, "Boat refuel")

    if fleetId then
        MySQL.Async.execute([[
            UPDATE ocean_delivery_fleet SET fuel_level = LEAST(100, fuel_level + ?) WHERE id = ? AND citizenid = ?
        ]], {amount, fleetId, citizenid})
    end

    cb(true, totalCost, amount)
end)

-- =============================================================================
-- ENCOUNTER CALLBACKS
-- =============================================================================

-- Log encounter result
RegisterNetEvent('cargo:logEncounter', function(encounterType, outcome, reward, xpEarned, cargoType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid

        MySQL.Async.execute([[
            INSERT INTO ocean_delivery_encounters (citizenid, encounter_type, outcome, reward, xp_earned, cargo_type)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {citizenid, encounterType, outcome, reward or 0, xpEarned or 0, cargoType})

        -- Award bonus XP/money for successful encounters
        if outcome == 'success' and reward > 0 then
            Player.Functions.AddMoney('cash', reward, "Encounter reward: " .. encounterType)
        end

        if outcome == 'success' and xpEarned > 0 then
            AwardXP(citizenid, xpEarned, "Encounter: " .. encounterType)
        end

        debugPrint(citizenid .. " completed encounter: " .. encounterType .. " - " .. outcome)
    end
end)

-- Police alert for illegal cargo (DPSRP 1.5: Dynamic risk based on cop count)
RegisterNetEvent('cargo:policeAlert', function(coords, cargoType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not Config.PoliceIntegration.enabled or not Config.PoliceIntegration.alertPolice then
        return
    end

    -- Get base police chance from cargo type
    local baseChance = 0.15 -- Default 15%
    for _, cargo in ipairs(Config.CargoTypes) do
        if cargo.id == cargoType and cargo.policeChance then
            baseChance = cargo.policeChance
            break
        end
    end

    -- Get online police count
    local players = QBCore.Functions.GetPlayers()
    local policeCount = 0

    for _, playerId in ipairs(players) do
        local targetPlayer = QBCore.Functions.GetPlayer(playerId)
        if targetPlayer and targetPlayer.PlayerData.job.name == 'police' then
            policeCount = policeCount + 1
        end
    end

    -- Dynamic risk calculation (DPSRP optimization)
    local finalChance = baseChance
    if Config.PoliceIntegration.dynamicRisk then
        local riskPerCop = Config.PoliceIntegration.riskPerCop or 0.02
        local maxMultiplier = Config.PoliceIntegration.maxRiskMultiplier or 2.0
        local multiplier = math.min(1 + (policeCount * riskPerCop), maxMultiplier)
        finalChance = baseChance * multiplier
    end

    -- Off-peak hours scaling (keeps economy fair during low-pop times)
    local isOffPeak = false
    if Config.PoliceIntegration.timeBasedScaling then
        local currentHour = tonumber(os.date("%H"))
        local offPeakHours = Config.PoliceIntegration.offPeakHours or {}
        for _, hour in ipairs(offPeakHours) do
            if currentHour == hour then
                isOffPeak = true
                break
            end
        end
        if isOffPeak then
            local offPeakMult = Config.PoliceIntegration.offPeakMultiplier or 0.5
            finalChance = finalChance * offPeakMult
        end
    end

    -- Roll against adjusted chance
    local roll = math.random()
    if roll > finalChance then
        debugPrint(string.format("Police roll failed: %.2f > %.2f (base: %.2f, cops: %d, offPeak: %s)", roll, finalChance, baseChance, policeCount, tostring(isOffPeak)))
        return
    end

    debugPrint(string.format("Police roll success: %.2f <= %.2f (base: %.2f, cops: %d, offPeak: %s)", roll, finalChance, baseChance, policeCount, tostring(isOffPeak)))

    -- Handle no cops online - spawn NPC coast guard instead
    if policeCount < Config.PoliceIntegration.minCops then
        if Config.PoliceIntegration.noCopsAlternative then
            TriggerClientEvent('cargo:spawnCoastGuard', src, coords)
            debugPrint("No cops online - spawning NPC coast guard")
        end
        return
    end

    -- Alert all online police
    for _, playerId in ipairs(players) do
        local targetPlayer = QBCore.Functions.GetPlayer(playerId)
        if targetPlayer and targetPlayer.PlayerData.job.name == 'police' then
            TriggerClientEvent('cargo:policeNotification', playerId, coords, cargoType)
        end
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
-- ORPHANED ENCOUNTER CLEANUP (High-pop server optimization)
-- =============================================================================
-- NOTE: Only cleans up ENCOUNTER entities (pirates, coast guard NPCs/boats)
-- Player-owned boats are handled by server vehicle persistence - DO NOT DELETE

-- Track spawned ENCOUNTER entities only (not player boats)
local encounterEntities = {}

-- Register encounter entity for tracking (pirates, coast guard, etc.)
RegisterNetEvent('cargo:registerEncounterEntity', function(entityNetId, entityType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    if not encounterEntities[citizenid] then
        encounterEntities[citizenid] = {}
    end
    table.insert(encounterEntities[citizenid], {
        netId = entityNetId,
        entityType = entityType or 'unknown',  -- 'pirate', 'coastguard', 'ped', 'boat'
        spawnTime = os.time(),
        owner = src
    })
end)

-- Cleanup encounter entities when player disconnects
-- Player boats persist via server vehicle persistence system
AddEventHandler('playerDropped', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Clean up active job state (boat persists via vehicle persistence)
    if activeJobs[citizenid] then
        activeJobs[citizenid] = nil
        debugPrint("Cleaned up active job state for disconnected player: " .. citizenid)
    end

    if activeBoats[citizenid] then
        -- Don't delete the boat - vehicle persistence handles it
        -- Just clear the tracking reference
        activeBoats[citizenid] = nil
        debugPrint("Cleared boat reference for disconnected player (boat persists): " .. citizenid)
    end

    -- Clean up encounter entity tracking
    if encounterEntities[citizenid] then
        debugPrint("Cleaned up " .. #encounterEntities[citizenid] .. " encounter entities for: " .. citizenid)
        encounterEntities[citizenid] = nil
    end
end)

-- Server-side encounter entity sweep (runs every 10 minutes)
-- Only cleans up encounter NPCs (pirates, coast guard) - NOT player boats
CreateThread(function()
    local SWEEP_INTERVAL = 10 * 60 * 1000  -- 10 minutes
    local MAX_ENCOUNTER_AGE = 30 * 60      -- 30 minutes max lifetime for encounters

    while true do
        Wait(SWEEP_INTERVAL)

        local currentTime = os.time()
        local cleanedCount = 0

        for citizenid, entities in pairs(encounterEntities) do
            -- Check if player is still online
            local playerOnline = false
            local players = QBCore.Functions.GetPlayers()
            for _, playerId in ipairs(players) do
                local player = QBCore.Functions.GetPlayer(playerId)
                if player and player.PlayerData.citizenid == citizenid then
                    playerOnline = true
                    break
                end
            end

            if not playerOnline then
                -- Player disconnected - clean up their encounter entities
                debugPrint("Sweeping orphaned encounter entities for offline player: " .. citizenid)
                encounterEntities[citizenid] = nil
                cleanedCount = cleanedCount + 1
            else
                -- Player online - clean up old encounter entities
                local validEntities = {}
                for _, entity in ipairs(entities) do
                    if (currentTime - entity.spawnTime) < MAX_ENCOUNTER_AGE then
                        table.insert(validEntities, entity)
                    else
                        cleanedCount = cleanedCount + 1
                    end
                end
                encounterEntities[citizenid] = validEntities
            end
        end

        if cleanedCount > 0 then
            debugPrint("Encounter sweep completed - cleaned " .. cleanedCount .. " orphaned/stale NPC entries")
        end
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
