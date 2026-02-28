# Element Heroes — The Periodic Wars
## Development Progress Log

Last updated: 2026-02-28

---

## Project Overview

A 2D pixel-art top-down adventure game (Godot 4 / GDScript) built around the 118 elements of the periodic table. Players explore a procedurally generated world, collect elements in realistic lab containers, combine them into real chemical compounds, and battle element-themed enemies.

- **Engine:** Godot 4 (GDScript, strict typing)
- **Target audience:** Grades 6–12 (educational science game)
- **Repo:** https://github.com/jjdcodingcollective-collab/element-heroes-the-periodic-wars
- **Full plan:** `.claude/plans/game-development-plan.md`

---

## Build Status

| System | Status | Notes |
|--------|--------|-------|
| Project scaffolding | ✅ Done | Godot 4 project, autoloads, input map |
| Element data (118 elements) | ✅ Done | `data/elements.json` |
| Compound recipes (45+) | ✅ Done | `data/compounds.json` |
| Lab handling data (118 elements) | ✅ Done | `data/element_lab_handling.json` |
| World generation | ✅ Done | 6 biomes, tile-based, ore spawning |
| Player controller | ✅ Done | 8-direction, top-down, no gravity |
| Element collection / digging | ✅ Done | Float grams/mL, range check |
| Equipment system | ✅ Done | Containers + gloves tier hierarchy |
| Inventory system | ✅ Done | Float amounts, `inventory_changed` signal |
| HUD | ✅ Done | Health bar, inventory bar, biome label, minimap |
| Minimap | ✅ Done | Live player position overlay |
| Crafting UI | ✅ Done | 3×3 grid, C key toggle |
| Crafting system | ✅ Done | Recipe matching against compounds.json |
| Dialogue system | ✅ Done | Multi-line NPC dialogue, F/click to advance |
| NPC (Aldric) | ✅ Done | Placed in Ashenveil village |
| Camera | ✅ Done | World-bounds clamping, follows player |
| Save/load system | ✅ Done | X key save, inventory + equipment persisted |
| **Enemy system** | ✅ Done | Patrol/chase AI, contact damage, element drops |
| **Compendium UI** | ✅ Done | 118-element grid, category colours, detail panel |
| Pixel art sprites | ⬜ Pending | All visuals currently ColorRect placeholders |
| Sound / music | ⬜ Pending | No audio yet |
| Element-themed weapons | ⬜ Pending | Phase 4 |
| Boss encounters | ⬜ Pending | Phase 4 |
| Building system | ⬜ Pending | Phase 5 |
| Quiz / achievement system | ⬜ Pending | Phase 6 |

---

## File Structure

```
element-heros---the-periodic-wars/
├── data/
│   ├── elements.json               # 118 element definitions
│   ├── compounds.json              # 45+ craftable compound recipes
│   └── element_lab_handling.json  # Real lab containers/PPE per element
├── scenes/
│   ├── player/
│   │   └── player.tscn            # CharacterBody2D + Equipment child
│   ├── ui/
│   │   ├── hud.tscn               # Health bar, inventory bar, minimap, biome label, compendium
│   │   ├── crafting_ui.tscn       # 3×3 crafting grid, C to toggle
│   │   └── compendium_ui.tscn     # 118-element periodic table reference, C to open
│   └── world/
│       ├── world.tscn             # Main scene: world + player + HUD + NPC + enemies
│       ├── npc.tscn               # Aldric the Alchemist
│       └── enemy.tscn             # Patrol enemy base scene
├── scripts/
│   ├── player/
│   │   ├── player.gd              # Movement, digging, equipment checks, labels
│   │   ├── inventory.gd           # Float amounts, unit_for(), format_amount()
│   │   └── equipment.gd           # Container/glove tier system, consume_container_for()
│   ├── world/
│   │   ├── world.gd               # World gen, biomes, tile data, enemy spawning
│   │   ├── enemy.gd               # Patrol/chase AI, damage, element drops
│   │   ├── npc.gd                 # Interact radius, dialogue trigger
│   │   └── game_camera.gd         # Camera with world-bounds clamping
│   ├── ui/
│   │   ├── hud.gd                 # Health/inventory refresh, biome label
│   │   ├── minimap.gd             # Player dot on tile overview
│   │   ├── crafting_ui.gd         # Slot grid, recipe lookup, craft button
│   │   ├── dialogue_ui.gd         # Multi-line typewriter dialogue
│   │   └── compendium_ui.gd       # Grid build, discovered highlighting, detail panel
│   ├── crafting/
│   │   └── crafting_system.gd     # Autoload: recipe matching
│   └── data/
│       ├── element_database.gd    # Autoload: loads elements.json + handling.json
│       └── save_system.gd         # Autoload: save/load inventory + equipment
├── assets/
│   └── sprites/
│       └── icon.png               # Minimal 32×32 placeholder icon
└── project.godot                  # 1280×720, canvas_items stretch, gravity=0, input map
```

---

## Systems Detail

### Element Collection
- Left-click within 48px to dig a tile
- Each dig yields a random float amount (0.25–2.50 g or mL)
- Solids → grams, liquids/gases → milliliters
- Floating yellow `+1.25g Fe` label tweens up and fades

### Lab Equipment System
Every element has real-world lab requirements loaded from `element_lab_handling.json`:

| Container tier | Items | Examples |
|---------------|-------|---------|
| 0 — Standard | Standard Vial | H, C, N, O, common solids |
| 1 — Glass | Glass Vial | Hg, Br, I, liquids |
| 2 — Sealed/Pressure | Sealed Ampule, Pressure Canister | F, Cl, noble gases |
| 3 — Inert | Inert Container | Na, K, Li (pyrophoric) |
| 4 — Lead | Lead Container | U, Th, Ra, Pu (radioactive) |

| Handling tier | Item | Examples |
|--------------|------|---------|
| 0 | (none) | Inert elements |
| 1 | Nitrile Gloves | Most solids |
| 2 | Heavy Gloves | Hg, corrosives |
| 3 | Glove Box Kit | Pyrophorics, air-sensitive |
| 4 | Radiation Suit | Radioactive elements |

Higher-tier containers satisfy lower-tier requirements. Player starts with 20× Standard Vials + Nitrile Gloves.

### Enemy System
- **Patrol state:** Random direction changes every 1.5–3.5 s at 40 px/s
- **Chase state:** Triggered within 96px sight range, 80 px/s pursuit
- **Contact damage:** 10 HP per hit, 1 s cooldown, red `-10 HP` float label on player
- **On death:** Drops 1–2 elements from its biome into player inventory, green `+Fe` label
- **Spawning:** 4 hand-placed enemies in world.tscn + 3 procedural enemies per biome at world start (village safe zone excluded)

### Compendium
- Full-screen overlay (C to toggle)
- 18-column grid matching standard periodic table layout
- Undiscovered = dark grey; discovered = colour-coded by category
- Click any element for: symbol, name, atomic mass, category, biome location, fun fact
- `mark_discovered(symbol)` called automatically when element is first collected (hook point in inventory.gd)

### Save System
- X key saves to `user://savegame.json`
- Persists: player position, HP, inventory (float amounts), equipment counts, compendium discovered set

---

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Left Click | Dig (within 48px) |
| E | Toggle inventory panel |
| C | Toggle crafting UI / Compendium |
| F | Continue NPC dialogue |
| X | Save game |

---

## MVP Checklist (from plan)

- [x] Procedural world generation with 6 biomes
- [x] All 118 elements collectible (data complete)
- [x] 3×3 crafting grid with 45+ compound recipes
- [x] Basic combat system — patrol/chase enemies with element drops
- [x] Player HP, inventory, equipment system
- [x] Save/load system
- [x] In-game element reference UI (Compendium)
- [ ] Pixel art sprites (currently ColorRect placeholders)
- [ ] 5 enemy types (currently 1 base type)
- [ ] Boss encounters
- [ ] 30–60 min of story content

---

## Commit History

| Hash | Description |
|------|-------------|
| `5a71bd5` | Track element lab handling data file |
| `0f6c81a` | Add enemy system and compendium scene |
| `4ac8a91` | Add lab equipment system: containers, gloves, radiation suits |
| `206bd52` | Add grams/mL units, floating pickup labels, inventory bar, health bar, save key |
| `308629a` | Fix window size and disable gravity for top-down gameplay |
| `0e89259` | Fix four runtime errors and warnings |
| `b58625a` | Fix type inference on px/py/tile_x in minimap.gd |

---

## Next Steps (Phase 4+)

1. **Sprite art** — Replace all ColorRect placeholders with real pixel art (Aseprite)
2. **Enemy variety** — Alkali Golems, Noble Gas Wraiths, Toxic Sludges (type-specific AI + resistances)
3. **Element-based weapons** — Craft and equip chemistry weapons (Thermite Arrow, Chlorine Bomb)
4. **Boss encounters** — One boss per biome, drops rare elements
5. **Compendium discovery hook** — Auto-call `mark_discovered()` in inventory.gd when element first added
6. **Sound & music** — Ambient biome music, dig SFX, combat sounds
7. **Quiz mode** — Optional chemistry mini-challenges for bonus element drops
8. **Building system** — Place compound blocks, construct structures
