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
        label = "Coastal Ship",
        model = "costal",
        tier = 1,
        speed = 65,
        capacity = 2,
        handling = 1.0,
        fuelEfficiency = 1.0,
        description = "Standard coastal fishing ship. Reliable and steady.",
        price = 35000,
        insurance = 1750,
        maintenance = 250,
    },
    {
        label = "Coastal II Premium Ship",
        model = "costal2",
        tier = 2,
        speed = 85,
        capacity = 6,
        handling = 0.85,
        fuelEfficiency = 0.75,
        requiredLevel = 5,
        description = "Premium cargo ship. Massive hold, powerful engine, built for serious haulers.",
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
        description = "Luxury yacht. Slow but massive cargo space. Excellent stability.",
        price = 1500000,
        insurance = 75000,
        maintenance = 10000,
        stability = 0.85,           -- 85% reduced explosion risk for hazmat
        hazmatBonus = true,         -- Recommended for hazmat cargo
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
        description = "Industrial tugboat. Maximum cargo capacity. Built for hazardous cargo.",
        price = 2250000,
        insurance = 112500,
        maintenance = 15000,
        stability = 0.95,           -- 95% reduced explosion risk - best for hazmat
        hazmatBonus = true,
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
        description = "Massive ocean freighter. The ultimate cargo hauler. Maximum stability for any cargo.",
        price = 5000000,
        stability = 0.98,           -- 98% reduced explosion risk - safest ship
        hazmatBonus = true,
        insurance = 250000,
        maintenance = 35000,
    },
}

-- =============================================================================
-- BOAT STABILITY SYSTEM (Hazmat/Explosive cargo)
-- =============================================================================

Config.StabilitySystem = {
    enabled = true,

    -- Base explosion chance during rough weather (per delivery)
    baseExplosionChance = 0.15,     -- 15% base chance with explosionRisk cargo

    -- Weather modifiers for explosion risk
    weatherRisk = {
        clear = 0.0,                -- No extra risk
        cloudy = 0.0,
        rain = 0.05,                -- +5% in rain
        thunder = 0.20,             -- +20% in thunderstorm
        fog = 0.02,                 -- +2% in fog (reduced visibility)
    },

    -- Damage modifiers
    damageThreshold = 0.3,          -- If boat takes 30%+ damage, risk increases
    damageRiskBonus = 0.10,         -- +10% risk if above threshold

    -- Stability bonus payouts (for hazmat-rated boats)
    hazmatPayBonus = 1.10,          -- 10% bonus for using hazmat-rated boat
    hazmatXPBonus = 1.15,           -- 15% XP bonus
}

-- =============================================================================
-- DAILY MAINTENANCE COSTS (Money sink)
-- =============================================================================

Config.MaintenanceSystem = {
    enabled = true,
    checkInterval = 24,             -- Hours between maintenance checks
    graceDeliveries = 3,            -- Free deliveries before maintenance kicks in

    -- Maintenance cost multipliers based on usage
    perDeliveryWear = 0.02,         -- 2% condition loss per delivery
    weatherWearBonus = 0.01,        -- +1% extra wear in bad weather

    -- Repair cost calculation
    repairCostBase = 0.10,          -- 10% of boat price for full repair
    emergencyRepairMultiplier = 1.5, -- 50% more if boat breaks down mid-delivery

    -- Consequences for neglected maintenance
    breakdownChance = 0.05,         -- 5% breakdown chance if condition < 25%
    seizureThreshold = 0.10,        -- Coast guard can seize boats below 10% condition
}

-- =============================================================================
-- ENVIRONMENTAL HAZARDS (Weather affects fragile cargo)
-- =============================================================================

Config.EnvironmentalHazards = {
    enabled = true,

    -- Weather-based damage multipliers for fragile cargo
    -- These multiply the base damageMultiplier on fragile cargo
    weatherDamageMultipliers = {
        clear = 1.0,                -- Normal damage
        cloudy = 1.0,               -- Normal damage
        rain = 1.3,                 -- 30% more damage to fragile cargo
        thunder = 2.0,              -- DOUBLE damage in thunderstorms
        fog = 1.2,                  -- 20% more (reduced visibility = accidents)
    },

    -- Handling penalties in bad weather (stacks with cargo weight)
    weatherHandlingPenalty = {
        clear = 1.0,
        cloudy = 1.0,
        rain = 0.9,                 -- 10% worse handling
        thunder = 0.7,              -- 30% worse handling
        fog = 0.85,                 -- 15% worse handling
    },

    -- Passive damage accumulation (fragile cargo takes damage over time in bad weather)
    passiveDamageEnabled = true,
    passiveDamageInterval = 30,     -- Check every 30 seconds
    passiveDamageRates = {
        clear = 0.0,
        cloudy = 0.0,
        rain = 0.01,                -- 1% damage per interval in rain
        thunder = 0.03,             -- 3% damage per interval in storms
        fog = 0.005,                -- 0.5% damage per interval in fog
    },
}

-- =============================================================================
-- DYNAMIC PAYOUT SYSTEM (Distance-based rewards)
-- =============================================================================

Config.DynamicPayouts = {
    enabled = true,

    -- Base payout per meter traveled
    payPerMeter = 0.015,            -- $0.015 per meter = $15 per km

    -- Distance tier bonuses (reward longer routes)
    distanceTiers = {
        { minDistance = 0,     multiplier = 1.0 },      -- 0-2km: standard
        { minDistance = 2000,  multiplier = 1.1 },      -- 2-5km: 10% bonus
        { minDistance = 5000,  multiplier = 1.25 },     -- 5-10km: 25% bonus
        { minDistance = 10000, multiplier = 1.5 },      -- 10-20km: 50% bonus (Cayo runs)
        { minDistance = 20000, multiplier = 2.0 },      -- 20km+: DOUBLE payout
    },

    -- International route bonus (Cayo Perico)
    internationalBonus = 1.25,      -- 25% bonus for crossing to Cayo

    -- Risk-adjusted payouts
    riskPayouts = {
        safeHarbor = 1.15,          -- 15% bonus for delivering to gang territory
        illegalCargo = 1.20,        -- 20% bonus for illegal deliveries
        badWeather = 1.10,          -- 10% bonus for completing in bad weather
        nightDelivery = 1.05,       -- 5% bonus for night runs (20:00-06:00)
    },
}

-- =============================================================================
-- HEAVY LOAD PHYSICS
-- =============================================================================

Config.HeavyLoadPhysics = {
    enabled = true,

    -- Speed reduction for heavy cargo
    defaultSpeedMult = 1.0,         -- Normal speed
    heavyLoadSpeedMult = 0.8,       -- 80% speed for generic heavy loads

    -- Handling reduction for heavy cargo
    defaultHandlingMult = 1.0,
    heavyLoadHandlingMult = 0.85,   -- 85% handling for heavy loads

    -- Acceleration penalty
    heavyLoadAccelMult = 0.7,       -- 70% acceleration with heavy cargo

    -- Fuel consumption increase
    heavyLoadFuelMult = 1.3,        -- 30% more fuel consumption

    -- Cargo-specific overrides (use cargo's heavyLoadSpeedMult if defined)
    useCargoOverrides = true,
}

-- =============================================================================
-- MULTI-CREW SYSTEM
-- =============================================================================

Config.MultiCrew = {
    enabled = true,

    -- Crew size limits by boat capacity
    useBoatCapacity = true,         -- Use boat's capacity stat for max crew
    maxCrewOverride = 4,            -- Hard limit if not using boat capacity

    -- XP sharing
    xpShareEnabled = true,
    captainXPShare = 1.0,           -- Captain gets 100% XP
    crewXPShare = 0.75,             -- Crew members get 75% XP
    bonusPerCrewMember = 0.05,      -- +5% XP per crew member (teamwork bonus)

    -- Payout sharing
    payoutShareEnabled = true,
    captainPayShare = 0.50,         -- Captain gets 50% of payout
    crewPayShare = 0.50,            -- Remaining 50% split among crew
    equalSplit = false,             -- If true, everyone gets equal share

    -- Crew bonuses
    pirateDefenseBonus = 0.15,      -- +15% chance to escape pirates per crew member
    speedBonusPerCrew = 0.02,       -- +2% speed per crew (more hands on deck)
    maxSpeedBonus = 0.10,           -- Cap at +10% speed bonus

    -- Recruitment
    inviteRadius = 50.0,            -- How close to invite crew
    inviteTimeout = 30,             -- Seconds to accept invite
    canInviteMidJob = false,        -- Allow inviting crew after job starts

    -- Crew roles (future expansion)
    roles = {
        captain = { payMult = 1.2, xpMult = 1.0 },
        navigator = { payMult = 1.0, xpMult = 1.1 },
        gunner = { payMult = 1.0, xpMult = 1.0, pirateDefense = 0.25 },
        deckhand = { payMult = 0.9, xpMult = 0.9 },
    },
}

-- =============================================================================
-- DYNAMIC MARKET SYSTEM (Supply/Demand)
-- =============================================================================

Config.DynamicMarket = {
    enabled = true,

    -- Market update frequency
    updateInterval = 30,            -- Minutes between market updates
    priceMemory = 60,               -- Minutes to remember delivery history

    -- Price fluctuation ranges
    minMultiplier = 0.7,            -- Minimum 70% of base price (oversupply)
    maxMultiplier = 1.5,            -- Maximum 150% of base price (high demand)

    -- Supply impact (more deliveries = lower price)
    deliveriesForOversupply = 10,   -- This many deliveries = oversupply
    oversupplyDecay = 0.1,          -- 10% price drop per delivery over threshold

    -- Demand spikes (random high-demand events)
    demandSpikeEnabled = true,
    demandSpikeChance = 0.10,       -- 10% chance per update
    demandSpikeMult = 1.35,         -- 35% bonus during spike
    demandSpikeDuration = 15,       -- Minutes

    -- Cargo-specific demand modifiers
    cargoBaseDemand = {
        seafood = 1.1,              -- Always slightly higher demand
        restaurant_supplies = 1.0,
        boutique_clothing = 0.9,    -- Niche market
        vehicle_parts = 1.0,
        yacht_provisions = 0.85,    -- Luxury = limited market
        nightclub_supplies = 1.15,  -- Party city always needs supplies
    },

    -- Time-of-day demand (server time)
    timeOfDayDemand = {
        { start = 6, stop = 12, cargo = "restaurant_supplies", mult = 1.2 },  -- Morning deliveries
        { start = 18, stop = 23, cargo = "nightclub_supplies", mult = 1.3 }, -- Evening club rush
        { start = 20, stop = 4, cargo = "contraband", mult = 1.25 },         -- Night smuggling
    },

    -- Display market prices to players
    showMarketPrices = true,
    marketRefreshCost = 500,        -- Cost to refresh market data
}

-- =============================================================================
-- VISUAL CARGO SYSTEM (Props on boats)
-- =============================================================================

Config.VisualCargo = {
    enabled = true,

    -- Prop attachment settings
    attachToBoat = true,
    scaleByWeight = true,           -- Heavier cargo = larger props
    maxProps = 6,                   -- Maximum props per boat

    -- Boat-specific attachment points (local offsets from boat center)
    boatAttachPoints = {
        dinghy = {
            { offset = vector3(0.0, -0.5, 0.3), rotation = vector3(0, 0, 0) },
        },
        costal = {
            { offset = vector3(0.0, -1.5, 1.0), rotation = vector3(0, 0, 0) },
            { offset = vector3(0.0, -2.5, 1.0), rotation = vector3(0, 0, 0) },
        },
        costal2 = {
            { offset = vector3(0.0, -2.0, 1.5), rotation = vector3(0, 0, 0) },
            { offset = vector3(1.2, -2.0, 1.5), rotation = vector3(0, 0, 0) },
            { offset = vector3(-1.2, -2.0, 1.5), rotation = vector3(0, 0, 0) },
            { offset = vector3(0.0, -4.0, 1.5), rotation = vector3(0, 0, 0) },
            { offset = vector3(1.2, -4.0, 1.5), rotation = vector3(0, 0, 0) },
            { offset = vector3(-1.2, -4.0, 1.5), rotation = vector3(0, 0, 0) },
        },
        speeder = {
            { offset = vector3(0.0, -1.0, 0.4), rotation = vector3(0, 0, 0) },
            { offset = vector3(0.0, -1.8, 0.4), rotation = vector3(0, 0, 0) },
        },
        marquis = {
            { offset = vector3(0.0, -2.0, 1.2), rotation = vector3(0, 0, 0) },
            { offset = vector3(1.0, -2.0, 1.2), rotation = vector3(0, 0, 0) },
            { offset = vector3(-1.0, -2.0, 1.2), rotation = vector3(0, 0, 0) },
            { offset = vector3(0.0, -4.0, 1.2), rotation = vector3(0, 0, 0) },
        },
        tug = {
            { offset = vector3(0.0, -5.0, 2.5), rotation = vector3(0, 0, 0) },
            { offset = vector3(2.0, -5.0, 2.5), rotation = vector3(0, 0, 0) },
            { offset = vector3(-2.0, -5.0, 2.5), rotation = vector3(0, 0, 0) },
            { offset = vector3(0.0, -8.0, 2.5), rotation = vector3(0, 0, 0) },
            { offset = vector3(2.0, -8.0, 2.5), rotation = vector3(0, 0, 0) },
            { offset = vector3(-2.0, -8.0, 2.5), rotation = vector3(0, 0, 0) },
        },
    },

    -- Default attachment for unknown boats
    defaultAttachPoint = { offset = vector3(0.0, -1.5, 0.5), rotation = vector3(0, 0, 0) },

    -- Cargo-specific props
    cargoProps = {
        -- Standard cargo
        standard = { model = "prop_boxpile_07d", scale = 1.0 },
        electronics = { model = "prop_box_wood01a", scale = 0.8 },
        seafood = { model = "prop_fish_slice_01", scale = 1.2 },
        medical = { model = "prop_medcase_01", scale = 0.9 },

        -- Illegal cargo
        contraband = { model = "prop_box_wood04a", scale = 1.0 },
        weapons = { model = "prop_mil_crate_01", scale = 1.0 },      -- Military crate
        cocaine_raw = { model = "prop_drug_package", scale = 0.8 },
        weed_bales = { model = "prop_weed_01", scale = 1.5 },
        meth_precursors = { model = "prop_barrel_02a", scale = 1.0 }, -- Chemical barrel
        drug_shipment = { model = "prop_drug_package", scale = 1.0 },

        -- Weapons
        gun_parts = { model = "prop_box_guncase_01a", scale = 0.9 },
        pistol_crate = { model = "prop_box_ammo04a", scale = 1.0 },
        smg_crate = { model = "prop_box_ammo04a", scale = 1.1 },
        rifle_crate = { model = "prop_mil_crate_01", scale = 1.2 },
        ammo_crate = { model = "prop_box_ammo07a", scale = 1.0 },

        -- Business cargo
        restaurant_supplies = { model = "prop_food_cb_donuts", scale = 1.0 },
        boutique_clothing = { model = "prop_cs_cardbox_01", scale = 0.9 },
        vehicle_parts = { model = "prop_car_engine_01", scale = 1.2 },
        supercar_parts = { model = "prop_car_engine_01", scale = 1.4 },
        nightclub_supplies = { model = "prop_beer_box_01", scale = 1.0 },
        yacht_provisions = { model = "prop_foodwrap_01", scale = 0.8 },

        -- Hazmat
        hazmat = { model = "prop_barrel_02a", scale = 1.0, color = {255, 255, 0} }, -- Yellow barrel
        luxury = { model = "prop_ld_case_01", scale = 0.8 },
    },

    -- Fallback prop for unknown cargo
    defaultProp = { model = "prop_boxpile_07d", scale = 1.0 },
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
        description = "Heavy cargo, high risk, high reward - Master Mariners only",
        payMultiplier = 4.0,
        xpMultiplier = 2.5,
        weight = 2.5,           -- Severely affects handling
        fragile = false,
        illegal = true,
        perishable = false,
        minTier = 3,
        policeChance = 0.25,
        requiredLevel = 8,      -- Master Mariner only
        heavyLoad = true,
        heavyLoadSpeedMult = 0.75,  -- 75% speed with military gear
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

    -- ===========================================
    -- DRUG CARGO (Feeds into drug processing systems)
    -- ===========================================
    {
        id = "cocaine_raw",
        label = "Unprocessed Cocaine",
        description = "Raw coca paste from South America - needs processing",
        payMultiplier = 4.5,
        xpMultiplier = 2.5,
        weight = 1.5,
        fragile = false,
        illegal = true,
        perishable = false,
        minTier = 3,
        policeChance = 0.30,    -- 30% police chance
        drugType = "cocaine",   -- For drug system integration
        drugAmount = 50,        -- Units of raw material delivered
    },
    {
        id = "weed_bales",
        label = "Cannabis Bales",
        description = "Bulk marijuana shipment - strong smell",
        payMultiplier = 3.5,
        xpMultiplier = 2.0,
        weight = 2.0,           -- Bulky cargo
        fragile = false,
        illegal = true,
        perishable = false,
        minTier = 2,
        policeChance = 0.25,    -- 25% - smell makes it risky
        drugType = "weed",
        drugAmount = 100,       -- Units delivered
    },
    {
        id = "meth_precursors",
        label = "Chemical Precursors",
        description = "Industrial chemicals - definitely not for meth labs",
        payMultiplier = 4.0,
        xpMultiplier = 2.2,
        weight = 1.8,
        fragile = true,         -- Chemicals are volatile
        illegal = true,
        perishable = false,
        minTier = 3,
        policeChance = 0.20,    -- 20% - looks like legit chemicals
        drugType = "meth",
        drugAmount = 30,        -- Precursor units
        explosionRisk = true,   -- Volatile chemicals
    },
    {
        id = "drug_shipment",
        label = "Processed Product",
        description = "Street-ready product - maximum heat",
        payMultiplier = 5.0,    -- Highest payout
        xpMultiplier = 3.0,
        weight = 1.0,
        fragile = false,
        illegal = true,
        perishable = false,
        minTier = 4,            -- Requires highest tier
        policeChance = 0.35,    -- 35% - highest police risk
        drugType = "mixed",     -- Could be any processed drug
        drugAmount = 75,
    },

    -- ===========================================
    -- WEAPONS CARGO (Feeds into gang systems)
    -- ===========================================
    {
        id = "gun_parts",
        label = "Disassembled Firearms",
        description = "Gun parts for assembly - needs a workshop",
        payMultiplier = 3.5,
        xpMultiplier = 2.0,
        weight = 1.5,
        fragile = false,
        illegal = true,
        perishable = false,
        minTier = 2,
        policeChance = 0.20,    -- 20% - parts look like scrap
        weaponType = "parts",   -- For gang system integration
        weaponAmount = 10,      -- Gun part kits
    },
    {
        id = "pistol_crate",
        label = "Handgun Shipment",
        description = "Crate of street pistols - gang favorite",
        payMultiplier = 4.0,
        xpMultiplier = 2.2,
        weight = 1.2,
        fragile = false,
        illegal = true,
        perishable = false,
        minTier = 2,
        policeChance = 0.25,
        weaponType = "pistol",
        weaponAmount = 8,       -- Pistols in crate
    },
    {
        id = "smg_crate",
        label = "SMG Shipment",
        description = "Submachine guns - serious firepower",
        payMultiplier = 5.0,
        xpMultiplier = 2.8,
        weight = 1.8,
        fragile = false,
        illegal = true,
        perishable = false,
        minTier = 3,
        policeChance = 0.30,
        weaponType = "smg",
        weaponAmount = 5,
    },
    {
        id = "rifle_crate",
        label = "Assault Rifles",
        description = "Military-grade rifles - maximum heat",
        payMultiplier = 6.0,
        xpMultiplier = 3.5,
        weight = 2.5,
        fragile = false,
        illegal = true,
        perishable = false,
        minTier = 4,
        policeChance = 0.40,    -- 40% - feds are watching
        weaponType = "rifle",
        weaponAmount = 4,
    },
    {
        id = "ammo_crate",
        label = "Ammunition Crate",
        description = "Bulk ammo supply for the streets",
        payMultiplier = 2.5,
        xpMultiplier = 1.5,
        weight = 2.0,           -- Heavy
        fragile = false,
        illegal = true,
        perishable = false,
        minTier = 2,
        policeChance = 0.15,    -- Lower risk than guns
        weaponType = "ammo",
        weaponAmount = 500,     -- Rounds of ammo
    },

    -- ===========================================
    -- BUSINESS CARGO (Industry-specific deliveries)
    -- ===========================================
    {
        id = "restaurant_supplies",
        label = "Restaurant Supplies",
        description = "Fresh ingredients for local restaurants - quality drops over time",
        payMultiplier = 1.8,
        xpMultiplier = 1.4,
        weight = 1.5,
        fragile = false,
        illegal = false,
        perishable = true,
        perishTime = 0.6,           -- 60% of normal time - very urgent
        minTier = 1,
        qualityDrop = true,         -- Payout decreases over time
        qualityDropRate = 0.05,     -- -5% payout per 2 minutes
        qualityDropInterval = 120,  -- Every 2 minutes (seconds)
        businessType = "restaurant",
    },
    {
        id = "boutique_clothing",
        label = "Boutique Fashion",
        description = "Designer clothing - extremely fragile, avoid any impacts",
        payMultiplier = 2.8,
        xpMultiplier = 2.0,
        weight = 0.4,               -- Light but delicate
        fragile = true,
        illegal = false,
        perishable = false,
        minTier = 2,
        damageMultiplier = 3.0,     -- 3x damage penalty - ruined fabric
        businessType = "clothing",
        premiumInsurance = true,    -- Eligible for premium cargo insurance
    },
    {
        id = "vehicle_parts",
        label = "Vehicle Parts",
        description = "Heavy auto parts - requires large vessel, reduces speed",
        payMultiplier = 3.0,
        xpMultiplier = 2.2,
        weight = 3.5,               -- Very heavy
        fragile = false,
        illegal = false,
        perishable = false,
        minTier = 3,                -- Marquis/Tug only
        requiredBoats = {"marquis", "tug", "urchin"},  -- Specific boats only
        heavyLoad = true,           -- Reduces boat speed
        heavyLoadSpeedMult = 0.8,   -- 80% of normal speed
        loadStress = 0.15,          -- +15% maintenance cost
        businessType = "import",
    },
    {
        id = "supercar_parts",
        label = "Supercar Components",
        description = "Exotic car parts - gang exclusive, high value",
        payMultiplier = 5.5,
        xpMultiplier = 3.0,
        weight = 2.5,
        fragile = true,             -- Precision parts
        illegal = false,
        perishable = false,
        minTier = 3,
        requiredBoats = {"marquis", "tug", "urchin"},
        heavyLoad = true,
        heavyLoadSpeedMult = 0.85,
        loadStress = 0.20,          -- +20% maintenance cost
        businessType = "import",
        gangExclusive = true,       -- Requires gang membership
        requiredGangRank = 2,       -- Minimum gang rank to accept
    },
    {
        id = "nightclub_supplies",
        label = "Nightclub Supplies",
        description = "Premium alcohol and supplies for clubs",
        payMultiplier = 2.2,
        xpMultiplier = 1.6,
        weight = 2.0,
        fragile = true,             -- Bottles break easily
        illegal = false,
        perishable = false,
        minTier = 2,
        damageMultiplier = 1.5,
        businessType = "nightclub",
    },
    {
        id = "yacht_provisions",
        label = "Yacht Provisions",
        description = "Luxury supplies for private yachts - premium clients",
        payMultiplier = 3.5,
        xpMultiplier = 2.5,
        weight = 1.0,
        fragile = true,
        illegal = false,
        perishable = true,
        perishTime = 0.75,
        minTier = 2,
        qualityDrop = true,
        qualityDropRate = 0.03,     -- -3% per 2 minutes
        qualityDropInterval = 120,
        premiumInsurance = true,
        businessType = "luxury",
    },
}

-- =============================================================================
-- PREMIUM INSURANCE SYSTEM
-- =============================================================================

Config.PremiumInsurance = {
    enabled = true,
    baseCost = 5000,                -- Base cost for premium coverage
    costPercentOfValue = 0.02,      -- 2% of cargo value
    payoutPercent = 0.90,           -- 90% payout (vs standard 80%)
    eligibleCargo = {"boutique_clothing", "yacht_provisions", "supercar_parts"},
}

-- Drug system integration (DPSRP 1.5)
Config.DrugIntegration = {
    enabled = false,            -- Set true to give items on delivery
    script = 'none',            -- Options: 'qb-drugs', 'qs-drugs', 'custom'

    -- Item names for each drug type (adjust to match your drug script)
    items = {
        cocaine = 'cocaine_brick',
        weed = 'weed_brick',
        meth = 'meth_tray',
        mixed = 'drug_package',
    },

    -- Alternative: Trigger event instead of giving items
    useEvent = false,
    eventName = 'drugs:server:receivedShipment',  -- Your drug script's event
}

-- Gang/Weapons system integration (DPSRP 1.5 - rcore_gangs)
Config.GangIntegration = {
    enabled = false,            -- Set true to give weapons on delivery
    script = 'none',            -- Options: 'rcore_gangs', 'qb-gangs', 'custom'

    -- Require gang membership for weapons cargo
    requireGangMember = true,   -- Only gang members can accept weapon deliveries
    gangJobName = 'gang',       -- Job name to check (or use gang system API)

    -- Item names for each weapon type (adjust to match your items)
    items = {
        parts = 'weapon_parts',
        pistol = 'weapon_pistol',
        smg = 'weapon_smg',
        rifle = 'weapon_carbinerifle',
        ammo = 'ammo_9mm',
    },

    -- Alternative: Trigger event for gang script integration
    useEvent = false,
    eventName = 'gangs:server:weaponShipment',  -- Your gang script's event

    -- rcore_gangs specific settings
    rcoreGangs = {
        enabled = false,        -- Use rcore_gangs API
        addToGangStash = true,  -- Add weapons to gang stash instead of player
        territoryBonus = true,  -- Bonus payout if delivering to gang territory
        territoryBonusMult = 1.25,  -- 25% bonus in owned territory
    },

    -- Gang cut / laundering (money sink for economy balance)
    gangCut = {
        enabled = true,         -- Take a cut of weapons/drug payouts
        cutPercent = 0.15,      -- 15% goes to the "organization"
        useBank = true,         -- Use banking system for the cut
        bankAccount = 'gang_treasury',  -- qs-banking account name
        launderingFee = 0.05,   -- Additional 5% "laundering" fee for illegal cargo
        notifyPlayer = true,    -- Notify player about the cut
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
    -- Standard public ports
    { name = "Los Santos Marina",    coords = vector3(-802.0, -1496.0, 0.0),  tier = 1, hasFuel = true },
    { name = "Vespucci Beach",       coords = vector3(-1599.0, -1097.0, 0.0), tier = 1, hasFuel = false },
    { name = "Del Perro Pier",       coords = vector3(-1619.0, -1015.0, 0.0), tier = 1, hasFuel = false },
    { name = "Chumash Pier",         coords = vector3(-3426.0, 967.0, 0.0),   tier = 2, hasFuel = false },
    { name = "Galilee Marina",       coords = vector3(1299.0, 4216.0, 0.0),   tier = 2, hasFuel = false },
    { name = "Paleto Bay Pier",      coords = vector3(-275.0, 6635.0, 0.0),   tier = 3, hasFuel = true },

    -- Safe Harbors (Gang-controlled territories)
    -- Lower coast guard risk, higher pirate/rival gang risk
    {
        name = "Elysian Island Docks",
        coords = vector3(-163.0, -2378.0, 0.0),
        tier = 2,
        hasFuel = true,
        safeHarbor = true,          -- Gang-controlled port
        gangTerritory = "ballas",   -- Which gang controls this (for rcore_gangs)
        coastGuardMod = 0.3,        -- 70% less coast guard encounters
        pirateMod = 1.5,            -- 50% more pirate/rival encounters
        illegalOnly = false,        -- Allow all cargo or just illegal
    },
    {
        name = "Terminal Island",
        coords = vector3(1208.0, -2985.0, 0.0),
        tier = 3,
        hasFuel = false,
        safeHarbor = true,
        gangTerritory = "vagos",
        coastGuardMod = 0.2,        -- 80% less coast guard
        pirateMod = 2.0,            -- Double pirate risk
        illegalOnly = true,         -- Only illegal cargo accepted
    },
    {
        name = "NOOSE Facility",
        coords = vector3(3857.0, 4458.0, 0.0),
        tier = 3,
        hasFuel = false,
        safeHarbor = false,
        -- High security area - increased coast guard
        coastGuardMod = 2.0,        -- Double coast guard here
        pirateMod = 0.0,            -- No pirates at NOOSE
    },
    {
        name = "Sandy Shores Cove",
        coords = vector3(1538.0, 3902.0, 0.0),
        tier = 2,
        hasFuel = false,
        safeHarbor = true,
        gangTerritory = "lost_mc",
        coastGuardMod = 0.4,
        pirateMod = 1.8,
        illegalOnly = true,
    },

    -- ===========================================
    -- CAYO PERICO (Long-haul international routes)
    -- ===========================================
    {
        name = "Cayo Perico Main Dock",
        coords = vector3(4943.0, -5175.0, 0.0),
        tier = 3,
        hasFuel = true,
        cayoPerico = true,          -- International route
        distanceBonus = 1.5,        -- 50% bonus for long distance
        coastGuardMod = 0.1,        -- 90% less coast guard (international waters)
        pirateMod = 2.5,            -- High pirate risk
        illegalOnly = false,
        requiredLevel = 6,          -- Must be experienced captain
    },
    {
        name = "Cayo Perico North Beach",
        coords = vector3(5005.0, -4612.0, 0.0),
        tier = 3,
        hasFuel = false,
        cayoPerico = true,
        distanceBonus = 1.6,
        coastGuardMod = 0.05,       -- Almost no coast guard
        pirateMod = 3.0,            -- Very dangerous
        illegalOnly = true,         -- Smuggling only
        safeHarbor = true,
        gangTerritory = "cartel",   -- El Rubio's territory
    },
    {
        name = "Cayo Perico Airstrip Dock",
        coords = vector3(4518.0, -4556.0, 0.0),
        tier = 3,
        hasFuel = true,
        cayoPerico = true,
        distanceBonus = 1.55,
        coastGuardMod = 0.2,
        pirateMod = 2.0,
        illegalOnly = false,
        acceptedCargo = {"cocaine_raw", "weapons", "drug_shipment", "supercar_parts"},
        gangExclusive = true,
        requiredLevel = 8,
    },
}

-- Safe Harbor settings
Config.SafeHarbor = {
    enabled = true,
    requireGangMember = false,      -- Anyone can use, or require gang affiliation
    gangMemberBonus = 1.15,         -- 15% bonus payout for gang members at their territory
    rivalGangPenalty = 0.8,         -- 20% less payout for rival gang members
    neutralBonus = 1.0,             -- No bonus/penalty for non-gang members
}

-- =============================================================================
-- BUSINESS DELIVERY POINTS (Industry-specific locations)
-- =============================================================================

Config.BusinessDeliveryPoints = {
    -- Restaurant/Food destinations
    {
        name = "Vanilla Unicorn Beach Dock",
        coords = vector3(-1336.0, -1266.0, 0.0),
        tier = 1,
        hasFuel = false,
        businessType = "restaurant",
        acceptedCargo = {"restaurant_supplies", "seafood", "yacht_provisions"},
        payBonus = 1.10,            -- 10% bonus for direct delivery
    },
    {
        name = "Bahama Mamas West",
        coords = vector3(-1388.0, -588.0, 0.0),
        tier = 1,
        hasFuel = false,
        businessType = "nightclub",
        acceptedCargo = {"nightclub_supplies", "restaurant_supplies"},
        payBonus = 1.15,
    },
    {
        name = "Tequi-La-La Beach Drop",
        coords = vector3(-560.0, 278.0, 0.0),
        tier = 1,
        hasFuel = false,
        businessType = "nightclub",
        acceptedCargo = {"nightclub_supplies"},
        payBonus = 1.10,
    },

    -- Clothing/Fashion destinations
    {
        name = "Ponsonbys Del Perro",
        coords = vector3(-1454.0, -234.0, 0.0),
        tier = 2,
        hasFuel = false,
        businessType = "clothing",
        acceptedCargo = {"boutique_clothing"},
        payBonus = 1.20,            -- 20% bonus for fashion
    },
    {
        name = "Rockford Hills Boutique",
        coords = vector3(-710.0, -152.0, 0.0),
        tier = 2,
        hasFuel = false,
        businessType = "clothing",
        acceptedCargo = {"boutique_clothing", "yacht_provisions"},
        payBonus = 1.25,            -- Premium area
    },

    -- Vehicle Import destinations
    {
        name = "Port of LS Vehicle Bay",
        coords = vector3(-90.0, -2400.0, 0.0),
        tier = 3,
        hasFuel = true,
        businessType = "import",
        acceptedCargo = {"vehicle_parts", "supercar_parts"},
        payBonus = 1.15,
        gangTerritory = nil,        -- Neutral ground
    },
    {
        name = "Premium Deluxe Motorsport Dock",
        coords = vector3(-34.0, -1112.0, 0.0),
        tier = 3,
        hasFuel = false,
        businessType = "import",
        acceptedCargo = {"supercar_parts", "vehicle_parts"},
        payBonus = 1.30,            -- High-end dealership
        gangExclusive = true,       -- Gang members only
    },

    -- Luxury/Yacht destinations
    {
        name = "Casino Yacht Club",
        coords = vector3(-1595.0, 4773.0, 0.0),
        tier = 2,
        hasFuel = true,
        businessType = "luxury",
        acceptedCargo = {"yacht_provisions", "restaurant_supplies", "nightclub_supplies"},
        payBonus = 1.25,
    },
    {
        name = "Private Yacht Anchorage",
        coords = vector3(1529.0, 3778.0, 0.0),
        tier = 2,
        hasFuel = false,
        businessType = "luxury",
        acceptedCargo = {"yacht_provisions"},
        payBonus = 1.35,            -- Very exclusive
        vipOnly = true,             -- VIP members only (high level)
        requiredLevel = 8,
    },
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
    riskPerCop = 0.02,            -- +2% police chance per online cop
    maxRiskMultiplier = 2.0,      -- Maximum 2x the base policeChance

    -- Off-peak hours scaling (keeps economy fair during low-pop hours)
    timeBasedScaling = true,      -- Enable time-of-day risk adjustment
    offPeakHours = {0, 1, 2, 3, 4, 5, 6, 7},  -- Server hours considered off-peak (midnight-7am)
    offPeakMultiplier = 0.5,      -- 50% police chance during off-peak (e.g., 25% -> 12.5% for weapons)
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
