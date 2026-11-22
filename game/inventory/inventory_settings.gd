class_name InventorySettings
extends Resource
## Times of the inventory screen's magazine work (data/inventory/inventory_settings.tres).

## Seconds to load one round into a magazine.
@export_range(0.05, 2.0) var fill_time_per_round_s: float = 0.3
## Seconds to take one round out of a magazine.
@export_range(0.05, 2.0) var unload_time_per_round_s: float = 0.15
