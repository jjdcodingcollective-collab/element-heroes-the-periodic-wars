extends CharacterBody2D

# Top-down 8-directional movement. No gravity.

const SPEED: float = 120.0
const TILE_SIZE: int = 16

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var inventory: Node = $Inventory

var facing: Vector2 = Vector2.DOWN  # tracks last move direction for dig aim

func _ready() -> void:
	# Placeholder coloured rectangle — replace with sprite sheet later
	var rect = ColorRect.new()
	rect.color = Color(0.9, 0.2, 0.6)
	rect.size = Vector2(12, 12)
	rect.position = Vector2(-6, -6)
	add_child(rect)

func _physics_process(_delta: float) -> void:
	_handle_movement()
	_update_animation()
	move_and_slide()

func _handle_movement() -> void:
	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	).normalized()

	velocity = dir * SPEED

	if dir != Vector2.ZERO:
		facing = dir

func _update_animation() -> void:
	if animated_sprite.sprite_frames == null:
		return
	if velocity.length() > 1:
		animated_sprite.play("walk")
	else:
		animated_sprite.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dig"):
		_try_dig()
	elif event.is_action_pressed("open_inventory"):
		get_tree().call_group("ui", "toggle_inventory")
	elif event.is_action_pressed("open_compendium"):
		get_tree().call_group("ui", "toggle_compendium")

func _try_dig() -> void:
	# Dig the tile the mouse is hovering over
	var mouse_pos = get_global_mouse_position()
	var world_node = get_parent()
	if world_node.has_method("dig_tile"):
		var tile_coords = world_node.world_to_tile(mouse_pos)
		var element = world_node.dig_tile(tile_coords)
		if element != "":
			inventory.add_element(element, 1)
			_show_pickup_label(element)

func _show_pickup_label(symbol: String) -> void:
	var el = ElementDB.get_element(symbol)
	var name_str = el.get("name", symbol)
	print("+1 %s (%s)" % [name_str, symbol])
