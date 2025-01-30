local QBCore = exports['qb-core']:GetCoreObject()

-- ...existing code...

RegisterNetEvent('cargo:deliveryComplete', function(playerId, deliveryCount, distance)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local payout = distance * Config.BasePayoutPerDistance + (deliveryCount * Config.BonusPayout)
        
        -- Add bonus for completing a series of 4 deliveries
        if deliveryCount % 4 == 0 then
            payout = payout + Config.SeriesBonus
        end
        
        -- Add money to player's account using QS-banking
        exports['qs-banking']:AddMoney(Player.PlayerData.citizenid, payout, 'Cargo Delivery Payment')
        
        -- Log the delivery in the database
        MySQL.Async.execute('INSERT INTO cargo_deliveries (player_id, deliveries, distance) VALUES (?, ?, ?)', {Player.PlayerData.citizenid, deliveryCount, distance}, function(rowsChanged)
            if rowsChanged > 0 then
                print("Delivery logged successfully for player: " .. Player.PlayerData.citizenid)
            else
                print("Failed to log delivery for player: " .. Player.PlayerData.citizenid)
            end
        end)
    else
        print("Player not found for source: " .. src)
    end
end)

RegisterNetEvent('cargo:startDelivery', function(route)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        -- Notify the client to spawn the boat and pallet
        TriggerClientEvent('cargo:spawnBoatAndPallet', src, route)
    else
        print("Player not found for source: " .. src)
    end
end)

-- ...existing code...
