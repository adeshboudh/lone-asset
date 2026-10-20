# Lone Asset — Milestone 1 Technical Design Document (Web / WASM)

Status: Draft v0.2 (open questions from v0.1 resolved, see §25)
Date: 2026-10-20
Parent document: [Lone Asset — Modern Tactical Stealth FPS](overview.md) (Web / WebAssembly Edition)

---

## 0. Purpose and Scope

This document specifies how to build **Milestone 1 — Core Prototype** of Lone Asset as a browser game (Godot 4 web export, WASM + WebGL 2).

Milestone 1 goal (from the parent document):

> Prove that movement, shooting and stealth feel good — in the browser.

### 0.1 In scope

| Area | Milestone 1 content |
|---|---|
| Player | First-person controller: walk, sprint, crouch, lean, jump |
| Weapon | One suppressed rifle (semi + auto) |
| Enemy | One guard type; test level has 1–3 instances |
| AI | Patrol, Investigate, Search, Combat, Return To Patrol, Dead |
| Perception | Vision cone + hearing (gameplay noise events) |
| Stealth | Suspicion meter (0–100) with light, stance, movement, distance |
| Mission | One objective (reach + use terminal) + extraction |
| Interaction | Door, terminal |
| Equipment | Framework + binoculars |
| UI | Loading, click-to-start, HUD, prompts, pause, settings, end screen |
| Save | Settings + one checkpoint slot in IndexedDB |
| Level | One small graybox compound (~80 m × 80 m) with **one finished-art hero area** (see §17.3) |
| Platform | Web build deployed to a public URL (Chrome, Edge, Firefox desktop) |

### 0.2 Out of scope (deferred)

Prone, vaulting, climbing, squad AI, AI Director logic (stub only), penetration/ricochet, recon drone, hacking, chunk streaming, vehicles, multiplayer, native builds, gamepad polish, mobile/touch.

Data structures are designed so deferred features slot in without rewriting Milestone 1 systems.

---

## 1. Project Setup

### 1.1 Engine version

- Use the **latest stable Godot 4.x** at kickoff. Pin the exact version (e.g. `4.x.y-stable`) in `ENGINE_VERSION` at repo root.
- Export templates must match the editor version exactly.
- Version upgrades only by explicit decision, on a branch, with the full test suite and a browser smoke test.

### 1.2 Project settings (key values)

| Setting | Value | Reason |
|---|---|---|
| Rendering method (all platforms) | **Compatibility** | Editor matches the web build visually and in performance |
| 3D physics engine | **Jolt Physics** | Faster, more stable than Godot Physics |
| Physics ticks per second | 60 | Gameplay runs in `_physics_process` |
| Max physics steps per frame | 4 | Avoid spiral of death on slow frames |
| GDScript warning: untyped declaration | **Error** | Enforce typed GDScript |
| GDScript warning: unsafe property/method access | Warning | Catch dynamic access |
| Window stretch mode | `canvas_items`, aspect `expand` | UI scales with browser window |
| Audio: default bus layout | `res://game/audio/default_bus_layout.tres` | See §13 |
| Texture import: VRAM compression | Desktop formats (S3TC/BPTC) | Web desktop GPUs |

### 1.3 Web export preset ("Web")

| Option | Value |
|---|---|
| Thread support | **Off** (single-threaded; no COOP/COEP headers needed) |
| Extensions support (GDExtension) | Off in Milestone 1 (see §2.3) |
| VRAM texture compression | Desktop: on; Mobile: off |
| Custom HTML shell | Default Godot shell until WP 11; then `res://web/shell.html` (custom loader UI) |
| Head include | Page background styling; test hooks (`window.__lone_asset`) are set from GDScript by `Platform` |
| Export path | `build/web/index.html` |

Export command (CI and local):

```bash
godot --headless --export-release "Web" build/web/index.html
```

### 1.4 Hosting

- **Cloudflare Pages** (direct upload from GitHub Actions via Wrangler), HTTPS, Cloudflare CDN compression.
- `.wasm` served as `application/wasm`.
- Brotli pre-compression of `.wasm`, `.pck`, `.js` in CI (`*.br`), with gzip fallback.
- Godot export file names are not content-hashed, so `index.html` is `no-cache` and `.wasm`/`.pck`/`.js` use a short `max-age` with ETag revalidation (`web/_headers`).
- **Cloudflare Pages limits each file to 25 MiB.** CI fails if any file exceeds it. The Godot 4.7 engine `.wasm` is ~38 MiB (6.6 MiB Brotli), so only `index.wasm.br` is deployed and a Pages advanced-mode worker (`web/_worker.js`) serves it at `/index.wasm` with `Content-Encoding: br`. Size-optimised custom web templates remain a later option to cut download size further. The `.pck` stays under the limit through split resource packs.
- Every pull request deploys a preview URL; `main` deploys to the staging URL.

---

## 2. Code Module Structure

### 2.1 Architecture overview

```text
                    ┌──────────────────────────────┐
                    │          Autoloads           │
                    │ EventBus  Game  Settings     │
                    │ SaveService  NoiseSystem     │
                    │ PerceptionScheduler          │
                    │ MissionService  Platform     │
                    │ AIDirector (stub)  Log       │
                    └──────────────┬───────────────┘
                                   │ signals / service calls
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
   Player scene               Guard scene               Level scene
   (components)               (components)              (triggers, interactables,
                                                         light volumes, nav, routes)
        │                          │
        └──────── Data Resources (.tres in data/) ─────────────┘
          WeaponDefinition, EquipmentDefinition, GuardProfile,
          MissionDefinition, InteractionDefinition, SurfaceProfile
```

### 2.2 Autoloads (singletons)

Keep this list short. Adding an autoload needs a written reason in the commit message.

| Autoload | Responsibility |
|---|---|
| `Log` | Levelled logging, category filters, ring buffer for bug reports |
| `EventBus` | Global gameplay signals (see §2.4). No logic. |
| `Game` | Top-level state machine: Boot → Title → Loading → Playing → Paused → MissionEnd |
| `Settings` | Load/apply/save player settings (ConfigFile) |
| `SaveService` | Checkpoint save/load, schema versioning, persistence request |
| `NoiseSystem` | Receives gameplay noise events, delivers them to listeners in range |
| `PerceptionScheduler` | Per-frame raycast budget for all perception components |
| `MissionService` | Runs the active `MissionDefinition` |
| `AIDirector` | Stub in Milestone 1: tracks global alert level only |
| `Platform` | Web glue: pointer lock state, visibility changes, storage persistence, test hooks |

### 2.3 GDScript / C++ boundary

- Milestone 1 ships **100 % typed GDScript**.
- `native/` contains a GDExtension skeleton that CI compiles for Linux (tests) and WASM, so the toolchain is proven, but it is not enabled in the web export.
- A system moves to C++ only if, after GDScript optimisation, it exceeds its frame budget (§19) on reference hardware. Likely candidates: perception ray batching, ballistics stepping, tactical queries.
- Enabling GDExtension on web switches to the "extensions" export templates (larger download); measure before and after.

### 2.4 Communication rules

- **Down**: parents call methods on children/components directly.
- **Up**: children emit signals; parents connect.
- **Across systems**: `EventBus` signals for events that many systems care about.
- No absolute node paths. Use `@export` node references or `%UniqueName`.

`EventBus` signals (Milestone 1):

```gdscript
signal player_spawned(player: Player)
signal player_died()
signal damage_applied(target: Node, info: DamageInfo)
signal noise_emitted(event: NoiseEvent)
signal guard_state_changed(guard: Guard, old_state: StringName, new_state: StringName)
signal alert_level_changed(level: int)
signal interaction_completed(interactable: Interactable, actor: Node)
signal trigger_entered(trigger_id: StringName, body: Node)
signal objective_updated(objective_id: StringName, status: int)
signal mission_ended(success: bool)
```

---

## 3. Player Architecture

### 3.1 Scene composition

```text
Player (CharacterBody3D, class Player)
├── CollisionShape3D (capsule, height from StanceComponent)
├── MovementComponent
├── StanceComponent
├── HealthComponent
├── ExposureComponent          # light level + visibility score
├── NoiseEmitterComponent      # footsteps, landing, weapon
├── Head (Node3D)              # stance height
│   └── LeanPivot (Node3D)     # lean roll/offset
│       └── Camera3D
│           ├── Viewmodel (Node3D) → WeaponHolder
│           ├── Interactor (RayCast3D, 2.5 m)
│           └── EquipmentHolder
├── InventoryComponent
└── PlayerInput                # reads input, writes intents
```

### 3.2 Input → intent

`PlayerInput` converts raw input to an `InputIntent` struct each physics tick. Other components read intents, never raw input. This allows AI-driven test dummies and replays to drive the same player.

```gdscript
class_name InputIntent extends RefCounted
var move: Vector2
var look_delta: Vector2
var sprint: bool
var crouch_toggled: bool
var lean: int          # -1 left, 0 none, 1 right
var jump: bool
var fire: bool
var fire_pressed: bool
var aim: bool
var reload: bool
var interact: bool
var use_equipment: bool
```

### 3.3 Default bindings

| Action | Key | Notes |
|---|---|---|
| Move | W A S D | |
| Sprint | Shift (hold) | |
| Crouch | C (toggle) | Ctrl not used: Ctrl combos conflict with browser shortcuts |
| Lean | Q / E (hold) | |
| Jump | Space | |
| Fire / Aim | LMB / RMB | |
| Reload | R | |
| Interact | F (hold where required) | |
| Equipment | B (binoculars) | |
| Pause | Esc / P | Esc always releases pointer lock in browsers |
| Fire mode | X | |
| Debug overlay | F3 | Dev builds only |

All bindings are rebindable via the Input Map and persisted in settings.

---

## 4. Character Controller

### 4.1 Movement parameters (initial tuning; data in `data/player/player_movement.tres`)

| Parameter | Value |
|---|---|
| Walk speed | 3.2 m/s |
| Sprint speed | 5.8 m/s |
| Crouch speed | 1.7 m/s |
| Aiming speed multiplier | 0.6 |
| Acceleration (ground) | 30 m/s² |
| Deceleration (ground) | 40 m/s² |
| Air control | 0.25 |
| Jump velocity | 4.2 m/s |
| Stand / crouch capsule height | 1.80 m / 1.15 m |
| Eye height stand / crouch | 1.65 m / 1.00 m |
| Stance transition time | 0.25 s |
| Lean angle / offset | 12° / 0.35 m |
| Max slope | 40° |
| Step height | 0.35 m |

Equipment weight multiplies speeds (`1.0 − 0.01 × kg_over_free_limit`, clamped to 0.7). Milestone 1 sets this up but only binoculars exist.

### 4.2 Rules

- `CharacterBody3D.move_and_slide()` in `_physics_process`.
- Uncrouch and lean are blocked by a shape cast if there is no space.
- Lean is blocked while sprinting; sprint cancels when aiming, firing or crouching.
- Camera look is applied in `_process` from accumulated mouse delta for responsiveness; body yaw syncs in physics.
- Head bob and weapon sway are cosmetic, driven by velocity, and can be disabled in settings.

### 4.3 Pointer lock (web)

```text
Title / Pause screen
      │ user click (inside an input event handler)
      ▼
Input.mouse_mode = MOUSE_MODE_CAPTURED  →  browser grants pointer lock
      │
      │ user presses Esc / alt-tabs / browser revokes lock
      ▼
Platform detects mouse_mode != CAPTURED  →  Game.pause()  →  pause menu
```

- Capture is requested **only** from a click handler; browsers reject it otherwise.
- After Esc releases the lock, browsers enforce a short cooldown before re-locking is allowed; the "Resume" button must tolerate a failed first attempt and retry on the next click.
- `Platform` also listens for `document.visibilitychange` (via `JavaScriptBridge`) and pauses when the tab is hidden.

---

## 5. Weapon Framework

### 5.1 Data

```gdscript
class_name WeaponDefinition extends Resource

@export var id: StringName
@export var display_name: String
@export_group("Fire")
@export var damage: float = 34.0
@export var fire_rate_rpm: float = 750.0
@export var fire_modes: Array[StringName] = [&"semi", &"auto"]
@export var magazine_size: int = 30
@export var reserve_ammo: int = 90
@export var reload_time: float = 2.2
@export var reload_time_empty: float = 2.8
@export_group("Ballistics")
@export var muzzle_velocity: float = 880.0      # m/s
@export var gravity_scale: float = 1.0
@export var max_range: float = 400.0
@export var projectile_steps_per_tick: int = 4
@export var penetration_power: float = 0.0       # unused in Milestone 1
@export_group("Accuracy")
@export var spread_hip_deg: float = 2.5
@export var spread_ads_deg: float = 0.15
@export var spread_move_add_deg: float = 2.0
@export var spread_crouch_mult: float = 0.7
@export var recoil_pattern: Curve2D              # per-shot camera kick
@export var recoil_recovery: float = 8.0
@export_group("Stealth")
@export var noise_radius_m: float = 18.0         # suppressed
@export var suppressed: bool = true
@export_group("Presentation")
@export var viewmodel_scene: PackedScene
@export var audio_profile: WeaponAudioProfile
@export var animation_profile: WeaponAnimationProfile
```

Milestone 1 ships `data/weapons/rifle_suppressed.tres`. New weapons are new `.tres` files; core weapon code does not change.

### 5.2 Runtime

```text
WeaponHolder
└── Weapon (class Weapon, created from WeaponDefinition)
    state machine:  Idle ─fire→ Firing ─empty→ Empty
                     │  ▲                       │
                  reload│  └──────── done ───────┘ reload
                     ▼
                  Reloading (not interruptible in Milestone 1)
```

- Fire timing uses an accumulator so the RPM is exact at any frame rate.
- Each shot: compute spread cone → random direction (seeded `RandomNumberGenerator`) → spawn `Projectile` record in `BallisticsSystem` → apply recoil → emit `NoiseEvent` → play audio/VFX.

### 5.3 Ballistics (Milestone 1)

- Projectiles are **plain data records** in a pooled array inside `BallisticsSystem` (a node in the level), not scene instances.
- Each physics tick, each projectile advances in `projectile_steps_per_tick` segments: `velocity += gravity * dt`, raycast from previous to next position.
- First hit → build `DamageInfo` → `HealthComponent.apply_damage()` if the collider has one → spawn impact effect from the hit `SurfaceProfile`.
- Projectile removed on hit, on exceeding `max_range`, or after 2 s.
- Bullet travel time is short at these ranges, but the system is in place for penetration/ricochet in Milestone 2.

---

## 6. Damage System

```gdscript
class_name DamageInfo extends RefCounted
var amount: float
var type: StringName          # &"ballistic", &"melee", &"explosive", &"fall"
var source: Node              # instigator
var hit_position: Vector3
var hit_normal: Vector3
var direction: Vector3
var hit_zone: StringName      # &"head", &"torso", &"limb"
```

- Hit zones: each hit collision shape (on a `BoneAttachment3D`) has metadata `hit_zone` and a reference to the owner's `HealthComponent`.
- Zone multipliers live in `data/damage/hit_zones.tres`: head ×4.0, torso ×1.0, limb ×0.6.
- `HealthComponent`: `max_health`, `health`, `apply_damage(info) -> float`, signals `damaged(info)`, `died(info)`.
- Guard: 100 HP. Player: 100 HP, no regeneration in Milestone 1; damage direction indicator on HUD.
- Fall damage: above 4 m fall height, linear to lethal at 10 m.
- Damage to a guard always raises its suspicion to 100 (Combat) unless it dies from that hit.

---

## 7. AI Architecture

### 7.1 Guard scene

```text
Guard (CharacterBody3D, class Guard)
├── CollisionShape3D
├── Skeleton/Model (with hit-zone shapes on bone attachments)
├── NavigationAgent3D
├── HealthComponent
├── PerceptionComponent
├── SuspicionComponent
├── Brain (class GuardBrain — hierarchical state machine)
├── Blackboard (RefCounted, owned by Brain)
├── GuardWeapon (uses a WeaponDefinition)
├── NoiseEmitterComponent
└── DebugDraw (dev builds: cone, state label, suspicion bar)
```

Tuning lives in `GuardProfile` resources (`data/ai/guard_default.tres`): speeds, vision ranges, suspicion rates, accuracy, reaction time.

### 7.2 Decision model

Milestone 1 uses a **hierarchical finite state machine** (HFSM): simple, debuggable, and enough for one guard type. Each state is a class with `enter()`, `exit()`, `tick(delta) -> StringName` (next state or empty).

The interface is kept narrow so it can be replaced with a behavior tree in Milestone 2/3 without touching perception or movement.

```text
           ┌──────────────┐
           │    Patrol    │◄──────────────────────┐
           └──────┬───────┘                       │
   suspicion ≥ 40 │                               │ timeout,
   or noise heard │                               │ suspicion < 20
           ┌──────▼───────┐   suspicion ≥ 60  ┌───┴──────────┐
           │ Investigate  ├──────────────────►│    Search    │
           └──────┬───────┘                   └───┬──────────┘
                  │ suspicion ≥ 80                │ suspicion ≥ 80
                  ▼                               ▼
           ┌──────────────────────────────────────────┐
           │                 Combat                    │
           │  sub-states: Engage / Reposition / Chase  │
           └──────────────┬───────────────────────────┘
                          │ target lost > 8 s
                          ▼
                       Search ─── 45 s without contact ──► ReturnToPatrol ──► Patrol

           Any state ── health ≤ 0 ──► Dead
```

### 7.3 Blackboard (per guard)

| Key | Type | Notes |
|---|---|---|
| `target` | Node | Player when known |
| `last_known_position` | Vector3 | Updated by perception |
| `last_known_time` | float | Seconds since level start |
| `investigate_position` | Vector3 | From sight or noise |
| `confidence` | float 0–1 | How accurate the last known position is |
| `search_points` | Array[Vector3] | Generated around last known position |
| `patrol_route` | PatrolRoute | Assigned in level |
| `patrol_index` | int | |
| `alerted_by` | StringName | `&"sight"`, `&"noise"`, `&"damage"`, `&"body"` (later) |

Milestone 2 adds a squad-level blackboard with the same keys, shared through the squad.

### 7.4 State behaviour (summary)

| State | Behaviour |
|---|---|
| Patrol | Follow `PatrolRoute` points, wait at points with `wait_time` and optional look direction |
| Investigate | Stop, turn to stimulus (0.6 s), walk to `investigate_position`, look around 4 s |
| Search | Generate 4–6 navmesh points within 12 m of last known position, visit them, scan at each |
| Combat / Engage | Has line of sight: stop or strafe, aim with reaction delay (0.35 s) and accuracy error that shrinks over time |
| Combat / Reposition | Every 4–7 s, or when taking damage, move to a point with LOS to target (simple sampling in M1; tactical queries in M2) |
| Combat / Chase | No LOS: move to last known position |
| ReturnToPatrol | Walk to nearest patrol point, resume route; suspicion floor stays at 10 for 60 s |
| Dead | Ragdoll or death animation, disable collisions with player, stays in level (body detection in M2) |

Guards fire with the same `BallisticsSystem` as the player, so gameplay is symmetric.

---

## 8. Perception System

### 8.1 Vision

| Parameter | Default |
|---|---|
| Primary cone | 100° horizontal, 0–35 m |
| Peripheral cone | 160° horizontal, 0–10 m |
| Vertical limit | ±50° |
| LOS sample points on player | head, chest, pelvis (3 rays) |
| Collision mask for LOS | world geometry + doors + foliage-blockers |

Visibility for one check = fraction of sample points with clear LOS (0, 0.33, 0.67, 1.0). Leaning around a corner exposes only the head point, so leaning is meaningfully safer.

### 8.2 Hearing

- Gameplay noise is separate from audio playback. `NoiseEvent { position, radius_m, type, source, loudness }`.
- Types and default radii: footstep walk 4 m, sprint 12 m, crouch 1.5 m, landing 8 m, suppressed shot 18 m, unsuppressed shot 80 m, door 10 m, impact 12 m.
- Surface multiplier on footsteps (metal 1.5, grass 0.7).
- `NoiseSystem` delivers events to guards within `radius_m`. Each wall between source and listener (one raycast) multiplies effective radius by 0.5.
- A heard noise sets `investigate_position` and adds suspicion (§9.3).

### 8.3 Scheduler (frame budget)

`PerceptionScheduler` owns a queue of perception requests and executes at most **N rays per physics tick** (default 24).

| Guard distance to player | Vision update rate |
|---|---|
| < 15 m | 10 Hz |
| 15–40 m | 5 Hz |
| > 40 m | 1 Hz (cone test only, rays only if inside cone) |
| In Combat state | 10 Hz regardless |

Cheap tests first: distance → angle → (only then) raycasts. Timings are recorded in a custom `Performance` monitor (`ai/perception_ms`).

---

## 9. Stealth / Suspicion System

### 9.1 Player exposure (light level)

The web renderer cannot cheaply read back lighting, so light level is **authored**:

- `LightVolume` nodes (`Area3D` + box/sphere shape) with `light_level: float` (0 = pitch black, 1 = fully lit) and `priority`.
- The level sets an `ambient_light_level` (e.g. night 0.15, day 0.9).
- `ExposureComponent` on the player takes the highest-priority volume it overlaps, else ambient. Re-evaluated on area enter/exit, not per frame.
- A flashlight or muzzle flash temporarily raises exposure (muzzle flash: 1.0 for 0.1 s).
- Level art and light volumes are checked together (debug view colours the volumes); mismatches are a bug.

### 9.2 Suspicion gain from sight

Per vision update, if visibility > 0:

```text
gain_per_second = base_rate                      # 45 / s
                × visibility                      # 0.33 … 1.0 (LOS fraction)
                × f_distance(d)                   # 1.0 at ≤5 m → 0.15 at max range (smoothstep)
                × f_light(exposure)               # lerp(0.1, 1.0, exposure)
                × f_stance                        # stand 1.0, crouch 0.6
                × f_motion                        # still 0.5, walk 1.0, sprint 1.6
                × f_cone                          # primary 1.0, peripheral 0.4
                × f_state                         # Patrol 1.0, Investigate/Search 1.5, Combat 3.0

suspicion = min(100, suspicion + gain_per_second × dt_since_last_update)
```

**Instant detection:** within 3 m, visibility ≥ 0.67 and exposure ≥ 0.3 → suspicion = 100.

### 9.3 Suspicion from other sources

| Stimulus | Effect |
|---|---|
| Footstep / landing heard | +10 (cap at 45 so footsteps alone cause Investigate, not Search) |
| Suppressed shot / impact heard | +35, investigate at noise position |
| Unsuppressed shot heard | Set to 80 (Combat-ready search at position) |
| Took damage | Set to 100 |

### 9.4 Decay

- After 3 s without new stimulus, suspicion decays at 8 / s.
- Decay floor depends on state history: 0 normally, 10 after any Search for 60 s, 30 after any Combat for the rest of Milestone 1 sessions (guards stay wary).

### 9.5 Thresholds and feedback

| Range | Band | Guard behaviour | Player feedback |
|---|---|---|---|
| 0–20 | Normal | Patrol | None |
| 20–40 | Curious | Patrol, slows, turns head toward stimulus | White indicator filling |
| 40–60 | Suspicious | Investigate | Yellow indicator + bark |
| 60–80 | Searching | Search | Orange indicator |
| 80–100 | Combat | Combat | Red indicator, combat music sting |

HUD shows a directional suspicion indicator per guard (arc around crosshair pointing to the guard) plus a small player exposure meter (light level).

The `SuspicionComponent` is pure logic (no scene dependencies), so the formulas are unit-tested directly.

---

## 10. Navigation

- `NavigationRegion3D` per level, baked in editor; baked navmesh saved as a resource (no runtime baking in Milestone 1).
- Agent: radius 0.4 m, height 1.8 m, max climb 0.35 m, max slope 40°.
- Doors: `NavigationLink3D` through each doorway; guards open closed, unlocked doors via the interaction system (same `Interactable` as the player).
- `PatrolRoute` node: ordered child `PatrolPoint` markers (`wait_time`, optional `look_direction`, optional animation tag). Supports loop and ping-pong.
- `NavigationAgent3D` avoidance off in Milestone 1 (≤3 guards); path recompute throttled to max 2 Hz per agent.
- Search point generation: random points via `NavigationServer3D.map_get_closest_point` around the last known position, rejecting points closer than 3 m to each other.

---

## 11. Mission / Objective Framework

### 11.1 Data

```gdscript
class_name MissionDefinition extends Resource
@export var id: StringName
@export var display_name: String
@export var objectives: Array[ObjectiveDefinition]
@export var fail_conditions: Array[StringName]   # &"player_died", &"alarm_raised" (optional)

class_name ObjectiveDefinition extends Resource
@export var id: StringName
@export var text: String
@export var type: StringName          # &"reach_trigger", &"interact", &"eliminate", &"extract"
@export var target_id: StringName     # trigger_id / interactable_id / guard_id
@export var optional: bool = false
@export var activate_on: Array[StringName] = []   # objective ids that must complete first
@export var checkpoint_on_complete: bool = true
```

Level objects are referenced by **stable string IDs** (`trigger_id`, `interactable_id`, `guard_id`), never by node path, so missions survive level edits and future chunk streaming.

### 11.2 Runtime

- `MissionService.start(mission)` creates runtime objective records with status `Inactive → Active → Completed / Failed`.
- Objective handlers listen to `EventBus` (`trigger_entered`, `interaction_completed`, `damage_applied`/death) and complete matching active objectives.
- Completion of an objective with `checkpoint_on_complete` triggers `SaveService.save_checkpoint()`.
- When all non-optional objectives complete → mission ends with success.

### 11.3 Milestone 1 mission (`data/missions/m1_prototype.tres`)

```text
obj_reach_compound   reach_trigger  → trigger "compound_inner"
        ↓
obj_download_data    interact       → interactable "terminal_01" (hold 4 s)
        ↓
obj_extract          extract        → trigger "extraction_zone"
optional: obj_undetected  — complete the mission with no guard reaching Combat
```

---

## 12. Interaction System

```gdscript
class_name InteractionDefinition extends Resource
@export var id: StringName
@export var prompt_text: String            # "Open", "Download data"
@export var hold_duration: float = 0.0     # 0 = instant
@export var required_item: StringName = &""
@export var interrupt_on_damage: bool = true
@export var noise_radius_m: float = 0.0
@export var one_shot: bool = false
```

- `Interactable` (Node3D component on the target object) holds an `InteractionDefinition`, an `interactable_id`, an `enabled` flag, and virtual hooks `_can_interact(actor)`, `_on_completed(actor)`.
- `Interactor` (player RayCast3D, 2.5 m) finds the focused interactable, drives the prompt UI and hold progress, and calls `complete()`.
- AI uses the same `Interactable` API (guards open doors).
- Milestone 1 implementations: `Door` (open/close, animated, emits noise, toggles nav link), `Terminal` (hold 4 s, plays loop sound, completes objective).

---

## 13. Equipment Framework

```gdscript
class_name EquipmentDefinition extends Resource
@export var id: StringName
@export var display_name: String
@export var weight_kg: float
@export var slot: StringName             # &"gadget"
@export var scene: PackedScene           # behaviour + presentation
@export var blocks_weapon: bool = true
```

- `EquipmentHolder` equips one gadget at a time; equipping lowers the weapon.
- Equipment scenes implement `equip()`, `unequip()`, `use_primary(pressed)`, `use_secondary(pressed)`.
- Milestone 1: **Binoculars** — 4× and 8× zoom (camera FOV change), mouse sensitivity scaled by zoom, slight vignette shader, **tag guards** by aiming at them for 0.5 s (tagged guards show an outline/marker through walls for 60 s). Tagging is the first recon mechanic and reuses perception raycasts.

---

## 14. Audio (Milestone 1)

- Buses: `Master` → `Music`, `SFX` → (`Weapons`, `Footsteps`, `Ambience`), `UI`, `Voice`.
- `AudioStreamPlayer3D` for world sounds; pooled players for footsteps and impacts (max 24 concurrent 3D voices).
- Occlusion: one raycast from listener to source on play (and 4 Hz for looping sources); occluded sounds get volume −6 dB and use an occluded variant bus with low-pass. **Validate early** that the low-pass bus effect works in the single-threaded web build; if not, fall back to pre-filtered "muffled" sample variants.
- Audio unlocks on the click-to-start screen.
- Format: Ogg Vorbis for everything except very short UI sounds (WAV).

---

## 15. Basic UI

| Screen | Content |
|---|---|
| HTML loader (`web/shell.html`) | Logo, progress bar from Godot's loader callbacks, browser-compatibility message if WebGL 2 is missing |
| Title / click-to-start | "Click to play" (unlocks audio + pointer lock), Continue (if checkpoint), New Game, Settings |
| HUD | Crosshair (spread-reactive), ammo/fire mode, health, stance icon, exposure meter, suspicion indicators, objective text, damage direction, interaction prompt + hold progress |
| Pause | Resume (re-acquires pointer lock), Settings, Restart from checkpoint, Quit to title |
| Settings | Mouse sensitivity, invert Y, FOV (70–100), quality preset, render scale, master/music/SFX volume, head bob, key rebinding |
| Mission end | Success/fail, time, detected yes/no, optional objective result, Retry / Title |
| Debug overlay (F3, dev) | FPS, frame time, AI/perception/physics ms, draw calls, memory, guard states |

Built with Godot `Control` nodes and one shared `Theme`. All text through `tr()` keys from day one.

---

## 16. Save System

### 16.1 Storage

- `user://` maps to **IndexedDB** in the web build.
- Settings: `user://settings.cfg` (ConfigFile).
- Checkpoint: `user://saves/checkpoint.json`.
- On first launch, `Platform` calls `navigator.storage.persist()` through `JavaScriptBridge` to reduce eviction risk.
- Settings menu offers **Export save** (downloads the JSON via `JavaScriptBridge.download_buffer`) and **Import save** (file picker).

### 16.2 Checkpoint schema

```json
{
  "schema_version": 1,
  "build_id": "2026.10.20-abc1234",
  "saved_at_unix": 1792483200,
  "mission_id": "m1_prototype",
  "objectives": { "obj_reach_compound": "completed", "obj_download_data": "active" },
  "player": {
    "position": [12.0, 0.0, -4.5], "yaw": 1.57, "stance": "crouch",
    "health": 72.0, "weapon": { "id": "rifle_suppressed", "mag": 18, "reserve": 60 }
  },
  "guards": [
    { "guard_id": "guard_01", "alive": true, "state": "patrol", "position": [0, 0, 0], "suspicion_floor": 10 }
  ],
  "world": { "doors": { "door_02": "open" }, "tags": ["guard_01"] },
  "alert_level": 1
}
```

Rules:

- Every saveable node implements `save_state() -> Dictionary` and `load_state(data: Dictionary)`, keyed by its stable ID.
- `SaveService` runs **migrations** from older `schema_version`s; unknown future versions are rejected with a message.
- Writes go to a temp file then rename, to avoid half-written saves.
- Checkpoints only (no save-anywhere) in Milestone 1.

---

## 17. Asset Pipeline and Budgets

### 17.1 Pipeline

```text
Blender (.blend, source in LFS)
   ↓ export glTF 2.0 (.glb)  [or direct .blend import]
Godot import presets (per folder: characters / props / environment)
   ↓ LODs generated on import, collision from *-col naming or simplified meshes
Textures: PNG source → VRAM compressed on import (desktop formats)
Audio: WAV source → Ogg Vorbis on import (quality per category)
```

Naming: `snake_case`, prefix by type (`sm_` static mesh, `sk_` skinned, `t_` texture, `m_` material, `sfx_`, `mus_`).

### 17.2 Budgets (Milestone 1 level)

| Budget | Limit |
|---|---|
| Total compressed download (engine + content) | **≤ 60 MB** (target 45 MB) |
| Engine WASM + JS (Brotli) | measured each build; reported, not owned by content |
| Visible triangles (worst view, High) | ≤ 1.0 M |
| Draw calls (worst view, High) | ≤ 400 |
| Unique materials in level | ≤ 60 |
| Texture memory | ≤ 384 MB |
| Shadow-casting lights | 1 directional + 2 omni/spot |
| Max texture size | 2048 (characters/hero props), 1024 default |
| WASM heap peak | ≤ 1.5 GB |
| Concurrent 3D audio voices | 24 |

CI fails the build when a budget is exceeded (size and texture checks automated; triangle/draw-call checks via the performance scene in §18.4).

### 17.3 Finished-art hero area

Milestone 1 includes **one finished-art area** to prove that WebGL 2 visuals are good enough for the game, before content production is planned around them.

| Item | Decision |
|---|---|
| Location | The terminal building interior and its courtyard (where `obj_download_data` happens), roughly 25 m × 25 m |
| Rest of level | Graybox with final collision and lighting volumes |
| Lighting | Baked LightmapGI + reflection probes, 1 shadow-casting directional light, at most 2 dynamic lights |
| Assets | Redistributable free assets only (§17.4): Poly Haven / ambientCG CC0 models and textures, re-textured for a consistent look; 2–3 hero props modelled in Blender |
| Look target | Night-time, moonlit exterior + sodium-lit interior; readable dark/lit zones that match the light volumes |
| Post-processing | Tonemapping, colour grading, light vignette, night vision/thermal shaders on binoculars (later equipment) |

Budget (inside the §17.2 totals):

| Budget | Limit |
|---|---|
| Hero area compressed download | ≤ 20 MB |
| Hero area texture memory | ≤ 192 MB |
| Draw calls when looking into the hero area | ≤ 300 |

Acceptance (also §23 item 21):

- Holds the §19 minimum-tier target inside the hero area.
- Light and shadow in the art match the stealth light volumes (no "lit-looking but dark-for-AI" spots).
- Screenshots from the hero area are good enough to use for a public preview page.

### 17.4 Asset sourcing and licensing (zero budget, open source)

The project is open source with no asset budget. Assets live in a **public repository**, so every asset must allow **redistribution in source form**, not just use inside a game.

#### Licence rules

| Licence | Allowed? | Notes |
|---|---|---|
| CC0 / public domain | **Yes (preferred)** | No attribution required (credit anyway) |
| CC BY 3.0 / 4.0 | Yes | Attribution in `CREDITS.md` and in-game credits |
| CC BY-SA 3.0 / 4.0 | Yes, with care | Derived assets must also be CC BY-SA; keep them in separate folders |
| OGA-BY | Yes | Treat like CC BY |
| GPL (for art) | Avoid | Unclear obligations for art in games |
| Any NC (non-commercial) or ND (no-derivatives) | **No** | Not open-source compatible |
| "Royalty-free, no redistribution" (Mixamo, Sonniss GDC bundles, Fab / Unity Asset Store standard licences, Sketchfab standard) | **No** | Free to use, but cannot be published in a public repo |
| AI-generated 3D/textures/audio | **No (for now)** | Copyright status and tool terms unclear; revisit later |
| Anything ripped or copied from existing commercial games | **Never** | Copyright and trademark infringement |

#### Project licensing

- Code: **MIT**.
- Original assets made for the project: **CC BY 4.0**.
- Third-party assets keep their own licence.
- Use the **REUSE** convention (SPDX headers / `REUSE.toml`) so every file has a machine-checkable licence; `reuse lint` runs in CI and fails on unlicensed files.
- `content/LICENSES.md` ledger: asset, author, source URL, licence, date added, modifications.
- `CREDITS.md` + in-game credits screen generated from the ledger.

#### Sources

| Need | Source (redistributable) |
|---|---|
| PBR textures | Poly Haven (CC0), ambientCG (CC0) |
| HDRI skies | Poly Haven (CC0) |
| Environment props | Poly Haven models (CC0), Kenney (CC0, mostly stylised — use for blockout/prototype only), OpenGameArt (check each licence) |
| Prototype textures | Kenney Prototype Textures (CC0) |
| Human characters | MakeHuman / MPFB in Blender (exports from the bundled CC0 asset set are CC0) |
| Character animations | CMU motion capture database (free to use and redistribute; credit requested), plus custom Blender animation; check any other library's licence individually |
| Weapon models | Modelled in Blender (simple, low/mid-poly rifle); OpenGameArt CC0/CC BY as reference or base |
| First-person arms + weapon animation | Simple gloved-arms mesh modelled in Blender; **procedural animation** in Godot (recoil, sway, bob, reload via tweens and IK) |
| Sound effects | Freesound (CC0 and CC BY only), OpenGameArt audio, Kenney audio (CC0), own Foley recordings |
| Music | OpenGameArt / Free Music Archive tracks with CC0 or CC BY only; or none in Milestone 1 |
| Fonts | Google Fonts (SIL Open Font License) |
| Particle textures | Kenney Particle Pack (CC0) |
| Materials | Created in Material Maker (own work, CC BY 4.0) |

#### Who makes what (Milestone 1)

| Asset | Made by | Approach |
|---|---|---|
| Blockout level, layout, lighting | Developer | Godot CSG + prototype textures, LightmapGI |
| Hero-area buildings | Developer | Modular wall/floor/door kit modelled in Blender, textured with CC0 PBR textures |
| Hero props (terminal, desk, door) | Developer | Blender |
| Rifle | Developer | Blender, low/mid-poly, one texture set |
| First-person arms | Developer | Blender, simple mesh; procedural animation in Godot |
| Guard character | Developer | MPFB base human + simple modelled gear (vest, helmet) |
| Guard animations | Developer | CMU mocap retargeted in Blender for locomotion; hand-keyed aim/fire/death |
| Sounds | Developer | Freesound CC0/CC BY layers mixed in Audacity |
| UI, icons | Developer | Godot Controls + Krita, Google Fonts |

#### Keeping the scope realistic

- Animation is the most time-consuming area. Milestone 1 uses **procedural first-person animation** (no hand-keyed reloads) and a small guard set: idle, walk, run, crouch-walk, aim, fire, hit, death.
- Prefer reusing one modular kit across the whole hero area over many unique models.
- Open source means outside artists can contribute: after Milestone 1 is public, add `CONTRIBUTING.md` with art guidelines, the licence rules above and an "asset wanted" list.

#### Repository size

Free Git LFS quotas on GitHub are small. Keep `content/` lean:

- commit exported game-ready files (`.glb`, `.png`, `.ogg`) to LFS;
- keep large source files (`.blend` with high-poly sculpts, raw recordings) in a separate `lone-asset-art` repository or attach them to releases;
- check the current GitHub LFS storage/bandwidth limits before the art pass.

---

## 18. Test Strategy

### 18.1 Unit tests (GdUnit4, headless)

| Test | Covers |
|---|---|
| `test_suspicion.gd` | Gain formula factors, instant detection, decay, floors, thresholds |
| `test_weapon_state.gd` | Fire rate accuracy at 30/60/144 FPS, magazine/reserve, reload, fire modes |
| `test_spread_recoil.gd` | Spread by stance/movement/aim, deterministic with seed |
| `test_damage.gd` | Zone multipliers, death, fall damage |
| `test_mission_runner.gd` | Activation order, optional objectives, completion, checkpoint trigger |
| `test_save_schema.gd` | Round-trip, migration v0→v1, rejection of future versions, atomic write |
| `test_interaction.gd` | Hold, interrupt on damage, required items |
| `test_noise.gd` | Radius, wall attenuation, surface multipliers |

### 18.2 Integration / scenario tests (headless, test scenes in `tests/scenarios/`)

Driven by a scripted `PlayerDummy` that feeds `InputIntent`s:

```text
AI_Sees_Lit_Standing_Player      → Combat within expected time
AI_Misses_Dark_Crouched_Player   → stays below 40 at 15 m
AI_Hears_Sprint                  → Investigate at noise position
AI_Lean_Exposes_Head_Only        → slower gain than full exposure
AI_Search_Then_Return            → Search → ReturnToPatrol → Patrol
AI_Door_Navigation               → guard opens door and continues patrol
Mission_Full_Path                → objectives complete → mission success
Checkpoint_Reload                → state restored exactly
```

Tests run with a fixed physics tick and seeded RNG for determinism.

### 18.3 Browser tests (Playwright, CI on Chromium + Firefox)

- Page loads, Godot reports ready (`window.__lone_asset.ready === true` set via `JavaScriptBridge`).
- No uncaught console errors during load and 30 s of auto-play.
- Click-to-start transitions to gameplay.
- Save → reload page → Continue restores the checkpoint (IndexedDB).
- Tab hidden → game paused.

Pointer lock and real GPU performance cannot be fully tested headless; they are covered by the manual checklist.

### 18.4 Performance tests

- `tests/perf/perf_flythrough.tscn`: fixed camera path through the level with 3 guards in Combat, run for 60 s in the web build.
- Reports average FPS, 1 % low, frame-time histogram, draw calls, primitives, memory, and AI/perception ms to `window.__lone_asset.perf`, which Playwright collects into a CI artifact.
- GPU-dependent numbers are only meaningful on reference hardware (§19); CI tracks trends, runs on reference hardware gate the milestone (see §18.4.1).

#### 18.4.1 Remote benchmark (friends' machines)

Minimum-tier hardware is borrowed from friends, so the benchmark must run without the developer present:

- Title screen → Settings → **Run benchmark**: plays `perf_flythrough` for 60 s at the minimum-tier settings (1080p, render scale 0.75, Medium).
- Result screen shows pass/fail against §19 and a **Copy results** button that copies a JSON report: build ID, browser and version, GPU string (`WEBGL_debug_renderer_info` where available), OS, resolution, settings, average FPS, 1 % low, frame-time histogram, per-system ms, peak memory.
- Friends paste the report into a message; reports are stored in `docs/benchmarks/`.
- One benchmark round per work package from WP 8 onward, and a final round for acceptance.

### 18.5 Manual playtest checklist

Pointer lock gain/loss on Chrome, Firefox, Edge; mouse feel at 60/144 Hz displays; audio unlock; fullscreen toggle; window resize; long session (30 min) memory stability; "feel" review notes (movement, gunplay, stealth readability).

### 18.6 Solo playtest protocol

The developer is currently the only playtester, so playtests are made more objective by structure:

- **Record every playtest session** (screen + game audio, e.g. OBS) with the debug overlay off. Watch recordings back the next day.
- **Rating sheet** (1–5) after each session: movement feel, aiming/recoil, weapon audio, stealth readability ("I knew why I was seen"), AI believability, hero-area visuals, performance smoothness. Kept in `docs/playtests/YYYY-MM-DD.md`.
- **Gap rule**: the ratings that count for acceptance come from two sessions at least 3 days apart, so tuning is not judged straight after changing it.
- **Fresh-eyes checks**: play once with unfamiliar settings (different sensitivity/FOV, Medium preset) and once on the minimum-tier hardware.
- **Detection log**: in recordings, each time a guard reaches Combat, note whether the cause was visible from the HUD/audio. Unexplained detections are bugs.
- **Telemetry to a local file** (dev builds): detection events with cause, time to complete, deaths. Downloadable from the debug overlay.
- Before Milestone 2: recruit 1–2 outside testers via a preview URL.

---

## 19. Performance Requirements

### 19.1 Reference hardware

| Tier | Hardware | Browser | Target |
|---|---|---|---|
| Minimum | Laptop, integrated GPU (Intel Iris Xe / Radeon 680M class), 16 GB RAM | Chrome stable | 1080p, render scale 0.75, Medium preset: **60 FPS average, 1 % low ≥ 45** |
| Recommended | Desktop, GTX 1660 / RX 6600 class | Chrome / Firefox stable | 1440p, High preset: **60 FPS, 1 % low ≥ 55** |

Minimum-tier runs are done on friends' laptops using the remote benchmark (§18.4.1).

### 19.2 Frame budget (16.6 ms, minimum tier)

| System | Budget |
|---|---|
| Gameplay scripts (player, weapons, mission) | 2.5 ms |
| AI decision + navigation | 1.0 ms |
| Perception (rays) | 0.5 ms |
| Physics (Jolt) | 2.0 ms |
| Audio | 0.5 ms |
| Render CPU submission | 5.0 ms |
| Headroom (browser, GC, spikes) | 5.1 ms |

### 19.3 Loading

| Metric | Target |
|---|---|
| First visit, 50 Mbps | Playable ≤ 15 s |
| Repeat visit (cached) | Playable ≤ 5 s |
| Checkpoint reload | ≤ 2 s |

---

## 20. Development Folder Structure

```text
lone-asset/
├── ENGINE_VERSION
├── project.godot
├── export_presets.cfg
├── .gitattributes                 # LFS rules
├── .gitignore                     # .godot/, build/
│
├── game/
│   ├── autoload/                  # Log, EventBus, Game, Settings, SaveService, ...
│   ├── core/                      # state machine base, utils, ids, math
│   ├── player/                    # player.tscn, components, input
│   ├── weapons/                   # weapon runtime, ballistics, viewmodels
│   ├── damage/                    # DamageInfo, HealthComponent, hit zones
│   ├── ai/
│   │   ├── guard/                 # guard.tscn, brain, states
│   │   ├── perception/            # PerceptionComponent, scheduler
│   │   ├── stealth/               # SuspicionComponent, LightVolume, ExposureComponent
│   │   └── navigation/            # PatrolRoute, search point generation
│   ├── noise/                     # NoiseEvent, NoiseSystem, emitters
│   ├── missions/                  # MissionService, objective handlers
│   ├── interaction/               # Interactable, Interactor, Door, Terminal
│   ├── equipment/                 # EquipmentHolder, binoculars
│   ├── audio/                     # bus layout, pools, occlusion
│   ├── ui/                        # title, hud, pause, settings, end, debug
│   ├── save_system/               # schema, migrations
│   ├── platform/                  # web glue (JavaScriptBridge)
│   └── levels/
│       └── m1_compound/           # level scene, nav, light volumes, routes
│
├── data/
│   ├── player/
│   ├── weapons/
│   ├── ai/
│   ├── damage/
│   ├── equipment/
│   ├── interactions/
│   ├── surfaces/
│   └── missions/
│
├── content/                       # art + audio (LFS)
├── native/                        # GDExtension skeleton (C++, SConstruct)
├── addons/                        # gdUnit4 + other pinned addons
├── web/                           # shell.html, loader CSS, hosting header config
├── tools/                         # export, compress, budget-check scripts
└── tests/
    ├── unit/
    ├── scenarios/
    ├── perf/
    └── browser/                   # Playwright specs
```

---

## 21. Coding Conventions

### 21.1 GDScript

- Follow the official Godot GDScript style guide.
- **Static typing everywhere** (enforced by project warnings as errors).
- `class_name` for every reusable script; file name = `snake_case` of class name.
- Naming: `PascalCase` classes, `snake_case` functions/variables, `UPPER_SNAKE` constants, `_leading_underscore` private members, signals in past tense (`died`, `objective_completed`).
- Order within a file: `class_name`, `extends`, doc comment, signals, enums, constants, `@export`s, public vars, private vars, `@onready`, built-in callbacks, public methods, private methods.
- Gameplay logic in `_physics_process`; presentation in `_process`.
- No magic numbers in gameplay code — tuning lives in Resources.
- Never mutate a shared Resource at runtime; `duplicate()` per instance if runtime state is needed, or keep runtime state in a separate object.
- Use `StringName` (`&"id"`) for IDs and states.
- One seeded `RandomNumberGenerator` per system; no global `randf()` in gameplay code.
- Pure logic (suspicion, damage maths, mission runner) is written as `RefCounted` classes without scene dependencies so it can be unit-tested.

### 21.2 Scenes

- One root script per scene; behaviour in component child nodes.
- Use `%UniqueName` for internal references; `@export` for external references.
- Stable gameplay IDs (`guard_id`, `interactable_id`, `trigger_id`) are `@export` fields, validated unique by a level-check tool.

### 21.3 C++ (GDExtension, when used)

- C++20, godot-cpp pinned to engine version, clang-format, no exceptions/RTTI in hot paths, same naming as Godot's C++ style.

### 21.4 Process

- Solo developer: trunk-based with short-lived branches; CI green before merge; self-review of the diff against the checklist in §21.5 before merging.
- Conventional Commits.
- Every pull request includes the preview URL and notes on how to test it in the browser.

### 21.5 Self-review checklist (before merge)

- Diff re-read the next day for anything non-trivial.
- Typed, no new warnings, no magic numbers outside Resources.
- Tests added/updated; CI green.
- Tried in the **web** preview build, not only the editor.
- Debug overlay budgets unchanged or improved.

---

## 22. Work Breakdown and Order

Each step ends with a web build on the preview URL.

| # | Work package | Depends on | Exit check |
|---|---|---|---|
| 1 | Repo, project settings, export preset, CI export + deploy, HTML shell | — | Empty scene loads at preview URL |
| 2 | Autoloads skeleton, Game state machine, Platform (pointer lock, visibility) | 1 | Click-to-start, pause on Esc, tab-hide pause |
| 3 | Player controller (move, stance, lean, jump), graybox level | 2 | Movement tuning playtest |
| 4 | Weapon framework, ballistics, damage, target dummies | 3 | Gunplay playtest; unit tests green |
| 5 | Noise system, light volumes, exposure | 3 | Debug views show noise and light |
| 6 | Guard: navigation, patrol, HFSM skeleton | 3 | Guard patrols with doors |
| 7 | Perception + scheduler + suspicion | 5, 6 | Scenario tests green |
| 8 | Guard investigate / search / combat | 4, 7 | Full AI loop playtest |
| 9 | Interaction (door, terminal), mission framework, M1 mission | 6 | Mission completes end-to-end |
| 10 | Binoculars + tagging | 7 | Tagging works through walls |
| 11 | UI (HUD, pause, settings, end), audio pass | 4–10 | Feature complete |
| 12 | Save/checkpoint, export/import | 9 | Reload-page test green |
| 12b | Hero area: asset sourcing, art pass, baked lighting, post-processing | 9, 5 | §17.3 criteria met; `reuse lint` clean |
| 13 | Performance pass on reference hardware, budgets in CI | all | §19 targets met |
| 14 | Playtest round, tuning, bug fixing | all | Acceptance criteria (§23) |

---

## 23. Acceptance Criteria — Milestone 1

Milestone 1 is complete when **all** of the following hold in the **deployed web build**:

**Platform**
1. Loads and is playable in current stable Chrome, Edge and Firefox on desktop. (Safari is not a target.)
2. Meets §19 performance targets on both reference tiers, and §17.2 download/memory budgets.
3. Pointer lock, Esc-to-pause, resume, tab-hide pause and fullscreen work on all supported browsers.
4. No uncaught errors in the browser console during a full mission playthrough.

**Movement and gunplay**
5. Walk, sprint, crouch, lean and jump work with no getting stuck on the graybox geometry.
6. Rifle fires at the exact configured RPM at 30, 60 and 144 FPS; spread, recoil and reload behave per data.
7. Changing a value in `rifle_suppressed.tres` changes behaviour without code changes.

**Stealth and AI**
8. A crouched, still player in a dark volume at 15 m is not detected (suspicion < 40) by a patrolling guard.
9. A standing, moving player in a lit area within 10 m in the primary cone is detected (≥ 80) within 1.5 s.
10. Leaning around a corner fills suspicion more slowly than standing fully exposed.
11. Sprinting near a guard (within 12 m, no LOS) triggers Investigate toward the noise.
12. Guard goes Patrol → Investigate → Search → ReturnToPatrol → Patrol when the player hides, and Combat → Search when LOS is lost.
13. Guards open doors and navigate the whole level without getting stuck in 20 consecutive scenario runs.
14. Perception stays within its 0.5 ms budget with 3 guards in Combat on minimum-tier hardware.

**Mission, interaction, save**
15. The M1 mission can be completed both fully undetected and via combat.
16. Terminal hold interaction is interrupted by damage and resumes correctly.
17. Binoculars zoom and tag guards; tags display for 60 s.
18. A checkpoint survives a full page reload and browser restart, and restores mission, player, guards and doors.

**Quality**
19. All unit, scenario and browser tests pass in CI.
20. Solo playtest protocol (§18.6) completed: all feel criteria rated 4/5 or better in two sessions at least 3 days apart, and every detection in the recorded sessions is explainable from the HUD and audio alone.
21. The finished-art hero area meets the §17.3 visual and budget criteria on the minimum-tier hardware.

---

## 24. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Single-threaded performance insufficient for AI + physics + rendering | Medium | High | Budgets from day 1, AI LOD, GDExtension path proven early |
| Web audio bus effects limited in single-threaded build | Medium | Medium | Validate in WP 2–3; pre-filtered sample fallback |
| WebGL 2 visual quality feels dated | Medium | Medium | Strong art direction, baked lighting, post-processing; WebGPU later |
| Pointer lock behaviour differs across browsers | Medium | Medium | Manual matrix each milestone; tolerant resume logic |
| Developer is the only playtester (bias, blind spots) | High | Medium | Recorded sessions, 3-day gap between ratings, fresh-eyes checks (§18.6); recruit 1–2 outside testers before Milestone 2 |
| Solo capacity for finished art and animation | High | Medium | Hero area kept small; CC0 textures, modular kit, procedural FP animation; invite art contributors after Milestone 1 |
| A non-redistributable asset slips into the public repo | Medium | High | Licence ledger, `reuse lint` in CI, licence check before every import |
| Name conflict with an existing game or trademark | Low | High | "Lone Asset" had no existing-game matches in an initial search; run formal trademark searches (USPTO, EUIPO, WIPO) before any release |
| Hosting choice delayed | Medium | Medium | Provider-agnostic build; decide before WP 1 (§25.3) |
| Download size creep | High | Medium | CI size budget fails builds |
| IndexedDB eviction loses saves | Low | Medium | Persistence request, save export/import |
| Godot version upgrade breaks web export | Low | Medium | Pinned version, upgrade only on branch with full test pass |

---

## 25. Decisions (resolved open questions)

### 25.1 Art direction — decided
One finished-art hero area in Milestone 1; rest of the level is graybox. Details in §17.3.

### 25.2 Safari — decided
Safari is **not** a target for Milestone 1 or Milestone 2. Supported: current stable Chrome, Edge and Firefox on desktop. The HTML shell shows an "unsupported browser" note on Safari but does not block loading. Revisit before any public release.

### 25.3 Hosting — decided
**Cloudflare Pages**, deployed from GitHub Actions with Wrangler. `main` deploys to production; every other branch and pull request gets its own preview URL. Watch the 25 MiB per-file limit (§1.4).

### 25.4 Playtesting — decided
The developer is the only playtester for Milestone 1. Process in §18.6; acceptance item 20 updated accordingly. Recruit 1–2 outside testers before Milestone 2.
