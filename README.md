# Ocean Delivery v2.0.0

An advanced boat cargo delivery job system for FiveM with a comprehensive progression system, multiple cargo types, weather effects, and fuel management.

## Features

### Progression System
- **10 Levels** with unique titles (Deckhand → Legendary Captain)
- **3 Ship Tiers**: Coastal, Regional, Long Haul
- **XP-based progression** with delivery bonuses
- **Streak bonuses** for consecutive successful deliveries
- **Series bonuses** for completing 4 deliveries in a row

### Ship Tiers

| Tier | Name | Description | Unlocked At |
|------|------|-------------|-------------|
| 1 | Coastal | Small boats for local harbor runs | Level 1 |
| 2 | Regional | Medium vessels for coastal voyages | Level 4 |
| 3 | Long Haul | Large ships for ocean crossings | Level 7 |

### Available Ships

**Tier 1 - Coastal:**
- Dinghy - Basic inflatable, light and agile
- Suntrap - Recreational boat, good visibility
- Speeder - Fast speedboat, burns fuel quickly
- Seashark - Personal watercraft, very fast but unstable

**Tier 2 - Regional (Level 4+):**
- Jetmax - High-performance yacht
- Tropic - Pontoon with cargo space
- Squalo - Sport yacht, balanced
- Toro - Classic speedboat with large deck

**Tier 3 - Long Haul (Level 7+):**
- Marquis - Luxury yacht, massive cargo space
- Tug - Industrial tugboat, maximum capacity

### Cargo Types

| Cargo | Pay Mult | XP Mult | Special |
|-------|----------|---------|---------|
| Standard | 1.0x | 1.0x | None |
| Electronics | 1.5x | 1.3x | Fragile |
| Fresh Seafood | 1.4x | 1.2x | Perishable |
| Medical Supplies | 2.0x | 1.8x | Fragile + Perishable |
| Unmarked Crates | 3.0x | 2.0x | Illegal (Police risk) |
| Military Hardware | 4.0x | 2.5x | Illegal + Heavy |
| Luxury Goods | 2.5x | 1.5x | Fragile (2x damage penalty) |
| Hazardous Materials | 3.5x | 2.0x | Fragile + Explosion risk |

### Weather System
- **Clear Skies** - Normal conditions
- **Overcast** - Slightly reduced visibility
- **Rain** - +10% pay bonus, reduced handling
- **Thunderstorm** - +25% pay bonus, severe conditions
- **Dense Fog** - +15% pay bonus, very low visibility

### Fuel System
- Ships spawn with 80% fuel
- Different ships have different fuel efficiency
- Fuel consumption based on speed and tier
- Low fuel warnings at 20% and 10%
- Out of fuel = job failed

### Damage System
- Cargo takes damage from boat collisions
- Fragile cargo takes 50% more damage
- Heavy cargo takes 20% more damage from momentum
- Damage reduces final payout:
  - 10% damage → 5% penalty
  - 30% damage → 15% penalty
  - 50% damage → 30% penalty
  - 70%+ damage → 50% penalty

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

The script automatically creates these tables:
- `ocean_delivery_players` - Player progression and stats
- `ocean_delivery_history` - Delivery history logs
- `cargo_locations` - Custom delivery locations
- `cargo_deliveries` - Legacy delivery tracking

## Commands

### Player Commands

| Command | Description |
|---------|-------------|
| `/startdelivery` | Start a new delivery job (opens selection UI) |
| `/enddelivery` | Cancel current delivery job |
| `/deliverystats` | View your progression stats in a menu |

### Admin Commands

| Command | Description |
|---------|-------------|
| `/adddeliverylocation [name] [tier] [hasFuel]` | Add location at current position |
| `/listdeliverylocations` | View all delivery locations |
| `/removedeliverylocation [id]` | Remove a custom location |
| `/resetdelivery [playerID]` | Reset a player's current job |
| `/setdeliverylevel [playerID] [level]` | Set a player's delivery level (1-10) |

## Configuration

All configuration is in `config.lua`:

```lua
-- XP Settings
Config.XPPerDelivery = 100           -- Base XP per delivery
Config.XPPerDistance = 0.5           -- Additional XP per distance unit
Config.XPBonusMultiplier = 1.5       -- Multiplier for bonus deliveries

-- Payment Settings
Config.BasePayoutPerDistance = 10    -- Base payout per distance unit
Config.BonusPayout = 500             -- Bonus per consecutive delivery
Config.SeriesBonus = 2000            -- Bonus for completing 4 deliveries

-- Time Settings
Config.PickupTimer = 15 * 60 * 1000  -- 15 minutes to pick up
Config.DeliveryTimer = 15 * 60 * 1000 -- 15 minutes to deliver

-- Enable/Disable Systems
Config.WeatherEffects.enabled = true
Config.FuelSystem.enabled = true
Config.DamagePenalty.enabled = true
```

## Dependencies

**Required:**
- qb-core or qbx-core
- ox_lib
- oxmysql

**Optional:**
- ox_target (enhanced interaction)
- qs-banking or renewed-banking (banking integration)

## Gameplay Flow

1. **Start Job** (`/startdelivery`)
   - Select your ship from available unlocked vessels
   - Choose cargo type based on your tier
   - Pick a route matching your ship's tier

2. **Pickup Phase**
   - Teleport to start location in your ship
   - Locate the cargo pallet (waypoint provided)
   - Use forklift to load cargo onto boat

3. **Delivery Phase**
   - Navigate to destination port
   - Manage fuel consumption
   - Avoid damage (especially with fragile cargo)
   - Weather affects handling and visibility

4. **Completion**
   - Unload cargo at delivery site
   - Receive payment with bonuses/penalties
   - Earn XP toward next level

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

## Roadmap

### Planned Features
- [ ] Fleet ownership (buy/maintain multiple ships)
- [ ] Supply/demand dynamic pricing
- [ ] Random encounters (pirates, coast guard)
- [ ] Crew system (hire NPCs)
- [ ] Ship customization/upgrades
- [ ] Refueling at port fuel stations
- [ ] Phone app integration

## Support

For issues and feature requests, please open an issue on GitHub.

## License

MIT License - See LICENSE file for details.

## Credits

- Original concept by DaemonAlex
