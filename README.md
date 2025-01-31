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

## Planned Future Functionality

- Integration with delivery scripts that provide sales stock to stores around Los Santos, including:
  - Convenience stores
  - Clothing stores
  - Bars
  - Restaurants
  - Vehicle dealerships
  - Other businesses
  - Some stock items will only come from certain locations, simulating international       imports. 
  - Examples:
   Certain cars only come from Cayo Perico or other locations that specialize in providing those goods.
   A dock area in the county is where most food comes from because the farms are near there.
