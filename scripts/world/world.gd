extends Node2D

# World — top-down procedural world using ColorRect tiles.
# Camera looks straight down. Biomes spread across the X/Y plane.
# Phase 2 will replace ColorRects with a proper TileMap + sprite sheet.

const TILE_SIZE: int = 16
const WORLD_WIDTH: int  = 200  # tiles
const WORLD_HEIGHT: int = 200  # tiles

# Tile colours
const COLOR_GRASS  := Color(0.24, 0.65, 0.24)   # open ground
const COLOR_DIRT   := Color(0.55, 0.37, 0.21)   # soft terrain
const COLOR_STONE  := Color(0.45, 0.45, 0.45)   # hard terrain
const COLOR_WATER  := Color(0.20, 0.55, 0.90)   # water tiles (impassable)
const COLOR_SAND   := Color(0.87, 0.80, 0.55)   # sandy areas
const COLOR_LAVA   := Color(0.95, 0.35, 0.05)   # lava (impassable, damages)

# Ore colours by element symbol
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

# Biome regions (by tile X range) — mirrors story biomes
# Surface Plains | Underground Mines | Crystal Caverns | Sky Islands | Ocean Floor | Magma Layer
const BIOMES := [
	{ "name": "surface_plains",   "x_start": 0,   "x_end": 39,  "base": "grass", "elements": ["Na","K","C"] },
	{ "name": "underground_mines","x_start": 40,  "x_end": 79,  "base": "stone", "elements": ["Fe","Cu","Zn","Ni"] },
	{ "name": "crystal_caverns",  "x_start": 80,  "x_end": 109, "base": "stone", "elements": ["Ag","Au"] },
	{ "name": "sky_islands",      "x_start": 110, "x_end": 139, "base": "dirt",  "elements": ["K","Na"] },
	{ "name": "ocean_floor",      "x_start": 140, "x_end": 169, "base": "sand",  "elements": ["Cu","Zn"] },
	{ "name": "magma_layer",      "x_start": 170, "x_end": 199, "base": "stone", "elements": ["U","Th","Pt"] },
]

# tile_data[Vector2i] = { "type": String, "element": String, "passable": bool }
var tile_data: Dictionary = {}
var tile_nodes: Dictionary = {}  # Vector2i -> ColorRect

func _ready() -> void:
	_generate_world()

func _generate_world() -> void:
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05

	for x in range(WORLD_WIDTH):
		var biome = _get_biome(x)
		for y in range(WORLD_HEIGHT):
			var coords = Vector2i(x, y)
			var n = noise.get_noise_2d(x, y)

			# Water/lava borders between biomes
			if biome.name == "ocean_floor" and n > 0.3:
				_create_tile(coords, COLOR_WATER, "water", "", false)
				continue
			if biome.name == "magma_layer" and n > 0.4:
				_create_tile(coords, COLOR_LAVA, "lava", "", false)
				continue

			# Scatter impassable terrain rocks
			if n > 0.55:
				var base_color = COLOR_STONE if biome.base == "stone" else COLOR_DIRT
				_create_tile(coords, base_color, "rock", "", false)
				continue

			# Ore nodes
			var ore_noise = noise.get_noise_2d(x * 4.1, y * 4.1)
			if ore_noise > 0.5 and biome.elements.size() > 0:
				var idx = int(abs(ore_noise * 10)) % biome.elements.size()
				var element = biome.elements[idx]
				_create_tile(coords, ORE_COLORS.get(element, Color.WHITE), "ore", element, true)
				continue

			# Open ground
			var base_color = _base_color(biome.base)
			_create_tile(coords, base_color, biome.base, "", true)

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
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	rect.position = Vector2(coords.x * TILE_SIZE, coords.y * TILE_SIZE)
	add_child(rect)
	tile_data[coords] = { "type": type, "element": element, "passable": passable }
	tile_nodes[coords] = rect

	if not passable:
		var body = StaticBody2D.new()
		body.position = rect.position + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
		var shape = CollisionShape2D.new()
		var box = RectangleShape2D.new()
		box.size = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = box
		body.collision_layer = 1
		body.add_child(shape)
		add_child(body)
		tile_data[coords]["body"] = body

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))

func dig_tile(tile_coords: Vector2i) -> String:
	var data = tile_data.get(tile_coords, {})
	if data.is_empty() or not data.get("passable", true):
		return ""
	# Only ore tiles yield elements
	var element = data.get("element", "")
	if element == "":
		return ""

	if tile_nodes.has(tile_coords):
		tile_nodes[tile_coords].queue_free()
		tile_nodes.erase(tile_coords)
	if data.has("body"):
		data["body"].queue_free()

	# Leave open ground behind
	var biome = _get_biome(tile_coords.x)
	var base_color = _base_color(biome.base)
	_create_tile(tile_coords, base_color, biome.base, "", true)
	return element
