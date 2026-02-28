extends Node2D

# World — procedural world using ColorRect tiles. No TileSet asset needed.
# Each tile is a ColorRect child node, coloured by type.
# Phase 2 will replace this with a proper TileMap + sprite sheet.

const TILE_SIZE: int = 16
const WORLD_WIDTH: int = 200   # tiles (reduced for prototype performance)
const WORLD_HEIGHT: int = 120  # tiles
const SEA_LEVEL: int = 40      # tile row where surface starts

# Tile colours
const COLOR_SKY   := Color(0.53, 0.81, 0.98)   # light blue
const COLOR_DIRT  := Color(0.55, 0.37, 0.21)   # brown
const COLOR_STONE := Color(0.45, 0.45, 0.45)   # grey
const COLOR_GRASS := Color(0.24, 0.65, 0.24)   # green (surface row)

# Ore colours by element symbol
const ORE_COLORS := {
	"Na": Color(0.9,  0.9,  0.3),   # yellow
	"K":  Color(0.8,  0.6,  0.9),   # purple
	"C":  Color(0.15, 0.15, 0.15),  # dark (coal)
	"Fe": Color(0.7,  0.35, 0.1),   # rust orange
	"Cu": Color(0.72, 0.45, 0.2),   # copper
	"Zn": Color(0.6,  0.75, 0.75),  # teal
	"Ni": Color(0.5,  0.7,  0.5),   # pale green
	"Ag": Color(0.85, 0.85, 0.90),  # silver
	"Au": Color(1.0,  0.85, 0.0),   # gold
	"Pt": Color(0.9,  0.95, 1.0),   # platinum white
	"U":  Color(0.2,  0.8,  0.2),   # radioactive green
	"Th": Color(0.3,  0.9,  0.4),   # thorium green
}

# tile_data[Vector2i] = { "type": "dirt"|"stone"|"ore"|"air", "element": "Fe" }
var tile_data: Dictionary = {}
var tile_nodes: Dictionary = {}  # Vector2i -> ColorRect

func _ready() -> void:
	_generate_world()

func _generate_world() -> void:
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.04

	for x in range(WORLD_WIDTH):
		var surface_y = SEA_LEVEL + int(noise.get_noise_1d(x) * 8)
		for y in range(WORLD_HEIGHT):
			var coords = Vector2i(x, y)
			if y < surface_y:
				tile_data[coords] = { "type": "air", "element": "" }
				# Don't create a node for air — sky is the background colour
			elif y == surface_y:
				_create_tile(coords, COLOR_GRASS, "dirt", "")
			else:
				var depth = y - surface_y
				var ore_noise = noise.get_noise_2d(x * 3.7, y * 3.7)
				var element = _get_ore_for_depth(depth, ore_noise)
				if element != "":
					_create_tile(coords, ORE_COLORS.get(element, Color.WHITE), "ore", element)
				else:
					var color = COLOR_DIRT if depth < 8 else COLOR_STONE
					var type  = "dirt"    if depth < 8 else "stone"
					_create_tile(coords, color, type, "")

func _create_tile(coords: Vector2i, color: Color, type: String, element: String) -> void:
	var rect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(TILE_SIZE, TILE_SIZE)
	rect.position = Vector2(coords.x * TILE_SIZE, coords.y * TILE_SIZE)
	add_child(rect)
	tile_data[coords] = { "type": type, "element": element }
	tile_nodes[coords] = rect

	# Add a StaticBody2D for solid tiles so the player collides with them
	if type != "air":
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

func _get_ore_for_depth(depth: int, noise_val: float) -> String:
	if depth < 15:
		if noise_val > 0.6:  return "Na"
		if noise_val > 0.55: return "K"
		if noise_val > 0.5:  return "C"
	elif depth < 50:
		if noise_val > 0.65: return "Fe"
		if noise_val > 0.6:  return "Cu"
		if noise_val > 0.55: return "Zn"
		if noise_val > 0.5:  return "Ni"
	elif depth < 100:
		if noise_val > 0.7:  return "Ag"
		if noise_val > 0.65: return "Au"
		if noise_val > 0.6:  return "Pt"
	else:
		if noise_val > 0.8:  return "U"
		if noise_val > 0.75: return "Th"
	return ""

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))

# Dig a tile — removes its visual and collision, returns element symbol (or "")
func dig_tile(tile_coords: Vector2i) -> String:
	var data = tile_data.get(tile_coords, {})
	if data.is_empty() or data["type"] == "air":
		return ""

	var element = data.get("element", "")

	# Remove visual
	if tile_nodes.has(tile_coords):
		tile_nodes[tile_coords].queue_free()
		tile_nodes.erase(tile_coords)

	# Remove collision body
	if data.has("body"):
		data["body"].queue_free()

	tile_data[tile_coords] = { "type": "air", "element": "" }
	return element
