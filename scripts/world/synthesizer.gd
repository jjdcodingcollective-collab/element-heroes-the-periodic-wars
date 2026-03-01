extends StaticBody2D

# Synthesizer — world object that lets players craft polymer/plastic intermediates.
# Press F (interact) when standing next to it to open the Synthesizer UI.
#
# SPRITE SWAP: replace ColorRect with a Sprite2D.

const INTERACT_RADIUS: float = 36.0

var _placeholder: ColorRect = null
var _label: Label = null

func _ready() -> void:
	add_to_group("synthesizer")
	_spawn_placeholder()

func _spawn_placeholder() -> void:
	_placeholder = ColorRect.new()
	_placeholder.color = Color(0.15, 0.65, 0.85)
	_placeholder.size = Vector2(20, 20)
	_placeholder.position = Vector2(-10, -10)
	_placeholder.z_index = 1
	add_child(_placeholder)

	_label = Label.new()
	_label.text = "SYN"
	_label.add_theme_font_size_override("font_size", 7)
	_label.position = Vector2(-8, -8)
	_label.z_index = 2
	add_child(_label)

# Called by player _unhandled_input via call_group("synthesizer", "try_interact", pos)
func try_interact(player_pos: Vector2) -> void:
	if global_position.distance_to(player_pos) <= INTERACT_RADIUS:
		get_tree().call_group("synthesizer_ui", "toggle_visible")
