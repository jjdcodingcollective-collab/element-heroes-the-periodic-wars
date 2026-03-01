extends StaticBody2D

# Lab Desk — Aldric's interactive research bench inside his workshop.
# Press F when nearby to open the science mini-game quiz.
#
# SPRITE SWAP: assign a texture to portrait_texture export, then remove the
# ColorRect placeholder from _spawn_visuals().

const INTERACT_RADIUS: float = 32.0

var _placeholder: ColorRect = null
var _label:       Label     = null
var _indicator:   Label     = null

func _ready() -> void:
	add_to_group("lab_desk")
	collision_layer = 1
	_spawn_visuals()

func _spawn_visuals() -> void:
	# Desk placeholder — warm amber colour so it reads as furniture
	_placeholder = ColorRect.new()
	_placeholder.color    = Color(0.60, 0.42, 0.18)
	_placeholder.size     = Vector2(20, 14)
	_placeholder.position = Vector2(-10, -14)
	_placeholder.z_index  = 1
	add_child(_placeholder)

	_label = Label.new()
	_label.text = "DESK"
	_label.add_theme_font_size_override("font_size", 6)
	_label.modulate = Color(0.9, 0.85, 0.7)
	_label.position = Vector2(-10, -20)
	_label.z_index  = 2
	add_child(_label)

	# [F] proximity hint
	_indicator = Label.new()
	_indicator.text = "[F] Study"
	_indicator.add_theme_font_size_override("font_size", 7)
	_indicator.modulate = Color.YELLOW
	_indicator.position = Vector2(-16, -30)
	_indicator.visible  = false
	_indicator.z_index  = 2
	add_child(_indicator)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_indicator.visible = (global_position.distance_to(player.global_position) <= INTERACT_RADIUS)

# Called by player via call_group("lab_desk", "try_interact", player_pos)
func try_interact(player_pos: Vector2) -> void:
	if global_position.distance_to(player_pos) > INTERACT_RADIUS:
		return
	# Don't open if NPC dialogue is already showing
	var dialogue_ui := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui and dialogue_ui.is_open():
		return
	var player := get_tree().get_first_node_in_group("player")
	get_tree().call_group("science_minigame_ui", "open_minigame", player)
