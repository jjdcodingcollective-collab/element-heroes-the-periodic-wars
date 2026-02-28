extends Node2D

# Top-down procedural world — ColorRect tiles, no TileSet asset needed.
# Phase 2: swap ColorRects for TileMap + sprite sheet without changing any
# game logic — just replace _create_tile() internals.

const TILE_SIZE: int = 16
const WORLD_WIDTH: int  = 200
const WORLD_HEIGHT: int = 200

# World pixel bounds — used by camera clamping
const WORLD_PX_W: float = WORLD_WIDTH  * TILE_SIZE
const WORLD_PX_H: float = WORLD_HEIGHT * TILE_SIZE

# Tile colours (replace with atlas UVs when upgrading to TileMap)
const COLOR_GRASS  := Color(0.24, 0.65, 0.24)
const COLOR_DIRT   := Color(0.55, 0.37, 0.21)
const COLOR_STONE  := Color(0.45, 0.45, 0.45)
const COLOR_WATER  := Color(0.20, 0.55, 0.90)
const COLOR_SAND   := Color(0.87, 0.80, 0.55)
const COLOR_LAVA   := Color(0.95, 0.35, 0.05)
const COLOR_ROCK   := Color(0.35, 0.33, 0.30)

# Ore colours keyed by element symbol
const ORE_COLORS := {
	"Na": Color(0.9,  0.9,  0.3),
	"K":  Color(0.8,  0.6,  0.9),
	"C":  Color(0.15, 0.15, 0.15),
	"Fe": Color(0.7,  0.35, 0.1),
	"Cu": Color(0.72, 0.45, 0.2),
	"Zn": Color(0.6,  0.75, 0.75),
	"Ni": Color(0.5,  0.7,  0.5),
	"Ag": Color(0.85, 0.85, 0.90),
	"Au": Color(1.0,  0.85, 0.0),
	"Pt": Color(0.9,  0.95, 1.0),
	"U":  Color(0.2,  0.8,  0.2),
	"Th": Color(0.3,  0.9,  0.4),
}

# Biomes — horizontal regions across the X axis
const BIOMES := [
	{ "name": "surface_plains",    "x_start": 0,   "x_end": 39,  "base": "grass", "elements": ["Na","K","C"] },
	{ "name": "underground_mines", "x_start": 40,  "x_end": 79,  "base": "stone", "elements": ["Fe","Cu","Zn","Ni"] },
	{ "name": "crystal_caverns",   "x_start": 80,  "x_end": 109, "base": "stone", "elements": ["Ag","Au"] },
	{ "name": "sky_islands",       "x_start": 110, "x_end": 139, "base": "dirt",  "elements": ["K","Na"] },
	{ "name": "ocean_floor",       "x_start": 140, "x_end": 169, "base": "sand",  "elements": ["Cu","Zn"] },
	{ "name": "magma_layer",       "x_start": 170, "x_end": 199, "base": "stone", "elements": ["U","Th","Pt"] },
]

# tile_data[Vector2i] = { "type", "element", "passable", optionally "body" }
var tile_data: Dictionary = {}
var tile_nodes: Dictionary = {}  # Vector2i -> ColorRect

func _ready() -> void:
	_generate_world()
	_spawn_village()
	# Wire HUD and CraftingUI after the full scene tree is loaded
	call_deferred("_init_ui")

func _init_ui() -> void:
	var player := get_node_or_null("Player")
	var hud    := get_node_or_null("HUD")
	if hud and player:
		hud.init(player, self)
		# Give CraftingUI a reference to the player inventory
		var crafting := get_node_or_null("CraftingUI")
		if crafting:
			var panel := crafting.get_node_or_null("Panel")
			if panel:
				panel.player_inventory = player.get_node_or_null("Inventory")
			crafting.add_to_group("crafting_ui")

	# Set Aldric's dialogue via exported property override in code
	# (avoids needing to open the editor to set the Inspector fields)
	var aldric := get_node_or_null("Aldric")
	if aldric:
		aldric.npc_name = "Prof. Aldric Voss"
		aldric.portrait_color = Color(0.25, 0.45, 0.65)
		aldric.interact_radius = 40.0
		aldric.dialogue = [
			"Kael! Just the person I needed. Come closer — these old ears aren't what they used to be.",
			"You've seen it too, haven't you? The water. Three wells have gone black this week alone.",
			"I've been running analyses. The contamination has an elemental signature — something is disrupting the hydrogen-oxygen bonds at a molecular level.",
			"It's not natural erosion. Something — or someone — is introducing a foreign compound into the aquifer.",
			"I have a theory, but I need your help to test it. Bring me two Hydrogen samples and one Oxygen sample. We'll synthesize a pure control batch and compare.",
			"You'll find the elements scattered around the plains. Use your hands — they're closer to the ground than mine these days.",
			"And Kael... be careful. The plains haven't felt right lately. I've noticed things moving at the edge of the fog.",
			"Go on then. The village is counting on us — even if they don't know it yet.",
		]

# ── Generation ────────────────────────────────────────────────────────────────

func _generate_world() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05

	for x: int in range(WORLD_WIDTH):
		var biome := _get_biome(x)
		for y: int in range(WORLD_HEIGHT):
			var coords := Vector2i(x, y)
			var n: float = noise.get_noise_2d(x, y)

			if biome.name == "ocean_floor" and n > 0.3:
				_create_tile(coords, COLOR_WATER, "water", "", false)
				continue
			if biome.name == "magma_layer" and n > 0.4:
				_create_tile(coords, COLOR_LAVA, "lava", "", false)
				continue
			if n > 0.55:
				_create_tile(coords, COLOR_ROCK, "rock", "", false)
				continue

			var ore_n: float = noise.get_noise_2d(x * 4.1, y * 4.1)
			if ore_n > 0.5 and biome.elements.size() > 0:
				var idx: int = int(abs(ore_n * 10)) % (biome.elements.size() as int)
				var element: String = biome.elements[idx]
				_create_tile(coords, ORE_COLORS.get(element, Color.WHITE), "ore", element, true)
				continue

			_create_tile(coords, _base_color(biome.base), biome.base, "", true)

func _spawn_village() -> void:
	# Ashenveil village in the surface_plains biome, centred around tile (15,15)
	# Buildings are impassable rock-coloured rectangles.
	# SPRITE SWAP: replace ColorRect logic here with instanced building scenes.
	var buildings := [
		{ "x": 10, "y": 10, "w": 5, "h": 4, "label": "Aldric's Workshop",  "color": Color(0.45, 0.30, 0.15) },
		{ "x": 17, "y": 10, "w": 4, "h": 3, "label": "Village Hall",       "color": Color(0.60, 0.50, 0.35) },
		{ "x": 10, "y": 16, "w": 3, "h": 3, "label": "House",              "color": Color(0.55, 0.45, 0.30) },
		{ "x": 15, "y": 16, "w": 3, "h": 3, "label": "House",              "color": Color(0.55, 0.45, 0.30) },
		{ "x": 20, "y": 15, "w": 3, "h": 3, "label": "Market Stall",       "color": Color(0.70, 0.60, 0.20) },
		{ "x": 13, "y": 13, "w": 2, "h": 2, "label": "Well",               "color": Color(0.35, 0.55, 0.75) },
	]
	for b: Dictionary in buildings:
		for bx: int in range(int(b.w)):
			for by: int in range(int(b.h)):
				var coords := Vector2i(int(b.x) + bx, int(b.y) + by)
				_create_tile(coords, b.color, "building", "", false)

# ── Tile helpers ──────────────────────────────────────────────────────────────

func _get_biome(x: int) -> Dictionary:
	for b in BIOMES:
		if x >= b.x_start and x <= b.x_end:
			return b
	return BIOMES[0]

func _base_color(base: String) -> Color:
	match base:
		"grass": return COLOR_GRASS
		"stone": return COLOR_STONE
		"sand":  return COLOR_SAND
		_:       return COLOR_DIRT

func _create_tile(coords: Vector2i, color: Color, type: String, element: String, passable: bool) -> void:
	# Remove any existing tile first
	if tile_nodes.has(coords):
		tile_nodes[coords].queue_free()
		tile_nodes.erase(coords)
	if tile_data.has(coords) and tile_data[coords].has("body"):
		tile_data[coords]["body"].queue_free()

	var rect := ColorRect.new()
	rect.color = color
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	rect.position = Vector2(coords.x * TILE_SIZE, coords.y * TILE_SIZE)
	add_child(rect)
	tile_nodes[coords] = rect
	tile_data[coords] = { "type": type, "element": element, "passable": passable }

	if not passable:
		var body := StaticBody2D.new()
		body.position = rect.position + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = box
		body.collision_layer = 1
		body.add_child(shape)
		add_child(body)
		tile_data[coords]["body"] = body

# ── Public API ────────────────────────────────────────────────────────────────

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))

func get_biome_at(world_pos: Vector2) -> String:
	var tile := world_to_tile(world_pos)
	return _get_biome(tile.x).get("name", "unknown")

func dig_tile(tile_coords: Vector2i) -> String:
	var data: Dictionary = tile_data.get(tile_coords, {})
	if data.is_empty() or not data.get("passable", true):
		return ""
	var element: String = data.get("element", "")
	if element == "":
		return ""
	# Remove ore tile, replace with passable ground
	var biome := _get_biome(tile_coords.x)
	_create_tile(tile_coords, _base_color(biome.base), biome.base, "", true)
	return element
