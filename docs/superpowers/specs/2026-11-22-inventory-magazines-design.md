# Magazines, ammo types and inventory: design

Date: 2026-11-22. Status: draft, awaiting the developer's approval. This is a post-Milestone-1 feature (`docs/architecture.md` lists inventory as out of scope for M1); the first pull request updates that document.

## Intent

Reloading should be about magazines, not a number. Each gun accepts certain magazine types; a magazine holds rounds of one caliber and, in this first version, one ammo type; the player carries a limited number of magazines in pouches and a stock of loose ammo. Reloading swaps the magazine in the gun for another from the pouches. Filling magazines from loose ammo happens in the inventory screen, in real time. This rewards preparation, makes loot meaningful, and fits the stealth tone (a careful player counts rounds, a careless one runs dry in a fight).

## Goals

- A reload swaps magazines; it never refills one. The assets for this exist (`Magazine_Detach`, `Magazine_Attach_Tactical`, `Magazine_Attach_Empty`, `Magazine_Check` clips and sounds on the Glock and M4A1 rigs).
- Magazine types are shared where real magazines are: every 5.56 STANAG magazine fits the M4A1, and a Glock 17 takes both its 17-round and 33-round magazines.
- Ammo types (full metal jacket, armour-piercing, subsonic and so on) change how a round behaves and are chosen when filling a magazine.
- A chambered round is modelled: a tactical reload keeps it, an empty reload does not.
- Everything is data (`data/**/*.tres`) and every rule is a pure class with unit tests.

## Non-goals (first version)

Mixed ammo types in one magazine, magazines dropped on the floor, a grid or weight inventory, backpacks, crafting, trading, attachments in the inventory screen, `.300 BLK` and other calibers that share a magazine (the data model leaves room, see "Calibers and fit").

## Concepts and data

All new types live in a new layer `game/inventory/` (rules and runtime classes) with resources under `data/ammo/`, `data/magazines/` and `data/inventory/`.

| Type | Kind | Fields |
|---|---|---|
| `AmmoType` | Resource | `id`, `display_name`, `icon`, `caliber` (id), `damage_mult`, `penetration_mult`, `velocity_mult`, `noise_mult`, `tracer` |
| `MagazineType` | Resource | `id`, `display_name`, `icon`, `family` (id, for example `stanag`, `glock_9mm`), `accepted_calibers`, `capacity` |
| `WeaponDefinition` (existing) | Resource | adds `chambering` (caliber id), `magazine_families` (ids it accepts), `default_magazine` (type used when none is given), `icon` |
| `Magazine` | runtime, saved | `type`, `rounds: Array[StringName]` (ammo ids, the last element is the top round) |
| `AmmoInventory` | runtime, saved | `pouches: Array[Magazine]` (fixed slot count), `loose: Dictionary` (ammo id to count) |
| `StartingLoadout` | Resource | pouch count, magazines to start with (type, ammo, rounds), loose ammo |

The first set of data: calibers `5.56x45` and `9x19`; ammo `fmj_556`, `ap_556`, `fmj_9`, `subsonic_9` (numbers to tune); magazines `stanag_30` (family `stanag`), `glock_17rd` and `glock_33rd` (family `glock_9mm`). The M4A1 accepts `stanag`; the Glock 17 accepts `glock_9mm`. Icons are the developer-supplied `Icon_M4A1_Magazine.png` and `Icon_Glock_17_Magazine.png` (the STANAG icon covers every STANAG type for now); weapon icons are `Icon_M4A1.png` and `Icon_Glock_17.png`.

### Calibers and fit

Two separate checks, kept apart on purpose:

- **Magazine fit**: a magazine can be inserted into a weapon when `magazine.type.family` is in `weapon.magazine_families`.
- **Load fit**: a round can be loaded into a magazine when `ammo.caliber` is in `magazine.type.accepted_calibers`.
- **Chamber fit** (later): a round can be fired when `ammo.caliber` matches `weapon.chambering`. In the first version every accepted caliber equals the chambering, so this check always passes. It exists in the model so a `.300 BLK` round, which fits a STANAG magazine but is not safe in a 5.56 chamber, can be added as data plus a "wrong ammo" rule later.

## Runtime rules (`MagazineRules`, pure)

- `can_insert(weapon, magazine) -> bool` (magazine fit).
- `can_load(magazine, ammo) -> bool`: load fit, and the magazine is empty or already holds this ammo id (one type per magazine).
- `load_round(magazine, ammo) -> bool`, `unload_round(magazine) -> StringName` (returns the removed ammo id, or an empty id).
- `fullness(magazine) -> float` and `fullness_label(magazine) -> String` ("full", "mostly full", "about half", "nearly empty", "empty"), used by the magazine check.
- `best_magazine(pouches, weapon, current_ammo) -> int`: the pouch index to reload from. Order: compatible and not empty; prefer the ammo id of the round already in the gun; then the fullest; then the lowest index. Returns -1 when none.

### Weapon state and the chamber

`WeaponLogic` stops owning `magazine` and `reserve` integers. It holds:

- `inserted: Magazine` (may be empty or null when the gun has no magazine),
- `chambered: StringName` (ammo id of the round in the chamber, empty when none).

Firing consumes `chambered`; the next round from `inserted` is chambered at once (a semi or full-auto action cycles by itself). The `AmmoType` of the fired round is applied to the shot through a small `ShotProfile` (damage, penetration and velocity multipliers, noise radius multiplier, tracer flag) that `Weapon` hands to `BallisticsSystem.fire` together with the weapon definition; the definition itself is not duplicated per shot. When the chamber and the magazine are both empty the gun is "dry": the trigger clicks.

### Reload flow

1. R (or a trigger pull on a dry gun) asks `best_magazine`. With no result, play the dry click and show "no magazine"; nothing else happens.
2. **Tactical reload** (a round is chambered): play `anim_reload` / `reload_sound`, duration `reload_time`. The chambered round stays; the old magazine goes into the pouch slot the new one left; the new magazine becomes `inserted`. Capacity in the gun is therefore magazine capacity plus one.
3. **Empty reload** (nothing chambered): play `anim_reload_empty` / `reload_empty_sound`, duration `reload_time_empty`, which already includes the slide release. At the end the next round is chambered from the new magazine.
4. The swap is committed at the end of the animation, as `_finish_reload` is today. Switching weapons mid-reload cancels it (already implemented, `WeaponLogic.cancel_reload`): nothing moves and the old magazine stays in the gun. Two clips matter for later polish: the clips `Magazine_Detach` and `Magazine_Attach_*` can split a reload into two timed steps; the first version uses the existing single clips.

The old magazine always returns to the pouches, so no slot is ever lost and nothing hits the floor. The pouch count never changes during play.

## Inventory screen

Opened with a key (suggested `Tab`; the key goes through `InputIntent` like every other control). It does **not** pause the game: the world keeps running, the weapon sees no input (the same path binoculars use), the player can still be hurt or seen. Closing it returns control at once.

Layout (first version, no drag and drop needed): a row of pouch slots (magazine icon, ammo type, round count), a list of loose ammo (icon, name, count), and the weapons with their icons showing the inserted magazine and chambered round. Controls: select a magazine, then:

- **Fill**: moves loose ammo of the selected type into the magazine, one round every 0.3 s while held or toggled, with a progress bar. A round is moved at the end of its 0.3 s, so cancelling loses at most the round in progress (which stays loose).
- **Unload**: moves rounds from the magazine back to loose ammo, one every 0.15 s.
- Only magazines in the pouches can be changed; the magazine in a gun cannot.
- One operation at a time. The weapon in hand keeps its current state; the player is not holstered.

A sound plays per round (a new short `round_load` click; the supplied recordings are for whole-weapon actions, so this needs a sound, noted as a gap).

## HUD

Today the HUD shows `magazine / reserve`. In the first version it shows the rounds in the inserted magazine plus the chambered round, and the number of spare magazines that hold rounds (not the total rounds). A later option, "Magazine check only", hides the number and shows `fullness_label` after the player presses a check key (plays `Magazine_Check`); this is listed under "Later" so the first pull request does not depend on it.

## Guards

Guards keep working without an inventory. `GuardWeapon` builds its `WeaponLogic` with an `infinite_magazines` flag: a guard reload creates a fresh full magazine of the guard weapon's default ammo. Guard ammo type is the default type, so no balancing changes.

## Save and checkpoints

The checkpoint schema moves from version 1 to 2 (`docs/architecture.md`: bump and migrate). The player's weapon state becomes the inserted magazine (type id, ammo ids), the chambered ammo id, and the variant as today; the inventory adds `pouches` (type id and rounds each) and `loose` (ammo id to count). The migration from version 1 turns `mag` N into a magazine of the weapon's default type holding N rounds of the default ammo, and `reserve` R into full spare magazines (up to the pouch count, one pouch each) with the remainder as loose ammo. A test loads a version 1 file and checks the totals.

## Events

New `EventBus` signals (no cross-system node references): `magazine_changed(weapon_id)`, `inventory_changed`, `reload_blocked(reason)`. The HUD and the inventory screen listen; they do not poll the weapon.

## Testing

- Unit: `MagazineRules` (fit, load, unload, fullness labels, `best_magazine` ordering including ties and mixed ammo ids), `AmmoInventory` (fill and unload counts, pouch limits), `WeaponLogic` (chamber, tactical versus empty reload, no magazine available, cancel keeps the old magazine), the version 1 to 2 migration.
- Scenario: a reload picks the fullest compatible magazine, the old magazine returns to its pouch, a Glock accepts a 33-round magazine and the M4A1 refuses it, fill and unload on the real screen with timing, the save and load round trip.
- Existing weapon tests that read `logic.magazine` and `logic.reserve` change with the first pull request.

## Delivery

1. **Pull request 1: data, rules and magazine-based reload.** Resources, `MagazineRules`, `ShotProfile`, `WeaponLogic` and `Weapon` changes, HUD readout, guards flag, save migration, the debug starting loadout in `data/inventory/starting_loadout.tres`, `docs/architecture.md` updates (the `game/inventory` layer, the M1 scope note), ledger entries for the four icons. There is no inventory screen yet: magazines are filled by the starting loadout only.
2. **Pull request 2: inventory screen** with fill, unload, the real-time progress, the `round_load` sound and the settings text.
3. **Pull request 3: pickups and loot**: loose ammo stacks and magazines found in the level, a pickup rule when the pouches are full.

Each pull request waits for the developer to play the build.

## Later

Mixed rounds in a magazine (the ordered round list already allows it), magazine check key with approximate fullness, chamber fit and cross-caliber magazines (`.300 BLK`, 6.5 Grendel and the big-bore family with their own magazine families), a backpack grid, dropped magazines, split `Magazine_Detach` and `Magazine_Attach_*` reload steps, an ammo type picker on the reload key.

## Open questions

- Pouch count (suggested 6) and starting loadout contents.
- Fill and unload times per round (suggested 0.3 s and 0.15 s).
- The inventory key and whether the inventory should also close on damage.
- Ammo type numbers (damage, penetration, noise multipliers) and which ammo the guards drop.
- Ammo icons: `Items/Ammo/` was not copied from the developer's pack; placeholders until they are.
