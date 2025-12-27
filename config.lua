Config = {}

-- =============================================================================
-- PROGRESSION SYSTEM
-- =============================================================================

-- XP Settings
Config.XPPerDelivery = 100           -- Base XP per delivery
Config.XPPerDistance = 0.5           -- Additional XP per distance unit
Config.XPBonusMultiplier = 1.5       -- Multiplier for bonus deliveries (series of 4)
Config.XPPenaltyFailed = 50          -- XP lost for failed/cancelled delivery

-- Level thresholds (cumulative XP required)
Config.Levels = {
    { level = 1,  xp = 0,      title = "Deckhand",           tier = 1 },
    { level = 2,  xp = 500,    title = "Sailor",             tier = 1 },
    { level = 3,  xp = 1500,   title = "Boatswain",          tier = 1 },
    { level = 4,  xp = 3000,   title = "Helmsman",           tier = 2 },
    { level = 5,  xp = 5000,   title = "Navigator",          tier = 2 },
    { level = 6,  xp = 8000,   title = "First Mate",         tier = 2 },
    { level = 7,  xp = 12000,  title = "Captain",            tier = 3 },
    { level = 8,  xp = 18000,  title = "Master Mariner",     tier = 3 },
    { level = 9,  xp = 25000,  title = "Fleet Admiral",      tier = 3 },
    { level = 10, xp = 35000,  title = "Legendary Captain",  tier = 3 },
}

-- =============================================================================
-- SHIP TIERS
-- =============================================================================

-- Tier 1: Coastal - Small boats for short, local deliveries
-- Tier 2: Regional - Medium vessels for trips across the coast
-- Tier 3: Long Haul - Larger ships for trans-oceanic routes

Config.ShipTiers = {
    [1] = {
        name = "Coastal",
        description = "Small boats for local harbor runs",
        minDistance = 500,
        maxDistance = 3000,
        payMultiplier = 1.0,
        fuelCapacity = 50,      -- Liters
        fuelConsumption = 0.5,  -- Liters per km
    },
    [2] = {
        name = "Regional",
        description = "Medium vessels for coastal voyages",
        minDistance = 2000,
        maxDistance = 6000,
        payMultiplier = 1.5,
        fuelCapacity = 150,
        fuelConsumption = 1.0,
        requiredLevel = 4,
    },
    [3] = {
        name = "Long Haul",
        description = "Large ships for ocean crossings",
        minDistance = 4000,
        maxDistance = 12000,
        payMultiplier = 2.5,
        fuelCapacity = 500,
        fuelConsumption = 2.0,
        requiredLevel = 7,
    },
}

-- =============================================================================
-- BOATS / SHIPS
-- =============================================================================

Config.Boats = {
    -- Tier 1: Coastal (levels 1-3)
    {
        label = "Dinghy",
        model = "dinghy",
        tier = 1,
        speed = 60,           -- Max speed in knots (for display)
        capacity = 1,         -- Number of cargo units
        handling = 1.0,       -- Handling multiplier (1.0 = normal)
        fuelEfficiency = 1.2, -- 20% more efficient
        description = "Basic inflatable boat. Light and agile.",
    },
    {
        label = "Suntrap",
        model = "suntrap",
        tier = 1,
        speed = 55,
        capacity = 1,
        handling = 1.1,
        fuelEfficiency = 1.0,
        description = "Small recreational boat. Good visibility.",
    },
    {
        label = "Speeder",
        model = "speeder",
        tier = 1,
        speed = 75,
        capacity = 1,
        handling = 0.9,
        fuelEfficiency = 0.8,
        description = "Fast speedboat. Burns fuel quickly.",
    },
    {
        label = "Seashark",
        model = "seashark",
        tier = 1,
        speed = 80,
        capacity = 1,
        handling = 0.85,
        fuelEfficiency = 0.7,
        description = "Personal watercraft. Very fast but unstable.",
    },

    -- Tier 2: Regional (levels 4-6)
    {
        label = "Jetmax",
        model = "jetmax",
        tier = 2,
        speed = 70,
        capacity = 2,
        handling = 0.95,
        fuelEfficiency = 0.9,
        requiredLevel = 4,
        description = "High-performance yacht. Fast and reliable.",
    },
    {
        label = "Tropic",
        model = "tropic",
        tier = 2,
        speed = 50,
        capacity = 3,
        handling = 1.0,
        fuelEfficiency = 1.1,
        requiredLevel = 4,
        description = "Pontoon boat with cargo space.",
    },
    {
        label = "Squalo",
        model = "squalo",
        tier = 2,
        speed = 65,
        capacity = 2,
        handling = 0.9,
        fuelEfficiency = 0.85,
        requiredLevel = 5,
        description = "Sport yacht. Balance of speed and capacity.",
    },
    {
        label = "Toro",
        model = "toro",
        tier = 2,
        speed = 60,
        capacity = 3,
        handling = 0.85,
        fuelEfficiency = 0.9,
        requiredLevel = 6,
        description = "Classic speedboat with large deck.",
    },

    -- Tier 3: Long Haul (levels 7+)
    {
        label = "Marquis",
        model = "marquis",
        tier = 3,
        speed = 45,
        capacity = 5,
        handling = 0.7,
        fuelEfficiency = 1.0,
        requiredLevel = 7,
        description = "Luxury yacht. Slow but massive cargo space.",
    },
    {
        label = "Tug",
        model = "tug",
        tier = 3,
        speed = 30,
        capacity = 8,
        handling = 0.5,
        fuelEfficiency = 0.6,
        requiredLevel = 8,
        description = "Industrial tugboat. Maximum cargo capacity.",
    },
}

-- =============================================================================
-- CARGO TYPES
-- =============================================================================

Config.CargoTypes = {
    {
        id = "standard",
        label = "Standard Cargo",
        description = "General goods, no special handling required",
        payMultiplier = 1.0,
        xpMultiplier = 1.0,
        weight = 1.0,          -- Affects handling
        fragile = false,
        illegal = false,
        perishable = false,
        minTier = 1,
    },
    {
        id = "electronics",
        label = "Electronics",
        description = "Fragile electronics - avoid rough waters",
        payMultiplier = 1.5,
        xpMultiplier = 1.3,
        weight = 0.8,
        fragile = true,         -- Damage on impact
        illegal = false,
        perishable = false,
        minTier = 1,
    },
    {
        id = "seafood",
        label = "Fresh Seafood",
        description = "Perishable goods - deliver quickly",
        payMultiplier = 1.4,
        xpMultiplier = 1.2,
        weight = 1.2,
        fragile = false,
        illegal = false,
        perishable = true,      -- Time limit reduced
        perishTime = 0.7,       -- 70% of normal time
        minTier = 1,
    },
    {
        id = "medical",
        label = "Medical Supplies",
        description = "Critical medical supplies - fragile and urgent",
        payMultiplier = 2.0,
        xpMultiplier = 1.8,
        weight = 0.6,
        fragile = true,
        illegal = false,
        perishable = true,
        perishTime = 0.8,
        minTier = 2,
    },
    {
        id = "contraband",
        label = "Unmarked Crates",
        description = "No questions asked - avoid authorities",
        payMultiplier = 3.0,
        xpMultiplier = 2.0,
        weight = 1.5,
        fragile = false,
        illegal = true,         -- Police risk
        perishable = false,
        minTier = 2,
        policeChance = 0.15,    -- 15% chance of police attention
    },
    {
        id = "weapons",
        label = "Military Hardware",
        description = "Heavy cargo, high risk, high reward",
        payMultiplier = 4.0,
        xpMultiplier = 2.5,
        weight = 2.5,           -- Severely affects handling
        fragile = false,
        illegal = true,
        perishable = false,
        minTier = 3,
        policeChance = 0.25,
    },
    {
        id = "luxury",
        label = "Luxury Goods",
        description = "Expensive items - handle with extreme care",
        payMultiplier = 2.5,
        xpMultiplier = 1.5,
        weight = 0.5,
        fragile = true,
        illegal = false,
        perishable = false,
        minTier = 3,
        damageMultiplier = 2.0, -- Lose more pay on damage
    },
    {
        id = "hazmat",
        label = "Hazardous Materials",
        description = "Toxic/explosive cargo - careful handling required",
        payMultiplier = 3.5,
        xpMultiplier = 2.0,
        weight = 1.8,
        fragile = true,
        illegal = false,
        perishable = false,
        minTier = 3,
        explosionRisk = true,   -- Can explode on heavy impact
    },
}

-- =============================================================================
-- WEATHER SYSTEM
-- =============================================================================

Config.WeatherEffects = {
    enabled = true,

    -- Weather types and their effects
    types = {
        {
            id = "clear",
            label = "Clear Skies",
            speedMultiplier = 1.0,
            visibilityMultiplier = 1.0,
            handlingMultiplier = 1.0,
            fuelMultiplier = 1.0,
            payBonus = 0,
        },
        {
            id = "cloudy",
            label = "Overcast",
            speedMultiplier = 1.0,
            visibilityMultiplier = 0.9,
            handlingMultiplier = 1.0,
            fuelMultiplier = 1.0,
            payBonus = 0,
        },
        {
            id = "rain",
            label = "Rain",
            speedMultiplier = 0.9,
            visibilityMultiplier = 0.7,
            handlingMultiplier = 0.85,
            fuelMultiplier = 1.1,
            payBonus = 0.1,     -- 10% bonus for bad weather
        },
        {
            id = "thunder",
            label = "Thunderstorm",
            speedMultiplier = 0.75,
            visibilityMultiplier = 0.5,
            handlingMultiplier = 0.7,
            fuelMultiplier = 1.3,
            payBonus = 0.25,    -- 25% bonus
        },
        {
            id = "fog",
            label = "Dense Fog",
            speedMultiplier = 0.85,
            visibilityMultiplier = 0.3,
            handlingMultiplier = 0.95,
            fuelMultiplier = 1.05,
            payBonus = 0.15,
        },
    },
}

-- =============================================================================
-- FUEL SYSTEM
-- =============================================================================

Config.FuelSystem = {
    enabled = true,
    startingFuel = 0.8,         -- Ships spawn with 80% fuel
    lowFuelWarning = 0.2,       -- Warning at 20%
    criticalFuelWarning = 0.1,  -- Critical at 10%

    -- Refuel locations (can add to ports)
    refuelCost = 3,             -- $ per liter

    -- Fuel stations at ports
    fuelStations = {
        { port = "Los Santos Marina", coords = vector3(-800.0, -1500.0, 0.5) },
        { port = "Elysian Island Docks", coords = vector3(-160.0, -2380.0, 0.5) },
        { port = "Paleto Bay Pier", coords = vector3(-280.0, 6630.0, 0.5) },
    },
}

-- =============================================================================
-- PAYMENT SETTINGS
-- =============================================================================

Config.BasePayoutPerDistance = 10   -- Base payout per distance unit
Config.BonusPayout = 500            -- Bonus payout for every additional delivery in a row
Config.SeriesBonus = 2000           -- Bonus payout for completing a series of 4 deliveries
Config.JobStartCost = 0             -- Cost to start a delivery job, set to 0 for free jobs

-- Damage penalty settings
Config.DamagePenalty = {
    enabled = true,
    maxPenalty = 0.5,               -- Maximum 50% pay reduction for damaged cargo
    thresholds = {
        { damage = 0.1, penalty = 0.05 },  -- 10% damage = 5% penalty
        { damage = 0.3, penalty = 0.15 },  -- 30% damage = 15% penalty
        { damage = 0.5, penalty = 0.30 },  -- 50% damage = 30% penalty
        { damage = 0.7, penalty = 0.50 },  -- 70%+ damage = 50% penalty
    },
}

-- =============================================================================
-- PORTS AND LOCATIONS
-- =============================================================================

Config.Ports = {
    { name = "Los Santos Marina",    coords = vector3(-802.0, -1496.0, 0.0),  tier = 1, hasFuel = true },
    { name = "Vespucci Beach",       coords = vector3(-1599.0, -1097.0, 0.0), tier = 1, hasFuel = false },
    { name = "Del Perro Pier",       coords = vector3(-1619.0, -1015.0, 0.0), tier = 1, hasFuel = false },
    { name = "Elysian Island Docks", coords = vector3(-163.0, -2378.0, 0.0),  tier = 2, hasFuel = true },
    { name = "Chumash Pier",         coords = vector3(-3426.0, 967.0, 0.0),   tier = 2, hasFuel = false },
    { name = "Galilee Marina",       coords = vector3(1299.0, 4216.0, 0.0),   tier = 2, hasFuel = false },
    { name = "Paleto Bay Pier",      coords = vector3(-275.0, 6635.0, 0.0),   tier = 3, hasFuel = true },
    { name = "NOOSE Facility",       coords = vector3(3857.0, 4458.0, 0.0),   tier = 3, hasFuel = false },
}

-- =============================================================================
-- ROUTE GENERATION
-- =============================================================================

Config.MinRouteDistance = 500.0     -- Minimum for tier 1
Config.MaxRouteDistance = 12000.0   -- Maximum for tier 3
Config.RouteOptions = 4             -- Number of route options to present

-- =============================================================================
-- FORKLIFT SETTINGS
-- =============================================================================

Config.ForkliftModel = "forklift"
Config.ForkliftSpawnDistance = 20

-- =============================================================================
-- TIME SETTINGS (milliseconds)
-- =============================================================================

Config.PickupTimer = 15 * 60 * 1000   -- 15 minutes to pick up the pallet
Config.DeliveryTimer = 15 * 60 * 1000 -- 15 minutes to deliver the pallet

-- =============================================================================
-- PROXIMITY SETTINGS
-- =============================================================================

Config.PalletProximity = 7.0
Config.ForkliftReturnProximity = 5.0
Config.DeliverySiteProximity = 5.0
Config.FuelStationProximity = 10.0

-- =============================================================================
-- INTEGRATION SETTINGS
-- =============================================================================

Config.UseBankingSystem = true

-- Police integration (for illegal cargo)
Config.PoliceIntegration = {
    enabled = true,
    alertPolice = true,           -- Send alerts to police
    minCops = 0,                  -- Minimum cops online for illegal cargo
    wantedLevel = 2,              -- Stars when caught
}

-- =============================================================================
-- FLEET OWNERSHIP (Future Feature)
-- =============================================================================

Config.FleetOwnership = {
    enabled = false,               -- Enable when ready
    maxShipsPerPlayer = 5,
    maintenanceCostPerDay = 500,  -- Per ship
    insuranceCostPercentage = 0.1, -- 10% of ship value
}

-- =============================================================================
-- DEBUG SETTINGS
-- =============================================================================

Config.Debug = false

-- =============================================================================
-- CUSTOM LOCATIONS (populated from database)
-- =============================================================================

Config.CustomLocations = {}
Config.AllLocations = {}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Get level info from XP
function Config.GetLevelFromXP(xp)
    local currentLevel = Config.Levels[1]
    for _, level in ipairs(Config.Levels) do
        if xp >= level.xp then
            currentLevel = level
        else
            break
        end
    end
    return currentLevel
end

-- Get unlocked tier from level
function Config.GetUnlockedTier(level)
    for i = #Config.Levels, 1, -1 do
        if level >= Config.Levels[i].level then
            return Config.Levels[i].tier
        end
    end
    return 1
end

-- Get boats available at tier
function Config.GetBoatsForTier(tier, level)
    local available = {}
    for _, boat in ipairs(Config.Boats) do
        if boat.tier <= tier then
            local requiredLevel = boat.requiredLevel or 1
            if level >= requiredLevel then
                table.insert(available, boat)
            end
        end
    end
    return available
end

-- Get cargo types available at tier
function Config.GetCargoForTier(tier)
    local available = {}
    for _, cargo in ipairs(Config.CargoTypes) do
        if cargo.minTier <= tier then
            table.insert(available, cargo)
        end
    end
    return available
end

-- Get XP for next level
function Config.GetXPForNextLevel(currentXP)
    for _, level in ipairs(Config.Levels) do
        if currentXP < level.xp then
            return level.xp
        end
    end
    return Config.Levels[#Config.Levels].xp -- Already max level
end

-- Calculate XP progress percentage
function Config.GetXPProgress(currentXP)
    local currentLevel = Config.GetLevelFromXP(currentXP)
    local nextLevelXP = Config.GetXPForNextLevel(currentXP)

    if currentLevel.level >= #Config.Levels then
        return 100 -- Max level
    end

    local previousXP = currentLevel.xp
    local xpInLevel = currentXP - previousXP
    local xpNeeded = nextLevelXP - previousXP

    return math.floor((xpInLevel / xpNeeded) * 100)
end
