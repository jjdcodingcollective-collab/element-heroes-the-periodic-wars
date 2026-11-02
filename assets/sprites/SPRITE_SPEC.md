# Sprite Sheet Specification — Element Heroes

All sprites are **16×16 pixels** unless noted; humans (player and NPCs) are **16×24** (D-013). Export as PNG with transparent backgrounds.

**Status (2026-11-01):** none of these files exist yet; `assets/sprites/icon.png` is the only real art. The human style is locked (D-010, see `ART_STYLE.md` §3a). Human frames are 16×24 (D-013). Enemy/boss style and tiles are still open.
Godot import settings: Filter = **Nearest** (pixel art), Mipmaps = off.

**Integration:** `scripts/world/sprite_library.gd` loads these sheets automatically. Save a PNG at the path below with exactly this row/column layout and it appears in game; no SpriteFrames editing is needed. A missing or undersized sheet falls back to the coloured placeholder. NPC sheets are a single 2-frame `idle` row. Human frame size is `CHARACTER_FRAME` in that script (16×24); the sheet for Orion is therefore 64×192 px.

---

## Player — Orion (16×24 per frame)

**File:** `player/orion.png`
**Frames:** 24 drawn frames on a 4-column × 8-row grid (one animation per row; idle rows use the first 2 cells)

| Row | Animation | Frames | Description |
|-----|-----------|--------|-------------|
| 0 | idle_down  | 2 | Slight bob. Frame 0: neutral. Frame 1: 1px lower. |
| 1 | idle_up    | 2 | Back view. Same bob. |
| 2 | idle_left  | 2 | Side profile. |
| 3 | idle_right | 2 | Mirror of left (or redraw). |
| 4 | walk_down  | 4 | Leg swing, arm swing opposite. |
| 5 | walk_up    | 4 | Back view walk. |
| 6 | walk_left  | 4 | Side walk, hair/jacket bounce. |
| 7 | walk_right | 4 | Mirror or redraw. |

**Godot SpriteFrames setup:**
- Animation speed: idle = 4 fps, walk = 8 fps, all looping
- Animation names match exactly: `idle_down`, `walk_right`, etc.
- Hframes = 4, Vframes = 8 in the SpriteFrames editor, or use Aseprite export as strip

**Design notes:**
- Battered saddle-brown leather jacket over teal shirt, goggles on forehead (see `ART_STYLE.md`)
- Satchel visible on side views
- 3-colour palette + black outline + 1 highlight

---

## NPCs (16×24, 2-frame idle)

| File | Character | Colour | Notes |
|------|-----------|--------|-------|
| `npc/aldric.png` | Prof. Aldric Daedalus | Dark blue robes, white beard | Idle bob only, no walk needed |
| `npc/villager_a.png` | Generic villager | Brown tunic | |
| `npc/villager_b.png` | Generic villager | Green tunic | |

---

## Enemies (16×16 per frame, 4-frame walk cycle)

Each enemy is a real animal fused with an element (D-011). "Reverted" subjects went through Project REVERSION and look golem-like, spectral or ooze-like, but keep a readable trace of their animal silhouette (D-012).

Each enemy: 2 rows × 4 frames = 8 frames total.

**Rarity sheets (optional, D-014):** `enemies/<id>_strong.png`, `<id>_shiny.png`, `<id>_prime.png` use the same 2×4 layout. Strong and prime frames are the creature's `strong_footprint` in tiles × 16 px (32×32, 32×16 or 16×32; see `data/enemy_data.json`); shiny frames are 16×16. Without a rarity sheet the game reuses the base sheet, scaled up for strong/prime and tinted gold (shiny) or iridescent (prime).
Row 0 = walk left, Row 1 = walk right (or mirror).

| File | Enemy | Base animal | Colour palette |
|------|-------|-------------|---------------|
| `enemies/ashburn_shambler.png` | Ashburn Shambler | Black ash, orange ember glow | Black bear |
| `enemies/carbon_crawler.png` | Carbon Crawler | Dark grey/black, chitinous | Stag beetle |
| `enemies/potash_poltergeist.png` | Potash Poltergeist | Violet/purple spectral | Cane toad (reverted) |
| `enemies/iron_hulk.png` | Iron Hulk | Dark iron-grey, chunky | Rhinoceros |
| `enemies/copper_coil.png` | Copper Coil | Copper/verdigris green | King cobra |
| `enemies/zinc_phantom.png` | Zinc Phantom | Pale blue-white | Moon jellyfish (reverted) |
| `enemies/silver_specter.png` | Silver Specter | Translucent silver shimmer | Manta ray (reverted) |
| `enemies/gold_golem.png` | Gold Golem | Rich gold, heavy | Silverback gorilla (reverted) |
| `enemies/prismatic_hound.png` | Prismatic Hound | Shifting rainbow crystal | Grey wolf |
| `enemies/alkali_hawk.png` | Alkali Hawk | White feathers, fizzing tips | Peregrine falcon |
| `enemies/static_djinn.png` | Static Djinn | Electric blue/yellow arcs | Electric eel (reverted) |
| `enemies/stormwing.png` | Stormwing | Dark storm-cloud grey, lightning | Wandering albatross |
| `enemies/brine_crawler.png` | Brine Crawler | Cyan/teal crab | Mantis shrimp |
| `enemies/verdigris_lurker.png` | Verdigris Lurker | Mottled green-blue | Giant octopus (reverted) |
| `enemies/deep_shocker.png` | Deep Shocker | Deep purple, electric tendrils | Box jellyfish |
| `enemies/uranium_wraith.png` | Uranium Wraith | Black + sickly green aura | Death's-head hawkmoth (reverted) |
| `enemies/thorium_scorcher.png` | Thorium Scorcher | Orange-red flame lizard | Komodo dragon |
| `enemies/platinum_sentinel.png` | Platinum Sentinel | Silvery-white armoured | Pangolin (reverted) |

**Tier variants:** No separate sprites needed. Code applies modulate tint:
- Basic: no tint
- Intermediate: `modulate = Color(1.0, 0.85, 0.5)` (warm gold tint)
- Expert: `modulate = Color(0.8, 0.3, 1.0)` (purple tint)

---

## Bosses (one square frame per boss, 112–160 px, 4-frame idle + 2-frame attack)

Bosses are **mythical creatures** fused with their compound (D-011); regular enemies are real animals.

| File | Boss | Notes |
|------|------|-------|
| `bosses/peroxis.png` | PEROXIS — Sodium Peroxide | Manticore: crystal lion, scorpion tail, caustic foam |
| `bosses/chalcor.png` | CHALCOR — Chalcopyrite | Hoard dragon: fool's-gold scales, purple tarnish, sulfur breath |
| `bosses/aurium.png` | AURIUM — Chloroauric Acid | Three-headed hydra: molten gold, ruby acid frills |
| `bosses/azrael.png` | AZRAEL — Sodium Azide | White crystal phoenix: halo, airbag-swell detonation |
| `bosses/atacama.png` | ATACAMA — Atacamite | Leviathan: verdigris bronze hull plates, barnacles, embedded cannon, emerald glow |
| `bosses/uranox.png` | URANOX — Uraninite | Basilisk: black uraninite plates, green radioactive cracks, gaze beam |

**Boss SpriteFrames:** idle = 4 fps (4 frames loop), attack = 8 fps (2 frames, no loop). Frame size = the boss's `size` in `data/boss_data.json` (Peroxis 112, Chalcor 128, Aurium 128, Azrael 112, Atacama 144, Uranox 160), so a sheet is 4 × size wide and 2 × size tall (D-015).

---

## World Objects (16×16 or 32×32 where noted)

| File | Object | Size |
|------|--------|------|
| `world/synthesizer.png` | Synthesizer machine | 32×32 |
| `world/lab_desk.png` | Aldric's research desk | 16×16 |
| `world/well.png` | Village well | 16×16 |
| `world/market_stall.png` | Market stall awning | 32×16 |
| `world/projectile.png` | Arrow/bolt projectile | 8×4 |

---

## Tileset (16×16 each, one atlas PNG)

**File:** `tiles/world_tiles.png`
Layout: each row is one biome, columns are tile variants.

| Row | Biome | Tiles needed |
|-----|-------|-------------|
| 0 | Surface Plains | grass, dirt, stone path, rock wall |
| 1 | Underground Mines | dark stone, iron ore, copper ore, zinc ore |
| 2 | Crystal Caverns | crystal floor, silver ore, gold ore, purple crystal wall |
| 3 | Sky Islands | cloud tile, sky stone, air gap (transparent) |
| 4 | Ocean Floor | dark sand, teal water, coral, brine rock |
| 5 | Magma Layer | black volcanic rock, lava tile, uranium ore, magma wall |
| 6 | Village | wooden floor, stone path, building wall |

---

## HUD / UI Icons (16×16 unless noted)

| File | Use |
|------|-----|
| `ui/health_full.png` | Heart full |
| `ui/health_empty.png` | Heart empty |
| `ui/slot_bg.png` | Inventory/crafting slot background |
| `ui/slot_selected.png` | Slot highlight border |
| `ui/sword_icon.png` | Weapon slot |
| `ui/shield_icon.png` | Armor slot |
| `ui/compendium_icon.png` | Compendium button |

---

## Aseprite Export Settings

1. File → Export Sprite Sheet
2. Layout: **Rows** (one animation per row)
3. Output: `element, tag, frameNumber` naming
4. Export PNG + JSON data file (Godot can import the Aseprite file directly in Godot 4.3+)

**Godot 4 direct import:** place `.aseprite` files in `res://assets/sprites/` and Godot will auto-generate SpriteFrames — no manual frame setup needed.

---

## Audio File Spec

**Format:** OGG Vorbis (`.ogg`) — Godot's preferred format for both music and SFX
**Music:** Export at ~128–192 kbps, loopable (trim silence at start/end, loop start = 0)
**SFX:** Export at 44100 Hz stereo or mono, keep short (<2s for hits/UI, <5s for boss roars)

### Music tracks (drop into `assets/audio/music/`)
| Filename | Mood | BPM suggestion |
|----------|------|---------------|
| `surface_plains.ogg` | Bright, adventurous, chiptune | 120 |
| `underground_mines.ogg` | Tense, echo-y, dark | 90 |
| `crystal_caverns.ogg` | Ethereal, shimmering arpeggios | 100 |
| `sky_islands.ogg` | Floaty, light, high-register | 130 |
| `ocean_floor.ogg` | Watery, ambient, mysterious | 80 |
| `magma_layer.ogg` | Heavy, driving, industrial | 140 |
| `boss_battle.ogg` | Intense, dramatic, full arrangement | 160 |
| `title.ogg` | Epic, periodic table motif | 100 |

### SFX (drop into `assets/audio/sfx/`)
| Filename | Sound description |
|----------|-----------------|
| `dig.ogg` | Short stone scrape/thunk |
| `pickup.ogg` | Bright chime / sparkle |
| `attack_melee.ogg` | Sword whoosh |
| `attack_ranged.ogg` | Arrow twang/release |
| `player_hit.ogg` | Thud + brief grunt |
| `enemy_hit.ogg` | Impact crunch |
| `enemy_die.ogg` | Dissolve/burst with element-ish tone |
| `boss_hit.ogg` | Heavy clang/boom |
| `boss_phase.ogg` | Dramatic swell/roar (phase transition) |
| `craft_success.ogg` | Rising chime sequence |
| `quiz_correct.ogg` | Bright ascending ding ding |
| `quiz_wrong.ogg` | Low buzzer / descending tone |
| `interact.ogg` | Soft click / page turn |
| `ui_open.ogg` | Whoosh in |
| `ui_close.ogg` | Whoosh out |

**Quick start with jsfxr (browser, free):**
Go to https://sfxr.me — use presets: Pickup (pickup.ogg), Hit/Hurt (player_hit, enemy_hit), Explosion (enemy_die), Blip/Select (interact, ui sounds).
Export each as WAV, convert to OGG with Audacity (File → Export → OGG).

**Quick start with BeepBox (browser, free):**
Go to https://beepbox.co — set to loop, compose 8–16 bar loops, export as OGG directly.
