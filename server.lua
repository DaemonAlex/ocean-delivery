-- SERVER.LUA - COMPLETE FILE
local QBCore = exports['qb-core']:GetCoreObject()

-- Store active jobs for persistence across server restarts
local activeJobs = {}
local activeBoats = {}

-- Function to handle payment with compatibility for both QS-Banking and Renewed Banking
local function AddMoneyToPlayer(player, amount, reason)
    local citizenid = player.PlayerData.citizenid
    
    -- Try Renewed Banking first
    if exports['renewed-banking'] then
        -- Renewed Banking
        exports['renewed-banking']:addAccountMoney(citizenid, amount, reason)
        return true
    elseif exports['qs-banking'] then
        -- QS-Banking fallback
        exports['qs-banking']:AddMoney(citizenid, amount, reason)
        return true
    else
        -- Basic QBCore fallback
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

-- Events
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

RegisterNetEvent('cargo:deliveryComplete', function(deliveryCount, distance)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        -- Sanity checks to prevent cheating
        if distance > 10000 then 
            -- Distance is unrealistically large
            debugPrint("Suspicious delivery detected: Distance too large (" .. distance .. ") for player: " .. Player.PlayerData.citizenid)
            return
        end
        
        if deliveryCount > 20 then
            -- Delivery count seems suspiciously high
            debugPrint("Suspicious delivery detected: Too many deliveries (" .. deliveryCount .. ") for player: " .. Player.PlayerData.citizenid)
            return
        end
        
        local payout = math.floor(distance * Config.BasePayoutPerDistance + (deliveryCount * Config.BonusPayout))
        
        -- Add bonus for completing a series of 4 deliveries
        if deliveryCount % 4 == 0 then
            payout = payout + Config.SeriesBonus
            TriggerClientEvent('QBCore:Notify', src, "Bonus payment of $" .. Config.SeriesBonus .. " for completing 4 deliveries!", "success")
        end
        
        -- Add money to player's account
        local success = AddMoneyToPlayer(Player, payout, 'Cargo Delivery Payment')
        
        if success then
            TriggerClientEvent('QBCore:Notify', src, "You received $" .. payout .. " for your delivery!", "success")
            debugPrint("Payment of $" .. payout .. " sent to player: " .. Player.PlayerData.citizenid)
        else
            TriggerClientEvent('QBCore:Notify', src, "Payment system error. Please contact an admin.", "error")
            debugPrint("Payment failed for player: " .. Player.PlayerData.citizenid)
        end
        
        -- Log the delivery in the database
        MySQL.Async.execute('INSERT INTO cargo_deliveries (player_id, deliveries, distance) VALUES (?, ?, ?)', {Player.PlayerData.citizenid, deliveryCount, distance}, function(rowsChanged)
            if rowsChanged > 0 then
                debugPrint("Delivery logged successfully for player: " .. Player.PlayerData.citizenid)
            else
                debugPrint("Failed to log delivery for player: " .. Player.PlayerData.citizenid)
            end
        end)
        
        -- Clear job data
        activeJobs[Player.PlayerData.citizenid] = nil
        activeBoats[Player.PlayerData.citizenid] = nil
    else
        debugPrint("Player not found for source: " .. src)
    end
end)

RegisterNetEvent('cargo:startDelivery', function(route)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        -- Check if player already has an active job
        if activeJobs[Player.PlayerData.citizenid] then
            TriggerClientEvent('QBCore:Notify', src, "You already have an active delivery job.", "error")
            return
        end
        
        -- Check if player has enough money to start job (optional)
        local jobStartCost = Config.JobStartCost or 0
        if jobStartCost > 0 then
            if Player.PlayerData.money.cash >= jobStartCost then
                -- Remove money
                Player.Functions.RemoveMoney('cash', jobStartCost, "Delivery Job Fee")
                TriggerClientEvent('QBCore:Notify', src, "You paid $" .. jobStartCost .. " to start the delivery job.", "info")
                
                -- Notify the client to spawn the boat and pallet
                TriggerClientEvent('cargo:spawnBoatAndPallet', src, route)
            else
                -- Not enough money
                TriggerClientEvent('QBCore:Notify', src, "You need $" .. jobStartCost .. " to start a delivery job", "error")
                return
            end
        else
            -- No cost to start job
            TriggerClientEvent('cargo:spawnBoatAndPallet', src, route)
        end
    else
        debugPrint("Player not found for source: " .. src)
    end
end)

-- Restore active job when player loads
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        
        if activeJobs[citizenid] then
            -- Restore active job
            Wait(2000) -- Give the client time to initialize
            TriggerClientEvent('cargo:restoreJob', src, activeJobs[citizenid])
            debugPrint("Restored job for player: " .. citizenid)
        end
    end
end)

-- Clean up if player disconnects
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        
        -- We don't remove the job data, just let it persist in case they reconnect
        debugPrint("Player unloaded, keeping job data for: " .. citizenid)
    end
end)

-- Get player's current delivery count
QBCore.Functions.CreateCallback('cargo:getDeliveryCount', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        
        -- Get delivery count from database
        MySQL.Async.fetchScalar('SELECT COUNT(*) FROM cargo_deliveries WHERE player_id = ?', {citizenid}, function(count)
            count = count or 0
            cb(count)
        end)
    else
        cb(0)
    end
end)

-- Get player's total earnings from deliveries
QBCore.Functions.CreateCallback('cargo:getTotalEarnings', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        
        -- Calculate total earnings based on deliveries
        MySQL.Async.fetchAll('SELECT deliveries, distance FROM cargo_deliveries WHERE player_id = ?', {citizenid}, function(result)
            local totalEarnings = 0
            
            if result and #result > 0 then
                for i=1, #result do
                    local delivery = result[i]
                    local payout = delivery.distance * Config.BasePayoutPerDistance + (delivery.deliveries * Config.BonusPayout)
                    
                    -- Add bonus for completing a series of 4 deliveries
                    if delivery.deliveries % 4 == 0 then
                        payout = payout + Config.SeriesBonus
                    end
                    
                    totalEarnings = totalEarnings + payout
                end
            end
            
            cb(totalEarnings)
        end)
    else
        cb(0)
    end
end)

-- Commands

-- Command to admin reset a player's delivery job
QBCore.Commands.Add('resetdelivery', 'Reset a player\'s delivery job (Admin Only)', {{name = 'id', help = 'Player ID'}}, true, function(source, args)
    local src = source
    local adminPlayer = QBCore.Functions.GetPlayer(src)
    
    -- Check admin permission
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
            debugPrint("Admin reset delivery job for player: " .. citizenid)
        else
            TriggerClientEvent('QBCore:Notify', src, "Player not found", "error")
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "Please specify a player ID", "error")
    end
end)

-- Command to check player stats
QBCore.Commands.Add('deliverystats', 'Check your delivery job statistics', {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        local citizenid = Player.PlayerData.citizenid
        
        -- Get delivery stats from database
        MySQL.Async.fetchAll('SELECT COUNT(*) as total, SUM(distance) as total_distance FROM cargo_deliveries WHERE player_id = ?', {citizenid}, function(result)
            if result and result[1] then
                local stats = result[1]
                local totalDeliveries = stats.total or 0
                local totalDistance = stats.total_distance or 0
                
                if totalDeliveries > 0 then
                    TriggerClientEvent('QBCore:Notify', src, "Total Deliveries: " .. totalDeliveries, "success")
                    TriggerClientEvent('QBCore:Notify', src, "Total Distance: " .. math.floor(totalDistance) .. " units", "success")
                else
                    TriggerClientEvent('QBCore:Notify', src, "You haven't completed any deliveries yet.", "info")
                end
            else
                TriggerClientEvent('QBCore:Notify', src, "Error retrieving delivery statistics.", "error")
            end
        end)
    end
end)

-- Resource start
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    
    debugPrint('Resource started')
    
    -- Check if all dependencies are available
    local allDependenciesAvailable = true
    
    if not exports['qb-core'] then
        debugPrint('ERROR: qb-core dependency missing!')
        allDependenciesAvailable = false
    end
    
    if not exports['oxmysql'] then
        debugPrint('ERROR: oxmysql dependency missing!')
        allDependenciesAvailable = false
    end
    
    -- Check for banking systems
    local bankingAvailable = false
    
    if exports['renewed-banking'] then
        debugPrint('Using Renewed Banking for payments')
        bankingAvailable = true
    elseif exports['qs-banking'] then
        debugPrint('Using QS-Banking for payments')
        bankingAvailable = true
    else
        debugPrint('No banking system found, falling back to basic QBCore money functions')
        bankingAvailable = true -- We'll still work with basic QBCore
    end
    
    if not allDependenciesAvailable then
        debugPrint('WARNING: Some dependencies are missing, the resource might not work correctly!')
    else
        debugPrint('All required dependencies are available')
    end
end)

-- Resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    
    debugPrint('Resource stopped')
    
    -- We could save active jobs to a file here if we wanted persistence across resource restarts
    -- For now, just log how many jobs were active
    local activeJobCount = 0
    for _ in pairs(activeJobs) do activeJobCount = activeJobCount + 1 end
    
    debugPrint('Resource stopping with ' .. activeJobCount .. ' active delivery jobs')
end)
