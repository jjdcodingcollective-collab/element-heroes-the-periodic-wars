# Element Heroes — The Periodic Wars
## Development Progress Log

Last updated: 2026-03-01

---

## Project Overview

A 2D pixel-art top-down adventure game (Godot 4 / GDScript) built around the 118 elements of the periodic table. Players explore a procedurally generated world, collect elements in realistic lab containers, combine them into real chemical compounds, craft weapons and armor, battle element-themed enemies, and learn real science through an in-game quiz system.

- **Engine:** Godot 4 (GDScript, strict typing)
- **Target audience:** Grades 6–12 (educational science game)
- **Repo:** https://github.com/jjdcodingcollective-collab/element-heroes-the-periodic-wars
- **Full plan:** `.claude/plans/game-development-plan.md`

---

## Build Status

| System | Status | Notes |
|--------|--------|-------|
| Project scaffolding | ✅ Done | Godot 4, autoloads, input map |
| Element data (118 elements) | ✅ Done | `data/elements.json` |
| Compound recipes (65+) | ✅ Done | Base, weapons, polymers, armors |
| Lab handling data (118 elements) | ✅ Done | `data/element_lab_handling.json` |
| World generation | ✅ Done | 6 biomes, tile-based, ore spawning |
| Player controller | ✅ Done | 8-direction, top-down, i-frames |
| Element collection / digging | ✅ Done | Float grams/mL, range check |
| Lab equipment system | ✅ Done | 5-tier container + glove hierarchy |
| Inventory system | ✅ Done | Float amounts, inventory_changed signal |
| HUD | ✅ Done | Health, inventory bar, minimap, biome, weapon + armor display |
| Minimap | ✅ Done | Live player position overlay |
| Crafting UI | ✅ Done | 3×3 grid, auto-equips weapons/armor on craft |
| Crafting system | ✅ Done | Recipe matching, item-ingredient support |
| Dialogue system | ✅ Done | Multi-line NPC typewriter dialogue |
| NPC — Aldric Voss | ✅ Done | Placed in Ashenveil village, full quest intro dialogue |
| Camera | ✅ Done | World-bounds clamping |
| Save/load system | ✅ Done | Inventory, equipment, weapon, armor, compendium |
| Enemy system | ✅ Done | Patrol/chase AI, contact damage, element drops |
| Enemy variants — 18 CHIMERA × 3 tiers | ✅ Done | 54 variants total, specials, auras, resistances |
| Compendium UI | ✅ Done | 118-element grid, auto-discovers on first collect |
| Weapon system — 10 weapons (T1–T5) | ✅ Done | Melee arc + ranged projectile, DoT effects |
| Armor system — 5 armors (T1–T5) | ✅ Done | Single slot, flat DR%, Zelda-style |
| Synthesizer machine | ✅ Done | World object + UI, 5 polymer intermediates |
| Boss encounters — 6 Compound Titans | ✅ Done | 3-phase fights, arena hazards, lore drops |
| Science mini-game (quiz) | ✅ Done | Aldric's desk, 26 questions, element rewards, graded |
| Audio system | ✅ Done | AudioManager autoload, crossfade music, SFX pool — awaiting .ogg files |
| Sprite spec | ✅ Done | Full animation spec in `assets/sprites/SPRITE_SPEC.md` |
| Pixel art sprites | ⬜ Pending | All visuals are ColorRect placeholders — spec written |
| Sound / music files | ⬜ Pending | Folders created, AudioManager ready — awaiting .ogg files |
| Building system | ⬜ Pending | Phase 5 |
| Achievement system | ⬜ Pending | Phase 6 — streak/score tracking |
| Story expansion | ⬜ Pending | Phase 7 — NPC quests, biome narratives |

---

## File Structure

```
element-heros---the-periodic-wars/
├── data/
│   ├── elements.json                   # 118 element definitions
│   ├── compounds.json                  # 65+ recipes: base, weapons, polymers, armors
│   ├── enemy_data.json                 # 18 CHIMERA creature definitions
│   ├── boss_data.json                  # 6 Compound Titan definitions
│   ├── quiz_questions.json             # 26 science quiz questions (6 categories)
│   └── element_lab_handling.json       # Real lab containers/PPE per element
├── assets/
│   ├── sprites/
│   │   └── SPRITE_SPEC.md              # Full sprite + animation specification
│   └── audio/
│       ├── music/                      # Drop biome .ogg tracks here
│       └── sfx/                        # Drop sound effect .ogg files here
├── scenes/
│   ├── player/
│   │   └── player.tscn                 # CharacterBody2D + Inventory + Equipment + Weapon + Armor
│   ├── ui/
│   │   ├── hud.tscn                    # Health bar, inventory bar, minimap, biome, compendium
│   │   ├── crafting_ui.tscn            # 3×3 crafting grid
│   │   ├── compendium_ui.tscn          # 118-element periodic table reference
│   │   ├── synthesizer_ui.tscn         # Polymer lab 3×3 grid
│   │   └── science_minigame_ui.tscn    # Chemistry quiz mini-game UI
│   └── world/
│       ├── world.tscn                  # Main scene root
│       ├── npc.tscn                    # Aldric the Alchemist
│       ├── enemy.tscn                  # Patrol enemy base scene
│       ├── boss.tscn                   # Boss enemy scene
│       ├── synthesizer.tscn            # Synthesizer world object
│       ├── lab_desk.tscn               # Aldric's interactive research desk
│       └── projectile.tscn             # Ranged weapon projectile
├── scripts/
│   ├── player/
│   │   ├── player.gd                   # Movement, digging, combat, i-frames, audio hooks
│   │   ├── inventory.gd                # Float amounts, has/remove elements
│   │   ├── equipment.gd                # Lab container/glove tier system
│   │   ├── weapon.gd                   # Melee arc, ranged spawn, DoT burn
│   │   └── armor.gd                    # Single armor slot, get_damage_reduction()
│   ├── world/
│   │   ├── world.gd                    # World gen, biomes, all entity spawning
│   │   ├── enemy.gd                    # Patrol/chase AI, damage, drops, specials, audio
│   │   ├── boss.gd                     # Multi-phase boss controller
│   │   ├── boss_arena.gd               # Arena hazard spawner
│   │   ├── npc.gd                      # Interact radius, dialogue trigger
│   │   ├── lab_desk.gd                 # Interactive desk → opens science mini-game
│   │   ├── synthesizer.gd              # World object, F key opens SynthesizerUI
│   │   ├── projectile.gd               # Speed/range/splash/piercing/burn
│   │   ├── enemy_projectile.gd         # Silver Specter ranged bolt
│   │   ├── hazard_zone.gd              # Puddle/fire trail hazard
│   │   ├── hazard_zone_corrode.gd      # Acid pool with DR corrode
│   │   ├── hazard_zone_knockback.gd    # Wind column knockback
│   │   └── game_camera.gd              # Camera with world-bounds clamping
│   ├── ui/
│   │   ├── hud.gd                      # Health/inventory/weapon/armor refresh
│   │   ├── minimap.gd                  # Player dot on tile overview
│   │   ├── crafting_ui.gd              # Slot grid, recipe lookup, craft + auto-equip, audio
│   │   ├── dialogue_ui.gd              # Multi-line typewriter dialogue
│   │   ├── compendium_ui.gd            # Grid build, category colours, detail panel
│   │   ├── synthesizer_ui.gd           # Polymer crafting, output to equipment.items
│   │   └── science_minigame_ui.gd      # 3-question quiz, element rewards, S/A/B/C grading
│   ├── audio/
│   │   └── audio_manager.gd            # Autoload: crossfade music, SFX pool, volume control
│   ├── crafting/
│   │   └── crafting_system.gd          # Autoload: recipe matching, item-ingredient crafting
│   └── data/
│       ├── element_database.gd         # Autoload: elements + handling data loader
│       └── save_system.gd              # Autoload: save/load all player state
└── project.godot                       # Autoloads: ElementDB, CraftingSystem, SaveSystem, AudioManager
```

---

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Left Click | Dig (within 48px) |
| Right Click / Space | Attack |
| E | Toggle inventory bar |
| C | Toggle crafting / Compendium |
| F | NPC dialogue / Synthesizer / Lab desk |
| X | Save game |
| ESC | Close open UI |

---

## Weapon System

| Tier | Melee | Recipe | Damage | Special |
|------|-------|--------|--------|---------|
| 1 | Bronze Sword | Cu×3 + Sn | 12 | Starter |
| 2 | Steel Sword | Fe×4 + C | 20 | — |
| 3 | Titanium Blade | Ti×2 + N | 30 | — |
| 4 | Thermite Blade | Fe×2 + O×3 + Al×2 | 45 | Burns 5/s × 3s |
| 5 | Plutonium Edge | Pu + O×2 | 80 | Irradiates 15/s × 4s |

| Tier | Ranged | Recipe | Damage | Special |
|------|--------|--------|--------|---------|
| 1 | Flint Arrow | Si + C | 10 | — |
| 2 | Phosphorus Bolt | P×4 | 18 | Burns 4/s × 2s |
| 3 | Chlorine Bomb | Cl×2 | 25 | AoE 32px poison |
| 4 | Uranium Shell | U + O×2 | 50 | Piercing |
| 5 | Plutonium Cannon | Pu + F×6 | 90 | AoE 40px irradiate |

Crafting a weapon or armor auto-equips it. State saved/loaded with game.

---

## Armor System

Single slot (Zelda-style). Formula: `final_damage = incoming × (1.0 − DR)`

| Tier | Armor | DR | Requires |
|------|-------|----|---------|
| 1 | Limestone Jerkin | 10% | Ca×2 + C + O×3 |
| 2 | Iron Plate | 20% | Fe×6 + C×2 |
| 3 | Kevlar Vest | 35% | PPTA×2 + Polyethylene + PVC |
| 4 | Titanium Composite | 50% | Ti×3 + Al×2 + Polycarbonate×2 |
| 5 | Graphene Nanosuit | 70% | C×4 + Boron Nitride×3 |

Tier 3–5 require polymer intermediates from the Synthesizer.

---

## Synthesizer

World object at tile (22,12), east of Ashenveil village. Press **F** nearby to open.

| Polymer | Recipe | Used In |
|---------|--------|---------|
| Polyethylene | C×2 + H×4 | Kevlar Vest |
| PVC Sheet | C×2 + H×3 + Cl | Kevlar Vest |
| PPTA Fiber | C×6 + H×4 + N + O | Kevlar Vest |
| Polycarbonate Panel | C×3 + H×4 + O | Titanium Composite |
| Boron Nitride Sheet | B + N | Graphene Nanosuit |

---

## Lab Equipment System

| Container tier | Examples | Required PPE |
|---------------|---------|-------------|
| 0 — Standard Vial | H, C, N, O, common solids | Nitrile Gloves |
| 1 — Glass Vial | Hg, Br, I, liquids | Nitrile Gloves |
| 2 — Sealed/Pressure | F, Cl, noble gases | Nitrile Gloves |
| 3 — Inert Container | Na, K, Li (pyrophoric) | Heavy Gloves |
| 4 — Lead Container | U, Th, Ra, Pu (radioactive) | Radiation Suit |

Player starts with 20× Standard Vials + Nitrile Gloves.

---

## Science Mini-Game — Aldric's Lab

Accessible at the research desk inside Aldric's Workshop (tile 12,11). Press **F** to start.

- **3 questions per session**, drawn from a 26-question pool
- Questions are balanced across difficulty tiers 1/2/3 per session
- **Correct:** Element reward added to inventory + explanation shown
- **Wrong:** 5 HP penalty + explanation still shown (learning moment)
- **End screen:** S / A / B / C grade with a Prof. Aldric quote

| Category | Questions |
|----------|-----------|
| Atomic structure | Protons, ions, isotopes, subatomic particles |
| Periodic table | Groups, periods, electronegativity trends |
| Compounds | NaCl, H₂O, CO₂, Fe₂O₃, Na₂O₂ and more |
| Reactivity | Alkali metals, combustion, displacement reactions |
| States of matter | Phase changes, boiling points, sublimation |
| Lab safety | PPE, acid spills, radiation shielding |

---

## Audio System

`AudioManager` autoload (`scripts/audio/audio_manager.gd`) handles all game audio.

- Crossfading music player (channels A/B, 1.5s fade)
- 12-slot SFX pool (no AudioStreamPlayer exhaustion)
- Music and SFX buses with independent volume/mute controls
- `on_biome_changed(biome)` / `on_boss_fight_start()` API for automatic music switching
- Pre-wired calls in: player hit, dig, pickup, attack, enemy die, craft success, quiz correct/wrong

**To activate audio:** drop `.ogg` files into `assets/audio/music/` and `assets/audio/sfx/`,
then uncomment the matching preload lines in `audio_manager.gd`. No other changes needed.

See `assets/sprites/SPRITE_SPEC.md` for the full audio file list and sound descriptions.

---

## Boss System — Compound Titans

| Boss | Compound | Formula | Biome | Min Tier |
|------|----------|---------|-------|---------|
| PEROXIS | Sodium Peroxide | Na₂O₂ | Surface Plains | T2 |
| CHALCOR | Chalcopyrite | CuFeS₂ | Underground Mines | T2 |
| AURIUM | Chloroauric Acid | HAuCl₄ | Crystal Caverns | T3 |
| AZRAEL | Sodium Azide | NaN₃ | Sky Islands | T3 |
| ATACAMA | Atacamite | Cu₂Cl(OH)₃ | Ocean Floor | T3 |
| URANOX | Uraninite | UO₂ | Magma Layer | T4 |

Each boss has 3 phases (triggers at 55% and 25% HP), biome-specific arena hazards, phase-based special abilities, and element + lore-item drops on death.

---

## Enemy System — Project CHIMERA

18 creature types × 3 tier variants = 54 total. Fully data-driven via `data/enemy_data.json`.

| Tier | HP mult | Damage mult | XP |
|------|---------|-------------|-----|
| Basic | ×1.0 | ×1.0 | 10 |
| Intermediate | ×1.8 | ×1.6 | 25 |
| Expert | ×3.5 | ×2.8 | 60 |

Expert tier tinted purple in-game. Intermediate tinted warm gold.

---

## Next Steps

| Priority | Task | Phase |
|----------|------|-------|
| High | Pixel art sprites — use `SPRITE_SPEC.md` as guide in Aseprite | 7 |
| High | SFX files via jsfxr → drop into `assets/audio/sfx/` + uncomment in AudioManager | 7 |
| High | Biome music via BeepBox → drop into `assets/audio/music/` + uncomment | 7 |
| Medium | Building system — compound-based block placement | 5 |
| Medium | Achievement system — quiz streaks, boss kill milestones | 6 |
| Medium | Story expansion — NPC quests, biome-specific dialogue | 7 |
| Low | More compound recipes (target: 200+, current: 65+) | 3 |
| Low | Per-biome NPC characters | 7 |

---

## Commit History (recent)

| Hash | Description |
|------|-------------|
| *(next)* | Add Phase 6 science mini-game, audio system, sprite spec |
| `a5b17ad` | Add 6 compound titan bosses with 3-phase fights and arena hazards |
| `a0b4731` | Add 18 CHIMERA enemy variants with 3-tier grinding system |
| `4a3aad7` | Update PROGRESS.md — armor, weapons, Synthesizer |
| `6ac608b` | Add armor system and Synthesizer machine for polymers/plastics |
| `a9c0e77` | Add Zelda-style real-time combat system |
| `05c1750` | Add PROGRESS.md — full build status and system docs |
| `0f6c81a` | Add enemy system and compendium scene |
| `4ac8a91` | Add lab equipment system: containers, gloves, radiation suits |
