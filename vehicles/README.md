# Ocean Delivery - Required Vehicles

This resource requires the following boat/ship models for the fleet system.

## Required Downloads

All vehicles are created by **Jimmyr** on GTA5-Mods.com.

| Vehicle | Spawn Name | Download Link |
|---------|------------|---------------|
| Old Cargo Ship | `costal` | [Download](https://www.gta5-mods.com/vehicles/old-cargo-ship-add-on-five-m) |
| Old Cargo Ship GERMANY | `costal2` | [Download](https://www.gta5-mods.com/vehicles/old-cargo-ship-germany-add-on-fivem) |
| Urchin 2 Bulk Carrier | `urchin` | [Download](https://www.gta5-mods.com/vehicles/urchin2-add-on-fivem) |

## Installation

### For FiveM:
1. Download each vehicle from the links above
2. Extract the vehicle folders
3. Place each vehicle folder in your server's `resources/[vehicles]/` directory
4. Add each to your `server.cfg`:
   ```
   ensure costal
   ensure costal2
   ensure urchin
   ```

### Handling Overrides:
This resource includes custom handling.meta files in the `vehicles/` folder to make these ships feel heavier and more realistic:
- `costal_handling.meta` - Standard cargo ship handling
- `costal2_handling.meta` - Premium cargo ship (heavier, slower)
- `urchin_handling.meta` - Mega freighter (very heavy, 90% submerged)

To use the custom handling, copy these files into each vehicle's `stream/` folder, replacing the original handling.meta.

## Vehicle Stats in Ocean Delivery

| Vehicle | Tier | Capacity | Speed | Price | Required Level |
|---------|------|----------|-------|-------|----------------|
| Coastal | 1 | 2 | 65 | $35,000 | 1 |
| Coastal II Premium | 2 | 6 | 85 | $450,000 | 5 |
| Urchin II Mega Freighter | 3 | 16 | 20 | $5,000,000 | 10 |

## Credits

All vehicle models by **Jimmyr**:
- https://www.gta5-mods.com/users/Jimmyr

Please respect the original creator's terms of use.
