# Element Heroes — The Periodic Wars

> A pixel-based 2D top-down adventure game with Minecraft-style crafting built around all 118 elements of the periodic table.

---

## About the Game

**Element Heroes** is an educational adventure game where players explore a procedurally generated top-down pixel world, collect raw elements, and combine them into real chemical compounds to craft tools, weapons, structures, and more. Every mechanic is grounded in real chemistry — making science fun for grades 6–12.

---

## Core Features

- **Top-down exploration** — Bird's-eye pixel world with distinct biome regions spread across the map
- **Minecraft-style crafting** — 3×3 crafting grid where element arrangements follow real chemical formulas
- **All 118 elements** — Collect, combine, and discover every element on the periodic table
- **Chemistry-driven mechanics** — Alkali metals explode in water, noble gases are chemically inert, metals conduct electricity
- **Educational layer** — In-game element compendium, reaction log, and periodic table HUD

---

## Biomes

| Biome | Elements | Theme |
|-------|----------|-------|
| Surface Plains | Na, K, C, N, O | Starting area — alkali metals & nonmetals |
| Underground Mines | Fe, Cu, Zn, Ni | Rocky cavern region — transition metals |
| Crystal Caverns | He, Ne, Ar, F, Cl | Glowing cave region — noble gases & halogens |
| Sky Islands | Al, Mg, Li, Be | Elevated rocky platforms — lightweight metals |
| Ocean Floor | Hg, Br, I | Flooded region — lanthanides & aquatic elements |
| Magma Layer | U, Th, Ra, Pu | Dangerous southern region — radioactive elements |

Biomes are arranged as distinct horizontal regions on the top-down map. Players travel between them on foot, unlocking new elements and story content as they explore.

---

## Controls

| Key | Action |
|-----|--------|
| W / A / S / D | Move (8-directional) |
| Left Click | Dig / collect element node |
| Right Click | Place block |
| E | Open inventory |
| C | Open element compendium |
| F | Interact |
| X | Open crafting bench |

---

## Crafting System

Players arrange element "atoms" in a 3×3 grid matching real chemical formulas:

```
[ Na ] [ Cl ] [    ]     →   NaCl (Table Salt)
[    ] [    ] [    ]         Preserves food, crafts buffs
[    ] [    ] [    ]
```

**Modes:**
- **Explorer Mode** — Suggests valid compounds (beginner-friendly)
- **Scientist Mode** — Exact stoichiometry required (real chemistry)

### Example Compounds

| Compound | Formula | Game Use |
|----------|---------|----------|
| Steel | Fe + C | Strong building blocks |
| Glass | SiO₂ | Transparent walls/windows |
| Gunpowder | K + N + S + C | Mining, explosives |
| Aspirin | C₉H₈O₄ | Health potion |
| Neon Sign | Ne | Glowing decorations |
| Chlorine Gas | Cl₂ | Toxic weapon/trap |

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Game Engine | Godot 4 (GDScript) |
| Pixel Art | Aseprite |
| Map Editor | Tiled |
| Element Data | JSON (PubChem-sourced) |
| Audio | Godot AudioStreamPlayer |
| Version Control | Git + GitHub |
| Platforms | Web (HTML5), Windows, macOS, Linux |

---

## Development Roadmap

| Phase | Focus | Timeline |
|-------|-------|----------|
| 1 | Foundation & Prototype | Weeks 1–4 |
| 2 | World Generation & Biomes | Weeks 5–8 |
| 3 | Chemistry Crafting System | Weeks 9–12 |
| 4 | Combat & Enemies | Weeks 13–16 |
| 5 | Structures & Building | Weeks 17–20 |
| 6 | Education & UI Layer | Weeks 21–24 |
| 7 | Polish & Beta Release | Weeks 25–28 |

Full plan: [`.claude/plans/game-development-plan.md`](.claude/plans/game-development-plan.md)

---

## MVP Checklist

- [ ] Procedural top-down world generation (2 biomes)
- [ ] 20 collectible elements
- [ ] 3×3 crafting grid with 30+ compound recipes
- [ ] Basic combat (5 enemy types)
- [ ] Player progression (health, inventory, tools)
- [ ] Save/load system
- [ ] In-game periodic table reference UI
- [ ] 30–60 minutes of gameplay

---

## Educational Goals

- Teach element symbols, properties, and groups through gameplay
- Reinforce compound formulas via crafting mechanics
- Introduce real chemistry concepts: reactivity, conductivity, states of matter, bonding
- Target audience: **Grades 6–12**

---

## Enemy Types

- **Alkali Golems** — Explode on contact with water attacks
- **Noble Gas Wraiths** — Chemically inert, immune to compound effects
- **Iron Constructs** — Weaken with acid/oxidation
- **Toxic Sludges** — Heavy metal compounds, poison damage
- **Radioactive Elementals** — Magma region bosses

---

*"Learn the elements. Master the reactions. Win the Periodic Wars."*
