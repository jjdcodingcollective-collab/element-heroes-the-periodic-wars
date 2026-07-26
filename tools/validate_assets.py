#!/usr/bin/env python3
"""Validate that every committed art asset is actually the image it claims to be.

Twenty-six sprite files in this repository were once committed as `.png` while
actually containing an HTML error page, and the problem went unnoticed for two
months because nothing ever opened them. This script is the guard against a
repeat: it checks magic bytes, not file extensions.

Run directly, or via the Tests workflow:

    python3 tools/validate_assets.py
"""

from __future__ import annotations

import hashlib
import struct
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ASSET_DIR = REPO_ROOT / "assets"

# extension -> (magic prefix, human label)
MAGIC = {
    ".png": (b"\x89PNG\r\n\x1a\n", "PNG"),
    ".jpg": (b"\xff\xd8\xff", "JPEG"),
    ".jpeg": (b"\xff\xd8\xff", "JPEG"),
    ".gif": (b"GIF8", "GIF"),
    ".webp": (b"RIFF", "WebP"),
    ".ogg": (b"OggS", "Ogg"),
    ".wav": (b"RIFF", "WAV"),
}

MIN_BYTES = 64


def png_dimensions(path: Path):
    """Return (width, height) for a PNG, or None if the header is unreadable."""
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or header[12:16] != b"IHDR":
        return None
    width, height = struct.unpack(">II", header[16:24])
    return width, height


def main() -> int:
    if not ASSET_DIR.is_dir():
        print("No assets directory at %s; nothing to validate." % ASSET_DIR)
        return 0

    errors = []
    warnings = []
    checked = 0
    digests = defaultdict(list)

    for path in sorted(ASSET_DIR.rglob("*")):
        if not path.is_file():
            continue
        expected = MAGIC.get(path.suffix.lower())
        if expected is None:
            continue

        checked += 1
        rel = path.relative_to(REPO_ROOT)
        magic, label = expected
        blob = path.read_bytes()

        if len(blob) < MIN_BYTES:
            errors.append(
                "%s: only %d bytes - almost certainly not a real %s"
                % (rel, len(blob), label)
            )
            continue

        if not blob.startswith(magic):
            preview = blob[:40].decode("utf-8", errors="replace").replace("\n", " ")
            errors.append(
                "%s: expected a %s but the file starts with %r" % (rel, label, preview)
            )
            continue

        if path.suffix.lower() == ".png":
            dims = png_dimensions(path)
            if dims is None:
                errors.append("%s: PNG header is malformed" % rel)
                continue
            if 0 in dims:
                errors.append("%s: PNG reports a zero dimension %s" % (rel, dims))
                continue

        digests[hashlib.md5(blob).hexdigest()].append(rel)

    # Many identical "different" sprites is the exact signature of the original
    # failure, so flag it loudly even when the files are valid images.
    for digest, paths in digests.items():
        if len(paths) > 2:
            listed = ", ".join(str(p) for p in paths[:5])
            if len(paths) > 5:
                listed += "..."
            warnings.append(
                "%d asset files are byte-identical (%s): %s"
                % (len(paths), digest[:8], listed)
            )

    for warning in warnings:
        print("WARNING: %s" % warning)

    if errors:
        print("\nFAILED - %d invalid asset(s) of %d checked:\n" % (len(errors), checked))
        for error in errors:
            print("  - %s" % error)
        return 1

    print("OK - %d asset file(s) validated, all genuine." % checked)
    return 0


if __name__ == "__main__":
    sys.exit(main())
