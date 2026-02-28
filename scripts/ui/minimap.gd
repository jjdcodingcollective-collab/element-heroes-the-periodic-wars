extends Control

# Minimap — top-right HUD overlay.
# Draws a small pixel representation of the world biomes + player position.
#
# SPRITE SWAP: biome colors here are intentionally separate from world.gd
# so the minimap still works after the tile system is upgraded.

const MAP_W: int = 100   # minimap pixels wide
const MAP_H: int = 100   # minimap pixels tall
const WORLD_W: int = 200 # must match world.gd
const WORLD_H: int = 200

const BIOME_COLORS := {
	"surface_plains":    Color(0.24, 0.65, 0.24),
	"underground_mines": Color(0.45, 0.45, 0.45),
	"crystal_caverns":   Color(0.55, 0.70, 0.90),
	"sky_islands":       Color(0.65, 0.55, 0.35),
	"ocean_floor":       Color(0.20, 0.45, 0.80),
	"magma_layer":       Color(0.80, 0.25, 0.05),
}

const BIOMES := [
	{ "name": "surface_plains",    "x_start": 0,   "x_end": 39  },
	{ "name": "underground_mines", "x_start": 40,  "x_end": 79  },
	{ "name": "crystal_caverns",   "x_start": 80,  "x_end": 109 },
	{ "name": "sky_islands",       "x_start": 110, "x_end": 139 },
	{ "name": "ocean_floor",       "x_start": 140, "x_end": 169 },
	{ "name": "magma_layer",       "x_start": 170, "x_end": 199 },
]

var player_ref: Node = null
var _map_image: Image
var _map_texture: ImageTexture
var _map_rect: TextureRect

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_W + 4, MAP_H + 20)
	_build_map_image()

	_map_rect = TextureRect.new()
	_map_rect.texture = _map_texture
	_map_rect.size = Vector2(MAP_W, MAP_H)
	_map_rect.position = Vector2(2, 18)
	add_child(_map_rect)

	# Background panel
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.size = Vector2(MAP_W + 4, MAP_H + 20)
	bg.z_index = -1
	add_child(bg)

	# Label
	var lbl := Label.new()
	lbl.text = "MAP"
	lbl.position = Vector2(2, 2)
	lbl.add_theme_font_size_override("font_size", 10)
	add_child(lbl)

func _build_map_image() -> void:
	_map_image = Image.create(MAP_W, MAP_H, false, Image.FORMAT_RGB8)
	for bx: int in range(MAP_W):
		var world_x: int = int(float(bx) / MAP_W * WORLD_W)
		var biome_name: String = _biome_for_x(world_x)
		var col: Color = BIOME_COLORS.get(biome_name, Color.GRAY)
		for by: int in range(MAP_H):
			_map_image.set_pixel(bx, by, col)
	_map_texture = ImageTexture.create_from_image(_map_image)

func _process(_delta: float) -> void:
	if player_ref == null:
		return
	queue_redraw()

func _draw() -> void:
	if player_ref == null:
		return
	# Player dot on minimap
	var pos: Vector2 = (player_ref as Node2D).global_position
	var px: float = (pos.x / (WORLD_W * 16.0)) * MAP_W + 2
	var py: float = (pos.y / (WORLD_H * 16.0)) * MAP_H + 18
	draw_circle(Vector2(px, py), 2.0, Color.WHITE)
	draw_circle(Vector2(px, py), 1.0, Color(0.9, 0.2, 0.6))

	# Biome label at player position
	var tile_x: int = int(pos.x / 16.0)
	var biome: String = _biome_for_x(tile_x).replace("_", " ").capitalize()
	draw_string(ThemeDB.fallback_font, Vector2(2, MAP_H + 16), biome, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)

func _biome_for_x(x: int) -> String:
	for b: Dictionary in BIOMES:
		if x >= int(b.x_start) and x <= int(b.x_end):
			return str(b.name)
	return "surface_plains"
