#!/usr/bin/env python3
"""Generate 16×16 pixel-art item icons for the journal inventory.

Hand-placed shapes on the real pixel grid (ART_STYLE.md: coloured 1-px outline,
3 shades + 1 highlight, light from the top-left), recoloured per item.
Writes assets/sprites/items/<item_id>.png. Deterministic; re-run after edits.

Usage:  python3 tools/generate_item_icons.py      (needs Pillow)
"""
import json
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "sprites", "items")

# Shape maps. O = outline, 1 = dark, 2 = mid, 3 = light, 4 = highlight,
# W = white glint, G = glass, B = brass, D = dark brass, . = transparent.
SHAPES = {
    "potion": [
        "......OOOO......",
        "......ODDO......",
        "......OBBO......",
        ".......OO.......",
        "......OGGO......",
        ".....OGWGGO.....",
        "....OGWGGGGO....",
        "...O3344333O....",
        "..O332433222O...",
        "..O322222221O...",
        "..O322222221O...",
        "..O222222211O...",
        "...O2222211O....",
        "....OO1111O.....",
        "......OOOO......",
        "................",
    ],
    "crystal": [
        "................",
        ".......OO.......",
        "......O43O......",
        ".....O4332O.....",
        "....O43322O.....",
        "....O433221O....",
        "...O4433221O....",
        "...O4332221O....",
        "...O3332211O....",
        "...O3322211O....",
        "....O322211O....",
        "....O32211O.....",
        ".....O2211O.....",
        "......O11O......",
        ".......OO.......",
        "................",
    ],
    "canister": [
        "................",
        "......OOOO......",
        ".....OBBBDO.....",
        "......OBDO......",
        "....OOOOOOOO....",
        "...O34322211O...",
        "...O34322211O...",
        "...O3OOOOOO1O...",
        "...O3OWWWWO1O...",
        "...O3OOOOOO1O...",
        "...O34322211O...",
        "...O34322211O...",
        "...O33222111O...",
        "....OOOOOOOO....",
        "................",
        "................",
    ],
    "valve": [
        "................",
        "......OOOO......",
        ".....O4332O.....",
        "....O43OO21O....",
        "....O3O..O1O....",
        "....O43OO21O....",
        ".....O3221O.....",
        "......OBBO......",
        "......OBDO......",
        "..OOOOOBDOOOOO..",
        ".O4333BBDD2221O.",
        ".O3222BBDD2111O.",
        "..OOOOOBDOOOOO..",
        "......OBDO......",
        "......OOOO......",
        "................",
    ],
    "coil": [
        "................",
        "....OOOOOOOO....",
        "...O44333222O...",
        "...OOOOOOOOOO...",
        "...O33322221O...",
        "...OOOOOOOOOO...",
        "...O43332221O...",
        "...OOOOOOOOOO...",
        "...O33322211O...",
        "...OOOOOOOOOO...",
        "...O33222111O...",
        "....OOOOOOOO....",
        "......OBDO......",
        "......OBDO......",
        "......OOOO......",
        "................",
    ],
    "ingot": [
        "................",
        "................",
        "................",
        "................",
        ".....OOOOOOOO...",
        "....O44443332O..",
        "...O444333322O..",
        "..OOOOOOOOOO2O..",
        "..O3333222221O..",
        "..O3W33222211O..",
        "..O3332222111OO.",
        "..O222222111OO..",
        "..OOOOOOOOOOO...",
        "................",
        "................",
        "................",
    ],
    "feather": [
        "............OO..",
        "..........OO43O.",
        "........OO4332O.",
        ".......O44332O..",
        "......O4332O....",
        ".....O4332O.....",
        "....O4322O......",
        "....O3322O......",
        "...O3322O.......",
        "...O322O........",
        "..O3221O........",
        "..O221O.........",
        ".OD11O..........",
        "ODDOO...........",
        "OO..............",
        "................",
    ],
    "lens": [
        "................",
        ".....OOOOOO.....",
        "....ODBBBBDO....",
        "...OBOOOOOOBO...",
        "..OBO44WG33OBO..",
        "..OBO4WGG32OBO..",
        "..OBOGGG332OBO..",
        "..OBO3333221OBO.",
        "..OBO3332211OBO.",
        "..OBO2222111OBO.",
        "...OBOOOOOOBO...",
        "....ODBBBBDO....",
        ".....OOOOOO.....",
        "................",
        "................",
        "................",
    ],
    "pellet": [
        "................",
        "................",
        "................",
        "......OOOO......",
        "....OO4433OO....",
        "...O44433322O...",
        "...O43332221O...",
        "..O4333222211O..",
        "..O3332222111O..",
        "..O3322221111O..",
        "...O222211111O..",
        "...OO2221111O...",
        ".....OOOOOOO....",
        "................",
        "................",
        "................",
    ],
    "rods": [
        "................",
        "...OO..OO..OO...",
        "..O43OO43OO43O..",
        "..O32OO32OO32O..",
        "..O32OO32OO32O..",
        "..O32OO32OO32O..",
        "..O32OO32OO32O..",
        "..O32OO32OO32O..",
        ".OOOOOOOOOOOOOO.",
        ".OBBBBBBBBBBBDO.",
        ".ODDDDDDDDDDDDO.",
        ".OOOOOOOOOOOOOO.",
        "..O21OO21OO21O..",
        "..O11OO11OO11O..",
        "...OO..OO..OO...",
        "................",
    ],
    "bosskey": [
        "................",
        "....OOOOOO......",
        "...O443332O.....",
        "..O43OOOO21O....",
        "..O3O....O2O....",
        "..O3O....O1O....",
        "..O32OOOO11O....",
        "...O322211O.....",
        "....OOBBOO......",
        "......OBDOOOO...",
        "......OBBBBDDO..",
        "......OBDOODO...",
        "......OBDOO.....",
        "......OBBBDO....",
        "......OBDOO.....",
        "......OOO.......",
    ],
    "sword": [
        "..............OO",
        ".............O4O",
        "............O43O",
        "...........O43O.",
        "..........O43O..",
        ".........O43O...",
        "........O43O....",
        ".......O43O.....",
        "..OO..O43O......",
        "..OBO.O3O.......",
        "...OBO3O........",
        "....OBDO........",
        "...ODOBDO.......",
        "..ODO.OBDO......",
        ".OO....OO.......",
        "................",
    ],
    "armour": [
        "................",
        "...OOO....OOO...",
        "..O443OOOO332O..",
        "..O43333222221O.",
        "..O3O433322O1O..",
        "...OO433322OO...",
        "....O433322O....",
        "....O433221O....",
        "....O333221O....",
        "....O332211O....",
        "....OBBBBBDO....",
        "....O332211O....",
        "....O322211O....",
        ".....OOOOOO.....",
        "................",
        "................",
    ],
    "glove": [
        "................",
        "....OO.OO.......",
        "...O4OO4OOO.....",
        "...O3OO3O43O....",
        "...O3OO3O32O....",
        "...O3OO3O32OOO..",
        "...O33O3332O43O.",
        "...O3333322O32O.",
        "...O433332221O..",
        "...O33332221O...",
        "...O3322221O....",
        "....O222211O....",
        "....OBBBBBDO....",
        "....ODDDDDDO....",
        ".....OOOOOO.....",
        "................",
    ],
    "vial": [
        "................",
        "......OOOO......",
        "......OBDO......",
        "......OOOO......",
        "......OGGO......",
        "......OWGO......",
        "......OGGO......",
        "......OGGO......",
        "......O43O......",
        "......O32O......",
        "......O32O......",
        "......O21O......",
        "......O21O......",
        ".......OO.......",
        "................",
        "................",
    ],
}

# Ramp colours: (outline, dark, mid, light, highlight)
RAMPS = {
    "red":     ((70, 18, 24),  (140, 30, 40),  (196, 54, 58),  (232, 106, 96),  (255, 196, 170)),
    "teal":    ((16, 52, 60),  (30, 104, 110), (52, 160, 160), (110, 210, 200), (210, 250, 240)),
    "grey":    ((36, 38, 48),  (82, 88, 104),  (128, 136, 150), (176, 184, 196), (232, 236, 244)),
    "copper":  ((64, 30, 18),  (136, 66, 34),  (190, 104, 56),  (226, 150, 96),  (255, 214, 170)),
    "gold":    ((80, 52, 10),  (160, 112, 24), (214, 166, 44),  (244, 210, 96),  (255, 246, 200)),
    "silver":  ((44, 48, 60),  (110, 118, 136), (162, 170, 186), (206, 212, 224), (250, 252, 255)),
    "violet":  ((44, 20, 64),  (92, 46, 130),  (140, 86, 186),  (190, 140, 226), (236, 210, 255)),
    "green":   ((20, 52, 28),  (40, 104, 52),  (72, 156, 76),   (130, 204, 110), (210, 245, 190)),
    "ember":   ((50, 22, 12),  (110, 36, 16),  (200, 76, 28),   (244, 140, 48),  (255, 222, 140)),
    "slate":   ((22, 24, 30),  (46, 50, 60),   (72, 78, 92),    (110, 118, 134), (170, 178, 196)),
    "white":   ((54, 58, 74),  (150, 160, 180), (198, 206, 222), (230, 236, 246), (255, 255, 255)),
    "navy":    ((14, 22, 48),  (28, 46, 96),   (48, 78, 150),   (90, 130, 200),  (180, 210, 250)),
    "leather": ((48, 26, 14),  (96, 56, 30),   (138, 86, 48),   (180, 122, 74),  (226, 180, 130)),
    "uranium": ((20, 40, 18),  (40, 90, 30),   (80, 160, 50),   (150, 220, 80),  (230, 255, 170)),
}
BRASS = (214, 160, 64)
DARK_BRASS = (140, 96, 34)
GLASS = (196, 228, 236)
WHITE = (255, 255, 255)

# item id -> (shape, ramp)
ICONS = {
    # consumables
    "saline_tonic": ("potion", "red"), "buffer_solution": ("potion", "teal"), "lead_draught": ("potion", "slate"),
    # Peroxis
    "carbon_ember": ("crystal", "ember"), "pressure_valve": ("valve", "grey"), "canister_shell": ("canister", "silver"),
    "co2_canister": ("canister", "navy"),
    # Chalcor
    "frother_flask": ("potion", "white"), "collector_crystal": ("crystal", "gold"), "bellows_core": ("pellet", "copper"),
    "flotation_charge": ("canister", "gold"),
    # Aurium
    "citrate_phial": ("vial", "gold"), "heating_coil": ("coil", "copper"), "prism_lens": ("lens", "violet"),
    "reducing_lance": ("sword", "gold"),
    # Azrael
    "nitrite_salt": ("pellet", "white"), "acid_ampoule": ("vial", "green"), "storm_feather": ("feather", "white"),
    "nitrite_flask": ("potion", "navy"),
    # Atacama
    "zinc_ingot": ("ingot", "silver"), "copper_strap": ("coil", "copper"), "charged_coil": ("coil", "teal"),
    "sacrificial_anode": ("ingot", "grey"),
    # Uranox
    "boron_carbide_pellet": ("pellet", "slate"), "cadmium_sleeve": ("canister", "grey"), "rod_housing": ("valve", "slate"),
    "control_rods": ("rods", "uranium"),
    # equipment (shown on the Equipment page)
    "_weapon": ("sword", "silver"), "_armour": ("armour", "leather"), "_gloves": ("glove", "teal"), "_container": ("vial", "teal"),
}


def render(shape, ramp):
    o, d, m, l, h = RAMPS[ramp]
    lut = {"O": o, "1": d, "2": m, "3": l, "4": h, "W": WHITE, "G": GLASS, "B": BRASS, "D": DARK_BRASS}
    rows = SHAPES[shape]
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), shape
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in lut:
                im.putpixel((x, y), lut[ch] + (255,))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(ROOT, "data", "items.json")) as f:
        items = json.load(f)
    expected = set(items["consumables"]) | set(items["key_items"])
    missing = expected - set(ICONS)
    if missing:
        raise SystemExit("No icon recipe for: %s" % ", ".join(sorted(missing)))
    for item_id, (shape, ramp) in ICONS.items():
        render(shape, ramp).save(os.path.join(OUT, item_id + ".png"))
    print("wrote %d icons to %s" % (len(ICONS), OUT))


if __name__ == "__main__":
    main()
