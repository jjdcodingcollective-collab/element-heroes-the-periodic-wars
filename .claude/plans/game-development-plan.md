# Plan: Element Heroes — The Periodic Wars
## Game Development Roadmap

Last updated: 2026-03-01

---

## Summary

A 2D pixel-art top-down adventure game built in Godot 4 around all 118 elements of the periodic table. Players explore a procedurally generated world, collect elements with realistic lab equipment, combine them into real chemical compounds, craft weapons and armor, battle element-themed enemies across 6 biomes, and learn real science through an embedded quiz system.

---

## Phase 1: Foundation & Prototype ✅ COMPLETE

**Delivered:**
- Godot 4 project with strict GDScript typing
- All 118 elements in `data/elements.json` (atomic number, mass, group, reactivity, biome, rarity)
- 65+ compound recipes in `data/compounds.json` with real chemical formulas
- Autoloads: `ElementDB`, `CraftingSystem`, `SaveSystem`, `AudioManager`
- Tilemap renderer (ColorRect tiles — sprite-ready swap points)
- Input map: WASD, left-click dig, right-click/space attack, E/C/F/X

---

## Phase 2: World Generation & Biomes ✅ COMPLETE

**Delivered:**
- 200×200 tile procedural world with FastNoiseLite
- 6 biomes arranged as horizontal regions on the map
- Biome-specific tile colors, ore spawning, and enemy weights
- Ashenveil village (6 buildings, well, market stall) at tile cluster (10–22, 10–18)
- Camera with world-bounds clamping

| Biome | X Range | Base Tile | Key Elements |
|-------|---------|-----------|-------------|
| Surface Plains | 0–39 | Grass/Dirt | Na, K, C |
| Underground Mines | 40–79 | Stone | Fe, Cu, Zn, Ni |
| Crystal Caverns | 80–109 | Stone | Ag, Au |
| Sky Islands | 110–139 | Dirt | K, Na |
| Ocean Floor | 140–169 | Sand | Cu, Zn |
| Magma Layer | 170–199 | Volcanic Rock | U, Th, Pt |

---

## Phase 3: Chemistry Crafting System ✅ COMPLETE

**Delivered:**
- 3×3 crafting grid with real chemical formula matching
- `CraftingSystem` autoload (`try_craft`, `try_craft_with_items`, `evaluate_grid`)
- Polymer/plastic intermediate system via Synthesizer machine (tile 22,12)
- Weapons and armor auto-equip on craft
- Equipment tier hierarchy (5 container tiers, 3 glove tiers, radiation suits)
- Lab handling constraints enforced on element collection

**Compound categories:** base materials, weapon recipes (melee + ranged T1–T5), armor recipes (T1–T5), polymer intermediates (5 types), healing, quest items

---

## Phase 4: Combat & Enemies ✅ COMPLETE

**Delivered:**

### Combat System
- Zelda-style real-time combat — melee arc (facing direction) + ranged projectile
- I-frames (0.5s), stun, knockback, armor corrode status effects
- 10 weapons: Bronze Sword → Plutonium Edge (melee T1–T5), Flint Arrow → Plutonium Cannon (ranged T1–T5)
- 5 armors: Limestone Jerkin (10% DR) → Graphene Nanosuit (70% DR)
- DoT effects: burn, irradiate, poison

### Enemy System — Project CHIMERA
- 18 creature types × 3 tiers = 54 variants (fully data-driven via `enemy_data.json`)
- AI: patrol → chase loop with sight radius, biome-weighted spawning
- 12+ special abilities: explosions, auras, ranged bolts, stun, knockback, armor corrode, shields
- Aura types: lightning, poison, irradiate (continuous proximity damage)

### Boss System — Compound Titans
- 6 bosses, one per biome (fully data-driven via `boss_data.json`)
- 3-phase architecture (triggers at 55% and 25% HP)
- Per-phase: color change, aura scaling, arena hazard rate, new special abilities
- Arena hazard types: water puddles, sulfur vents, acid pools, wind columns, brine tide, radiation zones
- Element + lore-item drops on death

---

## Phase 5: Structures & Building ⬜ PLANNED (Weeks 17–20)

**Goal:** Let players place compound-based blocks to build structures and crafting stations.

### Tasks
1. Block placement system (right-click place, left-click break)
2. Compound block library — Glass (SiO₂), Steel (Fe+C), Concrete (CaO+SiO₂+H₂O), Ceramic (Al₂O₃), Copper Wire (Cu), Rubber (C₅H₈)
3. Advanced crafting stations — Furnace (smelting), Electrolysis Chamber (break compounds), Chemistry Lab (complex synthesis)
4. Player base: persistent placed blocks saved with `SaveSystem`
5. Structure blueprints for common builds

---

## Phase 6: Education & UI Layer ✅ COMPLETE

**Delivered:**

### Compendium
- 118-element periodic table grid in-game, grouped by category
- Auto-discovers on first element collection
- Category colour-coding: Alkali, Transition Metals, Halogens, Noble Gases, etc.

### Science Mini-Game — Aldric's Lab
- Research desk world object inside Aldric's Workshop (tile 12,11)
- Press F to start a 3-question quiz session
- 26 questions across 6 categories (difficulty tiers 1/2/3)
- Correct → element reward in inventory + chemistry explanation
- Wrong → 5 HP penalty + explanation (learning moment preserved)
- End-screen grading: S / A / B / C with Prof. Aldric quote
- Questions balanced per session (one of each difficulty tier)

**Categories:** Atomic structure · Periodic table · Compounds · Reactivity · States of matter · Lab safety

### Still Pending (Phase 6)
- Achievement system — quiz streaks, boss kill milestones, first-collection badges
- Reaction log — record all crafted compounds with real-world context
- Extended glossary of chemistry terms

---

## Phase 7: Polish & Content Expansion 🔄 IN PROGRESS (Weeks 25–28)

### Audio — Ready, awaiting files
`AudioManager` autoload is complete with:
- Crossfading music player (A/B channels, 1.5s fade)
- 12-slot SFX pool
- `on_biome_changed()`, `on_boss_fight_start/end()` API
- All game events pre-wired (player hit, dig, pickup, attack, enemy die, craft, quiz)

**To activate:** drop `.ogg` files into `assets/audio/music/` and `assets/audio/sfx/`, uncomment preloads in `audio_manager.gd`.

| Music track | Mood | BPM |
|-------------|------|-----|
| `surface_plains.ogg` | Bright, adventurous chiptune | 120 |
| `underground_mines.ogg` | Tense, echo-y, dark | 90 |
| `crystal_caverns.ogg` | Ethereal, shimmering arpeggios | 100 |
| `sky_islands.ogg` | Floaty, light, high-register | 130 |
| `ocean_floor.ogg` | Watery, ambient, mysterious | 80 |
| `magma_layer.ogg` | Heavy, driving, industrial | 140 |
| `boss_battle.ogg` | Intense, dramatic | 160 |
| `title.ogg` | Epic, periodic table motif | 100 |

**Recommended tools:** jsfxr (browser, instant SFX) · BeepBox (browser, chiptune music loops) · Audacity (WAV→OGG conversion)

### Pixel Art — Spec written, awaiting assets
Full specification in `assets/sprites/SPRITE_SPEC.md` covering:
- Player (Kael): 16×16, 8 animations (idle/walk × 4 directions), 24 frames total
- 18 enemies: 16×16, 4-frame walk cycle per creature
- 6 bosses: 48×48, idle + attack frames
- World tiles: atlas PNG, 6 biome rows
- World objects: Synthesizer (32×32), lab desk, well, market stall
- HUD icons: hearts, inventory slots, weapon/armor slots

**Godot 4.3+:** Drop `.aseprite` files directly — auto-generates SpriteFrames, no manual setup.
Tier visual variants applied via code `modulate` (Intermediate = warm gold, Expert = purple).

### Story & Content Expansion
- Aldric quest line: deliver elements → unlock new dialogue and compendium entries
- Per-biome NPC characters (1 new NPC per biome)
- 30–60 minutes of narrative content
- More compound recipes (target: 200+, current: 65+)
- Balance pass on weapons, enemies, and bosses

---

## Milestones

| Milestone | Target | Status |
|-----------|--------|--------|
| M1 — Prototype | Week 4 | ✅ Done |
| M2 — World Gen | Week 8 | ✅ Done |
| M3 — Crafting | Week 12 | ✅ Done |
| M4 — Combat | Week 16 | ✅ Done |
| M5 — Building | Week 20 | ⬜ Planned |
| M6 — Education | Week 24 | ✅ Done |
| M7 — Beta | Week 28 | 🔄 In Progress |

---

## Autoloads

| Name | File | Role |
|------|------|------|
| `ElementDB` | `scripts/data/element_database.gd` | Loads all JSON data, recipe matching |
| `CraftingSystem` | `scripts/crafting/crafting_system.gd` | Grid evaluation, item-aware crafting |
| `SaveSystem` | `scripts/data/save_system.gd` | Persist/restore all player state |
| `AudioManager` | `scripts/audio/audio_manager.gd` | Music crossfade, SFX pool, volume |

---

## Open Questions

1. **Building system scope** — Full Terraria-style placement, or simpler room-based building?
2. **Multiplayer?** — Co-op lab sharing could be educationally powerful; deferred to post-beta
3. **Mobile port?** — Touch UI would need redesign; out of scope for MVP
4. **More compounds** — Currently 65+; PubChem API could auto-generate recipes to reach 200+
5. **Monetization** — Free educational release vs. paid indie game on itch.io/Steam
6. **Accessibility** — Colorblind mode (symbols not just color) planned for Phase 7

---

## Notes

- All game systems are **data-driven** — new enemies, bosses, compounds require only JSON entries
- **Sprite-swap ready** — all ColorRect placeholders have clear swap comments; animation code pre-wired
- **Audio-swap ready** — AudioManager is live, calls wired; files just need dropping in
- Physics: `default_gravity=0.0` (top-down, no gravity)
- Rendering: `canvas_items` stretch, 1280×720 base viewport, nearest-neighbor texture filter
