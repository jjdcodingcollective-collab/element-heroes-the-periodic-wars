# Art Style Guide — Element Heroes

This is the visual rulebook for every sprite, tile and portrait. `SPRITE_SPEC.md` says
*what* to draw and at what size; this file says *how* it should look. If the two disagree,
raise it rather than picking one silently.

**Direction (confirmed 2026-11-01):** keep the documented style — Golden Sun (GBA) mixed
with NES/SNES Zelda, top-down 3/4 perspective, 16×16 tile grid. The reference board below
refines that direction; it does not replace it.

---

## 1. Reference board

The user's reference images (2026-11-01) live in `uploads/`. They fall into three tiers.
Only Tier 1 sets rules; the others contribute specific ideas.

| Tier | What | Take from it |
|------|------|--------------|
| **1 — Core** | Golden Sun overworld sheets and screenshots (Isaac sheet, Vale crowd, inn scene, sanctum), Zelda: Minish Cap screenshots | Proportions, 3/4 camera, outline treatment, palette warmth, tile density, animation layout |
| **2 — Mood & bosses** | FF6 battle sprites and monster sheets, Golden Sun battle sprites, Chrono Trigger campfire, Sea of Stars–style sunset hill, FF6 Goddess | Boss silhouettes and detail level, lighting moods for set-piece scenes, portrait style (GBA cross-stitch portraits) |
| **3 — Ideas only** | Elemental golem sheets (pixel and painted), rusty robot, clockwork golem, eyeball wraith, ice spirit, flat icon packs (Tiny RPG, monster grid) | Creature concepts: "element made solid" golems, glowing cores, material-readable bodies. **Do not copy their rendering** — the painted golems are not pixel art, and the icon packs are too flat and chunky for our sprites |

---

## 2. Core rules

### Camera and proportions
- **Top-down 3/4 view** for all world sprites and tiles: you see the top and the front of
  every object. Building roofs and tree canopies take up most of their height.
- **Characters are chibi**: the head is roughly 40% of total height and the eyes sit low on
  the face. Golden Sun characters stand about **1.5 tiles tall**.
- **Light comes from the top-left**, always. Highlights go on top-left edges and shadows on
  bottom-right. Every world object casts a soft dark oval on the ground beneath it.

### Outlines
- **The outside edge is 1 pixel and dark**, but **coloured, not pure black**: dark brown on
  skin and wood, dark navy on blue cloth, deep green on foliage. This is the biggest single
  difference between our GBA look and NES art.
- **Inside lines are lighter** than the outside line: a darker shade of the area's own
  colour, never black.
- Avoid stair-step "jaggies" on curves. Use runs of 1-2-3 pixels and keep them consistent.

### Colour and shading
- **Each material gets 3 shades plus 1 highlight** (shadow, base, light, highlight pixel).
  This extends the spec's "3-colour palette + black outline + 1 highlight" to every material
  on a sprite, not just the sprite as a whole.
- **Saturated and warm.** Grass is yellow-green, not blue-green. Shadows shift toward
  purple or blue rather than just going darker grey.
- **Shade by hue shift:** move the hue as you darken (yellow → orange → red-brown), as both
  Golden Sun and FF6 do.
- **Dithering** only on big surfaces (cliffs, cave walls, large boss bodies) and only in a
  checker pattern of 2 shades. Never dither on 16×16 characters.
- **No anti-aliasing, blur, gradients or semi-transparent pixels** in sprites. Glows and
  auras are drawn as solid pixels in stepped rings.

### Detail
- **Faces:** 1-2 pixel eyes with an optional single white highlight pixel; the mouth is
  usually omitted.
- **Each character has one readable "icon" detail** visible at 1× zoom (Orion's goggles,
  Mira's bandana, Aldric's beard).
- **Element identity is shown through colour and material, not text.** Copper is orange
  with verdigris-green spots, iron is blue-grey with rust flecks, sodium is pale
  yellow-white crystal, uranium has a sickly green glow.

### Animation
- **Walk cycles are 4 frames:** contact, pass, contact, pass. Idles are 2 frames with a
  1-pixel bob.
- **Draw the left-facing frames and mirror them for the right**, unless the design is
  asymmetric (for example, a satchel worn on one side).
- **Boss idles loop** with a pulse or float (cores glow, shards orbit). Attacks have a
  clear wind-up frame, then an impact frame.

### Sizes
| Asset | Frame size | Notes |
|-------|-----------|-------|
| Tiles | 16×16 | One biome per row of the atlas |
| Player / NPC | 16×16 per `SPRITE_SPEC.md` | **Open decision:** Golden Sun characters are about 16×24. We recommend 16×24 frames, with the feet in the bottom 16×16 tile, to get the reference look. Until that is approved, draw to 16×16. |
| Enemies | 16×16 | Larger enemies are allowed as 32×32 if the spec is updated |
| Bosses | 48×48 | Mythical creatures (D-011). Top-heavy silhouettes with big upper bodies; read as large from a distance |
| Dialogue portrait | 48×48 | GBA bust style (see the cross-stitch portraits): 3/4 face, big eyes |

### File output
- **PNG only, with a transparent background.** JPG is not allowed because it blurs pixels.
- **Draw at 1× and let the engine scale it up** (`default_texture_filter=0`). Never commit
  upscaled art.
- **Use an indexed palette per sprite** where the tool supports it.
- `tools/validate_assets.py` must pass before you commit.

---

## 3. Character canon (visual)

| Character | Role | Palette and icon details |
|-----------|------|--------------------------|
| **Orion** | Protagonist, scientist | Sharp, angular build to match Mira (not rounded); spiky chestnut hair; **brass goggles on forehead**; **battered saddle-brown leather jacket** (scuffed elbows, stitched patches, brass buckles, upturned collar) over a dark teal shirt; olive canvas satchel; dark trousers; brown boots |
| **Mira** | Companion, combat (Fe/Cu) | Copper-red choppy hair; **sage-green bandana**; iron-grey padded vest with copper rivets; fingerless gloves; pick-hammer on her back; miner's lamp on her belt |
| **Prof. Aldric Daedalus** | Mentor | Dark blue robes; white beard (per the spec) |
| **Bosses (D-011)** | All 6 Compound Titans | **Mythical creature + compound.** Regular enemies are real animals + element. The creature is chosen for how it echoes the chemistry or lore |
| **PEROXIS** (Na₂O₂) | Boss 1, Surface Plains | Manticore: pale yellow crystal lion, crystal bat wings, scorpion tail oozing caustic foam, orange-white core |
| **CHALCOR** (CuFeS₂) | Boss 2, Underground Mines | Hoard dragon: fool's-gold plate scales with purple/blue tarnish, copper horns, sulfur breath, fake-gold hoard |
| **AURIUM** (HAuCl₄) | Boss 3, Crystal Caverns | Three-headed hydra: molten gold necks, ruby acid frills, acid spit hardens to gold |
| **AZRAEL** (NaN₃) | Boss 4, Sky Islands | White phoenix: crystal feathers, crystal halo, cold blue flame, chest swells like an airbag then detonates |
| **ATACAMA** (Cu₂Cl(OH)₃) | Boss 5, Ocean Floor | Leviathan: vast sea beast armoured in verdigris bronze hull plates, embedded cannon, emerald glow |
| **URANOX** (UO₂) | Boss 6, Magma Layer | Basilisk: black uraninite plates with radioactive green cracks, green crystal crown, lethal gaze beam |

---

## 3a. Locked human style (D-010, 2026-11-01)

Every human sprite matches these two approved concept sheets. Treat them as the
benchmark: put a new design next to them and it should look like the same game.

| Benchmark | File (outputs/concept-sprites/) | Gallery imageId |
|-----------|-------------------------------|-----------------|
| Orion v3, battered leather | `orion_overworld_concept_v3_leather.jpg` | `tn790ftmswq2461e4x7tydns9h8hcwh9` |
| Mira | `mira_overworld_concept.jpg` | `tn75jmwt0216jhk3tdeyfr2psn8hczhq` |

**Rules for every human design**
- **Sharp, not round.** Spiky or choppy hair in pointed tufts, narrow faces with a defined
  chin, lean builds, angular hems and cloth edges. If it looks soft or "blobby", redo it.
- **Grounded, worn materials:** leather, canvas, iron, padded cloth, all with scuffs,
  patches, rivets and buckles. No clean bright fantasy costumes. Bright saturated colour
  is kept for accents: hair, scarves, trims, gems, element glows.
- **One accent colour per character** that no one else in the main cast uses (Orion: teal
  shirt and brass goggles; Mira: sage bandana and copper hair).
- **Separate the silhouette by value:** hair, outerwear and bag must differ enough in
  lightness to stay readable at 1×. Don't let hair and coat share one tone.
- **Same scale and proportions as the benchmarks:** about 1.5 tiles tall, head about 40%
  of height, single-pixel eyes.

**How to generate a new human concept:** call image generation with
`reference_image_id` set to the Orion v3 imageId (or Mira for female or lighter
builds), and the prompt "Keep this exact pixel art style, proportions, grid layout and
sprite size, but draw a different character: …". Then check the result against the rules
above before showing it.

## 4. Prompt template (for AI concept passes)

Generated images are **concept art only**. They are JPGs on a background, off-grid and
inconsistent between frames, so final assets must be redrawn or cleaned up on the real
grid in Aseprite. Use this prompt template so all concept passes stay consistent:

> Game Boy Advance era pixel art in the exact style of Golden Sun and Zelda: The Minish
> Cap. Top-down 3/4 perspective, chibi proportions, big head. [SUBJECT + palette + icon
> detail]. [LAYOUT]. Dark coloured (not pure black) outlines, 3 shades per colour plus one
> bright highlight pixel, warm saturated GBA palette, single-pixel eyes, crisp hard pixels,
> no anti-aliasing, no blur, no text, consistent size every frame.

For bosses, swap the first sentence for "16-bit / GBA era pixel art boss sprite in the style
of Golden Sun / Final Fantasy VI monster sprites".
