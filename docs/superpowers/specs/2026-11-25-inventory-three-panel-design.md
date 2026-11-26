<!--
SPDX-FileCopyrightText: 2026 Lone Asset contributors
SPDX-License-Identifier: CC-BY-4.0
-->

# Inventory: operative, rig and backpack, and a situational container panel

Status: draft for approval, 2026-11-25. Builds on `docs/superpowers/specs/2026-11-22-inventory-magazines-design.md` and the glass `InventoryScreen`.

## Intent

The player opens the inventory in the field and manages the loadout by dragging items: a magazine onto a gun reloads it, loose rounds onto a magazine pack it, items move between rig, backpack and an external container (crate, locker, shelf, fallen guard). The player decides which magazines are quick to reach (the rig, the only source for the R key) and which are stored (the backpack), and can strip rounds from found magazines. The inventory is the place where ammo choices (FMJ, AP, Subsonic) are made before a fight.

## Layout

```
[ CONTAINER (situational) ] [ OPERATIVE + WEAPONS (fixed) ] [ RIG + BACKPACK (fixed) ]
```

- Middle panel (operative and weapons) and right panel (rig and backpack) are anchored to the right of the screen and never move. The container panel sits in the reserved space to their left, `visible = false` until the player opens a container.
- Middle panel top: portrait, vital HP, bleed, limb injuries (upper body and arms, legs), stress. Display only. Bottom: M4A1 and Glock 17 (loud or suppressed state, inserted magazine and chambered round), combat knife, binoculars.
- Right panel top: rig slots (magazines, quick medical and utility items). Bottom: backpack with loose ammo by caliber and ammo type, spare magazines, extra medical items.
- Style stays as the existing glass theme: dark glass, thin light borders, square corners, `#3ddc5f` accent, Rajdhani, green square before section titles.

## Goals

- Drag and drop between every place that can hold items, with the drop doing the action (see Moves).
- Rig versus backpack: only rig magazines are used by R.
- Magazines hold per-round contents and may mix ammo types (LIFO, the last loaded fires first).
- Container panel for crates, lockers, shelves and fallen guards, including stripping rounds from their magazines.
- Operative condition and the whole inventory saved in checkpoints and carried across missions.

## Non-goals

- No gameplay effect for bleed, limb injury or stress (display only), no medical item use, no AI, mission scripting or level work, no weight or grid size, no new weapon models or attachment models.

## Constraints

- `docs/architecture.md`: logic in pure `*_rules.gd` classes with unit tests, tunable numbers in `data/**/*.tres`, systems talk through `EventBus`, saved things implement `save_state()` / `load_state()`, checkpoint schema bumps with a migration.
- UI authored for 1920x1080, built in code like the current screen.
- Do not commit or push before the developer approves.

## Approaches considered

1. Extend the current screen and data in place (chosen). Moderate size, keeps tested code.
2. New generic slot-based UI from scratch: cleaner, but discards the working screen and tests.
3. Keep select-and-button interaction, add dragging as a layer: two ways to do one thing, against the request.

## Design

### Data

- `AmmoInventory`: the existing `pouches` array is the **rig** (kept under that name so `WeaponLogic` and its tests do not change; documented as the rig). Add `backpack: Array[Magazine]` with `backpack_capacity`; `loose` is the backpack's loose ammo (unchanged). Medical and utility items are a small `items: Dictionary` of id to count (rig and backpack each), display and storage only.
- `Magazine`: unchanged shape (ordered `rounds`, last fires first). `MagazineRules.can_load` stops requiring one ammo type per magazine: any accepted caliber with room loads, on top of the stack. `best_magazine` keeps preferring the gun's current ammo by top round, then fullest.
- `LootStore` (RefCounted, `game/inventory/loot_store.gd`): magazines, loose ammo, items, with `to_dict` / `from_dict`. Same shape as the backpack so the same moves work.
- `OperativeCondition` (Resource, `game/damage/operative_condition.gd`): `bleeding: bool`, `limbs: Dictionary` (`upper` and `lower` to a level 0 to 2), `stress: float` 0 to 100. Vital HP stays on `Health`. `to_dict` / `from_dict`.

### Moves (pure)

`InventoryMoves` (`game/inventory/inventory_moves.gd`) answers "may this drag land here, and what happens". A place is `{kind: RIG | BACKPACK | CONTAINER | GUN, index}`. Results are plain dictionaries the screen applies, so the rules are testable without nodes.

| Drag | Drop | Result |
|---|---|---|
| Magazine (rig, backpack, container) | rig, backpack, container slot | move, if there is room |
| Rig magazine | gun slot | start a reload with that magazine (same as R: `WeaponLogic` takes the chosen magazine) |
| Backpack or container magazine | gun slot | rejected, toast "MOVE TO RIG FIRST" |
| Loose ammo stack | magazine (any place) | timed packing through `MagazineOperation`, one round per step |
| Loose ammo stack | backpack or container | move |
| Magazine | "unload" area, or a container magazine's strip action | timed unload to loose ammo of the place it is in |
| Spare attachment tile | its gun | swap, same as T (0.9 s) |

Wrong caliber or family: dropped item snaps back, with a toast.

### UI

- `ItemSlot` (Control, `game/ui/inventory/item_slot.gd`) uses Godot's `_get_drag_data`, `_can_drop_data`, `_drop_data`. Payload is a dictionary (place, item kind, index). A drag preview is a small glass tile. Slots ask `InventoryMoves` and emit `dropped`; they hold no rules.
- `InventoryScreen` stays one `CanvasLayer`, restructured into the three panels; `open_container(store)` shows the left panel, `close` hides it. Keeps real-time operation, hands busy and no pause.
- Containers: `LootContainer` node (an `Interactable`, F to open) on crates, lockers and shelves; a fallen guard gets one holding its magazine and drop (replaces `AmmoPickup` drops from guards). Container contents are saved in `world.containers`.

### Persistence

- Checkpoint schema 3: `inventory` gains `backpack`, `items`; the player gains `condition`. Migration from 2: pouches become the rig, backpack empty, condition default.
- Between missions: `user://profile.json` (atomic write, same as checkpoints) holds condition, weapons, magazines with per-round contents and loose ammo. Written on mission complete, read at the start of the next mission that is marked to carry over.

### Tests

Unit: `InventoryMoves` (every row above plus rejections), mixed-round loading and LIFO, `best_magazine` with mixed tops, backpack capacity, `LootStore` and `OperativeCondition` round trips, schema 2 to 3 migration, profile read and write. Scenario: dragging through the screen (reload from rig, pack a magazine, move to container, container panel shows and hides, middle and right panels keep their position).

## Calls I made (correct them)

- The existing agreed rule "one ammo type per magazine" is dropped, because this request wants mixed magazines.
- Guard corpses become containers instead of dropping one `AmmoPickup`.
- Cross-mission carry-over is written on mission complete and applied only when a mission asks for it; the single M1 mission does not.
- Attachments are a tile that swaps the alternate variant (T already does this); there are no separate attachment items yet.
- Medical and utility items are counts with no use action.

## Left to the builder

Slot sizes and colours within the existing theme, the order of rig and backpack capacities (start from the current 8 pouches and a 12-magazine backpack in `data/inventory/`), toast wording, file names inside the folders named above.

## Process

Branch `feat/inventory-three-panel` from `dev`, one commit per logical change, run `tools/ci/run_tests.sh` and `reuse lint`, update `docs/handoff.md` and `docs/acceptance/m1-acceptance.md`, wait for the developer to play the build before any PR merge.

## Revision 2026-11-25: only body magazine slots and backpack slots

The developer decided there are only two kinds of slots: magazine slots on the body (the old "rig", still `AmmoInventory.pouches`, the only source for R) and backpack slots. No other slots (no medical or utility slots). Loose ammo is no longer a separate list: it uses backpack slots, one slot per started stack of `AmmoType.stack_size` rounds (60 for every type today, in `data/ammo/*.tres`), and magazines in the backpack use one slot each. A full backpack refuses new magazines and loose rounds (`AmmoInventory.free_slots`, `loose_room`); unloading a magazine stops with "NO ROOM IN THE BACKPACK" when the rounds do not fit; a pickup takes only what fits and the rest stays in the world; a magazine pickup goes to a free body slot, otherwise a free backpack slot. Containers keep unlimited loose ammo and 12 magazine slots. The UI shows loose ammo as cells in the backpack grid and has an UNLOAD strip under it.
