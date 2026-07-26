# Element Heroes — The Periodic Wars

> *"Learn the elements. Master the reactions. Win the Periodic Wars."*

A pixel-art 2D top-down adventure game built in **Godot 4** around all 118 elements of the periodic table. Collect real elements, craft real chemical compounds, and battle element-themed enemies across six biomes — all grounded in actual chemistry.

**Target audience:** Grades 6–12 · **Engine:** Godot 4 (GDScript) · **Status:** Active development

---

## Features

### Exploration & World
- **Procedurally generated top-down world** — 200×200 tile map across 6 distinct biomes
- **6 element-themed biomes** — each with unique ore deposits, enemies, and a Compound Titan boss
- **Ashenveil village** — NPC hub with Prof. Aldric Voss, the Synthesizer machine, and the research lab

### Chemistry Crafting
- **All 118 elements** collectible with realistic lab equipment constraints (containers, PPE tiers)
- **64 compound recipes** matching real chemical formulas in a 3×3 crafting grid
- **Synthesizer machine** — polymer lab for advanced plastic/composite intermediates
- **Real lab handling data** — every element requires the correct container tier and PPE

### Combat
- **Real-time Zelda-style combat** — melee arc attacks + ranged projectiles
- **10 weapons (Tiers 1–5)** — melee and ranged, with DoT effects (burn, irradiate, poison)
- **5 armors (Tiers 1–5)** — flat damage reduction, single equipment slot
- **I-frames, stun, knockback, armor corrode** — full status effect system

### Enemies & Bosses
- **18 CHIMERA creature types × 3 tiers** = 54 total variants, fully data-driven
- **6 Compound Titan bosses** — 3-phase fights with arena hazards and element drops
- **Special abilities** — explosions, auras, ranged attacks, phase transitions, drain effects

### Education — Phase 6
- **In-game Compendium** — 118-element periodic table, auto-unlocks on discovery
- **Science Mini-Game** — chemistry quiz at Aldric's desk, 26 questions across 6 topics
- Element rewards for correct answers · HP penalty + explanation for wrong ones
- S/A/B/C graded sessions with Prof. Aldric quotes

### Audio & Art (not started)
- **AudioManager** autoload is written and call sites are wired — but no `.ogg` files exist yet
- Full **sprite animation spec** written (`assets/sprites/SPRITE_SPEC.md`)
- **No art exists.** The game currently renders entirely as coloured rectangles, and
  no sprite is referenced by any scene or script. See `assets/sprites/reference/README.md`

---

## Biomes

| Biome | Elements | Boss Titan |
|-------|----------|-----------|
| Surface Plains | Na, K, C | PEROXIS — Na₂O₂ |
| Underground Mines | Fe, Cu, Zn, Ni | CHALCOR — CuFeS₂ |
| Crystal Caverns | Ag, Au | AURIUM — HAuCl₄ |
| Sky Islands | K, Na | AZRAEL — NaN₃ |
| Ocean Floor | Cu, Zn | ATACAMA — Cu₂Cl(OH)₃ |
| Magma Layer | U, Th, Pt | URANOX — UO₂ |

---

## Controls

| Key | Action |
|-----|--------|
| WASD | Move (8-directional) |
| Left Click | Dig / collect element |
| Right Click / Space | Attack |
| E | Toggle inventory |
| C | Toggle crafting / Compendium |
| F | Interact — NPC / Synthesizer / Lab desk |
| X | Save game |
| ESC | Close UI |

---

## Crafting Examples

```
[ Na ] [ Cl ] [    ]   →   NaCl  (Table Salt)
[    ] [    ] [    ]
[    ] [    ] [    ]

[ Fe ] [ Fe ] [ Fe ]   →   Fe₂O₃  (Iron Oxide / Rust)
[ O  ] [ O  ] [ O  ]
[    ] [    ] [    ]

[ H  ] [ O  ] [ H  ]   →   H₂O  (Water)
[    ] [    ] [    ]
[    ] [    ] [    ]
```

---

## Science Quiz Topics

Questions in Aldric's lab span 6 chemistry categories:

| Category | Examples |
|----------|----------|
| Atomic structure | Proton counts, ions, isotopes |
| Periodic table | Groups, periods, electronegativity |
| Compounds | NaCl, H₂O, CO₂, Na₂O₂ formulas |
| Reactivity | Alkali metals, combustion, displacement |
| States of matter | Boiling points, sublimation |
| Lab safety | PPE, acid spills, radiation shielding |

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Engine | Godot 4 (GDScript, strict typing) |
| Pixel Art | Aseprite / Pixelorama |
| Element Data | JSON (118 elements, 64 recipes) |
| Audio | Godot AudioStreamPlayer + custom AudioManager |
| Version Control | Git + GitHub |
| Target Platforms | Web (HTML5), Windows, macOS, Linux |

---

## Project Structure

```
├── data/                   # JSON game data (elements, compounds, enemies, bosses, quiz)
├── scripts/
│   ├── player/             # Movement, inventory, equipment, weapons, armor
│   ├── world/              # World gen, enemies, bosses, NPCs, hazards, lab desk
│   ├── ui/                 # HUD, crafting, compendium, synthesizer, quiz mini-game
│   ├── audio/              # AudioManager autoload
│   ├── crafting/           # CraftingSystem autoload
│   └── data/               # ElementDB + SaveSystem autoloads
├── scenes/                 # Godot .tscn scene files
├── assets/
│   ├── sprites/            # Pixel art (SPRITE_SPEC.md has full animation spec)
│   └── audio/
│       ├── music/          # Biome + boss music (.ogg loops)
│       └── sfx/            # Sound effects (.ogg one-shots)
└── .claude/plans/          # Development plan and session notes
```

---

## Development Roadmap

| Phase | Focus | Status |
|-------|-------|--------|
| 1 — Foundation | Engine setup, element data, prototype | ✅ Complete |
| 2 — World Gen | Procedural biomes, ore spawning | ✅ Complete |
| 3 — Crafting | 3×3 grid, 65+ recipes, Synthesizer | ✅ Complete |
| 4 — Combat | Enemies, bosses, weapons, armor | ✅ Complete |
| 5 — Building | Compound-based block placement | ⬜ Planned |
| 6 — Education | Science mini-game, compendium, quiz | ✅ Complete |
| 7 — Polish | Pixel art sprites, music, SFX, story | ⬜ Not started |

Full plan: [`.claude/plans/game-development-plan.md`](.claude/plans/game-development-plan.md)

---

## Educational Goals

- Teach element symbols, atomic numbers, and group properties through gameplay
- Reinforce real compound formulas via crafting mechanics
- Introduce chemistry concepts — reactivity, conductivity, states of matter, lab safety
- Quiz system rewards learning with in-game element drops
- Compendium auto-discovery encourages exploration and retention

---

## Contributing

See `PROGRESS.md` for full build status, system documentation, and next steps.
See `assets/sprites/SPRITE_SPEC.md` for the pixel art animation specification.
