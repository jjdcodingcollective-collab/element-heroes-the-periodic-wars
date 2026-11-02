extends StaticBody2D

# NPC — interactable character.
# Place in world scene. Set exported vars in the Inspector.
#
# SPRITES: call use_sprite_sheet("aldric") to load assets/sprites/npc/aldric.png
# (2-frame idle, SPRITE_SPEC.md). A static portrait_texture also still works.
# Without either, the ColorRect placeholder is shown.

@export var npc_name: String = "Villager"
@export var portrait_color: Color = Color(0.3, 0.5, 0.7)
@export var portrait_texture: Texture2D = null   # assign in Inspector when ready
@export var interact_radius: float = 32.0
@export_multiline var dialogue: Array[String] = ["..."]

# When true this NPC performs the Act 3 Resonance Engine assembly if the
# player is carrying all six components. Set on Aldric in world.gd.
@export var handles_resonance_assembly: bool = false

@export_multiline var assembly_dialogue: Array[String] = [
	"Orion — stop. Put them on the bench. All six of them.",
	"Alkali conductors. A ferromagnetic core. Noble gas resonators. A thermal coil, a stabilizer... and a fuel cell.",
	"Do you understand what you've done? You didn't find these. You MADE them. You learned the reactions.",
	"Hold the casing steady. This is going to resonate.",
]

var _placeholder: ColorRect = null
var _sprite: Sprite2D = null
var _anim_sprite: AnimatedSprite2D = null

const SpriteLibrary := preload("res://scripts/world/sprite_library.gd")
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

# Swaps the placeholder for an animated sheet if one exists. Returns true on success.
# Safe to call after _ready(), which is how world.gd configures Aldric.
func use_sprite_sheet(sprite_id: String) -> bool:
	if _anim_sprite != null:
		return true
	_anim_sprite = SpriteLibrary.attach(self, SpriteLibrary.npc_path(sprite_id), "npc")
	if _anim_sprite == null:
		return false
	if _placeholder != null:
		_placeholder.queue_free()
		_placeholder = null
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	return true

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
	if dialogue_ui == null or dialogue_ui.is_open():
		return

	AudioManager.on_interact()
	if handles_resonance_assembly and _try_assemble_engine(dialogue_ui):
		return

	dialogue_ui.show_dialogue(npc_name, dialogue, portrait_color)

# Returns true if the engine was assembled and assembly dialogue was shown.
func _try_assemble_engine(dialogue_ui: Node) -> bool:
	if ResonanceSystem.is_assembled:
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var equip := player.get_node_or_null("Equipment")
	if equip == null or not ResonanceSystem.has_all_parts(equip):
		return false

	var engine: Dictionary = ResonanceSystem.assemble(equip)
	if engine.is_empty():
		return false

	dialogue_ui.show_dialogue(npc_name, assembly_dialogue, portrait_color)
	return true
