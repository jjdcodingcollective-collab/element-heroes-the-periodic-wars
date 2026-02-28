extends StaticBody2D

# NPC — interactable character.
# Place in world scene. Set exported vars in the Inspector.
#
# SPRITE SWAP: assign a Texture2D to portrait_texture in the Inspector.
# The Sprite2D child will display it. Delete the ColorRect placeholder then.

@export var npc_name: String = "Villager"
@export var portrait_color: Color = Color(0.3, 0.5, 0.7)
@export var portrait_texture: Texture2D = null   # assign in Inspector when ready
@export var interact_radius: float = 32.0
@export_multiline var dialogue: Array[String] = ["..."]

var _placeholder: ColorRect = null
var _sprite: Sprite2D = null
var _label: Label = null
var _indicator: Label = null

func _ready() -> void:
	add_to_group("npc")
	collision_layer = 1

	_spawn_visuals()
	_spawn_interact_indicator()

func _spawn_visuals() -> void:
	if portrait_texture != null:
		_sprite = Sprite2D.new()
		_sprite.texture = portrait_texture
		add_child(_sprite)
	else:
		# Placeholder coloured rectangle
		_placeholder = ColorRect.new()
		_placeholder.color = portrait_color
		_placeholder.size = Vector2(12, 16)
		_placeholder.position = Vector2(-6, -16)
		_placeholder.name = "Placeholder"
		add_child(_placeholder)

	# Name label above NPC
	_label = Label.new()
	_label.text = npc_name
	_label.position = Vector2(-20, -28)
	_label.add_theme_font_size_override("font_size", 8)
	add_child(_label)

func _spawn_interact_indicator() -> void:
	_indicator = Label.new()
	_indicator.text = "[F]"
	_indicator.position = Vector2(-8, -38)
	_indicator.add_theme_font_size_override("font_size", 8)
	_indicator.modulate = Color.YELLOW
	_indicator.visible = false
	add_child(_indicator)

func _process(_delta: float) -> void:
	# Show [F] indicator when player is close
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_indicator.visible = global_position.distance_to(player.global_position) <= interact_radius

# Called by player via call_group("npc", "try_interact", player_pos)
func try_interact(player_pos: Vector2) -> void:
	if global_position.distance_to(player_pos) > interact_radius:
		return
	var dialogue_ui := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui and not dialogue_ui.is_open():
		dialogue_ui.show_dialogue(npc_name, dialogue, portrait_color)
