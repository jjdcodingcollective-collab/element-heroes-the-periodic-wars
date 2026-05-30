# Element Heroes — The Periodic Wars
## Comprehensive Architecture & Gap Analysis
### As of 2026-05-29 | Engine: Godot 4.3 (GL Compatibility)

---

## Table of Contents

1. [Project Architecture & Overall Structure](#1-project-architecture--overall-structure)
2. [Codebase Organisation & File Hierarchy](#2-codebase-organisation--file-hierarchy)
3. [Core Systems & Their Implementations](#3-core-systems--their-implementations)
4. [Dependencies & External Integrations](#4-dependencies--external-integrations)
5. [Asset Management & Resource Pipeline](#5-asset-management--resource-pipeline)
6. [Build & Deployment Configuration](#6-build--deployment-configuration)
7. [Performance Bottlenecks & Optimisation Opportunities](#7-performance-bottlenecks--optimisation-opportunities)
8. [Code Quality Metrics & Technical Debt](#8-code-quality-metrics--technical-debt)
9. [Gap Analysis](#9-gap-analysis)
10. [Priority Action Matrix](#10-priority-action-matrix)

---

## 1. Project Architecture & Overall Structure

### Engine & Runtime

| Property | Value |
|---|---|
| Engine | Godot 4.3 |
| Renderer | GL Compatibility (OpenGL ES 3 backend) |
| Target resolution | 1280×720 |
| Stretch mode | `canvas_items` / `keep` aspect |
| Texture filter | Nearest-neighbour (pixel-art correct) |
| Gravity | 0.0 (top-down, no gravity) |
| Main scene | `res://scenes/world/world.tscn` |
| Language | GDScript (strict typing enforced) |

### Architectural Pattern

The project follows a **data-driven singleton + scene-graph** pattern standard for Godot 4:

```
Global Autoloads (singletons)
  ElementDB         — loads & queries all element/compound/handling data
  CraftingSystem    — recipe evaluation, item-ingredient crafting
  SaveSystem        — serialise/deserialise full player state
  AudioManager      — music crossfade, SFX pool, volume control

Scene Graph (per-session)
  World (Node2D)
    ├── Tile nodes (ColorRect ×N)
    ├── Static bodies (collision ×N)
    ├── Player (CharacterBody2D)
    │     ├── Inventory (Node)
    │     ├── Equipment (Node)
    │     ├── Weapon (Node)
    │     └── Armor (Node)
    ├── Enemy ×N (CharacterBody2D)
    ├── Boss ×6 (CharacterBody2D) + Arena ×6 (Node2D)
    ├── NPC — Aldric (Node2D)
    ├── Synthesizer (Node2D)
    ├── LabDesk (Node2D)
    └── UI Layer
          ├── HUD (CanvasLayer)
          ├── CraftingUI (CanvasLayer)
          ├── SynthesizerUI (CanvasLayer)
          └── ScienceMinigameUI (CanvasLayer)
```

### Design Principles (Observed)

- **Data over code**: All game content (elements, compounds, enemies, bosses, quiz) lives in JSON files under `data/`. Changing a boss phase requires editing JSON, not GDScript.
- **Placeholder-first rendering**: Every visual is a `ColorRect` placeholder. Sprites can be swapped at a scene level without touching game logic.
- **Forward-compatible world gen**: `world.gd` explicitly comments `# Phase 2: swap ColorRects for TileMap` — tile system is designed for visual upgrade without logic change.
- **Thin autoloads**: Autoloads are pure services (no UI, no physics). UI and game entities consume them but do not depend on each other directly.

---

## 2. Codebase Organisation & File Hierarchy

### Directory Tree

```
element-heroes-the-periodic-wars/
├── project.godot                     Engine config, autoloads, input map, physics layers
├── data/                             ALL game content (read-only at runtime)
│   ├── elements.json                 118 element definitions (~50 KB)
│   ├── compounds.json                65+ recipes: base compounds, weapons, polymers, armors (~29 KB)
│   ├── enemy_data.json               18 CHIMERA creatures + tier multipliers (~17 KB)
│   ├── boss_data.json                6 Compound Titans, 3 phases each (~17 KB)
│   ├── quiz_questions.json           26 science questions, 6 categories (~11 KB)
│   ├── element_handling.json         Per-element container/PPE requirements (~14 KB)
│   └── element_lab_handling.json     Extended lab handling data (~18 KB)
├── assets/
│   ├── sprites/
│   │   ├── icon.png                  16×16 app icon (only real sprite in-project)
│   │   ├── SPRITE_SPEC.md            Full animation specification (not yet produced)
│   │   └── reference/README.md       AI sprite generation guide
│   └── audio/
│       ├── music/ (.gitkeep)         Empty — awaiting .ogg biome tracks
│       └── sfx/ (.gitkeep)           Empty — awaiting .ogg sound effects
├── scenes/
│   ├── player/player.tscn            CharacterBody2D root
│   ├── ui/                           5 CanvasLayer UI scenes
│   └── world/                        9 world-entity scenes
├── scripts/
│   ├── audio/audio_manager.gd        (236 lines)
│   ├── crafting/crafting_system.gd   (89 lines)
│   ├── data/
│   │   ├── element_database.gd       (114 lines)
│   │   └── save_system.gd            (69 lines)
│   ├── player/                       5 scripts (610 lines total)
│   ├── ui/                           8 scripts (1,091 lines total)
│   └── world/                        13 scripts (1,538 lines total)
├── resources/
│   └── basic_tileset.tres            Unused tileset resource (placeholder)
├── context/                          Working documentation (not shipped)
└── plans/                            Development roadmap (not shipped)
```

### Script Distribution

| Module | Files | Lines | Responsibility |
|---|---|---|---|
| world/ | 13 | 1,538 | World gen, AI, bosses, hazards, projection |
| ui/ | 8 | 1,091 | All in-game UI panels |
| player/ | 5 | 610 | Player controller and subsystems |
| audio/ | 1 | 236 | Audio singleton |
| data/ | 2 | 183 | Data loading, save/load |
| crafting/ | 1 | 89 | Recipe evaluation |
| **Total** | **30** | **3,747** | (explore agent reported 4,204; diff is blank lines) |

### Physics Layer Assignments

| Layer | Name | Used By |
|---|---|---|
| 1 | world | Tile collision bodies |
| 2 | player | Player CharacterBody2D |
| 3 | enemies | Enemy/Boss CharacterBody2D |
| 4 | items | (reserved, unused) |
| 5 | projectiles | Player/enemy projectiles |

---

## 3. Core Systems & Their Implementations

### 3.1 World Generation (`scripts/world/world.gd`)

**Approach**: Flat 200×200 tile grid. Six biomes mapped to horizontal X ranges. Each tile is a `ColorRect` node with an optional `StaticBody2D` for collision.

**Biome Layout**

| Biome | X range | Base tile | Ore elements |
|---|---|---|---|
| surface_plains | 0–39 | grass | Na, K, C |
| underground_mines | 40–79 | stone | Fe, Cu, Zn, Ni |
| crystal_caverns | 80–109 | stone | Ag, Au |
| sky_islands | 110–139 | dirt | K, Na |
| ocean_floor | 140–169 | sand | Cu, Zn |
| magma_layer | 170–199 | stone | U, Th, Pt |

**Generation algorithm**:
1. `FastNoiseLite` seeded with `randi()` — fully random per launch (no deterministic seed)
2. Ocean floor: noise > 0.3 → water tile (impassable)
3. Magma layer: noise > 0.4 → lava tile (impassable)
4. Any biome: noise > 0.55 → rock tile (impassable)
5. Secondary noise pass (×4.1 frequency): > 0.5 → ore tile for biome element
6. Default: base terrain

**Village**: Hard-coded 6 buildings at tiles (10–22, 10–18). Impassable rectangles.

**Spawning order** (all deferred via `call_deferred`):
1. `_generate_world()` — synchronous (blocking, ~200×200 = 40,000 iterations)
2. `_spawn_village()`
3. `_init_ui()` — wires HUD, CraftingUI, SynthesizerUI, LabDesk, MinigameUI
4. `_spawn_enemies()` — 6 enemies per biome (36 total), skips village safe zone
5. `_spawn_bosses()` — 1 boss per biome (6 total) with arena node

**Critical issue**: World generation creates 40,000 `ColorRect` nodes + up to ~8,000 `StaticBody2D` + `CollisionShape2D` nodes for impassable tiles synchronously. This is the primary performance risk (see §7).

---

### 3.2 Player System (`scripts/player/`)

**player.gd** — `CharacterBody2D`, 200 lines
- WASD movement at 120px/s, 8-directional, normalised
- `take_damage()` with 0.5s i-frames, armour DR, corrode debuff
- `apply_stun()`, `apply_knockback()`, `apply_armor_corrode()`
- `_try_dig()`: range-check 48px, calls `world.dig_tile()`, equipment validation gate
- `_try_attack()`: delegates to `weapon.try_attack(facing)`
- `_unhandled_input()`: handles all UI open/close + interact + save via groups
- Animation wiring: `AnimatedSprite2D` — skipped if `sprite_frames == null` (placeholder mode)

**inventory.gd** — `Node`, 67 lines
- Float element storage `{ "Fe": 3.5 }`
- `add_element`, `remove_element`, `has_element`, `has_elements`, `remove_elements`
- `MAX_AMOUNT = 9999.0` cap
- `unit_for(symbol)` reads `ElementDB` to return `"g"` or `"mL"` based on physical state
- Signals: `inventory_changed(symbol, amount)`
- Full `serialize()` / `deserialize()` for save system

**equipment.gd** — `Node`, 126 lines
- Separate store for lab equipment items (containers + PPE)
- 5-tier container hierarchy (`CONTAINER_TIER`), 4-tier handling hierarchy (`HANDLING_TIER`)
- `can_collect(symbol)` — checks element handling requirements against held items
- `consume_container_for(symbol)` — conserves highest containers, uses lowest sufficient tier
- Signals: `equipment_changed`

**weapon.gd** — `Node`, 171 lines
- Single equipped slot; stats from `compounds.json["weapon"]` dict
- Melee: 120° arc hitbox flash (`ColorRect`), enemies hit via `get_nodes_in_group("enemy")`
- Ranged: `projectile.tscn` instantiated, stats passed via `.set_meta()`
- DoT: `_burn_timers` dictionary tracks per-enemy burn timers; ticked in `_process`
- Visual: swing `ColorRect` tinted to weapon colour

**armor.gd** — `Node`, 46 lines
- Single slot; DR% from `compounds.json["armor"]` dict
- `get_damage_reduction()` consumed by `player.take_damage()`
- Signals: `armor_changed`

---

### 3.3 Enemy System (`scripts/world/enemy.gd`)

**Architecture**: Data-driven base class. `creature_id` + `tier` set by spawner; stats loaded from `enemy_data.json`.

**State machine**: `patrol → chase → dead`
- Patrol: random direction changes every 1.5–3.5s
- Chase: activates within `sight_range` (modified by tier multiplier)
- Contact damage every 1.0s within 14px

**Tier multipliers** (from JSON):
| Stat | Basic | Intermediate | Expert |
|---|---|---|---|
| HP | ×1.0 | ×1.8 | ×3.5 |
| Damage | ×1.0 | ×1.6 | ×2.8 |
| Speed | ×1.0 | ×1.2 | ×1.5 |
| Sight | ×1.0 | ×1.1 | ×1.2 |

**Special abilities** (12 active + 3 passive/aura):
- `explode_on_death`, `leave_puddle`, `shockwave`, `stun_on_hit`
- `corrode_armor`, `ranged_attack`, `flash_blind`, `dive_bomb`
- `knockback_slam`, `aoe_stun`, `leave_fire_trail`, `shield_pulse`
- Auras: `lightning`, `poison`, `irradiate` (continuous proximity damage)
- Passive: `damage_reduction`

**Drop system**: Per-tier drop tables in JSON. Expert tier can drop equipment bonus items.

---

### 3.4 Boss System (`scripts/world/boss.gd` + `boss_arena.gd`)

**6 bosses**, each with 3 phases triggered at 55% and 25% HP:

| Boss | Biome | Formula | Min Weapon Tier |
|---|---|---|---|
| PEROXIS | surface_plains | Na₂O₂ | T2 |
| CHALCOR | underground_mines | CuFeS₂ | T2 |
| AURIUM | crystal_caverns | HAuCl₄ | T3 |
| AZRAEL | sky_islands | NaN₃ | T3 |
| ATACAMA | ocean_floor | Cu₂Cl(OH)₃ | T3 |
| URANOX | magma_layer | UO₂ | T4 |

**Phase system**: Each phase defines `color`, `aura`, `aura_params`, `passive`, `special`, `special_params`, `arena_hazard`, `hazard_interval`. `_apply_phase()` updates all of these atomically.

**Special abilities** (16 boss-specific):
- `caustic_spray/corrosive_spit` — directional projectile
- `oxygen_burst/caustic_nova/gamma_burst` — AoE damage
- `shockwave/gold_prison/aoe_stun` — AoE + stun
- `flake_burst` — scatter projectiles + blind
- `ranged_acid_bolt` — multi-bolt spread
- `ruby_cloud` — AoE blind + damage
- `nitrogen_lance` — high-speed piercing beam
- `chain_detonation` — 4 timed explosions
- `tide_surge` — knockback + flood
- `copper_implosion` — pull + burst
- `meltdown` — full-arena 120px supercritical explosion
- `reactive_detonation` (AZRAEL) — triggers on every hit received

**Arena hazards** (7 types): `water_puddles`, `sulfur_vents`, `acid_pools`, `wind_columns`, `brine_tide`, `radiation_zones`, `flood`. Spawned by `boss_arena.gd` at configurable intervals.

---

### 3.5 Crafting System

**crafting_system.gd** (autoload): Recipe matching is exact dictionary equality — grid contents must match compound's `elements` dict exactly.

**Compound database** (`compounds.json`): Indexed by formula string. Categories:
- Base compounds (NaCl, H₂O, etc.)
- Weapons (T1–T5 melee + ranged)
- Polymer intermediates (Polyethylene, PVC, PPTA, Polycarbonate, Boron Nitride)
- Armors (T1–T5)

**Crafting flows**:
1. `try_craft(grid, inventory)` — element-only recipes
2. `try_craft_with_items(grid, inventory, equipment)` — recipes needing polymer intermediates

**Issue**: Recipe matching uses `==` on Dictionaries. Ingredient ordering in JSON must exactly match the grid-derived dict. There is no partial-match or fuzzy matching.

---

### 3.6 Element Database (`scripts/data/element_database.gd`)

Loads three JSON files at `_ready()`: `elements.json`, `compounds.json`, `element_handling.json`.

Key methods:
- `get_element(symbol)` → element dict
- `get_compound(formula)` → compound dict
- `match_recipe(ingredient_map)` → compound dict or `{}`
- `get_handling(symbol)` → `{ container_item, handling_item, hazards }`
- `get_elements_by_biome(biome)` — note: elements.json uses `"biome"` field but biomes are defined separately in `world.gd`

**Inconsistency**: `element_handling.json` and `element_lab_handling.json` both exist. Only `element_handling.json` is loaded by `ElementDB`. The `element_lab_handling.json` appears to be an extended version — its consumer is unclear.

---

### 3.7 Save System (`scripts/data/save_system.gd`)

Saves to `user://savegame.json` (Godot's platform-specific user data folder).

Saved state:
- `inventory` — element amounts dict
- `equipment` — item counts dict
- `weapon` — equipped weapon name string
- `armor` — equipped armor name string
- `position` — `{x, y}` float
- `discovered` — compendium discovery dict
- `timestamp` — ISO datetime

**Gap**: World state (tile modifications from digging) is not saved. Player position is saved but tile ore depletion is lost on reload. New game ≠ loaded game in terms of world.

---

### 3.8 Audio System (`scripts/audio/audio_manager.gd`)

Fully implemented infrastructure, zero audio files present.

- Dual `AudioStreamPlayer` (A/B) with 1.5s crossfade tween
- 12-slot SFX pool, round-robin allocation (oldest reused when full)
- Music/SFX buses created dynamically if missing from project `AudioServer`
- `on_biome_changed()` / `on_boss_fight_start()` / `on_boss_fight_end()` public API

**Activation**: Uncomment preload blocks in `audio_manager.gd` once `.ogg` files are placed.

**Gap**: `on_biome_changed()` is never called by HUD or world. The HUD polls biome every 0.5s but never calls `AudioManager.on_biome_changed()`. Music switching is wired but never triggered.

---

### 3.9 Science Mini-Game (`scripts/ui/science_minigame_ui.gd`)

376-line implementation, fully procedural (UI built in code, no `.tscn` needed for layout).

- 26 questions, 6 categories, 3 difficulty tiers
- Session: 3 questions selected to balance difficulty tiers
- Correct: element reward added to inventory + explanation
- Wrong: 5 HP penalty + explanation shown
- Grade: S/A/B/C with Prof. Aldric quotes

**Integration**: Triggered via `call_group("science_minigame_ui", "open_minigame", player)` from `lab_desk.gd`.

---

## 4. Dependencies & External Integrations

### Engine Dependencies

| Dependency | Version | Source |
|---|---|---|
| Godot Engine | 4.3 | godotengine.org |
| GDScript | 4.3 built-in | — |
| GL Compatibility renderer | Built-in | For broad platform support |

### External Libraries

**None.** The project uses zero addons, plugins, or third-party GDScript libraries. All systems are hand-written.

### Data Sources

All game data is self-contained in `data/*.json`. No network calls, no external APIs, no CDN.

### Platform Targets

Not yet configured in `project.godot` (no `export_presets.cfg` present). Implied targets based on GL Compatibility renderer: Windows, macOS, Linux, HTML5 (WebGL), Android, iOS.

### Steam Integration

Referenced in the task context (`store.steampowered.com/app/2983860/ISOCORE`) — **no Steamworks SDK, GodotSteam plugin, or Steam-specific configuration is present** in the repository. Steam integration is entirely absent from the codebase.

---

## 5. Asset Management & Resource Pipeline

### Current State

| Asset type | Status | Count |
|---|---|---|
| Sprites / textures | 1 real file (icon.png) | 1 |
| Tilemaps / atlases | 0 | 0 |
| Audio (music) | 0 | 0 |
| Audio (SFX) | 0 | 0 |
| Godot resources (.tres) | 1 (unused basic_tileset.tres) | 1 |
| Scenes (.tscn) | 14 | 14 |
| Scripts (.gd) | 30 | 30 |
| Data (JSON) | 7 | 7 |

### Sprite Pipeline

The sprite spec at `assets/sprites/SPRITE_SPEC.md` defines:
- Player: 8-direction idle + walk (idle: 2 frames, walk: 4 frames) = 64 frames
- 18 enemy types (6 frames each) = 108 frames
- 6 bosses (8 frames each) = 48 frames
- NPC Aldric (4-direction idle, 4 frames) = 16 frames
- UI elements, tiles, buildings

Recommended tool: **Aseprite** for pixel art creation.

Swap path in code: `player.gd` lines 9–12 document exactly how to wire an `AnimatedSprite2D` resource. Enemy and boss use `_spawn_placeholder()` which creates a `ColorRect` child — replace with `Sprite2D` or `AnimatedSprite2D`.

### Audio Pipeline

AudioManager expects `.ogg` format files (Godot's preferred compressed audio format). Names are documented in `audio_manager.gd` lines 13–20:
- 8 music tracks (biome × 6 + boss + title)
- 15 SFX files

Recommended tools: **BeepBox** (music), **jsfxr** (sound effects).

### Resource Loading Pattern

All resources loaded at runtime via `FileAccess.open()` + `JSON.parse_string()`. No preloaded resources except the commented-out audio blocks. This means JSON parsing happens every time the game starts — acceptable for a small game but not scalable.

---

## 6. Build & Deployment Configuration

### Current Configuration

`project.godot` defines:
- Application name, version 0.1.0
- Main scene, icon
- Feature flags: `["4.3", "GL Compatibility"]`
- Input map (WASD + mouse + hotkeys)
- Physics: 2D gravity = 0

### Missing Configuration

- **No `export_presets.cfg`** — exports have never been configured
- **No CI/CD** — no GitHub Actions, no automated build pipeline
- **No `.gdignore`** or resource include/exclude rules
- **No version number tracking** beyond the string in `project.godot`
- **No Steam AppID** or platform-specific build settings

### Build Readiness

To produce a distributable build:
1. Open `Project → Export` in the Godot editor
2. Add export presets per platform
3. Install platform export templates
4. Configure application metadata per platform
5. (Optional) Add GodotSteam for Steam features

---

## 7. Performance Bottlenecks & Optimisation Opportunities

### Critical Issues

#### 7.1 World Generation — Node Explosion

**Location**: `world.gd:_generate_world()` + `_create_tile()`

**Problem**: For a 200×200 world, the generator creates:
- Up to 40,000 `ColorRect` nodes (one per tile)
- Up to ~8,000–12,000 `StaticBody2D` + `CollisionShape2D` pairs for impassable tiles
- Combined: potentially 60,000+ Godot nodes added to the scene tree synchronously

At 60fps, `_process()` iterates all nodes. Even idle `ColorRect` nodes have per-frame overhead. This will cause:
- Startup freeze of 2–5 seconds depending on hardware
- Ongoing frame budget pressure from node count
- Memory spike: estimated 30–60 MB for node objects alone

**Fix (Phase 2 plan already noted in code)**:
Replace `ColorRect` tile nodes with a `TileMap` using a single atlas texture. Target: 1 node instead of 40,000. The code is already architected for this swap — `_create_tile()` internals are the only change point.

**Interim fix**: Implement tile chunking or frustum culling — only create visible tiles, pool/destroy off-screen.

#### 7.2 Enemy Group Query — O(N) per Frame

**Location**: `weapon.gd:_do_melee()` line 87 — `get_tree().get_nodes_in_group("enemy")`

**Problem**: Called every time the player attacks. Iterates all enemies in the scene. With 36+ enemies active, this is acceptable now but will degrade with more enemies.

**Fix**: Cache enemy list in world.gd, or use Area2D overlap detection instead of group iteration.

#### 7.3 Boss Hazard Zone Accumulation

**Location**: `boss_arena.gd:_active_zones`

**Problem**: `_active_zones` array is appended but never trimmed of freed nodes. If hazard zones `queue_free()` themselves, the array grows with invalid references until `clear_hazards()` is called at boss death. `is_instance_valid()` checks are missing.

**Fix**: Add `_active_zones = _active_zones.filter(func(z): return is_instance_valid(z))` in `_process()` or hook `queue_free` to remove from array.

#### 7.4 HUD Inventory Refresh — Excessive Rebuilds

**Location**: `hud.gd:_refresh_inventory_bar()`

**Problem**: `_refresh_inventory_bar()` rebuilds the entire inventory display string every time any item changes. Called on `inventory_changed` signal which fires on every element pickup.

**Fix**: Debounce with a dirty flag; only rebuild once per frame even if multiple items change in one tick.

#### 7.5 Save System — No World Tile State

**Location**: `save_system.gd`

**Problem**: Dug ore tiles are not saved. World regenerates fresh on load, so all previously mined tiles reappear. This breaks progression — a player who mines an area returns to find it refilled.

**Fix**: Save `tile_data` diff (only changed tiles) as a compact array of `[x, y, type, element]` tuples.

#### 7.6 Burn Timer Dictionary — Memory Leak Potential

**Location**: `weapon.gd:_burn_timers`

**Problem**: The `_burn_timers` dictionary keys are node references. If an enemy is freed without going through `_die()` (e.g., scene cleanup), its node key remains in `_burn_timers` until the weapon processes it. `is_instance_valid()` check on line 147 handles this, but large battles could leave stale entries for multiple frames.

**Fix**: Connect to enemy's `tree_exiting` signal to immediately erase from `_burn_timers`.

---

## 8. Code Quality Metrics & Technical Debt

### Positive Patterns

- **Strict typing** consistently applied — all function signatures have typed parameters and return types
- **Signal-based decoupling** — Inventory, Equipment, Weapon, Armor all communicate via signals
- **Data-driven design** — game balance changes require only JSON edits
- **No circular dependencies** — autoloads consumed by scenes, never vice versa
- **Forward-compatible comments** — explicit `# SPRITE SWAP GUIDE` and `# Phase 2` notes throughout

### Technical Debt Items

#### TD-01: Duplicate Hazard Spawn Functions
`enemy.gd:_spawn_hazard_zone()` (line 444) and `boss.gd:_spawn_hazard()` (line 547) are nearly identical. A shared `HazardFactory` utility function or a static method on `hazard_zone.gd` would eliminate ~30 lines of duplication.

#### TD-02: Duplicate VFX Functions
`_spawn_shockwave_vfx()`, `_spawn_hit_label()`, `_spawn_damage_label()`, `_spawn_drop_label()` exist in both `enemy.gd` and `boss.gd` with nearly identical implementations. Should be extracted to a shared `CombatVFX` autoload or utility.

#### TD-03: Enemy Data Loading Redundancy
`enemy.gd:_load_data()` (lines 69–94) has a primary path (via `ElementDatabase.get_enemy_data()`) and a fallback that directly opens `enemy_data.json`. The primary path calls a method (`get_enemy_data`) that does not exist in `element_database.gd`. This means the fallback always runs. The primary path is dead code.

#### TD-04: `element_lab_handling.json` Orphan
This file (~18 KB) exists in `data/` but is never loaded by `ElementDB` or any other script. It may be superseded by `element_handling.json`, or it may be intended for a future extended handling system. Status is ambiguous.

#### TD-05: Boss Weapon Tier Gate — Soft Floor Comment
`boss.gd:take_damage()` line 463 says "world.gd should not spawn bosses until player is ready — this is just a soft floor." The `min_weapon_tier` field is loaded but never enforced in damage calculation. The gate that should prevent a T1-weapon player from dealing full damage to a T4 boss is implemented as a no-op.

#### TD-06: No `on_biome_changed()` Call
`AudioManager.on_biome_changed()` is fully implemented but never called. `hud.gd` checks biome every 0.5s and updates the label but does not relay the biome change to AudioManager. Music will never automatically switch biomes.

#### TD-07: `hud.gd` shows `"show_lore"` method referenced in `boss.gd`
`boss.gd:_drop_loot()` line 522 calls `hud.show_lore(name, lore)` but `hud.gd` does not implement `show_lore()`. Bosses drop lore text but it silently fails.

#### TD-08: `Compendium` node access inconsistency
`hud.gd` accesses compendium via `get_node_or_null("Compendium")` (direct child) in some places and via group `"compendium"` in others. If the scene tree changes, one path will silently fail.

#### TD-09: Ranged attack SFX missing
`player.gd:_try_attack()` calls `AudioManager.on_attack_melee()` regardless of weapon type. Ranged weapons should call `AudioManager.on_attack_ranged()`. The method exists but is never called.

#### TD-10: Boss fight music not triggered
`boss.gd` never calls `AudioManager.on_boss_fight_start()` or `on_boss_fight_end()`. The API exists but is unused.

---

## 9. Gap Analysis

### 9.1 Missing Implementations

| Gap | Impact | Effort |
|---|---|---|
| **Pixel art sprites** | Entire visual presentation is placeholder ColorRects | High |
| **Audio files** (music + SFX) | Game is completely silent | Medium |
| **World tile state in save** | Mining progress lost on reload | Medium |
| **Biome music triggering** | Music never switches (TD-06) | Low |
| **Boss fight music** | Boss music never plays (TD-10) | Low |
| **`show_lore()` on HUD** | Boss lore drops silently fail (TD-07) | Low |
| **Weapon tier SFX** | Ranged attacks play melee sound (TD-09) | Low |
| **Steam/platform integration** | No achievements, cloud saves, overlays | High |
| **Export presets** | No distributable build possible | Medium |
| **Achievement system** | Referenced in PROGRESS.md Phase 6 | Medium |
| **Building/placement system** | Referenced in PROGRESS.md Phase 5 | High |
| **Additional quests / NPCs** | Only Aldric exists | High |
| **Boss weapon tier enforcement** | Boss can be killed with T1 weapon | Low |

### 9.2 Inconsistencies Between Intended & Actual Architecture

| Inconsistency | Location | Status |
|---|---|---|
| `ElementDB.get_enemy_data()` referenced but not implemented | `enemy.gd:69` | Dead code path, fallback always runs |
| `element_lab_handling.json` loaded by nobody | `data/` folder | Orphan file |
| Boss `min_weapon_tier` loaded but never enforced | `boss.gd:92` | Loaded, unused |
| `hud.show_lore()` called but not defined | `boss.gd:522` | Silent failure |
| Tile data has no serialisation hook in save | `save_system.gd` | World state not persisted |
| `HUD.on_biome_changed` not wired | `hud.gd:_process` | Feature not connected |
| Two handling JSON files with unclear relationship | `data/` | Ambiguous data source |

### 9.3 Performance & Scalability Gaps

| Gap | Severity | Fix Complexity |
|---|---|---|
| 40,000+ ColorRect tiles created at startup | Critical | Medium (TileMap migration) |
| No spatial partitioning for enemy/collision | Moderate | Medium |
| No object pooling for VFX labels (spawn/free per hit) | Moderate | Low |
| No frustum culling for off-screen tiles | Moderate | Medium |
| Save file has no versioning | Low | Low |

### 9.4 Documentation & Testing Gaps

| Gap | Notes |
|---|---|
| No automated tests | Zero test scenes or GUT (Godot Unit Test) framework |
| No CI/CD pipeline | No GitHub Actions for build validation |
| No in-engine documentation | Only source-level comments |
| `DECISIONS.md` is empty | Active decision log exists but has no entries |
| PROGRESS.md last updated 2026-03-01 | Phase 6 content has since been added |

### 9.5 Security & Compatibility Gaps

| Gap | Notes |
|---|---|
| Save file is unencrypted JSON | Trivially editable by players; acceptable for single-player game |
| No save file version migration | Future schema changes will break existing saves silently |
| No input sanitisation on save load | `JSON.parse_string()` return cast directly to Dictionary — malformed save could crash |
| GL Compatibility renderer chosen | Correct for broad compatibility but limits advanced shader effects |

---

## 10. Priority Action Matrix

### Immediate (Blocks Playability)

| # | Action | File(s) | Impact |
|---|---|---|---|
| P1 | Migrate tile rendering to TileMap | `world.gd`, `_create_tile()` | Eliminates 40,000-node startup freeze |
| P2 | Wire `AudioManager.on_biome_changed()` in HUD | `hud.gd:_process()` | Biome music begins working |
| P3 | Implement `hud.show_lore()` | `hud.gd` | Boss lore drops surface to player |
| P4 | Call `AudioManager.on_boss_fight_start/end()` from `boss.gd` | `boss.gd:_ready`, `_die()` | Boss music plays |
| P5 | Fix ranged weapon SFX | `player.gd:_try_attack()` | Correct audio feedback |

### High Priority (Before First Public Build)

| # | Action | File(s) | Impact |
|---|---|---|---|
| P6 | Add world tile state to save system | `save_system.gd`, `world.gd` | Mining progress persists |
| P7 | Produce sprite assets (use `SPRITE_SPEC.md`) | `assets/sprites/` | Real visuals replace placeholders |
| P8 | Produce audio files and activate AudioManager | `assets/audio/`, `audio_manager.gd` | Game has sound |
| P9 | Configure export presets | Godot Editor | Build becomes distributable |
| P10 | Extract shared VFX/hazard utilities | New: `scripts/util/combat_vfx.gd` | Eliminates TD-01, TD-02 |

### Medium Priority (Polish & Completeness)

| # | Action | File(s) | Impact |
|---|---|---|---|
| P11 | Implement `ElementDB.get_enemy_data()` | `element_database.gd` | Removes dead fallback code |
| P12 | Clarify `element_lab_handling.json` status | `data/`, `element_database.gd` | Resolves orphan file |
| P13 | Enforce `min_weapon_tier` in `boss.take_damage()` | `boss.gd` | Meaningful progression gate |
| P14 | Add save file schema versioning | `save_system.gd` | Prevents silent corruption on updates |
| P15 | Implement `show_lore` as floating panel or HUD overlay | `hud.gd`, `scripts/ui/` | Boss narrative lands |
| P16 | Fix `_active_zones` stale reference accumulation | `boss_arena.gd` | Prevents memory growth in long boss fights |

### Long-term (Feature Parity with Plan)

| # | Action | Notes |
|---|---|---|
| P17 | Building/placement system | Phase 5 — compound-based block placement |
| P18 | Achievement system | Phase 6 — boss kills, quiz streaks |
| P19 | Story expansion | Phase 7 — per-biome NPCs and quests |
| P20 | Expand compound recipes (65 → 200+) | Data work only |
| P21 | Steam integration (GodotSteam) | Required for Steam release features |

---

*Document generated: 2026-05-29*
*Analysed by: architectural deep-dive of all 30 GDScript files, 7 JSON data files, 14 scene files, project.godot, and all documentation.*
