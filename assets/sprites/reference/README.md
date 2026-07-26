# Reference Art

This folder is currently **empty of images by design**.

## What happened here

An earlier development session attempted to produce sprite reference sheets via
AI image generation. The generation step did not return images — it returned an
HTML page — and the result was written to disk under `.png` filenames and
committed anyway. Twenty-six "sprites" across `player/`, `tiles/`, `enemies/`
and `bosses/` were byte-identical copies of the same 1,427-byte HTML document.

Nothing detected this for two months because the project had never been opened
in Godot, so the broken imports were never surfaced.

Those files have been removed. `assets/sprites/icon.png` is the only genuine
image in the repository.

## Before adding art here

Run the validator. It checks magic bytes rather than file extensions and will
reject anything that is not a real image:

```bash
python3 tools/validate_assets.py
```

This also runs automatically in CI (`.github/workflows/tests.yml`), so a repeat
of the original failure cannot reach `main` unnoticed.

## Do not "ask an AI to regenerate these"

The previous version of this file instructed exactly that, and that instruction
is what produced the broken commits. If you use image generation, you must
verify the bytes that land on disk before committing them.

## What is actually needed

`assets/sprites/SPRITE_SPEC.md` holds the full animation specification — frame
counts, dimensions, and per-entity descriptions. Any art path (hand-drawn,
commissioned, or programmatically generated) should be driven from that spec.

Note that producing the images is only half the work: **no sprite is currently
referenced by any scene or script.** The loading and animation layer
(`SpriteFrames`, `AnimatedSprite2D` wiring, tileset atlas slicing) still has to
be written, and that code is identical regardless of who draws the pixels.
