# Lone Asset — Modern Tactical Stealth FPS
## Project Handoff & Development Summary (Web / WebAssembly Edition)

### 1. Project Objective

Build a modern tactical stealth FPS inspired by the gameplay philosophy of classic covert-operations shooters, delivered in the **web browser via WebAssembly (WASM)**, using modern game-engine technology, AI, animation, graphics, physics, audio, and software-engineering practices.

The project name is:

**Lone Asset**

The game must run in a desktop web browser with no install and no plugin. The player opens a URL and plays.

This document describes the technical and gameplay direction only. Story, characters, narrative, dialogue, and specific missions are intentionally excluded.

The project is **open source** and built with a **zero budget**: free and open-source tools only, and only assets whose licences allow redistribution in a public repository (see [Milestone 1 technical design](m1-technical-design.md), §17.4).

Lone Asset is an original project. It does not use names, characters, logos, maps, assets or audio from any existing game or franchise, and its marketing must not reference other games' trademarks.

---

# 2. Game Vision

The game should provide the experience of playing as a highly capable covert operative conducting operations behind enemy lines.

The core gameplay loop is:

```text
Observe
   ↓
Reconnaissance
   ↓
Plan
   ↓
Infiltrate
   ↓
Manipulate / Disable
   ↓
Complete Objective
   ↓
Adapt to Enemy Response
   ↓
Extract
```

Combat is available, but the game should not become a conventional run-and-gun FPS.

The player should be rewarded for:

- planning
- reconnaissance
- stealth
- tactical positioning
- information gathering
- equipment selection
- environmental awareness
- intelligent use of weapons and tools
- adapting to changing situations

---

# 3. Core Gameplay Pillars

## 3.1 Stealth

Stealth must be systemic rather than scripted.

Enemy detection should consider:

- player visibility
- distance
- lighting
- movement
- stance
- sound
- environmental obstruction
- enemy awareness
- disguise/context where applicable

The game should use a suspicion/awareness model rather than binary detection.

Example:

```text
0–20     Normal
20–40    Curious
40–60    Suspicious
60–80    Searching
80–100   Combat
```

Note for the web build: lighting-based visibility must not depend on reading back GPU lighting (expensive and unreliable in WebGL). Use designer-placed light volumes / light probes sampled on the CPU to compute a player "light level".

---

## 3.2 Tactical Combat

Combat should be dangerous and tactical.

Systems should support:

- weapon recoil
- weapon spread
- damage
- hit reactions
- ammunition
- reloads
- projectile simulation
- penetration
- material interaction
- suppression
- cover
- enemy coordination

Combat should complement stealth rather than replace it.

---

## 3.3 Reconnaissance

Reconnaissance should be a major gameplay mechanic.

Player tools may include:

- binoculars
- night vision
- thermal optics
- reconnaissance drones
- surveillance systems
- cameras
- hacking equipment

The player should be able to learn about an environment before committing to an approach.

Night vision and thermal are implemented as full-screen post-process shaders plus per-material "heat" parameters, which work within the WebGL 2 renderer.

---

## 3.4 Multiple Approaches

Major objectives should support multiple approaches.

Example:

```text
                 OBJECTIVE
                     │
          ┌──────────┼──────────┐
          │          │          │
       Stealth    Social      Assault
          │          │          │
       Tunnel     Access      Breach
```

Possible approaches can include:

- stealth infiltration
- long-range reconnaissance
- disguised access
- hacking
- environmental manipulation
- direct assault

The game should avoid forcing one predetermined solution whenever practical.

---

## 3.5 Dynamic Enemy Response

Enemy behavior should respond to player actions.

Example:

```text
Player remains undetected
        ↓
Normal patrol behavior

Suspicious activity detected
        ↓
Investigation

Confirmed threat
        ↓
Combat response

Communications disabled
        ↓
Reduced coordination

Alarm triggered
        ↓
Security response / reinforcements
```

Mission states should evolve dynamically.

---

# 4. Enemy AI

Enemy AI is one of the most important systems.

The AI should consist of multiple layers.

```text
                  AI Director
                       │
             ┌─────────┴─────────┐
             │                   │
          Squad AI          Individual AI
             │                   │
       ┌─────┼─────┐       ┌─────┼─────┐
       │     │     │       │     │     │
     Leader Scout Heavy  Perception Search Combat
```

## Individual AI

NPCs should support states such as:

```text
Patrol
Idle
Investigate
Suspicious
Search
Combat
Take Cover
Flank
Retreat
Communicate
Return To Patrol
```

## Perception

AI should detect:

- visual targets
- sounds
- gunshots
- footsteps
- explosions
- dead bodies
- suspicious behavior
- environmental changes

## Web performance budget

The browser build may run single-threaded, so AI must be time-sliced:

- perception raycasts are spread across frames (round-robin, fixed budget per frame)
- distant NPCs update at reduced frequency (AI LOD)
- per-frame AI budget is enforced and measured (see Section 29)

---

# 5. Squad AI

Enemy squads should maintain shared tactical information.

Potential shared data:

```text
EnemyLastKnownPosition
EnemyConfidence
SearchArea
AlertLevel
SquadFormation
CurrentObjective
AvailableCover
CommunicationState
```

This allows enemies to coordinate instead of every NPC independently knowing exactly where the player is.

Example:

```text
Guard A detects player
        ↓
Reports contact
        ↓
Squad receives approximate position
        ↓
Leader assigns roles
        ↓
One unit suppresses
One unit flanks
One unit searches
```

---

# 6. AI Director

The project should have a higher-level AI/Mission Director.

This is **gameplay AI**, not an LLM.

It monitors:

- player behavior
- alert state
- mission progress
- enemy availability
- communications status
- player equipment
- environmental conditions

It can dynamically adjust:

- enemy responses
- reinforcement behavior
- patrol behavior
- search areas
- mission events

The AI Director should remain deterministic and controllable by game designers.

LLMs should not be required for real-time NPC decision making.

---

# 7. Game Engine

## Godot 4 (Web export)

Primary engine:

**Godot 4.x**, exported to the web. The engine itself is compiled to **WebAssembly** (via Emscripten) and renders through **WebGL 2**.

Why Godot for this project:

- full editor for level design (critical for multi-route tactical maps)
- engine runs as WASM in the browser; no plugin
- open source (MIT), no royalties, engine source available for fixes
- text-based scene/resource formats that work well with Git
- native C++ extension path (GDExtension) that also compiles to WASM

Primary gameplay language:

**GDScript** (typed GDScript, static typing enforced)

Performance-critical systems:

**C++ via GDExtension**, compiled to WASM with Emscripten (e.g. perception queries, ballistics, AI tactical queries) — only where profiling shows GDScript is the bottleneck.

Important constraint: **Godot C# projects cannot currently be exported to the web.** Do not use C# for this project.

Alternatives considered:

| Option | Reason not chosen as primary |
|---|---|
| Unreal Engine 5 | No official web export since UE4.24; Nanite/Lumen unavailable in browsers |
| Unity 6 Web | Proprietary, large builds, licensing; viable fallback |
| Rust + Bevy | Excellent WASM/WebGPU support, but no mature level editor |
| Three.js / Babylon.js + WASM modules | Very web-native, but all engine tooling must be built in-house |

Use Godot's existing systems wherever practical instead of reinventing engine functionality.

---

# 8. Godot / Web Technology Stack

```text
Godot 4.x (Web export, WASM + WebGL 2)
│
├── Typed GDScript
├── GDExtension (C++ → WASM) for hot paths
├── Input Map + Pointer Lock (mouse capture)
├── Custom Ability/Action framework (data-driven Resources)
├── Custom Behavior Tree / State Machine (or a vetted addon)
├── Custom Tactical Query system (EQS-equivalent)
├── NavigationServer3D (navmesh, avoidance)
├── Chunked level streaming (resource packs)
├── Compatibility renderer (WebGL 2)
├── LightmapGI (baked lighting)
├── GPUParticles3D / CPUParticles3D
├── Audio buses + AudioStreamPlayer3D (Web Audio backend)
├── Jolt Physics (built in since Godot 4.4) / Godot Physics
├── AnimationTree + blend spaces
├── SkeletonModifier3D-based IK
└── High-level Multiplayer API (WebSocket / WebRTC peers)
```

Browser platform APIs used:

```text
WebAssembly
WebGL 2
Web Audio API
Pointer Lock API
Fullscreen API
Gamepad API
IndexedDB (save data, via Godot user://)
Fetch / HTTP (resource pack streaming)
WebSocket / WebRTC (multiplayer, later phase)
```

---

# 9. Graphics

Target: good-looking, readable, stylised-realistic visuals that hold **60 FPS on a mid-range laptop** in a browser.

The web build uses Godot's **Compatibility renderer (WebGL 2)**. The Forward+ and Mobile renderers, SDFGI, VoxelGI, volumetric fog and other high-end features are **not available** on the web.

Technology:

```text
WebGL 2 (Compatibility renderer)
Baked lightmaps (LightmapGI)
Reflection probes
Mesh LODs + visibility ranges (HLOD)
Occlusion culling (baked occluders)
KTX2 / Basis Universal compressed textures (ETC2/ASTC/S3TC targets)
Dynamic resolution / render scale
Post-process shaders (night vision, thermal, damage)
```

Rules:

- prefer baked lighting; limit real-time shadow-casting lights
- strict per-level budgets for triangles, draw calls, materials and texture memory
- texture atlasing and material sharing to reduce draw calls
- quality presets (Low / Medium / High) selectable at runtime

Future option: when Godot ships a WebGPU backend, evaluate migrating for better performance. Do not plan Milestone 1 around it.

Performance must be treated as an engineering requirement rather than something addressed at the end.

---

# 10. Animation

Character animation should use:

- AnimationTree with state machines and blend spaces
- root motion where appropriate
- aim offsets (2D blend space)
- procedural weapon alignment / sway
- SkeletonModifier3D-based IK (look-at, two-bone IK for hands and feet)
- procedural foot placement
- animation LOD (reduced update rate for distant characters)

Motion Matching and Control Rig are not available; the same goals are met with well-structured blend trees plus procedural layers.

Character animation should support:

- walking
- sprinting
- crouching
- prone
- leaning
- vaulting
- climbing
- weapon transitions
- hit reactions
- contextual movement

Animation retargeting is done offline (Blender) or via Godot's skeleton retargeting on import.

---

# 11. Weapon Architecture

Weapons should be data-driven.

In Godot, each weapon is a `WeaponDefinition` **Resource** (`.tres`), edited in the inspector.

Example:

```text
WeaponDefinition
│
├── Damage
├── FireRate
├── MagazineSize
├── ReloadTime
├── Recoil
├── Spread
├── ProjectileType
├── MuzzleVelocity
├── Penetration
├── Suppression
├── AudioProfile
└── AnimationProfile
```

Individual weapons should primarily be configurations/data rather than completely separate implementations.

The architecture should make it easy to add new weapons without modifying core weapon logic.

---

# 12. Ballistics

Potential ballistic system:

```text
Weapon Fire
     ↓
Projectile Simulation
     ↓
Velocity
     ↓
Gravity
     ↓
Material Interaction
     ↓
Penetration / Ricochet
     ↓
Damage
```

Implementation: projectiles are simulated as stepped raycasts (no physics body per bullet) to keep cost low in WASM. Candidate for C++ GDExtension if profiling requires it.

Materials can define behavior for:

- wood
- glass
- concrete
- steel
- brick
- dirt
- vehicles
- armor

Surface materials are `PhysicsMaterialProfile` Resources assigned to collision shapes.

---

# 13. Equipment System

Equipment should be modular.

Potential equipment:

```text
Binoculars
Night Vision
Thermal Optics
Recon Drone
Hacking Device
Camera
EMP Device
Breaching Equipment
Lock Bypass Tools
Surveillance Equipment
```

Equipment should have limitations and tradeoffs.

For example:

```text
Heavy equipment
      ↓
Greater capability
      ↓
Higher weight
      ↓
Reduced mobility
```

---

# 14. Recon Drone

A reconnaissance drone can be a major gameplay system.

Architecture:

```text
Player
  │
  ▼
Recon Drone
  │
  ├── Camera
  ├── Thermal
  ├── Audio
  ├── Target Marking
  └── Limited Communication
```

Constraints should include:

- battery
- range
- noise
- detection risk
- signal interference

Web note: the drone view switches the active camera rather than rendering a second simultaneous viewport, to avoid doubling GPU cost.

---

# 15. Interaction System

Create a reusable interaction framework.

Potential interactions:

```text
Doors
Terminals
Cameras
Security Systems
Vehicles
Ladders
Loot
Documents
Keycards
Equipment
Environmental Objects
```

Interaction should be data-driven.

Example:

```text
Interactable
│
├── Interaction Type
├── Required Item
├── Required Skill
├── Animation
├── Duration
├── Result
└── Failure Behavior
```

---

# 16. Hacking System

Hacking should be grounded and gameplay-oriented.

Possible systems:

```text
Security Cameras
Doors
Alarms
Communications
Power
Elevators
Access Control
```

Rather than using cinematic instant hacks, hacking should involve acquiring access and choosing which systems to manipulate.

---

# 17. Mission Framework

Mission logic should be data-driven and reusable.

```text
Mission
│
├── Primary Objectives
├── Optional Objectives
├── Triggers
├── Conditions
├── World Events
├── AI States
├── Mission State
├── Failure Conditions
├── Extraction
└── Rewards
```

Example:

```text
Objective 1
    ↓
Objective 2
    ↓
Objective 3
    ↓
Extraction
```

Objectives should also support branching and dynamic updates.

---

# 18. Persistent World State

Player actions should potentially influence later gameplay.

Example:

```text
Player disables communications
          ↓
Future mission
          ↓
Reduced enemy coordination
```

The system should maintain persistent operational state without requiring an enormous RPG-style branching narrative.

World state is serialised to `user://` (backed by IndexedDB in the browser). See Section 23.

---

# 19. Level Design

Maps should be designed around tactical freedom.

Typical structure:

```text
                 OBJECTIVE
                     │
        ┌────────────┼────────────┐
        │            │            │
      Route A      Route B      Route C
        │            │            │
     Stealth      Access       Combat
```

Levels should include:

- multiple infiltration routes
- alternate exits
- verticality
- observation positions
- cover
- restricted areas
- environmental interactions
- tactical chokepoints
- extraction options

Web constraint: levels must be designed with sight-line blockers and zone boundaries that allow occlusion culling and chunk streaming to work (see Section 20).

---

# 20. World Technology

There is no World Partition equivalent on the web, so large environments use a custom **chunk streaming** system:

```text
Level
│
├── Persistent core (player, mission logic, navmesh, AI director)
└── Chunks (geometry, props, lighting) loaded by distance / zone
        │
        ├── packaged as separate resource packs (.pck)
        ├── downloaded on demand over HTTP
        └── loaded with background resource loading
```

Rules:

- each chunk has a download-size and memory budget
- the next likely chunks are prefetched while the player is in recon/planning
- a mission must be playable without waiting on network loads mid-combat (preload the active play area before the mission starts)

Potential environment categories:

- military bases
- industrial facilities
- urban environments
- forests
- deserts
- snow regions
- underground facilities
- research facilities

The campaign should deliberately vary environments to prevent visual and gameplay repetition.

Dense vegetation (forests) is expensive in WebGL; use MultiMeshInstance3D, impostors and aggressive visibility ranges.

---

# 21. Vehicles

If vehicles are included:

**Godot VehicleBody3D** (or a custom raycast vehicle on Jolt)

Potential vehicles:

- military vehicles
- trucks
- boats
- helicopters
- utility vehicles

Vehicles should initially remain secondary to the core infantry/stealth experience, and are out of scope for the first web milestones.

---

# 22. Audio

Use:

**Godot audio buses + AudioStreamPlayer3D**, running on the browser's **Web Audio API** backend.

Audio should communicate gameplay information.

Important systems:

- footsteps
- gunshots
- explosions
- radio communications
- environmental sounds
- vehicle audio
- weapon audio
- occlusion (raycast-based, driving low-pass filter and volume)
- distance
- direction

Web constraints:

- browsers block audio until the first user interaction; the start screen must require a click/keypress
- in single-threaded web builds Godot uses Web Audio "sample" playback, where some bus effects are limited — validate the occlusion/reverb approach in Milestone 1
- use Ogg Vorbis for compressed audio to keep download size small

Sound should contribute directly to stealth and situational awareness. The **gameplay** sound-propagation system (what AI hears) is separate from audio playback and does not depend on the audio backend.

---

# 23. Backend & Hosting

For the initial single-player game, backend requirements should remain minimal.

Core:

```text
Static hosting + CDN (the game itself)
Local Save (IndexedDB via Godot user://)
Settings (IndexedDB)
Optional Cloud Save
```

Static hosting requirements:

```text
Correct MIME type: application/wasm
Brotli/gzip compression for .wasm, .pck, .js
Long-lived cache headers with hashed file names
HTTPS
Optional: Cross-Origin-Opener-Policy: same-origin
          Cross-Origin-Embedder-Policy: require-corp
          (only needed if the thread-enabled web export is used)
```

Default to the **single-threaded web export** (supported since Godot 4.3) so the game runs on any static host and embeds on game portals without COOP/COEP headers. Evaluate the threaded export only if profiling shows a clear win.

Browser storage can be evicted by the browser; request persistent storage (`navigator.storage.persist()`) and offer save export/import or cloud save.

If multiplayer/co-op is added:

```text
Browser Client
     ↓ WebSocket / WebRTC
Dedicated Server (headless Godot, Linux)
     ↓
Backend Services
     ├── Authentication
     ├── Player Profiles
     ├── Matchmaking
     ├── Statistics
     └── Cloud Data
```

Possible backend technology:

```text
Node.js
TypeScript
Fastify
PostgreSQL
Redis
Docker
Cloud Infrastructure
```

The backend should not unnecessarily complicate the single-player game.

---

# 24. Multiplayer

Multiplayer/co-op is a possible later phase.

Architecture:

```text
Client A (browser) ─────┐
Client B (browser) ─────┼── Dedicated Server (headless Godot)
Client C (browser) ─────┘
```

Browsers cannot open raw UDP sockets or host servers, so transport is:

- **WebSocketMultiplayerPeer** (simplest, TCP, higher latency under packet loss), or
- **WebRTCMultiplayerPeer** (unreliable/unordered channels, better for fast-paced play; requires signalling server)
- WebTransport may be evaluated later

Server-authoritative systems should control:

- player state
- damage
- objectives
- AI
- mission state
- important gameplay events

Client-side prediction and interpolation should be used where appropriate, built on Godot's high-level multiplayer API (MultiplayerSynchronizer / RPCs).

Multiplayer should **not** be built before the single-player gameplay loop is proven.

---

# 25. Development Tools

Recommended content pipeline:

### Engine / Code

- Godot 4.x editor (pinned version for the whole team)
- VS Code or JetBrains Rider with GDScript support
- Emscripten SDK (version matching the Godot export templates) for GDExtension builds
- Browser DevTools (Chrome/Firefox performance and memory profilers)

### 3D

All tools are free; open-source tools preferred.

- Blender (modelling, sculpting, UVs, rigging, animation; direct `.blend`/glTF import into Godot)
- MPFB (MakeHuman plugin for Blender) for base human characters

### Texturing

- Material Maker (open source, node-based materials — Substance Designer alternative)
- Blender texture painting / ArmorPaint (Substance Painter alternative)
- Krita / GIMP for 2D and UI
- Texture export via Godot import (VRAM compression)

### Audio

- Audacity (editing), LMMS or Ardour (music)

### Environment

- Blender geometry nodes (procedural props/terrain)
- Terrain addon for Godot (e.g. Terrain3D) — verify web compatibility before adoption

### Animation

- CC0 / freely redistributable animation libraries and mocap (e.g. CMU mocap), cleaned in Blender
- Procedural animation in Godot for first-person weapon handling
- Godot AnimationTree

Asset format: **glTF 2.0** everywhere.

---

# 26. Repository Structure

Suggested high-level structure:

```text
lone-asset/
│
├── project.godot
├── export_presets.cfg
│
├── game/                    # GDScript gameplay code + scenes
│   ├── core/
│   ├── player/
│   ├── characters/
│   ├── weapons/
│   ├── ai/
│   ├── missions/
│   ├── vehicles/
│   ├── interaction/
│   ├── equipment/
│   ├── inventory/
│   ├── animation/
│   ├── audio/
│   ├── ui/
│   ├── streaming/
│   ├── multiplayer/
│   └── save_system/
│
├── data/                    # Resources: weapon/equipment/mission definitions (.tres)
│
├── content/                 # Art assets (Git LFS)
│   ├── characters/
│   ├── weapons/
│   ├── environments/
│   ├── materials/
│   ├── vfx/
│   └── audio/
│
├── native/                  # GDExtension C++ source (compiled to WASM + desktop)
│   ├── src/
│   └── SConstruct
│
├── addons/                  # Third-party Godot addons (pinned versions)
│
├── web/                     # Custom HTML shell, loader UI, hosting headers config
│
├── tools/                   # Build, packing, asset-validation scripts
│
└── tests/                   # GdUnit4 / GUT tests
```

---

# 27. Version Control

Godot's scenes and resources are text-based, so Git works well.

### Preferred

**Git + Git LFS** (GitHub)

- source code, scenes (`.tscn`), resources (`.tres`) → regular Git
- binary art (`.blend`, `.png`, `.wav`, `.glb`, source textures) → Git LFS
- `.godot/` import cache → ignored

Perforce is not required at this scale. Re-evaluate only if the art team and asset volume grow significantly.

Do not place large binary assets in Git without LFS.

---

# 28. CI/CD

Use automated builds.

Potential pipeline:

```text
Developer Commit
       ↓
GitHub
       ↓
CI (GitHub Actions)
       ├── Build GDExtension (Emscripten → WASM, plus Linux for server/tests)
       ├── Static checks (typed GDScript, gdlint/format)
       ├── Unit Tests (headless Godot)
       ├── Functional / AI Tests (headless Godot)
       ├── Asset budget validation (size, triangles, textures)
       ├── Web Export (headless, release template)
       ├── Size report (wasm + pck, compressed)
       ├── Browser smoke test (Playwright: loads, renders, no console errors)
       └── Deploy preview build to static host / CDN
```

Every pull request should produce a playable preview URL.

For dedicated servers (later phase):

```text
Source
  ↓
Build (headless Linux export)
  ↓
Server Package
  ↓
Container
  ↓
Deployment
```

---

# 29. Testing Strategy

Testing should begin early.

Test framework: **GdUnit4** (or GUT), run headless in CI.

## Unit Tests

Examples:

```text
WeaponDamageTest
InventoryTest
MissionStateTest
SaveGameTest
AIStateTest
EquipmentTest
```

## Functional Tests

Example:

```text
Player enters area
      ↓
Objective activates
      ↓
Player completes objective
      ↓
Mission state changes
      ↓
Extraction activates
```

## AI Tests

```text
NPC detects player
NPC becomes suspicious
NPC investigates
NPC searches
NPC loses target
NPC returns to patrol
```

## Browser Tests

```text
Game loads in Chrome, Edge, Firefox (desktop)
Pointer lock acquire / release (Esc) handled correctly
Audio starts after first user interaction
Save → reload page → load works (IndexedDB)
Tab hidden / resumed does not break simulation
Window resize / fullscreen toggle
```

## Performance Tests

Track:

```text
FPS
Frame Time
CPU (script / physics / AI) Time
GPU Time
WASM heap memory
JS heap memory
Draw Calls
AI Cost
Initial download size (compressed)
Time to first playable frame
Network Bandwidth (multiplayer phase)
```

Reference hardware: a mid-range laptop with integrated graphics, and a mid-range desktop GPU.

---

# 30. Development Philosophy

Do not attempt to build the complete game immediately.

The project must be developed through progressively larger validated milestones.

Validate in the **browser from day one**. A feature is not "done" when it works in the editor; it is done when it works in the web export on reference hardware.

---

# 31. Milestone 1 — Core Prototype

Build only:

```text
Player
+
Basic Movement
+
One Weapon
+
One Enemy
+
AI Perception
+
Basic Stealth
+
Basic Environment
+
Web export deployed to a URL
```

Goal:

**Prove that movement, shooting and stealth feel good — in the browser.**

Also prove the web pipeline: export, compression, hosting, pointer lock, audio unlock, save to IndexedDB, and performance on reference hardware.

---

# 32. Milestone 2 — Vertical Slice

Build one complete playable operation.

Required:

```text
Player
Weapon
Stealth
Enemy AI
Patrols
Alarm
Recon
Objective
Combat
Extraction
Save
Basic UI
Chunk streaming (at least two chunks)
```

Example flow:

```text
Start
 ↓
Recon
 ↓
Infiltration
 ↓
Objective
 ↓
Enemy Response
 ↓
Combat / Escape
 ↓
Extraction
 ↓
Mission Complete
```

This is the most important milestone.

If this vertical slice is not fun, the full game should not proceed to large-scale content production.

---

# 33. Milestone 3 — Core Framework

Once the vertical slice works, extract reusable systems:

```text
Mission System
AI System
Weapon System
Inventory
Equipment
Interaction
Save System
Dialogue System
Cinematics
Audio
UI
World State
Streaming / Asset Packaging
```

The goal is to make future missions primarily content/configuration work rather than repeated engine programming.

---

# 34. Milestone 4 — Campaign Production

Only after the core framework is stable should large-scale content production begin.

Production includes:

- levels
- environments
- characters
- weapons
- animations
- audio
- VFX
- objectives
- cinematics
- mission scripting
- QA (including cross-browser QA)

---

# 35. Initial Scope

The project should initially target:

### Single-player

### Desktop web browsers (Chrome, Edge, Firefox; Safari not targeted before Milestone 3)

### Godot 4 Web export (WASM + WebGL 2)

### Keyboard + mouse (gamepad optional)

### Modern tactical stealth FPS

### One polished vertical-slice mission

Out of scope for the first milestones: mobile browsers, touch controls, multiplayer, native desktop/console builds, WebGPU, large-scale procedural generation, advanced online infrastructure, vehicles.

Note: because the game is built in Godot, native desktop builds (Windows/Linux/macOS) can be added later from the same project at low cost.

---

# 36. Browser Platform Constraints

These constraints shape every technical decision:

| Constraint | Impact | Mitigation |
|---|---|---|
| WebGL 2 only (no WebGPU in Godot yet) | Lower GPU feature set | Baked lighting, LODs, Compatibility renderer budgets |
| WASM 32-bit memory (max 4 GB, practical ~2 GB) | Limits loaded content | Chunk streaming, texture compression, memory budgets |
| Single-threaded by default | AI/physics/streaming share one thread | Time-slicing, AI LOD, GDExtension hot paths |
| Download size | Load time, player drop-off | Brotli, KTX2, Ogg, split resource packs, preload screen |
| Audio autoplay policy | No sound before interaction | Click-to-start screen |
| Pointer Lock / Esc behaviour | Esc always releases the mouse | Pause menu on pointer-lock loss; don't bind Esc to gameplay |
| Browser shortcuts (Ctrl+W, Ctrl+T, F5) | Cannot be overridden reliably | Avoid Ctrl-based bindings; confirm-on-leave prompt |
| Storage eviction | Saves may be lost | `navigator.storage.persist()`, save export, cloud save |
| Tab backgrounding throttles timers | Simulation pauses | Auto-pause when tab hidden |
| GPU/driver variance across browsers | Visual bugs, perf variance | Cross-browser CI smoke tests, quality presets |

---

# 37. Technology Summary

| Category | Technology |
|---|---|
| Platform | Desktop web browser |
| Runtime | WebAssembly (Emscripten) + WebGL 2 |
| Engine | Godot 4.x (Web export) |
| Main Language | Typed GDScript |
| Native / Hot Paths | C++ via GDExtension (compiled to WASM) |
| AI | Custom Behavior Tree / State Machine + Tactical Queries |
| Navigation | Godot NavigationServer3D |
| Rendering | Compatibility renderer, LightmapGI, LODs, occlusion culling |
| Textures | KTX2 / Basis Universal |
| Animation | AnimationTree + blend spaces + SkeletonModifier3D IK |
| Physics | Jolt (built in) / Godot Physics |
| VFX | GPUParticles3D / CPUParticles3D + shaders |
| Audio | Godot audio buses on Web Audio API |
| Save | IndexedDB (Godot `user://`) |
| Streaming | Split resource packs (.pck) over HTTP |
| 3D | Blender (glTF 2.0) |
| Sculpting | Blender |
| Texturing | Material Maker / Blender / Krita |
| Licence | Code: MIT; original assets: CC BY 4.0; third-party assets: their own (tracked) |
| Testing | GdUnit4 / GUT + Playwright |
| Version Control | Git + Git LFS |
| CI/CD | GitHub Actions |
| Hosting | Static host + CDN (Brotli, HTTPS) |
| Backend (later) | Node.js + TypeScript + Fastify |
| Database (later) | PostgreSQL |
| Cache (later) | Redis |
| Containers (later) | Docker |
| Multiplayer (later) | Headless Godot server + WebSocket / WebRTC |
| Cloud | AWS / Azure / GCP / Cloudflare |

---

# 38. Immediate Next Step

Do **not** start implementing the entire game.

The next task is to produce a detailed **Technical Design Document for Milestone 1 (Web)**, covering:

1. Godot project setup and pinned engine/export-template versions
2. Web export configuration (single-threaded, compression, HTML shell, hosting headers)
3. Code module structure (GDScript + GDExtension boundary)
4. Player architecture
5. Character controller (including pointer lock handling)
6. Weapon framework
7. Damage system
8. AI architecture
9. Perception system (with per-frame budget)
10. Stealth/suspicion system (including CPU-side light level)
11. Navigation
12. Mission/objective framework
13. Interaction system
14. Equipment framework
15. Basic UI (loading screen, click-to-start, HUD, pause)
16. Save system (IndexedDB, persistence request)
17. Asset pipeline and budgets (glTF, KTX2, Ogg, download size)
18. Test strategy (headless + browser)
19. Development folder structure
20. Coding conventions
21. Performance requirements on reference hardware
22. Acceptance criteria for the vertical slice

The implementation should be **incremental, testable, modular, data-driven, production-oriented, and browser-first**.

The primary goal is not to produce a large amount of code.

The primary goal is to establish a strong gameplay foundation that can scale from a browser prototype into a complete tactical FPS.
