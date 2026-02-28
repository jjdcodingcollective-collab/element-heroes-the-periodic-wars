extends Node2D

# World — manages the tilemap, element ore spawning, and tile interactions.

const TILE_SIZE: int = 16
const WORLD_WIDTH: int = 400   # tiles
const WORLD_HEIGHT: int = 200  # tiles
const SEA_LEVEL: int = 60      # tile row where surface starts

@onready var tilemap: TileMap = $TileMap

# Tile IDs in the TileSet (set up in Godot editor)
enum TileType {
	AIR = -1,
	DIRT = 0,
	STONE = 1,
	ORE = 2,
}

# Maps tile coords to element symbol for ore tiles
var ore_map: Dictionary = {}

func _ready() -> void:
	_generate_world()

func _generate_world() -> void:
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.04

	for x in range(WORLD_WIDTH):
		var surface_y = SEA_LEVEL + int(noise.get_noise_1d(x) * 10)
		for y in range(WORLD_HEIGHT):
			if y < surface_y:
				tilemap.set_cell(0, Vector2i(x, y), -1, Vector2i(-1, -1))  # air
			elif y == surface_y:
				tilemap.set_cell(0, Vector2i(x, y), TileType.DIRT, Vector2i(0, 0))
			else:
				var depth = y - surface_y
				_place_terrain_tile(x, y, depth, noise)

func _place_terrain_tile(x: int, y: int, depth: int, noise: FastNoiseLite) -> void:
	var ore_noise = noise.get_noise_2d(x * 3.7, y * 3.7)
	var element = _get_ore_for_depth(depth, ore_noise)

	if element != "":
		tilemap.set_cell(0, Vector2i(x, y), TileType.ORE, Vector2i(0, 0))
		ore_map[Vector2i(x, y)] = element
	else:
		var tile = TileType.DIRT if depth < 10 else TileType.STONE
		tilemap.set_cell(0, Vector2i(x, y), tile, Vector2i(0, 0))

func _get_ore_for_depth(depth: int, noise_val: float) -> String:
	# Surface layer (0-15 tiles deep) — alkali metals & nonmetals
	if depth < 15:
		if noise_val > 0.6:  return "Na"
		if noise_val > 0.55: return "K"
		if noise_val > 0.5:  return "C"
	# Mid layer (15-50) — transition metals
	elif depth < 50:
		if noise_val > 0.65: return "Fe"
		if noise_val > 0.6:  return "Cu"
		if noise_val > 0.55: return "Zn"
		if noise_val > 0.5:  return "Ni"
	# Deep layer (50-100) — rare metals
	elif depth < 100:
		if noise_val > 0.7:  return "Ag"
		if noise_val > 0.65: return "Au"
		if noise_val > 0.6:  return "Pt"
	# Very deep (100+) — radioactive
	else:
		if noise_val > 0.8:  return "U"
		if noise_val > 0.75: return "Th"
	return ""

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))

# Dig a tile — removes it and returns the element symbol (or "")
func dig_tile(tile_coords: Vector2i) -> String:
	var cell = tilemap.get_cell_source_id(0, tile_coords)
	if cell == -1:
		return ""  # already air

	var element = ore_map.get(tile_coords, "")
	tilemap.set_cell(0, tile_coords, -1, Vector2i(-1, -1))  # set to air
	ore_map.erase(tile_coords)
	return element
