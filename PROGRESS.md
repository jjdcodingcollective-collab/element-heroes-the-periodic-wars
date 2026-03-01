# Element Heroes — The Periodic Wars
## Development Progress Log

Last updated: 2026-03-01

---

## Project Overview

A 2D pixel-art top-down adventure game (Godot 4 / GDScript) built around the 118 elements of the periodic table. Players explore a procedurally generated world, collect elements in realistic lab containers, combine them into real chemical compounds, craft weapons and armor, and battle element-themed enemies.

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
| Lab equipment system | ✅ Done | Container + glove tier hierarchy |
| Inventory system | ✅ Done | Float amounts, inventory_changed signal |
| HUD | ✅ Done | Health, inventory bar, minimap, biome, weapon + armor display |
| Minimap | ✅ Done | Live player position overlay |
| Crafting UI | ✅ Done | 3x3 grid, auto-equips weapons/armor |
| Crafting system | ✅ Done | Recipe matching, item-ingredient support |
| Dialogue system | ✅ Done | Multi-line NPC dialogue |
| NPC (Aldric) | ✅ Done | Placed in Ashenveil village |
| Camera | ✅ Done | World-bounds clamping |
| Save/load system | ✅ Done | Inventory, equipment, weapon, armor, compendium |
| Enemy system | ✅ Done | Patrol/chase AI, contact damage, element drops, burn DoT |
| Compendium UI | ✅ Done | 118-element grid, auto-discovers on first collect |
| Weapon system | ✅ Done | 10 weapons tier 1-5, melee arc + ranged projectile, DoT |
| Armor system | ✅ Done | 5 armors tier 1-5, flat DR%, single Zelda-style slot |
| Synthesizer machine | ✅ Done | World object + UI, 5 polymer intermediates |
| Pixel art sprites | ⬜ Pending | All visuals are ColorRect placeholders |
| Sound / music | ⬜ Pending | No audio yet |
| Enemy variety | ⬜ Pending | Only 1 base type — need typed variants |
| Boss encounters | ⬜ Pending | Phase 4 |
| Building system | ⬜ Pending | Phase 5 |
| Quiz / achievement system | ⬜ Pending | Phase 6 |

---

## File Structure

```
element-heros---the-periodic-wars/
├── data/
│   ├── elements.json               # 118 element definitions
│   ├── compounds.json              # 65+ recipes: base, weapons, polymers, armors
│   └── element_lab_handling.json  # Real lab containers/PPE per element
├── scenes/
│   ├── player/
│   │   └── player.tscn            # CharacterBody2D + Inventory + Equipment + Weapon + Armor
│   ├── ui/
│   │   ├── hud.tscn               # Health bar, inventory bar, minimap, biome, compendium
│   │   ├── crafting_ui.tscn       # 3x3 crafting grid
│   │   ├── compendium_ui.tscn     # 118-element periodic table reference
│   │   └── synthesizer_ui.tscn    # Polymer lab 3x3 grid
│   └── world/
│       ├── world.tscn             # Main scene
│       ├── npc.tscn               # Aldric the Alchemist
│       ├── enemy.tscn             # Patrol enemy base scene
│       ├── synthesizer.tscn       # Synthesizer world object
│       └── projectile.tscn        # Ranged weapon projectile
├── scripts/
│   ├── player/
│   │   ├── player.gd              # Movement, digging, combat, i-frames, equip helpers
│   │   ├── inventory.gd           # Float amounts, has/remove elements
│   │   ├── equipment.gd           # Lab container/glove tier system
│   │   ├── weapon.gd              # Melee arc, ranged spawn, DoT burn
│   │   └── armor.gd               # Single armor slot, get_damage_reduction()
│   ├── world/
│   │   ├── world.gd               # World gen, biomes, enemy/synthesizer spawn
│   │   ├── enemy.gd               # Patrol/chase AI, damage, drops, burn tick
│   │   ├── npc.gd                 # Interact radius, dialogue trigger
│   │   ├── synthesizer.gd         # World object, F key opens SynthesizerUI
│   │   ├── projectile.gd          # Speed/range/splash/piercing/burn
│   │   └── game_camera.gd         # Camera with world-bounds clamping
│   ├── ui/
│   │   ├── hud.gd                 # Health/inventory/weapon/armor refresh, discovery hook
│   │   ├── minimap.gd             # Player dot on tile overview
│   │   ├── crafting_ui.gd         # Slot grid, recipe lookup, craft + auto-equip
│   │   ├── dialogue_ui.gd         # Multi-line typewriter dialogue
│   │   ├── compendium_ui.gd       # Grid build, category colours, detail panel
│   │   └── synthesizer_ui.gd      # Polymer crafting, output to equipment.items
│   ├── crafting/
│   │   └── crafting_system.gd     # Autoload: recipe matching, item-ingredient crafting
│   └── data/
│       ├── element_database.gd    # Autoload: elements + handling data
│       └── save_system.gd         # Autoload: save/load all player state
└── project.godot                  # 1280x720, canvas_items, gravity=0, input map
```

---

## Weapon System

**Controls:** Right-click or Space to attack. Facing direction = melee arc direction.

| Tier | Melee | Recipe | Damage | Special |
|------|-------|--------|--------|---------|
| 1 | Bronze Sword | Cu x3 + Sn | 12 | Starter weapon |
| 2 | Steel Sword | Fe x4 + C | 20 | — |
| 3 | Titanium Blade | Ti x2 + N | 30 | — |
| 4 | Thermite Blade | Fe x2 + O x3 + Al x2 | 45 | Burns 5/s x 3s |
| 5 | Plutonium Edge | Pu + O x2 | 80 | Irradiates 15/s x 4s, boss required |

| Tier | Ranged | Recipe | Damage | Special |
|------|--------|--------|--------|---------|
| 1 | Flint Arrow | Si + C | 10 | — |
| 2 | Phosphorus Bolt | P x4 | 18 | Burns 4/s x 2s |
| 3 | Chlorine Bomb | Cl x2 | 25 | AoE 32px poison |
| 4 | Uranium Shell | U + O x2 | 50 | Piercing |
| 5 | Plutonium Cannon | Pu + F x6 | 90 | AoE 40px irradiate, boss required |

Crafting a weapon auto-equips it. Saved/loaded with game state.

---

## Armor System

Single slot (Zelda-style). Formula: `final_damage = incoming x (1.0 - DR)`

| Tier | Armor | Recipe | DR |
|------|-------|--------|----|
| 1 | Limestone Jerkin | Ca x2 + C + O x3 | 10% |
| 2 | Iron Plate | Fe x6 + C x2 | 20% |
| 3 | Kevlar Vest | PPTA x2 + Polyethylene + PVC | 35% |
| 4 | Titanium Composite | Ti x3 + Al x2 + Polycarbonate x2 | 50% |
| 5 | Graphene Nanosuit | C x4 + Boron Nitride x3 | 70% |

Tier 3-5 require polymer intermediates from the Synthesizer. Crafting auto-equips.

---

## Synthesizer Machine

World object at tile (22,12), east of Ashenveil village. Press **F** nearby to open.

| Polymer | Recipe | Used In |
|---------|--------|---------|
| Polyethylene | C x2 + H x4 | Kevlar Vest |
| PVC Sheet | C x2 + H x3 + Cl | Kevlar Vest |
| PPTA Fiber | C x6 + H x4 + N + O | Kevlar Vest (Kevlar) |
| Polycarbonate Panel | C x3 + H x4 + O | Titanium Composite |
| Boron Nitride Sheet | B + N | Graphene Nanosuit |

Polymers are stored as equipment items. Basic crafting table blocks polymer recipes.

---

## Lab Equipment System

Every element requires real-world lab containers and PPE based on `element_lab_handling.json`.

| Container tier | Examples |
|---------------|---------|
| 0 — Standard Vial | H, C, N, O, common solids |
| 1 — Glass Vial | Hg, Br, I, liquids |
| 2 — Sealed/Pressure | F, Cl, noble gases |
| 3 — Inert Container | Na, K, Li (pyrophoric) |
| 4 — Lead Container | U, Th, Ra, Pu (radioactive) |

Player starts with 20x Standard Vials + Nitrile Gloves. Higher-tier containers substitute for lower.

---

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Left Click | Dig (within 48px) |
| Right Click / Space | Attack |
| E | Toggle inventory bar |
| C | Toggle crafting / Compendium |
| F | NPC dialogue / Synthesizer |
| X | Save game |

---

## MVP Checklist

- [x] Procedural world generation with 6 biomes
- [x] All 118 elements collectible
- [x] 3x3 crafting grid with 65+ recipes
- [x] Real-time combat — melee + ranged, tier 1-5
- [x] Armor system — tier 1-5, damage reduction
- [x] Synthesizer — polymer/plastic crafting station
- [x] Lab equipment system (containers + PPE)
- [x] Save/load (inventory, weapon, armor, compendium)
- [x] In-game element Compendium (auto-discovers on collect)
- [ ] Pixel art sprites
- [ ] Enemy variety (Alkali Golem, Wraith, Toxic Sludge)
- [ ] Boss encounters
- [ ] Sound and music
- [ ] 30-60 min of story content

---

## Commit History

| Hash | Description |
|------|-------------|
| `6ac608b` | Add armor system and Synthesizer machine for polymers/plastics |
| `a9c0e77` | Add Zelda-style real-time combat system |
| `05c1750` | Add PROGRESS.md — full build status and system docs |
| `5a71bd5` | Track element lab handling data file |
| `0f6c81a` | Add enemy system and compendium scene |
| `4ac8a91` | Add lab equipment system: containers, gloves, radiation suits |
| `206bd52` | Add grams/mL units, floating labels, inventory bar, health bar, save |
| `308629a` | Fix window size and disable gravity for top-down gameplay |

---

## Next Steps

1. **Enemy variety** — Alkali Golems (explode near water/brine), Noble Gas Wraiths (immune to DoT), Toxic Sludges (poison aura). Typed resistances per enemy class.
2. **Boss encounters** — One per biome. Endgame bosses require Pu weapons + Graphene Nanosuit.
3. **Pixel art sprites** — Replace all ColorRect placeholders (Aseprite pipeline).
4. **Sound and music** — Biome ambient tracks, dig SFX, combat hits, Synthesizer hum.
5. **Story / quest system** — Extend Aldric quest line, add NPCs per biome.
6. **Quiz mode** — Optional chemistry mini-challenges for bonus element drops.
7. **Building system** — Place compound blocks, construct structures.
