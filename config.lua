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
        label = "Coastal",
        model = "costal",
        tier = 1,
        speed = 65,
        capacity = 2,
        handling = 1.0,
        fuelEfficiency = 1.0,
        description = "Standard coastal fishing boat. Reliable and steady.",
        price = 35000,
        insurance = 1750,
        maintenance = 250,
    },
    {
        label = "Coastal II Premium",
        model = "costal2",
        tier = 2,
        speed = 85,
        capacity = 6,
        handling = 0.85,
        fuelEfficiency = 0.75,
        requiredLevel = 5,
        description = "Premium cargo vessel. Massive hold, powerful engine, built for serious haulers.",
        price = 450000,
        insurance = 22500,
        maintenance = 3000,
    },
    {
        label = "Dinghy",
        model = "dinghy",
        tier = 1,
        speed = 60,
        capacity = 1,
        handling = 1.0,
        fuelEfficiency = 1.2,
        description = "Basic inflatable boat. Light and agile.",
        price = 15000,
        insurance = 750,
        maintenance = 100,
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
        price = 25000,
        insurance = 1250,
        maintenance = 175,
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
        price = 55000,
        insurance = 2750,
        maintenance = 400,
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
        price = 40000,
        insurance = 2000,
        maintenance = 300,
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
        price = 225000,
        insurance = 11250,
        maintenance = 1500,
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
        price = 150000,
        insurance = 7500,
        maintenance = 1000,
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
        price = 285000,
        insurance = 14250,
        maintenance = 2000,
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
        price = 375000,
        insurance = 18750,
        maintenance = 2500,
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
        price = 1500000,
        insurance = 75000,
        maintenance = 10000,
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
        price = 2250000,
        insurance = 112500,
        maintenance = 15000,
    },
    {
        label = "Urchin II Mega Freighter",
        model = "urchin",
        tier = 3,
        speed = 20,
        capacity = 16,
        handling = 0.3,
        fuelEfficiency = 0.4,
        requiredLevel = 10,
        description = "Massive ocean freighter. The ultimate cargo hauler for legendary captains. Slow but unmatched capacity.",
        price = 5000000,
        insurance = 250000,
        maintenance = 35000,
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

    -- Dynamic risk based on police count (DPSRP optimization)
    dynamicRisk = true,           -- Adjust risk based on online police
    noCopsAlternative = true,     -- If no cops online, spawn NPC Coast Guard instead
    riskPerCop = 0.02,            -- +2% police chance per online cop (max from policeChance)
    maxRiskMultiplier = 2.0,      -- Maximum 2x the base policeChance
}

-- =============================================================================
-- FLEET OWNERSHIP
-- =============================================================================

Config.FleetOwnership = {
    enabled = true,
    maxShipsPerPlayer = 5,
    sellBackPercent = 0.6,         -- Get 60% back when selling (adjust for hardcore economy: 0.4-0.5)
    insurancePayoutPercent = 0.8,  -- 80% of value on insurance claim
    maintenanceInterval = 24,      -- Hours between maintenance charges
    repairCostMultiplier = 0.1,    -- 10% of boat price for full repair
}

-- =============================================================================
-- STARTER BOAT (Free boat for new players)
-- =============================================================================

Config.StarterBoat = {
    enabled = true,
    model = "dinghy",              -- Free starter boat model
    name = "Starter Dinghy",       -- Display name
    canSell = false,               -- Can't sell the starter boat
    canTrade = false,              -- Can't trade the starter boat
    autoGrant = true,              -- Automatically grant on first job attempt
    message = "Welcome to Ocean Delivery! Here's your free starter boat to get you started.",
}

-- =============================================================================
-- FINANCING / PAYMENT PLANS
-- =============================================================================

Config.Financing = {
    enabled = true,
    downPaymentPercent = 0.20,     -- 20% down payment required
    interestRate = 0.15,           -- 15% interest on financed amount
    maxLoanWeeks = 8,              -- Maximum 8 weekly payments
    minLoanWeeks = 2,              -- Minimum 2 weekly payments
    missedPaymentPenalty = 0.10,   -- 10% penalty on missed payment
    maxMissedPayments = 2,         -- Repo after 2 missed payments
    paymentDay = 1,                -- Day of week (1 = Monday)

    -- Loan terms available
    terms = {
        { weeks = 2, interestMult = 0.8 },   -- 2 weeks = lower interest
        { weeks = 4, interestMult = 1.0 },   -- 4 weeks = standard
        { weeks = 6, interestMult = 1.15 },  -- 6 weeks = higher interest
        { weeks = 8, interestMult = 1.30 },  -- 8 weeks = highest interest
    }
}

-- =============================================================================
-- RANDOM ENCOUNTERS
-- =============================================================================

Config.RandomEncounters = {
    enabled = true,
    checkInterval = 60000,         -- Check every 60 seconds (optimized for performance)
    minDistanceFromPort = 500,     -- Don't spawn encounters near ports
    entityCullDistance = 200.0,    -- Auto-delete encounter entities beyond this distance

    -- Encounter types
    encounters = {
        {
            id = "pirates",
            label = "Pirates",
            description = "Hostile boats trying to steal your cargo",
            chance = 0.05,          -- 5% chance per check
            minTier = 2,            -- Only for tier 2+ routes
            illegalCargoBonus = 0.1, -- +10% chance with illegal cargo
            reward = 0,             -- No bonus reward (you're defending)
            xpBonus = 50,           -- Bonus XP for surviving
            vehicleModel = "dinghy",
            pedModel = "g_m_y_ballasout_01",
            attackerCount = 2,
            weapons = {"WEAPON_PISTOL", "WEAPON_MICROSMG"},
        },
        {
            id = "coastguard",
            label = "Coast Guard",
            description = "Patrol checking for illegal cargo",
            chance = 0.03,          -- 3% base chance
            minTier = 1,
            illegalCargoBonus = 0.15, -- +15% chance with illegal cargo
            reward = 0,
            xpBonus = 0,
            vehicleModel = "predator",
            pedModel = "s_m_y_uscg_01",
            attackerCount = 2,
            searchTime = 15000,     -- 15 seconds to search
            escapeDistance = 500,   -- Distance to escape
        },
        {
            id = "distress",
            label = "Distress Signal",
            description = "Someone needs rescue",
            chance = 0.04,          -- 4% chance
            minTier = 1,
            illegalCargoBonus = 0,
            reward = 2500,          -- Bonus for helping
            xpBonus = 100,
            rescueTime = 30000,     -- 30 seconds to rescue
            pedModel = "a_m_y_beach_01",
        },
        {
            id = "smuggler",
            label = "Fellow Smuggler",
            description = "Another smuggler offers a deal",
            chance = 0.02,          -- 2% chance
            minTier = 2,
            illegalCargoBonus = 0.1,
            reward = 5000,          -- Potential bonus
            xpBonus = 75,
            vehicleModel = "speeder",
            dealTypes = {"escort", "swap", "info"},
        },
    },
}

-- =============================================================================
-- REFUELING SYSTEM
-- =============================================================================

Config.Refueling = {
    enabled = true,
    costPerLiter = 3,              -- $ per liter
    refuelSpeed = 5,               -- Liters per second
    maxDistance = 15.0,            -- Max distance from fuel pump

    -- DPSRP 1.5: Using qs-fuelstations (provides LegacyFuel compatibility)
    -- Boats use internal fuel system - qs-fuelstations handles land vehicles
    externalFuelScript = 'none',   -- Keep 'none' for boats (separate from car fuel)
    useExternalFuelOnly = false,   -- Boats have their own fuel economy

    -- Fuel station markers (blips)
    showBlips = true,
    blipSprite = 361,              -- Fuel pump
    blipColor = 2,                 -- Green
    blipScale = 0.8,

    -- Fuel station locations (coords on water near docks)
    stations = {
        {
            name = "Los Santos Marina Fuel",
            coords = vector3(-795.0, -1510.0, 0.5),
            heading = 45.0,
        },
        {
            name = "Elysian Island Fuel Dock",
            coords = vector3(-175.0, -2395.0, 0.5),
            heading = 180.0,
        },
        {
            name = "Paleto Bay Fuel Station",
            coords = vector3(-285.0, 6645.0, 0.5),
            heading = 0.0,
        },
        {
            name = "Vespucci Canals Fuel",
            coords = vector3(-1095.0, -1620.0, 0.5),
            heading = 90.0,
        },
    },
}

-- =============================================================================
-- PHONE APP INTEGRATION
-- =============================================================================

Config.PhoneApp = {
    enabled = true,
    appName = "Ocean Delivery",
    appIcon = "anchor",            -- Font Awesome icon

    -- Supported phone resources
    supportedPhones = {
        "lb-phone",
        "qs-smartphone",
        "npwd",
    },

    -- App features
    features = {
        startJob = true,           -- Start delivery from phone
        viewStats = true,          -- View player stats
        manageFleet = true,        -- Manage owned boats
        viewHistory = true,        -- View delivery history
        checkWeather = true,       -- Check current weather bonus
        findFuel = true,           -- Show nearest fuel station
    },

    -- Notification settings
    notifications = {
        jobComplete = true,
        levelUp = true,
        encounterWarning = true,
        lowFuel = true,
        maintenanceDue = true,
    },
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

-- Get boat data by model name
function Config.GetBoatByModel(model)
    for _, boat in ipairs(Config.Boats) do
        if boat.model == model then
            return boat
        end
    end
    return nil
end

-- Get encounter by ID
function Config.GetEncounterById(id)
    for _, encounter in ipairs(Config.RandomEncounters.encounters) do
        if encounter.id == id then
            return encounter
        end
    end
    return nil
end

-- Get nearest fuel station
function Config.GetNearestFuelStation(coords)
    local nearest = nil
    local nearestDist = math.huge

    for _, station in ipairs(Config.Refueling.stations) do
        local dist = #(coords - station.coords)
        if dist < nearestDist then
            nearest = station
            nearestDist = dist
        end
    end

    return nearest, nearestDist
end
