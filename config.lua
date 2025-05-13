Config = {}

-- Payment settings
Config.BasePayoutPerDistance = 10 -- Base payout per distance unit
Config.BonusPayout = 500 -- Bonus payout for every additional delivery in a row
Config.SeriesBonus = 2000 -- Bonus payout for completing a series of 4 deliveries
Config.JobStartCost = 0 -- Cost to start a delivery job, set to 0 for free jobs

-- Define the ports and locations (updated with more realistic water locations)
Config.Ports = {
    {name = "Los Santos Marina", coords = vector3(-802.0, -1496.0, 0.0)},
    {name = "Paleto Bay Pier", coords = vector3(-275.0, 6635.0, 0.0)},
    {name = "Vespucci Beach", coords = vector3(-1599.0, -1097.0, 0.0)},
    {name = "NOOSE Facility", coords = vector3(3857.0, 4458.0, 0.0)}
}

-- Define the boats that can be used for deliveries
Config.Boats = {
    {label = "Dinghy", model = "dinghy"},
    {label = "Jetmax", model = "jetmax"},
    {label = "Marquis", model = "marquis"},
    {label = "Toro", model = "toro"}
}

-- Forklift settings
Config.ForkliftModel = "forklift" -- Model name for the forklift
Config.ForkliftSpawnDistance = 20 -- Maximum distance to spawn forklift from player

-- Time settings (in milliseconds)
Config.PickupTimer = 15 * 60 * 1000 -- 15 minutes to pick up the pallet
Config.DeliveryTimer = 15 * 60 * 1000 -- 15 minutes to deliver the pallet

-- Proximity settings
Config.PalletProximity = 7.0 -- How close the pallet needs to be to the boat to be considered delivered
Config.ForkliftReturnProximity = 5.0 -- How close the forklift needs to be to its spawn point to be considered returned
Config.DeliverySiteProximity = 5.0 -- How close the player needs to be to the delivery site to deliver

-- Banking system compatibility
Config.UseBankingSystem = true -- Set to false to use basic QBCore money functions

-- Debug settings
Config.Debug = false -- Set to true to enable debug prints
