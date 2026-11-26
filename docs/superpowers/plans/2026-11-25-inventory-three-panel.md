<!--
SPDX-FileCopyrightText: 2026 Lone Asset contributors
SPDX-License-Identifier: CC-BY-4.0
-->

# Inventory: three panels, drag and drop, containers: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rig and backpack inventory with mixed-round magazines, drag-and-drop actions, a situational container panel, display-only operative condition, and persistence across checkpoints and missions.

**Architecture:** Extend `AmmoInventory` (pouches stay as the rig, add a backpack). A pure `InventoryMoves` decides every drop; `ItemSlot` controls call it and the screen applies the result. `LootStore` is the container's contents; `LootContainer` node exposes it through an `Interactable`.

**Tech Stack:** Godot 4.7.2, typed GDScript, gdUnit4 (`tools/ci/run_tests.sh`).

**Spec:** `docs/superpowers/specs/2026-11-25-inventory-three-panel-design.md`

## Global Constraints

- Branch `feat/inventory-three-panel` from `dev`. **Never commit or push until the developer approves** (CLAUDE.md): every task leaves its changes in the working tree; there are no commit steps.
- Stage nothing with `git add -A`; `text_to_sfx.ipynb` and the untracked `ammo_boxes_*` files in the repo root are not part of this work.
- Logic in pure `*_rules.gd` classes with unit tests; scenario tests for scene behaviour; tunable numbers in `data/**/*.tres`.
- Systems talk through `EventBus` signals; saved nodes implement `save_state()` / `load_state()`; checkpoint schema bump needs a migration (`SaveRules`).
- UI units are 1920x1080 pixels, built in code, theme variations from `UiPalette` (`GlassPanel`, `GlassButton`, `SlotPanel`, `MutedLabel`, `AccentLabel`, `HeaderLabel`), accent `#3ddc5f`, font Rajdhani.
- After adding a `class_name` script run `godot --headless --path . --import`. gdUnit scenario tests free their scenes in `after_test`.
- New assets (none planned) need `content/LICENSES.md` and `REUSE.toml` rows; `reuse lint` must pass.
- Update `docs/handoff.md` and `docs/acceptance/m1-acceptance.md` at the end.

## Review Focus

- Dragging an item onto its own slot or a full slot: nothing changes, no item lost or duplicated (Task 4, 7).
- A reload started from the rig while the inventory moves that magazine away mid-reload: the gun keeps its magazine, nothing vanishes (`_finish_reload` already guards; Task 5 test).
- Packing rounds into a magazine while it is moved or the stack runs out: operation ends, counts consistent (Task 7).
- Container closed (Esc, walking away, death) during a timed operation: operation stops, nothing lost (Task 7, 8).
- A checkpoint made with schema 2 loads with an empty backpack and a default condition (Task 2, 3).

---

### Task 1: Mixed-round magazines

**Files:** Modify `game/inventory/magazine_rules.gd`, `tests/unit/test_magazine_rules.gd`, `tests/unit/test_ammo_inventory.gd`, `tests/unit/test_magazine_operation.gd` (whichever assert one-type-only).

**Interfaces:** Produces: `MagazineRules.can_load(magazine, ammo) -> bool` true for any accepted caliber when the magazine has room.

- [ ] **Step 1:** Run `git switch -c feat/inventory-three-panel dev`.
- [ ] **Step 2:** Change the tests that expect a second ammo type refused (`test_filling_refuses_a_second_ammo_type` and its siblings) to expect acceptance. Add `test_mixed_magazine_fires_last_loaded_first`: load FMJ then AP into a STANAG, assert `top() == AP.id`, `rounds == [FMJ.id, AP.id]`. Add `test_wrong_caliber_still_refused`: a 9x19 round into a STANAG returns false.
- [ ] **Step 3:** Run `tools/ci/run_tests.sh res://tests/unit`; the changed tests fail.
- [ ] **Step 4:** In `can_load` drop the `top() == ammo.id` clause (keep fullness and caliber checks). Update the doc comments of `can_load`, `Magazine`, and `MagazineOperation` that say one ammo type.
- [ ] **Step 5:** Re-run unit tests; all pass.

### Task 2: Backpack and schema 3

**Files:** Modify `game/inventory/ammo_inventory.gd`, `game/save/save_rules.gd`, `data/inventory/starting_loadout.tres`/`game/inventory/starting_loadout.gd`, `tests/unit/test_ammo_inventory.gd`, `tests/unit/test_save_rules.gd`.

**Interfaces:** Produces on `AmmoInventory`: `var backpack: Array[Magazine]`, `var backpack_capacity: int`, `func add_to_backpack(magazine: Magazine) -> bool`; `_init(slots: int = 6, backpack_slots: int = 12)`. `to_dict` gains `"backpack"` and `"backpack_capacity"`; `from_dict` reads them (missing means empty). `StartingLoadout.backpack_count: int = 12`. `SaveRules.SCHEMA_VERSION = 3`; `migrate` turns a version 2 save into 3 (inventory keeps `pouches`, no backpack, no condition).

- [ ] **Step 1:** Tests: `test_backpack_is_limited` (capacity 1, second add false); `test_inventory_round_trips_backpack` (to_dict/from_dict keeps order and rounds); `test_schema_2_save_migrates` in `test_save_rules.gd` (a v2 dictionary becomes `schema_version == 3` and still passes `problem_with`).
- [ ] **Step 2:** Run, expect failures.
- [ ] **Step 3:** Implement as in Interfaces. `loose` stays the backpack's loose ammo (comment it). Make the rig/backpack naming explicit in the class doc comment: `pouches` is the rig.
- [ ] **Step 4:** Run unit tests; all pass.

### Task 3: LootStore and OperativeCondition

**Files:** Create `game/inventory/loot_store.gd`, `game/damage/operative_condition.gd`, `tests/unit/test_loot_store.gd`, `tests/unit/test_operative_condition.gd`.

**Interfaces:**
- Produces `class_name LootStore extends RefCounted`: `var magazines: Array[Magazine]`, `var loose: Dictionary` (ammo id to count), `var items: Dictionary` (item id to count), `var capacity: int`; `add_magazine(m) -> bool`, `add_loose(id, n)`, `take_loose(id, n) -> int`, `loose_count(id) -> int`, `is_empty() -> bool`, `to_dict() -> Dictionary`, `static from_dict(data, catalog: InventoryCatalog) -> LootStore`.
- Produces `class_name OperativeCondition extends RefCounted`: `var bleeding: bool`, `var upper_injury: int`, `var lower_injury: int` (0..2), `var stress: float` (0..100); setters clamp; `to_dict()`, `static from_dict(data) -> OperativeCondition` (missing keys give defaults).

- [ ] **Step 1:** Tests: LootStore round trip keeps magazines with mixed rounds and loose counts; capacity refuses an extra magazine; `take_loose` returns the smaller of request and stock; OperativeCondition clamps injury to 0..2 and stress to 0..100 and round-trips; `from_dict({})` gives defaults.
- [ ] **Step 2:** Run (fail), implement, run (pass). Run `godot --headless --path . --import` after adding the files.

### Task 4: InventoryMoves

**Files:** Create `game/inventory/inventory_moves.gd`, `tests/unit/test_inventory_moves.gd`.

**Interfaces:**
- Consumes: `AmmoInventory`, `LootStore`, `MagazineRules`, `WeaponDefinition`.
- Produces `class_name InventoryMoves extends RefCounted` with `enum Place { RIG, BACKPACK, CONTAINER, GUN }` and static functions, each returning a `Dictionary {"ok": bool, "reason": StringName}` (reasons: `&"full"`, `&"wrong_fit"`, `&"move_to_rig"`, `&"same_slot"`, `&"empty"`):
  - `move_magazine(inventory: AmmoInventory, store: LootStore, from_place: Place, from_index: int, to_place: Place) -> Dictionary` applies the move (removes from the source array, appends to the destination if it has room; a full destination leaves the source unchanged).
  - `can_reload_from(from_place: Place) -> Dictionary`: ok only for `RIG`; `BACKPACK`/`CONTAINER` give `move_to_rig`.
  - `move_loose(inventory, store, ammo_id: StringName, count: int, to_place: Place) -> Dictionary` between backpack loose and container loose.
  - `can_pack(magazine: Magazine, ammo: AmmoType) -> Dictionary` wraps `MagazineRules.can_load` with a reason.

- [ ] **Step 1:** Tests for every row of the spec's moves table: rig to backpack and back, container to backpack, full destination leaves both arrays unchanged, same place and index is `same_slot`, backpack magazine onto gun is `move_to_rig`, wrong caliber pack is `wrong_fit`, loose move clamps to stock, no item is lost or duplicated (compare total round count before and after).
- [ ] **Step 2:** Run (fail), implement (no node access), run (pass).

### Task 5: Reload with a chosen magazine

**Files:** Modify `game/weapons/weapon_logic.gd`, `game/weapons/weapon.gd`, `tests/unit/test_inventory_reload.gd` or `tests/unit/test_weapon_logic.gd`.

**Interfaces:** Produces `WeaponLogic.start_reload_with(rig_index: int) -> bool` (like `start_reload` but uses `inventory.pouches[rig_index]`; false with `reload_block` `&"wrong_fit"` when `MagazineRules.can_insert` fails, `&"full"` when the gun is full and the magazine is not fuller, `&"no_magazine"` for a bad index). `Weapon.request_reload_with(rig_index: int) -> bool` mirrors the `intent.reload` path in `Weapon._process` (blocked while swapping the attachment; the node starts the sound and animation through the existing `logic.is_reloading` edge).

- [ ] **Step 1:** Tests: reload with index 2 swaps in magazine 2, not the "best" one; wrong family refused with `wrong_fit`; chosen magazine removed from the rig during reload (moved by the inventory) leaves the gun on its old magazine (existing `_finish_reload` guard).
- [ ] **Step 2:** Run (fail), implement by factoring the shared tail of `start_reload` into a private helper taking the found dictionary, run (pass).

### Task 6: Profile between missions

**Files:** Create `game/save/profile_rules.gd`, `game/autoload/profile_service.gd` (or a static class if no state is needed; follow `SaveService`), `tests/unit/test_profile_rules.gd`. Modify `game/autoload/game.gd`, `game/levels/mission definition resource` (field `carry_over: bool = false`, default false), `game/player/player.gd`.

**Interfaces:** `ProfileRules.build(player_state: Dictionary) -> Dictionary` (keeps `health`, `condition`, `inventory`, `loadout`; adds `profile_version: 1`); `ProfileRules.problem_with(data) -> String`; `ProfileService.write(player: Player) -> bool` (atomic temp-then-rename to `user://saves/profile.json`), `read() -> Dictionary`. `Player.save_state()` gains `"condition"`; `Player.load_state()` reads it (default when missing). `Game._on_mission_completed` writes the profile; level start applies it only when the mission has `carry_over`.

- [ ] **Step 1:** Tests: `build` drops position and slot keeps inventory and condition; `problem_with` flags a non-dictionary and a missing inventory; round trip through text preserves per-round magazine contents.
- [ ] **Step 2:** Run (fail), implement, run (pass).
- [ ] **Step 3:** Add `var condition: OperativeCondition` to `Player`; include it in `save_state`/`load_state`.

### Task 7: Drag and drop three-panel screen

**Files:** Create `game/ui/inventory/item_slot.gd`, `game/ui/inventory/condition_view.gd`. Modify `game/ui/inventory/inventory_screen.gd`, `tests/scenarios/test_inventory_screen.gd`.

**Interfaces:**
- Produces `class_name ItemSlot extends GlassButton`: `var place: InventoryMoves.Place`, `var index: int`, `var payload: Dictionary` (what it holds: `{"kind": "magazine" | "loose" | "gun" | "attachment", ...}`); signal `dropped(from_payload: Dictionary, to_slot: ItemSlot)`; implements `_get_drag_data` (returns `payload`, sets a small glass tile preview), `_can_drop_data`, `_drop_data` (emits `dropped`). It holds no rules.
- Produces `InventoryScreen.open_container(store: LootStore, title: String) -> void` and `close_container()`; signal `container_closed`.
- `ConditionView` shows vital HP, bleed, upper and lower injury, stress from `OperativeCondition` and `Health`.

- [ ] **Step 1:** Scenario tests on the real player (follow the existing helper style): `test_layout_panels_keep_position_when_container_opens` (record `global_position` of the middle and right panels, open a container, compare equal; the container panel `visible`); `test_dropping_rig_magazine_on_gun_starts_reload`; `test_dropping_backpack_magazine_on_gun_is_refused_with_toast` (listen to `EventBus.toast_requested`); `test_moving_magazine_backpack_to_rig`; `test_drop_on_full_rig_changes_nothing`; `test_packing_loose_rounds_into_magazine_over_time` (advance with `_process`, uses `MagazineOperation`); `test_closing_screen_stops_operation`.
- [ ] **Step 2:** Run (fail).
- [ ] **Step 3:** Restructure `_build` into: container panel (left, hidden), operative+weapons panel (middle: portrait, `ConditionView`, gun rows with an attachment tile, knife and binoculars rows), rig+backpack panel (right: rig grid `ItemSlot`s, backpack grid, loose ammo list with draggable stacks). Anchor middle and right panels to the right edge with fixed widths (470 px each); the container panel gets the reserved space at the left with the same height.
- [ ] **Step 4:** Connect every `dropped` to one `_on_dropped(from, to)` that calls `InventoryMoves`, applies the result, shows the reason as `EventBus.toast_requested` on refusal, then `_refresh()`. Magazine on gun calls `Weapon.request_reload_with`. Loose stack on a magazine starts a `MagazineOperation` (FILL). Drop on an "UNLOAD" tile starts UNLOAD. Attachment tile on its gun calls `Weapon.toggle_variant()`. Remove the old select and button flow.
- [ ] **Step 5:** `close()` also stops the operation and closes the container panel. Update key hint text to "Drag  Move items".
- [ ] **Step 6:** Run scenario tests (pass). Take a window screenshot check by running the game (`godot --path .`) and opening Tab, report to the developer.

### Task 8: Containers in the world

**Files:** Create `game/inventory/loot_container.gd`, `game/inventory/loot_container.tscn`, `tests/scenarios/test_loot_containers.gd`. Modify `game/ai/guard/guard.gd` (`_drop_loot`), `game/autoload/save_service.gd` (world `containers`), `game/levels/graybox/movement_course.tscn` (one crate near the start with mixed items), `game/autoload/event_bus.gd` (`container_opened(store, title)` signal).

**Interfaces:** `LootContainer extends Node3D` with `@export var container_id: StringName`, `@export var title: String`, `var store: LootStore`, an `Interactable` child (F: emits `EventBus.container_opened`), `save_state() -> Dictionary` (`store.to_dict()`), `load_state(data)`; group `&"containers"`. A dead guard spawns a `LootContainer` (id `drop_<guard_id>`, store holding the `drop_magazine` with `drop_magazine_rounds` of `drop_ammo`), replacing the `AmmoPickup`. `Player` listens to `EventBus.container_opened` and calls `inventory_screen.open_container`. The screen closes the container when the player moves more than 3 m away (checked in `_process`).

- [ ] **Step 1:** Tests: interacting emits `container_opened` with the store; a guard's death creates a container holding the profile's magazine; moving a magazine out then saving and loading the container state keeps it moved; walking away closes the panel.
- [ ] **Step 2:** Run (fail), implement, run (pass). `SaveService.save_checkpoint` writes `world.containers`; `apply` restores them deferred like pickups (corpse containers are created a moment after guards are restored).
- [ ] **Step 3:** Stripping rounds: dragging a loose-ammo stack from the container panel or using the unload tile on a container magazine unloads into the container's loose ammo through `MagazineOperation` on a temporary `AmmoInventory`-compatible store (add `LootStore.fill_one` and `unload_one` mirroring `AmmoInventory`, with a unit test in `test_loot_store.gd`).

### Task 9: Docs and final check

**Files:** Modify `docs/handoff.md`, `docs/acceptance/m1-acceptance.md`, `docs/architecture.md` (inventory line).

- [ ] **Step 1:** Add a handoff section "Inventory: rig, backpack, containers (date)" in the style of the existing ones: what exists, schema 3, profile file, what is not done (medical item use, condition effects, attachment items, container models).
- [ ] **Step 2:** Run `tools/ci/run_tests.sh` and `reuse lint`; both pass.
- [ ] **Step 3:** Report to the developer with the list of changed files; wait for them to play the build. Do not commit.
