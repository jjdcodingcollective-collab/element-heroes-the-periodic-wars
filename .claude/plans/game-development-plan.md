# Plan: Element Heroes — The Periodic Wars
## A Pixel-Based Science Adventure Game

---

## Summary

A 2D pixel-art top-down adventure game with Minecraft-style crafting built entirely around the 118 elements of the periodic table. Players explore a procedurally generated top-down world viewed from above, collect elements, combine them into compounds, and use chemistry-based mechanics to progress.

---

## Core Concept

- **World:** Procedurally generated top-down pixel world with biomes arranged as distinct regions spread across the map
- **Progression:** Collect raw elements → craft compounds → unlock tools/weapons/structures
- **Learning:** Every interaction teaches real chemistry (element properties, compound formulas, reactions)
- **Theme:** Top-down adventure with combat, exploration, and survival elements — viewed from above like classic Zelda or Stardew Valley

---

## Phase 1: Foundation & Prototype (Weeks 1–4)

### Goals
- Set up project structure and tech stack
- Implement core engine systems
- Basic playable prototype

### Tasks
1. **Tech Stack Selection**
   - Engine: Godot 4 (GDScript/C#) — ideal for 2D pixel games, free, open source
   - Alternatively: Phaser.js (web-based, easier for rapid prototyping)
   - Asset pipeline: Aseprite for pixel art, Tiled for map editing
   - Database: SQLite or JSON for element/compound data

2. **Element Data System**
   - Import all 118 elements with properties: atomic number, mass, group, period, electronegativity, reactivity
   - Build compound/reaction database (common compounds: H₂O, NaCl, Fe₂O₃, etc.)
   - Design "crafting recipe" system where element ratios = real chemical formulas

3. **Core Engine Systems**
   - Tilemap renderer (top-down pixel grid world)
   - Player controller (8-directional movement, dig, place blocks)
   - Top-down collision (no gravity — overhead view)
   - Camera follows player with smooth tracking

4. **Prototype Deliverable**
   - Open test world with 10 elements to collect
   - Basic crafting bench UI
   - 2–3 craftable compounds
   - Player can walk in all 8 directions, dig, and place blocks

---

## Phase 2: World Generation & Biomes (Weeks 5–8)

### Goals
- Procedurally generated world with element-themed biomes
- Element ore spawning system

### Biome Designs
| Biome | Theme | Elements Found |
|-------|-------|----------------|
| Surface Plains | Alkali metals & common nonmetals | Na, K, C, N, O |
| Underground Mines | Transition metals | Fe, Cu, Zn, Ni, Mn |
| Crystal Caverns | Noble gases & halogens | He, Ne, Ar, F, Cl |
| Deep Magma Layer | Radioactive elements | U, Th, Ra, Pu |
| Sky Islands | Lightweight metals | Al, Mg, Li, Be |
| Ocean Floor | Lanthanides & aquatic elements | Hg, Br, I |

### Tasks
1. Procedural terrain generation (Perlin noise / cellular automata)
2. Biome blending system
3. Element "ore" vein spawning with rarity scaling (noble gases = rarest)
4. Day/night cycle with atmospheric effects
5. Background parallax layers per biome

---

## Phase 3: Chemistry Crafting System (Weeks 9–12)

### Goals
- Full periodic table crafting UI
- Real-chemistry-based compound creation
- Element property mechanics

### Crafting System Design
- **Crafting Grid:** 3×3 grid (like Minecraft) where players arrange element "atoms"
- **Recipe Validation:** Check if arrangement matches a real chemical formula
- **Fuzzy Mode:** For beginners — suggest valid compounds from selected elements
- **Advanced Mode:** Exact ratio matching required (teaches stoichiometry)

### Chemistry Mechanics
- **Reactivity:** Alkali metals (Na, K) explode in water → game hazard
- **Conductivity:** Metals allow electrical circuits in structures
- **State of Matter:** Temperature affects element states (solid/liquid/gas blocks)
- **Toxicity:** Some compounds are hazardous → game damage mechanic
- **Luminescence:** Noble gases glow → lighting items

### Compound Categories & Uses
| Category | Examples | Game Use |
|----------|----------|----------|
| Structural | Steel (Fe+C), Concrete (Ca+Si+O) | Building blocks |
| Tools | Bronze (Cu+Sn), Titanium alloy | Pickaxes, swords |
| Medicine | Aspirin (C₉H₈O₄), Saltwater | Health potions |
| Explosives | Gunpowder (K+N+S+C), TNT | Mining, combat |
| Lighting | Neon signs, Phosphor compounds | Decoration, light |
| Poisons | H₂S, Chlorine gas | Weapons, traps |
| Fuel | Methane, Ethanol | Engines, torches |

---

## Phase 4: Combat & Enemies (Weeks 13–16)

### Goals
- Enemy system themed around element groups
- Element-based weapons and spells
- Boss encounters

### Enemy Archetypes
- **Alkali Golems** — Explode when hit with water attacks
- **Noble Gas Wraiths** — Immune to chemical reactions, only physical damage
- **Iron Constructs** — Rust mechanics (weaken with acid/water)
- **Toxic Sludges** — Made of heavy metal compounds, poison attacks
- **Radioactive Elementals** — Bosses from deep biomes

### Weapon System
- Element-infused weapons with chemistry-based effects
  - Sodium Sword: Reacts to water environments
  - Chlorine Gas Bomb: AoE toxic cloud
  - Magnesium Flare: Blinding bright light
  - Thermite Arrows: Iron oxide + aluminum → extreme heat

---

## Phase 5: Structures & Building (Weeks 17–20)

### Goals
- Full building system with compound-based blocks
- Crafting stations for advanced synthesis
- Player base/home system

### Building Blocks (Compound-Based)
| Block | Formula | Properties |
|-------|---------|------------|
| Glass | SiO₂ | Transparent |
| Steel | Fe + C | Strong, structural |
| Ceramic Tile | Al₂O₃ | Heat resistant |
| Copper Wire | Cu | Electrical |
| Rubber Insulation | C₅H₈ (polyisoprene) | Electrical insulation |
| Concrete | CaO + SiO₂ + H₂O | Heavy, blast resistant |

### Crafting Stations
- **Basic Workbench** — Simple element combinations
- **Furnace** — Smelting and thermal reactions
- **Electrolysis Chamber** — Break compounds into elements
- **Chemistry Lab** — Complex multi-step synthesis
- **Reactor Core** — Nuclear reactions (endgame)

---

## Phase 6: Education & UI Layer (Weeks 21–24)

### Goals
- In-game "Periodic Table" reference UI
- Element discovery journal
- Tooltips with real chemistry facts
- Achievement system tied to learning

### Educational Features
1. **Element Compendium** — Unlocked entries for each discovered element with real-world info
2. **Reaction Log** — Records all compounds crafted, shows formula and real-world use
3. **Chemistry Tips** — Context-sensitive hints during crafting
4. **Quiz Mode** — Optional mini-challenges for bonus rewards
5. **Periodic Table HUD** — Interactive table showing discovered elements, highlights current crafting materials

### Accessibility
- Colorblind mode (element categories use symbols, not just color)
- Difficulty tiers: Explorer (hints enabled), Scientist (real chemistry required)
- In-game glossary of chemistry terms

---

## Phase 7: Polish & Content Expansion (Weeks 25–28)

### Goals
- Full sound design and music
- Pixel art completion for all elements/compounds
- Balancing pass
- Save system and multiplayer groundwork

### Content Targets
- 118 elements (all collectible)
- 200+ craftable compounds
- 6 biomes fully generated
- 10+ enemy types
- 5 boss encounters
- 50+ building blocks
- Main story arc: "The Element Wars" narrative

---

## Tech Stack Recommendation

| Component | Technology |
|-----------|------------|
| Game Engine | **Godot 4** (GDScript) |
| Pixel Art | Aseprite |
| Map Editor | Tiled (Godot plugin) |
| Element Data | JSON database (PubChem API for reference) |
| Audio | FMOD or Godot AudioStreamPlayer |
| Version Control | Git + GitHub |
| Build/Deploy | Godot export → Web (HTML5), Windows, Mac, Linux |

---

## Data Architecture

### Element Schema
```json
{
  "atomic_number": 11,
  "symbol": "Na",
  "name": "Sodium",
  "group": 1,
  "period": 3,
  "category": "alkali_metal",
  "mass": 22.99,
  "electronegativity": 0.93,
  "reactivity": "very_high",
  "state_at_room_temp": "solid",
  "game_rarity": "common",
  "biome": "surface",
  "fun_fact": "Sodium explodes violently when it touches water!",
  "real_world_uses": ["table salt", "street lights", "soap making"]
}
```

### Compound/Recipe Schema
```json
{
  "name": "Sodium Chloride",
  "formula": "NaCl",
  "elements": {"Na": 1, "Cl": 1},
  "category": "salt",
  "game_item": "salt_block",
  "real_world_use": "Table salt, food preservation",
  "game_use": "Preserves food items, crafts seasoning buffs",
  "reaction_type": "ionic_bond"
}
```

---

## MVP Definition (Minimum Viable Product)

For a playable demo, achieve:
- [ ] Procedural world generation with 2 biomes
- [ ] 20 collectible elements
- [ ] 3×3 crafting grid with 30+ compound recipes
- [ ] Basic combat system with 5 enemy types
- [ ] Player progression (health, inventory, basic tools)
- [ ] Save/load system
- [ ] In-game element reference UI
- [ ] 30–60 minutes of gameplay content

---

## Milestones & Deliverables

| Milestone | Target | Deliverable |
|-----------|--------|-------------|
| M1 | Week 4 | Playable prototype (movement + basic crafting) |
| M2 | Week 8 | World generation demo with 2 biomes |
| M3 | Week 12 | Full chemistry crafting system |
| M4 | Week 16 | Combat loop complete |
| M5 | Week 20 | Building system complete |
| M6 | Week 24 | Educational layer + UI polish |
| M7 | Week 28 | Beta release candidate |

---

## Notes & Open Questions

1. **Multiplayer?** — Could add co-op (shared lab/crafting) in a later phase
2. **Mobile port?** — Touch UI would need redesign for periodic table crafting
3. **PubChem API** — Use for pulling real compound data to auto-generate recipes
4. **Licensing** — Ensure compound database is properly sourced/attributed
5. **Age target** — Middle school / high school level (grades 6–12)
6. **Monetization** — Free educational release? Or indie paid game on Steam/itch.io?
