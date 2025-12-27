# Ocean Delivery v3.0.0

An advanced boat cargo delivery job system for FiveM with fleet ownership, random encounters, fuel management, and phone app integration.

## What's New in v3.0.0

- **Fleet Ownership** - Buy, sell, repair, and insure your own boats
- **Random Encounters** - Pirates, Coast Guard, and rescue missions
- **Refueling System** - Functional fuel stations at ports
- **Phone App Integration** - Manage deliveries via lb-phone, qs-smartphone, or npwd
- **Insurance System** - Protect your investment
- **Maintenance Tracking** - Keep your fleet in top condition

## Features

### Progression System
- **10 Levels** with unique titles (Deckhand → Legendary Captain)
- **3 Ship Tiers**: Coastal, Regional, Long Haul
- **XP-based progression** with delivery bonuses
- **Streak bonuses** for consecutive successful deliveries

### Fleet Ownership

Buy and manage your own fleet of boats:

| Feature | Description |
|---------|-------------|
| Purchase | Buy boats at any level (some require higher levels) |
| Naming | Give your boats custom names |
| Repair | Fix damage for a percentage of boat value |
| Insurance | Protect against total loss (80% payout) |
| Sell | Sell boats for 60% of value (condition affects price) |
| Fleet Limit | Up to 5 boats per player |

### Ship Pricing

| Tier | Ship | Price | Insurance | Maintenance |
|------|------|-------|-----------|-------------|
| 1 | Dinghy | $5,000 | $250 | $50/day |
| 1 | Suntrap | $8,000 | $400 | $75/day |
| 1 | Speeder | $15,000 | $750 | $150/day |
| 1 | Seashark | $12,000 | $600 | $100/day |
| 2 | Jetmax | $75,000 | $3,750 | $500/day |
| 2 | Tropic | $45,000 | $2,250 | $350/day |
| 2 | Squalo | $95,000 | $4,750 | $650/day |
| 2 | Toro | $125,000 | $6,250 | $800/day |
| 3 | Marquis | $500,000 | $25,000 | $3,500/day |
| 3 | Tug | $750,000 | $37,500 | $5,000/day |

### Random Encounters

During deliveries, you may encounter:

| Encounter | Description | Reward |
|-----------|-------------|--------|
| Pirates | Hostile boats attack you | +50 XP for surviving |
| Coast Guard | Patrol checking cargo | Escape to avoid arrest |
| Distress Signal | Someone needs rescue | +$2,500 and +100 XP |
| Fellow Smuggler | Trade opportunities | +$5,000 and +75 XP |

Encounter chances increase with:
- Higher tier routes
- Illegal cargo

### Cargo Types

| Cargo | Pay Mult | Special Properties |
|-------|----------|-------------------|
| Standard | 1.0x | None |
| Electronics | 1.5x | Fragile |
| Fresh Seafood | 1.4x | Perishable |
| Medical Supplies | 2.0x | Fragile + Perishable |
| Unmarked Crates | 3.0x | Illegal (15% police chance) |
| Military Hardware | 4.0x | Illegal (25% police chance) |
| Luxury Goods | 2.5x | Fragile (2x damage penalty) |
| Hazardous Materials | 3.5x | Fragile + Explosion risk |

### Refueling System

- **4 Fuel Stations** at major ports
- **$3 per liter** refuel cost
- **Blips on map** for easy location
- Fuel consumption based on speed and ship efficiency

### Weather System

| Weather | Speed | Handling | Pay Bonus |
|---------|-------|----------|-----------|
| Clear | 100% | 100% | 0% |
| Overcast | 100% | 100% | 0% |
| Rain | 90% | 85% | +10% |
| Thunderstorm | 75% | 70% | +25% |
| Dense Fog | 85% | 95% | +15% |

### Phone App Integration

Manage your deliveries from your phone:

- **Start Job** - Begin a new delivery
- **View Stats** - Check XP, level, earnings
- **Manage Fleet** - View/repair your boats
- **Check Weather** - See current bonus
- **Find Fuel** - Locate nearest station

Supports:
- lb-phone
- qs-smartphone
- npwd

## Installation

1. Place the `ocean-delivery` folder in your server's resources directory
2. Add to your server.cfg:
   ```
   ensure ox_lib
   ensure oxmysql
   ensure qb-core
   ensure ocean-delivery
   ```
3. The database tables are created automatically on first start

## Database Tables

| Table | Purpose |
|-------|---------|
| `ocean_delivery_players` | Player progression and stats |
| `ocean_delivery_fleet` | Player-owned boats |
| `ocean_delivery_history` | Delivery logs |
| `ocean_delivery_maintenance` | Repair/insurance logs |
| `ocean_delivery_encounters` | Encounter history |
| `cargo_locations` | Custom delivery locations |

## Commands

### Player Commands

| Command | Description |
|---------|-------------|
| `/startdelivery` | Start a new delivery job |
| `/enddelivery` | Cancel current delivery |
| `/deliverystats` | View progression stats |
| `/fleet` | Open fleet management menu |
| `/buyboat` | Browse boats for sale |
| `/refuel` | Refuel at a fuel station |

### Admin Commands

| Command | Description |
|---------|-------------|
| `/adddeliverylocation [name] [tier] [fuel]` | Add location at position |
| `/listdeliverylocations` | View all locations |
| `/removedeliverylocation [id]` | Remove a location |
| `/resetdelivery [playerID]` | Reset player's job |
| `/setdeliverylevel [playerID] [level]` | Set player level |

## Configuration

All settings are in `config.lua`:

```lua
-- Fleet Ownership
Config.FleetOwnership = {
    enabled = true,
    maxShipsPerPlayer = 5,
    sellBackPercent = 0.6,         -- 60% of value
    insurancePayoutPercent = 0.8,  -- 80% of value
    repairCostMultiplier = 0.1,    -- 10% of boat price
}

-- Random Encounters
Config.RandomEncounters = {
    enabled = true,
    checkInterval = 30000,         -- Every 30 seconds
    minDistanceFromPort = 500,     -- Safety zone
}

-- Refueling
Config.Refueling = {
    enabled = true,
    costPerLiter = 3,
    showBlips = true,
}

-- Phone App
Config.PhoneApp = {
    enabled = true,
    appName = "Ocean Delivery",
}
```

## Dependencies

**Required:**
- qb-core or qbx-core
- ox_lib
- oxmysql

**Optional:**
- ox_target (enhanced interaction)
- qs-banking or renewed-banking (banking integration)
- lb-phone, qs-smartphone, or npwd (phone app)

## Gameplay Flow

1. **Purchase a Boat** (`/buyboat` or `/fleet`)
   - Browse available boats
   - Higher tier boats require higher levels
   - Name your boat

2. **Start Delivery** (`/startdelivery`)
   - Select your boat from your fleet
   - Choose cargo type based on tier
   - Pick a route

3. **During Delivery**
   - Manage fuel consumption
   - Watch for random encounters
   - Avoid damage (especially with fragile cargo)

4. **Encounters**
   - Pirates: Fight or flee
   - Coast Guard: Escape distance required
   - Distress: Rescue for bonus rewards

5. **Complete Delivery**
   - Earn payment with bonuses/penalties
   - Gain XP toward next level
   - Boat condition may decrease

6. **Maintain Fleet**
   - Repair damaged boats
   - Add insurance for protection
   - Sell unused boats

## Level Progression

| Level | Title | XP Required | Tier |
|-------|-------|-------------|------|
| 1 | Deckhand | 0 | 1 |
| 2 | Sailor | 500 | 1 |
| 3 | Boatswain | 1,500 | 1 |
| 4 | Helmsman | 3,000 | 2 |
| 5 | Navigator | 5,000 | 2 |
| 6 | First Mate | 8,000 | 2 |
| 7 | Captain | 12,000 | 3 |
| 8 | Master Mariner | 18,000 | 3 |
| 9 | Fleet Admiral | 25,000 | 3 |
| 10 | Legendary Captain | 35,000 | 3 |

## Exports

```lua
-- Get player stats
exports['ocean-delivery']:GetPlayerStats()

-- Get player fleet
exports['ocean-delivery']:GetPlayerFleet()

-- Check if on delivery job
exports['ocean-delivery']:IsOnDeliveryJob()
```

## Roadmap

### Completed
- [x] Tiered progression system
- [x] Multiple cargo types
- [x] Weather effects
- [x] Fuel management
- [x] Fleet ownership
- [x] Random encounters
- [x] Phone app integration

### Planned
- [ ] Crew system (hire NPCs)
- [ ] Ship customization/upgrades
- [ ] Supply/demand dynamic pricing
- [ ] Multiplayer convoy missions
- [ ] Achievements system

## Support

For issues and feature requests, please open an issue on GitHub.

## License

MIT License - See LICENSE file for details.

## Credits

- Original concept & code by DaemonAlex
