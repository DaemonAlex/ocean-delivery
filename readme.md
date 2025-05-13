# Ocean Delivery

This resource allows players to start a delivery job using a boat in GTA V. Players can select a route and will be spawned into a boat at a specified location. The delivery count is tracked and can be reset.

## Features

- Route selection for delivery jobs
- Boat spawning at specified locations
- Delivery count tracking
- Reset delivery count
- UI support using `ox_lib`
- Higher payouts for consecutive deliveries
- Bonus for completing a series of 4 deliveries

## Installation

1. Clone or download the repository.
2. Place the `ocean_delivery` folder in your server's resources directory.
3. Add `start ocean_delivery` to your server configuration file.
4. Import the `database.sql` file into your database.

## Usage

### Starting a Delivery Job

Players can start a delivery job by triggering the `cargo:startDelivery` event. This will prompt the player to select a route and spawn them into a boat at the designated location.

### Completing a Delivery Job

Players can complete a delivery job by triggering the `cargo:completeDelivery` event. This will notify the server of the completed delivery and update the delivery count. Players will receive higher payouts for consecutive deliveries, with a bonus for completing a series of 4 deliveries.

### Resetting the Delivery Count

The delivery count can be reset by triggering the `cargo:resetDeliveryCount` event.

### Moving Pallets with a Forklift

Players will need to move pallets with a forklift from one location to a location on the dock near the boat. If the player does not start moving the items within 15 minutes, the job will end, and the pallets and forklift will despawn.

### Returning the Forklift

Once the player is done moving the pallets, they need to return the forklift to the same location it spawned. If the player tries to leave without returning the forklift, they will receive a warning message stating that they won't get paid unless they return the forklift to that location.

### Delivery Locations

Once the player pulls the boat up to the delivery location, they will need to move the pallets off the ship and into a location at the delivery site. The same timing rules apply here: the player has 15 minutes to start the work, or everything will despawn, and they will fail the delivery.
1. **Adding Locations**:
   * As an admin, navigate to a suitable water location in a boat
   * Use command: `/adddeliverylocation Los Santos Yacht Club`
   * Confirm the location is added by using `/listdeliverylocations`
2. **Starting a Delivery Job**:
   * Use `/startdelivery` command
   * You should see a list of routes generated based on available locations
   * Each route will show start and end locations with distance
3. **Testing Route Delivery**:
   * Select a route and complete the delivery
   * Verify that the dynamic route works correctly
   * Check proximity for pallet loading and delivery

### Key Features to Verify

* **Location Management**:
   * Adding locations saves them to database
   * Locations persist after server restart
   * Can view and manage locations with admin commands
* **Dynamic Route Generation**:
   * Routes are generated based on available locations
   * Routes respect minimum and maximum distance settings
   * Routes include start/end locations and distance display
* **Route Selection**:
   * Route selection UI shows all valid routes
   * Player can choose from multiple route options
   * Route name displays both start and end location

### Admin Commands Reference

| Command | Description | Example |
|---------|-------------|---------|
| `/adddeliverylocation [name]` | Add location at current position | `/adddeliverylocation Paleto Dock` |
| `/listdeliverylocations` | View all available locations | `/listdeliverylocations` |
| `/removedeliverylocation [id]` | Remove location by ID | `/removedeliverylocation 5` |
| `/resetdelivery [player_id]` | Reset a player's delivery job | `/resetdelivery 3` |

### Player Commands

| Command | Description |
|---------|-------------|
| `/startdelivery` | Start a new delivery job |
| `/enddelivery` | Cancel current delivery job |
| `/deliverystats` | View delivery statistics |

### Troubleshooting Tips

* **If locations don't sync**: Check server console for errors in the `cargo_locations` table creation
* **If routes don't generate**: Make sure you have at least 2 valid locations
* **If ox_target isn't working**: The script will fall back to proximity detection
* **If banking payments fail**: Check if the appropriate banking system is installed
