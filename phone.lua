-- =============================================================================
-- OCEAN DELIVERY - PHONE APP INTEGRATION
-- Supports: lb-phone, qs-smartphone, npwd
-- =============================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local lib = exports['ox_lib']:GetLibObject()

local phoneResource = nil

-- Detect which phone resource is running
CreateThread(function()
    Wait(1000)

    if not Config.PhoneApp.enabled then
        return
    end

    for _, phone in ipairs(Config.PhoneApp.supportedPhones) do
        if GetResourceState(phone) == 'started' then
            phoneResource = phone
            print("[Ocean Delivery] Phone integration enabled: " .. phone)
            break
        end
    end

    if not phoneResource then
        print("[Ocean Delivery] No supported phone resource found")
        return
    end

    -- Register app based on phone type
    if phoneResource == 'lb-phone' then
        RegisterLBPhoneApp()
    elseif phoneResource == 'qs-smartphone' then
        RegisterQSPhoneApp()
    elseif phoneResource == 'npwd' then
        RegisterNPWDApp()
    end
end)

-- =============================================================================
-- LB-PHONE INTEGRATION
-- =============================================================================

function RegisterLBPhoneApp()
    -- Register the app with lb-phone
    exports['lb-phone']:AddCustomApp({
        identifier = 'ocean-delivery',
        name = Config.PhoneApp.appName,
        description = 'Ocean cargo delivery job',
        icon = 'https://cdn-icons-png.flaticon.com/512/870/870143.png',
        ui = GetCurrentResourceName() .. '/phone/lb-phone.html',
        fixBlur = true,
    })

    -- Handle app data requests
    RegisterNUICallback('ocean:getAppData', function(data, cb)
        QBCore.Functions.TriggerCallback('cargo:getPlayerStats', function(stats)
            QBCore.Functions.TriggerCallback('cargo:getPlayerFleet', function(fleet)
                cb({
                    stats = stats,
                    fleet = fleet,
                    weather = getCurrentWeatherData(),
                    fuelStations = Config.Refueling.stations
                })
            end)
        end)
    end)

    RegisterNUICallback('ocean:startJob', function(data, cb)
        TriggerEvent('cargo:startDelivery')
        cb({ success = true })
    end)

    RegisterNUICallback('ocean:viewFleet', function(data, cb)
        -- This triggers the in-game fleet menu
        TriggerEvent('ocean:openFleetMenu')
        cb({ success = true })
    end)
end

function getCurrentWeatherData()
    local weather = getCurrentWeather and getCurrentWeather() or { id = 'clear', label = 'Clear', payBonus = 0 }
    return weather
end

-- =============================================================================
-- QS-SMARTPHONE INTEGRATION
-- =============================================================================

function RegisterQSPhoneApp()
    -- qs-smartphone uses a different registration method
    exports['qs-smartphone']:AddCustomApp({
        app = 'ocean-delivery',
        name = Config.PhoneApp.appName,
        icon = 'fa-solid fa-anchor',
        color = '#1e88e5',
        onOpen = function()
            ShowQSPhoneMenu()
        end
    })
end

function ShowQSPhoneMenu()
    QBCore.Functions.TriggerCallback('cargo:getPlayerStats', function(stats)
        if not stats then
            exports['qs-smartphone']:ShowNotification('Ocean Delivery', 'Failed to load data', 'error')
            return
        end

        local menu = {
            {
                header = Config.PhoneApp.appName,
                isMenuHeader = true
            },
            {
                header = 'My Stats',
                txt = string.format('Level %d %s | %d XP', stats.level, stats.title, stats.xp),
                params = {
                    event = 'ocean:showStats'
                }
            },
            {
                header = 'Start Delivery',
                txt = 'Begin a new cargo delivery job',
                params = {
                    event = 'cargo:startDelivery'
                }
            },
            {
                header = 'My Fleet',
                txt = 'Manage your boats',
                params = {
                    event = 'ocean:openFleetMenu'
                }
            },
            {
                header = 'Weather',
                txt = getCurrentWeatherData().label .. ' (' .. (getCurrentWeatherData().payBonus * 100) .. '% bonus)',
                params = {}
            },
            {
                header = 'Find Fuel',
                txt = 'Locate nearest fuel station',
                params = {
                    event = 'ocean:findFuel'
                }
            },
        }

        exports['qs-smartphone']:OpenMenu(menu)
    end)
end

-- =============================================================================
-- NPWD INTEGRATION
-- =============================================================================

function RegisterNPWDApp()
    -- NPWD uses exports for app registration
    if exports['npwd'] then
        exports['npwd']:registerExternalApp({
            id = 'ocean-delivery',
            nameLocale = Config.PhoneApp.appName,
            icon = 'Anchor',
            backgroundColor = '#1e88e5',
            color = '#ffffff',
            path = '/ocean-delivery',
        })
    end
end

-- =============================================================================
-- SHARED EVENTS
-- =============================================================================

RegisterNetEvent('ocean:openFleetMenu', function()
    -- Trigger the fleet management UI
    ExecuteCommand('fleet')
end)

RegisterNetEvent('ocean:showStats', function()
    ExecuteCommand('deliverystats')
end)

RegisterNetEvent('ocean:findFuel', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local nearest, distance = Config.GetNearestFuelStation(playerCoords)

    if nearest then
        SetNewWaypoint(nearest.coords.x, nearest.coords.y)
        lib.notify({
            title = 'Fuel Station Found',
            description = nearest.name .. ' - ' .. math.floor(distance) .. 'm away',
            type = 'success'
        })
    else
        lib.notify({
            title = 'No Stations',
            description = 'No fuel stations found',
            type = 'error'
        })
    end
end)

-- =============================================================================
-- PHONE NOTIFICATIONS
-- =============================================================================

function SendPhoneNotification(title, message, icon)
    if not phoneResource or not Config.PhoneApp.enabled then return end

    if phoneResource == 'lb-phone' then
        exports['lb-phone']:SendNotification({
            app = 'ocean-delivery',
            title = title,
            content = message,
        })
    elseif phoneResource == 'qs-smartphone' then
        exports['qs-smartphone']:ShowNotification(title, message, 'info')
    elseif phoneResource == 'npwd' then
        exports['npwd']:createNotification({
            notisId = 'ocean-delivery',
            appId = 'ocean-delivery',
            content = message,
            secondaryTitle = title,
            keepOpen = false,
            duration = 5000,
        })
    end
end

-- Hook into existing events to send phone notifications
if Config.PhoneApp.notifications.jobComplete then
    RegisterNetEvent('cargo:deliveryPayout', function(data)
        SendPhoneNotification('Delivery Complete', '$' .. data.payout .. ' earned!', 'check')
    end)
end

if Config.PhoneApp.notifications.levelUp then
    RegisterNetEvent('cargo:levelUp', function(data)
        SendPhoneNotification('Level Up!', 'You are now Level ' .. data.newLevel .. ' - ' .. data.title, 'star')
    end)
end

if Config.PhoneApp.notifications.lowFuel then
    -- This is handled in the main client.lua fuel system
end

-- =============================================================================
-- EXPORTS FOR OTHER RESOURCES
-- =============================================================================

exports('GetPlayerStats', function()
    local stats = nil
    QBCore.Functions.TriggerCallback('cargo:getPlayerStats', function(data)
        stats = data
    end)
    Wait(500)
    return stats
end)

exports('GetPlayerFleet', function()
    local fleet = nil
    QBCore.Functions.TriggerCallback('cargo:getPlayerFleet', function(data)
        fleet = data
    end)
    Wait(500)
    return fleet
end)

exports('IsOnDeliveryJob', function()
    return isOnJob
end)
