# Element Heroes — The Periodic Wars
## Build Guide & Status Snapshot
**Date:** 2026-05-30
**Repo:** https://github.com/jjdcodingcollective-collab/element-heroes-the-periodic-wars
**Branch:** main
**Latest commit:** `ace7456` — Add 18 enemy sprites and 6 boss sprites

---

## 1. Project Overview

A 2D pixel-art top-down adventure RPG built in **Godot 4.3 / GDScript** around the 118 elements of the periodic table. Players explore a procedurally generated world across 6 biomes, collect real chemical elements in realistic lab containers, synthesise compounds, craft weapons and armour, battle 18 element-mutated CHIMERA creatures across 3 difficulty tiers, and defeat 6 Compound Titan bosses — all while learning real chemistry through an integrated quiz system.

- **Engine:** Godot 4.3 (GDScript, strict typing, GL Compatibility renderer)
- **Target audience:** Grades 6–12 (educational science game)
- **Art style:** Golden Sun GBA mixed with NES/SNES Zelda — thick black outlines, dithered shading, top-down 3/4 perspective, 16×16 tiles

---

## 2. How to Open and Run

### Prerequisites
- Godot 4.3 (download from https://godotengine.org)
- No other dependencies — all game logic is self-contained GDScript

### Steps
1. Clone the repo: `git clone https://github.com/jjdcodingcollective-collab/element-heroes-the-periodic-wars.git`
2. Open Godot 4.3 → **Import** → navigate to the cloned folder → select `project.godot`
3. Press **F5** (or the Play button) to run from `scenes/world/world.tscn`

### Autoloads (configured in project.godot)
| Singleton name | Script |
|---|---|
| `ElementDB` | `scripts/data/element_database.gd` |
| `CraftingSystem` | `scripts/crafting/crafting_system.gd` |
| `SaveSystem` | `scripts/data/save_system.gd` |
| `AudioManager` | `scripts/audio/audio_manager.gd` |

---

## 3. Controls

| Key | Action |
|---|---|
| WASD | Move (8-direction) |
| Left Click | Dig element tile (within 48px) |
| Right Click / Space | Attack (melee arc or ranged projectile) |
| E | Toggle inventory bar |
| C | Toggle crafting UI / Compendium |
| F | Interact (NPC dialogue, Synthesizer, Lab desk) |
| X | Save game |
| ESC | Close open UI |

---

## 4. Current Build Status

### Code Systems — All Complete

| System | Script(s) | Status |
|---|---|---|
| World generation (6 biomes, tile streaming) | `world.gd` | ✅ Done |
| Player controller (8-dir, i-frames, dig) | `player.gd` | ✅ Done |
| Inventory (float amounts, signals) | `inventory.gd` | ✅ Done |
| Lab equipment (5-tier container + PPE) | `equipment.gd` | ✅ Done |
| Weapon system (5 melee + 5 ranged, T1–T5) | `weapon.gd` | ✅ Done |
| Armour system (5 tiers, flat DR%) | `armor.gd` | ✅ Done |
| Crafting system (recipe matching, auto-equip) | `crafting_system.gd`, `crafting_ui.gd` | ✅ Done |
| Synthesizer (polymer intermediates) | `synthesizer.gd`, `synthesizer_ui.gd` | ✅ Done |
| Enemy AI (18 CHIMERA × 3 tiers = 54 variants) | `enemy.gd` | ✅ Done |
| Boss system (6 Titans, 3-phase, arena hazards) | `boss.gd`, `boss_arena.gd` | ✅ Done |
| NPC dialogue (typewriter, multi-line) | `npc.gd`, `dialogue_ui.gd` | ✅ Done |
| Compendium (118-element grid, auto-discover) | `compendium_ui.gd` | ✅ Done |
| Science mini-game (26 Qs, graded, rewards) | `science_minigame_ui.gd` | ✅ Done |
| HUD (health, inventory bar, minimap, biome) | `hud.gd`, `minimap.gd` | ✅ Done |
| Audio system (crossfade music, SFX pool) | `audio_manager.gd` | ✅ Done |
| Save / load (versioned, migration, corruption recovery) | `save_system.gd` | ✅ Done |
| Element + compound database (118 elements, 65+ recipes) | `element_database.gd` | ✅ Done |
| Hazard zones (DPS, corrode, knockback) | `hazard_zone*.gd` | ✅ Done |
| Projectiles (melee/ranged, splash, pierce, DoT) | `projectile.gd` | ✅ Done |

### Data Files — All Complete

| File | Contents |
|---|---|
| `data/elements.json` | 118 element definitions (symbol, name, atomic number, biome, category) |
| `data/compounds.json` | 65+ compound recipes (base materials, weapons, armours, polymers) |
| `data/enemy_data.json` | 18 CHIMERA creature definitions + tier multipliers |
| `data/boss_data.json` | 6 Compound Titan definitions (phases, hazards, lore, drops) |
| `data/quiz_questions.json` | 26 chemistry quiz questions across 6 categories |
| `data/element_handling.json` | Real-world lab container + PPE requirements per element |

### Sprites — Partially Complete

| Asset | Path | Status |
|---|---|---|
| Player — Kael (4×8 sheet, idle+walk 8-dir) | `assets/sprites/player/kael.png` | ✅ Done |
| World tileset (7 biomes × 4 tiles, 16×16) | `assets/sprites/tiles/world_tiles.png` | ✅ Done |
| Enemies — all 18 CHIMERA (2×4 walk cycle) | `assets/sprites/enemies/*.png` | ✅ Done (18/18) |
| Bosses — all 6 Titans (48×48, 4 idle + 2 attack) | `assets/sprites/bosses/*.png` | ✅ Done (6/6) |
| NPCs — Prof. Aldric Voss, villager_a, villager_b | `assets/sprites/npc/` | ⬜ Next |
| World objects — synthesizer, desk, well, stall, projectile | `assets/sprites/world/` | ⬜ Next |
| HUD icons — hearts, slots, weapon/armour/compendium | `assets/sprites/ui/` | ⬜ Next |

### Audio — Pending

| Asset | Status | Notes |
|---|---|---|
| Music (8 biome/boss tracks, .ogg) | ⬜ Pending | AudioManager ready — drop files into `assets/audio/music/` |
| SFX (15 sound effects, .ogg) | ⬜ Pending | Drop into `assets/audio/sfx/` — see `SPRITE_SPEC.md` for full list |

> **Quick start:** Use [BeepBox](https://beepbox.co) for music loops (export OGG directly) and [jsfxr](https://sfxr.me) for SFX (export WAV → convert to OGG in Audacity).

---

## 5. Enemy Roster (18/18 CHIMERA)

All enemies are real-world creatures mutated by chemical elements. Each has 3 tier variants (Basic / Intermediate / Expert), differing by HP, damage, speed, and visual tint.

| # | Name | Base creature | Element mutation | Biome |
|---|---|---|---|---|
| 01 | Ashburn Shambler | Bear | Na/K/C — ash + ember cracks | Surface Plains |
| 02 | Carbon Crawler | Stag beetle | C — graphite lattice exoskeleton | Underground Mines |
| 03 | Potash Poltergeist | Frog | K — bloated, caustic purple vapour | Surface Plains |
| 04 | Iron Hulk | Rhinoceros | Fe/Zn — riveted iron plate hide | Underground Mines |
| 05 | Copper Coil | King cobra | Cu — metallic copper scales, verdigris patches | Underground Mines |
| 06 | Zinc Phantom | Jellyfish | Zn — crystalline blue-white bell, oxide tendrils | Underground Mines |
| 07 | Silver Specter | Manta ray | Ag — shimmering translucent silver body | Crystal Caverns |
| 08 | Gold Golem | Galapagos tortoise | Au — dense gold-plated shell + scales | Crystal Caverns |
| 09 | Prismatic Hound | Wolf | Au/Ag — bimetallic scales, prismatic flash | Crystal Caverns |
| 10 | Alkali Hawk | Peregrine falcon | K/Na — reactive metal feather-tips, flame bursts | Sky Islands |
| 11 | Static Djinn | Electric eel | Na/K — plasma vortex, constant arc discharge | Sky Islands |
| 12 | Stormwing | Albatross | K/Na — storm-cloud wings, lightning veins | Sky Islands |
| 13 | Brine Crawler | Mantis shrimp | Cu/Zn — copper-zinc alloy claws + shell | Ocean Floor |
| 14 | Verdigris Lurker | Octopus | Zn/Cu — corroded verdigris skin, oxide cloud | Ocean Floor |
| 15 | Deep Shocker | Box jellyfish | Cu — purple bell, copper-filament voltage tentacles | Ocean Floor |
| 16 | Uranium Wraith | Moth | U — tattered black wings, gamma radiation aura | Magma Layer |
| 17 | Thorium Scorcher | Komodo dragon | Th — cracked volcanic scales, 1500°C body | Magma Layer |
| 18 | Platinum Sentinel | Pangolin | Pt — platinum-iridium overlapping plate scales | Magma Layer |

**Tier tints (applied in code, no extra sprites needed):**
- Basic: no tint
- Intermediate: `Color(1.0, 0.85, 0.5)` — warm gold
- Expert: `Color(0.8, 0.3, 1.0)` — purple

---

## 6. Boss Roster (6/6 Compound Titans)

Each boss has 3 combat phases (triggers at 55% and 25% HP), biome-specific arena hazards, and drops element lore on death.

| Boss | Compound | Formula | Biome | Min weapon tier |
|---|---|---|---|---|
| PEROXIS | Sodium Peroxide | Na₂O₂ | Surface Plains | T2 |
| CHALCOR | Chalcopyrite | CuFeS₂ | Underground Mines | T2 |
| AURIUM | Chloroauric Acid | HAuCl₄ | Crystal Caverns | T3 |
| AZRAEL | Sodium Azide | NaN₃ | Sky Islands | T3 |
| ATACAMA | Atacamite | Cu₂Cl(OH)₃ | Ocean Floor | T3 |
| URANOX | Uraninite | UO₂ | Magma Layer | T4 |

---

## 7. Weapon & Armour Reference

### Weapons
| Tier | Melee | Recipe | Damage | Special |
|---|---|---|---|---|
| T1 | Bronze Sword | Cu×3 + Sn | 12 | — |
| T2 | Steel Sword | Fe×4 + C | 20 | — |
| T3 | Titanium Blade | Ti×2 + N | 30 | — |
| T4 | Thermite Blade | Fe₂O₃ + Al×2 | 45 | Burns 5/s × 3s |
| T5 | Plutonium Edge | Pu + O×2 | 80 | Irradiates 15/s × 4s |

| Tier | Ranged | Recipe | Damage | Special |
|---|---|---|---|---|
| T1 | Flint Arrow | Si + C | 10 | — |
| T2 | Phosphorus Bolt | P×4 | 18 | Burns 4/s × 2s |
| T3 | Chlorine Bomb | Cl×2 | 25 | AoE poison 32px |
| T4 | Uranium Shell | U + O×2 | 50 | Piercing |
| T5 | Plutonium Cannon | Pu + F×6 | 90 | AoE irradiate 40px |

### Armour
| Tier | Armour | DR | Recipe highlights |
|---|---|---|---|
| T1 | Limestone Jerkin | 10% | Ca×2 + C + O×3 |
| T2 | Iron Plate | 20% | Fe×6 + C×2 |
| T3 | Kevlar Vest | 35% | PPTA×2 + Polyethylene + PVC (Synthesizer) |
| T4 | Titanium Composite | 50% | Ti×3 + Al×2 + Polycarbonate×2 |
| T5 | Graphene Nanosuit | 70% | C×4 + Boron Nitride×3 |

---

## 8. What Remains — Prioritised Backlog

### Immediate next (art pipeline)
1. **NPC sprites** — Prof. Aldric Voss (dark blue robes, white beard), villager_a (brown tunic), villager_b (green tunic) — 16×16, 2-frame idle
2. **World object sprites** — synthesizer (32×32), lab desk (16×16), well (16×16), market stall (32×16), projectile (8×4)
3. **HUD icons** — health_full, health_empty, slot_bg, slot_selected, sword_icon, shield_icon, compendium_icon (all 16×16)

### Audio (can be done in parallel)
4. **SFX (15 files)** — dig, pickup, attack_melee, attack_ranged, player_hit, enemy_hit, enemy_die, boss_hit, boss_phase, craft_success, quiz_correct, quiz_wrong, interact, ui_open, ui_close
5. **Music (8 tracks)** — surface_plains, underground_mines, crystal_caverns, sky_islands, ocean_floor, magma_layer, boss_battle, title

### Code — medium priority
6. **Export presets** — configure `export_presets.cfg` for Windows / Linux / macOS in Godot
7. **Building system** — compound-based block placement (Phase 5)
8. **Achievement system** — quiz streaks, boss kill milestones (Phase 6)

### Code — low priority
9. **Story expansion** — per-biome NPC quests and narrative dialogue (Phase 7)
10. **More compound recipes** — target 200+ (currently 65+)
11. **Per-biome NPC characters**

---

## 9. Commit History

| Commit | Description |
|---|---|
| `ace7456` | Add 18 enemy sprites and 6 boss sprites |
| `26132d9` | Add pixel art sprites, bug fixes, and architecture docs |
| `d002df0` | Add sprite reference folder with regeneration guide |
| `b90b68e` | Add Phase 6 science mini-game, audio system, sprite spec |
| `a5b17ad` | Add 6 compound titan bosses with 3-phase fights and arena hazards |
| `a0b4731` | Add 18 CHIMERA enemy variants with 3-tier grinding system |
| `4a3aad7` | Update PROGRESS.md — armor, weapons, Synthesizer |
| `6ac608b` | Add armor system and Synthesizer machine for polymers/plastics |
| `a9c0e77` | Add Zelda-style real-time combat system |
| `05c1750` | Add PROGRESS.md — full build status and system docs |

---

## 10. Key File Locations

```
element-heroes-the-periodic-wars/
├── project.godot                          ← Open this in Godot 4.3
├── data/
│   ├── elements.json                      ← 118 elements
│   ├── compounds.json                     ← 65+ recipes
│   ├── enemy_data.json                    ← 18 CHIMERA definitions
│   ├── boss_data.json                     ← 6 Titan definitions
│   ├── quiz_questions.json                ← 26 quiz questions
│   └── element_handling.json             ← Lab PPE/container rules
├── assets/
│   ├── sprites/
│   │   ├── SPRITE_SPEC.md                 ← Full animation spec
│   │   ├── player/kael.png               ← Player sprite sheet
│   │   ├── tiles/world_tiles.png         ← World tileset
│   │   ├── enemies/                      ← 18 enemy sprites ✅
│   │   └── bosses/                       ← 6 boss sprites ✅
│   └── audio/
│       ├── music/                         ← Drop .ogg tracks here
│       └── sfx/                           ← Drop .ogg SFX here
├── scenes/
│   ├── world/world.tscn                   ← Main scene (run this)
│   ├── player/player.tscn
│   └── ui/                               ← HUD, crafting, compendium, etc.
├── scripts/
│   ├── data/element_database.gd          ← Autoload: ElementDB
│   ├── crafting/crafting_system.gd       ← Autoload: CraftingSystem
│   ├── data/save_system.gd               ← Autoload: SaveSystem
│   └── audio/audio_manager.gd            ← Autoload: AudioManager
└── outputs/
    ├── BUILD_GUIDE_2026-05-30.md         ← This document
    └── ARCHITECTURE_ANALYSIS.md          ← Full technical deep dive
```

---

*Generated 2026-05-30. Repo: https://github.com/jjdcodingcollective-collab/element-heroes-the-periodic-wars*
