Config = {}

Config.BasePayoutPerDistance = 10 -- Base payout per distance unit
Config.BonusPayout = 500 -- Bonus payout for every additional delivery in a row
Config.SeriesBonus = 2000 -- Bonus payout for completing a series of 4 deliveries

-- Define the ports and locations
Config.Ports = {
    {name = "Los Santos", coords = vector3(-1600.0, 5260.0, 0.0)},
    {name = "Paleto Bay", coords = vector3(-1500.0, 5300.0, 0.0)},
    {name = "Vespucci", coords = vector3(-1700.0, 5200.0, 0.0)},
    {name = "Cayo Perico", coords = vector3(-1800.0, 5400.0, 0.0)}
}

-- Define the boats that can be used for deliveries
Config.Boats = {
    {label = "Dinghy", model = "dinghy"},
    {label = "Jetmax", model = "jetmax"},
    {label = "Marquis", model = "marquis"},
    {label = "Toro", model = "toro"}
}
