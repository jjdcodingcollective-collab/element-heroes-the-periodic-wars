extends Node2D

# Specimen Cabinet — a glass-fronted trophy case in Aldric's workshop
# (SYSTEMS_UX_REVIEW §3.4: pride, not logistics). Press F nearby to open its
# journal page (UIManager "cabinet"): Prime Codex entries, rare defeat counts,
# boss relics and the Prime set pieces unlocked so far.
#
# SPRITE SWAP: replace _draw() with a Sprite2D once cabinet art exists.

const INTERACT_RADIUS: float = 36.0
const CabinetPage := preload("res://scripts/ui/specimen_cabinet_ui.gd")

# Game palette: workshop wood, brass, glass and the Prime iridescence.
const WOOD       := Color("#5b3520")
const WOOD_DARK  := Color("#2e1a0e")
const BRASS      := Color("#d6a040")
const GLASS      := Color(0.70, 0.85, 0.90, 0.55)
const JAR_COLOURS := [Color("#e8c840"), Color("#5a7fa0"), Color("#9a6ad0"), Color("#3f8f5a")]

var page: CanvasLayer = null
var _indicator: Label

func _ready() -> void:
	add_to_group("specimen_cabinet")
	z_index = 1
	_indicator = Label.new()
	_indicator.text = "[F] Cabinet"
	_indicator.add_theme_font_size_override("font_size", 7)
	_indicator.modulate = Color.YELLOW
	_indicator.position = Vector2(-20, -40)
	_indicator.visible = false
	_indicator.z_index = 2
	add_child(_indicator)
	page = CanvasLayer.new()
	page.set_script(CabinetPage)
	page.name = "CabinetPage"
	add_child(page)

func _draw() -> void:
	# Body 18×26 standing on the tile, feet at y = +6.
	draw_rect(Rect2(-10, -22, 20, 28), WOOD_DARK)
	draw_rect(Rect2(-9, -21, 18, 26), WOOD)
	draw_rect(Rect2(-7, -19, 14, 20), GLASS)
	for shelf: int in 2:
		var y := -11.0 + shelf * 9.0
		draw_line(Vector2(-7, y), Vector2(7, y), WOOD_DARK, 1.0)
		for j: int in 3:
			var c: Color = JAR_COLOURS[(shelf * 3 + j) % JAR_COLOURS.size()]
			draw_rect(Rect2(-6 + j * 4.5, y - 4, 3, 4), c)
	draw_rect(Rect2(-10, -24, 20, 3), BRASS.darkened(0.2))
	draw_rect(Rect2(-1, -8, 2, 2), BRASS)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	_indicator.visible = player != null and global_position.distance_to(player.global_position) <= INTERACT_RADIUS

# Called by the player via call_group("specimen_cabinet", "try_interact", pos).
func try_interact(player_pos: Vector2) -> void:
	if global_position.distance_to(player_pos) > INTERACT_RADIUS or UIManager.is_open():
		return
	AudioManager.on_interact()
	UIManager.open("cabinet")
