# Lone Asset — Modern Tactical Stealth FPS
## Project Handoff & Development Summary (Desktop Edition)

### 1. Project Objective

Build a modern tactical stealth FPS inspired by the gameplay philosophy of classic covert-operations shooters, delivered as a **desktop game for Windows and Linux**, using modern game-engine technology, AI, animation, graphics, physics, audio, and software-engineering practices.

The project name is:

**Lone Asset**

The player downloads a zip, unzips it and runs the game; no installer. (Milestone 1 started as a browser game; on 2026-11-02 the project moved to desktop only for better graphics and performance. See Section 36.)

This document describes the technical and gameplay direction only. Story, characters, narrative, dialogue, and specific missions are intentionally excluded.

The project is **open source** and built with a **zero budget**: free and open-source tools only, and every third-party asset recorded in the licence ledger (see [Milestone 1 technical design](m1-technical-design.md), §17.4).

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

Lighting-based visibility must not depend on reading back GPU lighting (expensive and a frame late). Use designer-placed light volumes / light probes sampled on the CPU to compute a player "light level".

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

Night vision and thermal are implemented as full-screen post-process shaders plus per-material "heat" parameters, which work on every renderer including the OpenGL fallback.

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

## Performance budget

AI must stay cheap enough for minimum-spec laptops, so it is time-sliced:

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

## Godot 4 (desktop export)

Primary engine:

**Godot 4.x**, exported as native Windows and Linux applications (macOS later if there are testers for it).

Why Godot for this project:

- full editor for level design (critical for multi-route tactical maps)
- open source (MIT), no royalties or fees, engine source available for fixes
- text-based scene/resource formats that work well with Git
- the Forward+ renderer (Vulkan / Direct3D 12) covers the visual target (Section 9)
- native C++ extension path (GDExtension) for hot paths

Primary gameplay language:

**GDScript** (typed GDScript, static typing enforced)

Performance-critical systems:

**C++ via GDExtension** (e.g. perception queries, ballistics, AI tactical queries) — only where profiling shows GDScript is the bottleneck.

C# would now be possible (it was ruled out while the game targeted the web), but the code base is typed GDScript and stays that way.

Alternatives considered:

| Option | Reason not chosen |
|---|---|
| Unreal Engine 5 | Best photorealism, but a full rewrite (C++/Blueprints), heavy tooling, not open source; its strengths (Nanite, Lumen, MetaHuman) need content a zero-budget team cannot make |
| Unity 6 | Full rewrite in C#, proprietary licence with a history of sudden changes |
| Rust + Bevy | No mature level editor |

Use Godot's existing systems wherever practical instead of reinventing engine functionality.

---

# 8. Godot Technology Stack

```text
Godot 4.x (Windows / Linux export)
│
├── Typed GDScript
├── GDExtension (C++) for hot paths
├── Input Map + mouse capture
├── Custom Ability/Action framework (data-driven Resources)
├── Custom Behavior Tree / State Machine (or a vetted addon)
├── Custom Tactical Query system (EQS-equivalent)
├── NavigationServer3D (navmesh, avoidance)
├── Chunked level streaming (resource packs)
├── Forward+ renderer (Vulkan / Direct3D 12), OpenGL 3.3 fallback
├── LightmapGI (baked lighting), SDFGI / VoxelGI where affordable
├── GPUParticles3D / CPUParticles3D
├── Audio buses + AudioStreamPlayer3D
├── Jolt Physics (built in since Godot 4.4)
├── AnimationTree + blend spaces
├── SkeletonModifier3D-based IK
└── High-level Multiplayer API (ENet over UDP, later phase)
```

---

# 9. Graphics

Target: good-looking, readable, stylised-realistic visuals that hold **60 FPS on a mid-range laptop**.

The game uses Godot's **Forward+ renderer** (Vulkan on Linux and Windows, Direct3D 12 available on Windows). Machines without Vulkan support fall back to the OpenGL 3.3 Compatibility renderer automatically (`rendering_device/fallback_to_opengl3`), with fewer effects.

Technology:

```text
Forward+ renderer
Baked lightmaps (LightmapGI) as the base lighting
SDFGI / VoxelGI, volumetric fog, SSAO / SSIL / SSR (quality presets decide)
Reflection probes
Mesh LODs + visibility ranges (HLOD)
Occlusion culling (baked occluders)
VRAM-compressed textures (BPTC / S3TC)
TAA / FSR 2 upscaling, render scale
Post-process shaders (night vision, thermal, damage)
```

Rules:

- prefer baked lighting for the static world; limit real-time shadow-casting lights
- strict per-level budgets for triangles, draw calls, materials and texture memory
- texture atlasing and material sharing to reduce draw calls
- quality presets (Low / Medium / High) selectable at runtime; Low must look acceptable on the OpenGL fallback

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

Implementation: projectiles are simulated as stepped raycasts (no physics body per bullet) to keep cost low. Candidate for C++ GDExtension if profiling requires it.

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

Performance note: the drone view switches the active camera rather than rendering a second simultaneous viewport, to avoid doubling GPU cost.

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

World state is serialised to `user://` (the per-user application data folder). See Section 23.

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

Levels must be designed with sight-line blockers and zone boundaries that allow occlusion culling and chunk streaming to work (see Section 20).

---

# 20. World Technology

Godot has no World Partition equivalent, so large environments use a custom **chunk streaming** system:

```text
Level
│
├── Persistent core (player, mission logic, navmesh, AI director)
└── Chunks (geometry, props, lighting) loaded by distance / zone
        │
        ├── packaged as separate resource packs (.pck)
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

Dense vegetation (forests) is expensive; use MultiMeshInstance3D, impostors and aggressive visibility ranges.

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

Vehicles should initially remain secondary to the core infantry/stealth experience, and are out of scope for the first milestones.

---

# 22. Audio

Use:

**Godot audio buses + AudioStreamPlayer3D**.

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

Notes:

- Milestone 1 muffles sounds behind walls with pre-filtered copies (a web-era workaround). On desktop, bus effects (low-pass, reverb) work and can replace it.
- use Ogg Vorbis for compressed audio to keep the download small

Sound should contribute directly to stealth and situational awareness. The **gameplay** sound-propagation system (what AI hears) is separate from audio playback and does not depend on the audio backend.

---

# 23. Backend & Hosting

For the single-player game there is no backend.

```text
Game builds: GitHub Releases (a rolling "preview" pre-release from main; tagged releases later),
             optionally itch.io
Local save:  files under Godot user:// (per-user application data folder)
Settings:    user://settings.cfg
Optional:    cloud save (later)
```

Every pull request's CI run attaches Windows and Linux zips as build artifacts (downloadable when signed in to GitHub). The `preview` release needs no login, so outside testers use that.

Unsigned builds trigger warnings (Windows SmartScreen, "unknown publisher"). Code signing costs money, so testers are told to choose "More info → Run anyway"; revisit before a public release.

If multiplayer/co-op is added:

```text
Desktop Client
     ↓ ENet (UDP)
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
Client A ─────┐
Client B ─────┼── Dedicated Server (headless Godot)
Client C ─────┘
```

Transport: **ENetMultiplayerPeer** (UDP, reliable and unreliable channels), Godot's default.

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
- RenderDoc (GPU frame captures)

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
- Terrain addon for Godot (e.g. Terrain3D)

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
├── native/                  # GDExtension C++ source
│   ├── src/
│   └── SConstruct
│
├── addons/                  # Third-party Godot addons (pinned versions)
│
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

Pipeline (GitHub Actions):

```text
Developer Commit
       ↓
GitHub
       ↓
CI
       ├── Licence check (REUSE)
       ├── Smoke test and unit / scenario tests (headless Godot, GdUnit4)
       ├── Asset budget validation (later)
       ├── Windows + Linux export (headless, release templates), zipped
       ├── Build artifacts on every pull request
       └── Rolling "preview" GitHub release on every push to main
```

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

## Platform Tests (manual until automated)

```text
Windows and Linux builds start from the zip
Vulkan and OpenGL-fallback renderers both start
Mouse capture / Esc / alt-tab handled correctly
Save → quit → Continue works
Window resize / fullscreen toggle
```

## Performance Tests

Track:

```text
FPS
Frame Time
CPU (script / physics / AI) Time
GPU Time
Memory (RAM, VRAM)
Draw Calls
AI Cost
Download size (zip)
Time to first playable frame
Network Bandwidth (multiplayer phase)
```

Reference hardware: a mid-range laptop with integrated graphics, and a mid-range desktop GPU.

---

# 30. Development Philosophy

Do not attempt to build the complete game immediately.

The project must be developed through progressively larger validated milestones.

Validate in **exported builds from day one**. A feature is not "done" when it works in the editor; it is done when it works in the exported build on reference hardware.

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
Windows + Linux builds from CI
```

Goal:

**Prove that movement, shooting and stealth feel good.**

Also prove the pipeline: CI exports, downloadable builds, saving, and performance on reference hardware.

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
- QA (including Windows / Linux and GPU-vendor coverage)

---

# 35. Initial Scope

The project should initially target:

### Single-player

### Desktop: Windows 10/11 and Linux (x86_64); macOS later

### Godot 4 desktop export (Forward+ renderer, OpenGL fallback)

### Keyboard + mouse (gamepad optional)

### Modern tactical stealth FPS

### One polished vertical-slice mission

Out of scope for the first milestones: mobile, consoles, web builds, multiplayer, large-scale procedural generation, advanced online infrastructure, vehicles.

---

# 36. Platform Decision

Milestone 1's first twelve work packages were built for the browser (WebAssembly + WebGL 2). On **2026-11-02** the project moved to **desktop only**:

| Browser limitation met | Desktop |
|---|---|
| WebGL 2 Compatibility renderer: no real-time GI, volumetric fog, SSR; fewer lights | Forward+ renderer |
| Single-threaded engine and audio "sample" mode (no bus effects) | Multi-threaded; full audio buses |
| Pointer-lock rules (click to capture, Esc cooldown) | Normal mouse capture |
| Storage the browser may evict | Normal files |
| 25 MiB per-file hosting limit, download size pressure | Zip download of any size |
| Roughly 1.5–3x slower than native | Native speed |

What was given up: play-from-a-link with no install, and per-PR preview URLs. Testers now download a zip from GitHub Releases.

The game code was unaffected: only the renderer setting, export presets, CI, and the small amount of browser glue (test hooks, save export/import through the browser) changed.

---

# 37. Technology Summary

| Category | Technology |
|---|---|
| Platform | Desktop: Windows, Linux (macOS later) |
| Engine | Godot 4.x |
| Main Language | Typed GDScript |
| Native / Hot Paths | C++ via GDExtension |
| AI | Custom Behavior Tree / State Machine + Tactical Queries |
| Navigation | Godot NavigationServer3D |
| Rendering | Forward+ (Vulkan / D3D12), OpenGL 3.3 fallback, LightmapGI, LODs, occlusion culling |
| Textures | VRAM-compressed (BPTC / S3TC) |
| Animation | AnimationTree + blend spaces + SkeletonModifier3D IK |
| Physics | Jolt (built in) |
| VFX | GPUParticles3D / CPUParticles3D + shaders |
| Audio | Godot audio buses |
| Save | Files under Godot `user://` |
| Streaming | Split resource packs (.pck) |
| 3D | Blender (glTF 2.0) |
| Sculpting | Blender |
| Texturing | Material Maker / Blender / Krita |
| Licence | Code: MIT; original assets: CC BY 4.0; third-party assets: their own (tracked) |
| Testing | GdUnit4 |
| Version Control | Git + Git LFS |
| CI/CD | GitHub Actions |
| Distribution | GitHub Releases (optionally itch.io) |
| Backend (later) | Node.js + TypeScript + Fastify |
| Database (later) | PostgreSQL |
| Cache (later) | Redis |
| Containers (later) | Docker |
| Multiplayer (later) | Headless Godot server + ENet |

---

# 38. Immediate Next Step

The Milestone 1 technical design ([m1-technical-design.md](m1-technical-design.md)) is written and being implemented work package by work package. The implementation stays **incremental, testable, modular, data-driven and production-oriented**.

The primary goal is not to produce a large amount of code. It is to establish a strong gameplay foundation that can scale from a prototype into a complete tactical FPS.
