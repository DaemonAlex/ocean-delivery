# Ocean Delivery

This resource allows players to start a delivery job using a boat in GTA V. Players select a route, are spawned into a boat at a specified location, and must deliver cargo using forklifts. The script supports both QS-Banking and Renewed Banking for payments.

## Features

- Route selection for delivery jobs via ox_lib interface
- Realistic boat spawning at specified water locations
- Delivery count tracking with database persistence
- Forklift mechanics to move cargo pallets
- Enhanced pallet interaction using ox_target (if available)
- Higher payouts for consecutive deliveries
- Bonus for completing a series of 4 deliveries
- Job persistence across server restarts and player reconnections
- Compatible with both QS-Banking and Renewed Banking
- Interactive pallets with ox_target integration
- Admin commands for job management
- Player statistics and tracking
- 15-minute job timers with fail conditions
- Anti-cheat measures to prevent exploitation
- Comprehensive debug system

## Requirements

- **QBCore Framework**
- **ox_lib** - For UI interfaces
- **ox_target** (optional but recommended) - For enhanced interactions
- **oxmysql** - For database functionality
- One of the following banking systems:
  - **Renewed Banking** (preferred)
  - **QS-Banking** (alternative)
  - Or defaults to basic QBCore money functions

## Installation

1. Clone or download the repository.
2. Place the `ocean_delivery` folder in your server's resources directory.
3. Add `ensure ocean_delivery` to your server configuration file.
4. Import the `database.sql` file into your database.
5. Configure port locations and payment settings in `config.lua` if needed.

## Configuration

The `config.lua` file allows you to customize various aspects of the delivery job:

```lua
-- Payment settings
Config.BasePayoutPerDistance = 10 -- Base payout per distance unit
Config.BonusPayout = 500 -- Bonus payout for every additional delivery in a row
Config.SeriesBonus = 2000 -- Bonus payout for completing a series of 4 deliveries
Config.JobStartCost = 0 -- Cost to start a delivery job, set to 0 for free jobs

-- Define the ports and locations
Config.Ports = {
    {name = "Los Santos Marina", coords = vector3(-802.0, -1496.0, 0.0)},
    {name = "Paleto Bay Pier", coords = vector3(-275.0, 6635.0, 0.0)},
    {name = "Vespucci Beach", coords = vector3(-1599.0, -1097.0, 0.0)},
    {name = "NOOSE Facility", coords = vector3(3857.0, 4458.0, 0.0)}
}

-- Debug settings
Config.Debug = false -- Set to true to enable debug prints

```
## Usage

### Starting a Delivery Job

Players can start a delivery job in one of two ways:
- Use the `/startdelivery` command
- Trigger the `cargo:startDelivery` event

This will prompt the player to select a route and spawn them into a boat at the designated location with a pallet to pick up.

### Delivery Process

1. **Pick Up Phase**:
   - Spawn at the starting dock in a boat
   - Use the provided forklift to pick up the pallet
   - Load the pallet onto the boat
   - Return the forklift to its original location

2. **Transport Phase**:
   - Drive the boat to the delivery destination
   - Wait for the delivery site pallet to spawn

3. **Delivery Phase**: 
   - Unload the cargo at the delivery site
   - Receive payment based on distance and consecutive deliveries

### Completing a Delivery

The job is completed when the player successfully delivers the pallet to the destination. Players will receive higher payouts for consecutive deliveries, with a bonus for completing a series of 4 deliveries.

### Commands

- `/startdelivery` - Start a new delivery job
- `/enddelivery` - Cancel your current delivery job
- `/deliverystats` - Check your delivery statistics (total deliveries, distance traveled)
- `/resetdelivery [player_id]` - Admin command to reset a player's delivery job

### Resetting the Delivery Count

The delivery count can be reset by triggering the `cargo:resetDeliveryCount` event or using the admin command.

## Time Limitations

- Players have 15 minutes to begin moving items with a forklift, or the job will end
- Players have 15 minutes to deliver the cargo at the destination, or the job will fail
- Destruction of the delivery boat will result in job failure

## Developer Information

### Events

- `cargo:startDelivery` - Start a delivery job
- `cargo:deliveryComplete` - Complete a delivery job
- `cargo:resetDeliveryCount` - Reset delivery count
- `cargo:movePallet` - Spawn a forklift to move pallets
- `cargo:jobStarted` - Notify server of job start (persistence)
- `cargo:jobCompleted` - Notify server of job completion

### Callbacks

- `cargo:getDeliveryCount` - Get current delivery count for player
- `cargo:getTotalEarnings` - Get total earnings from deliveries

## Planned Future Functionality

- Integration with delivery scripts that provide sales stock to stores around Los Santos, including:
  - Convenience stores
  - Clothing stores
  - Bars
  - Restaurants
  - Vehicle dealerships
  - Other businesses
  - Some stock items will only come from certain locations, simulating international imports. 
  - Examples:
    - Certain cars only come from Cayo Perico or other locations that specialize in providing those goods
