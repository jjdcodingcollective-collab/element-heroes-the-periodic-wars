extends CharacterBody2D

const SPEED: float = 120.0
const JUMP_VELOCITY: float = -280.0
const TILE_SIZE: int = 16

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dig_raycast: RayCast2D = $DigRayCast
@onready var inventory: Node = $Inventory

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_on_floor_last: bool = false
var facing_right: bool = true

func _ready() -> void:
	# Draw a placeholder magenta rectangle so the player is visible without sprites
	var rect = ColorRect.new()
	rect.color = Color(0.9, 0.2, 0.6)
	rect.size = Vector2(12, 24)
	rect.position = Vector2(-6, -24)
	add_child(rect)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement()
	_update_animation()
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _handle_movement() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * SPEED
		facing_right = direction > 0
		animated_sprite.flip_h = not facing_right
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func _update_animation() -> void:
	# AnimatedSprite2D animations are optional for now — skip if no frames loaded
	if animated_sprite.sprite_frames == null:
		return
	if not is_on_floor():
		animated_sprite.play("jump")
	elif abs(velocity.x) > 1:
		animated_sprite.play("run")
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
	# Cast toward mouse position to determine dig target tile
	var mouse_pos = get_global_mouse_position()
	var world_node = get_parent()
	if world_node.has_method("dig_tile"):
		var tile_coords = world_node.world_to_tile(mouse_pos)
		var element = world_node.dig_tile(tile_coords)
		if element != "":
			inventory.add_element(element, 1)
			_show_pickup_label(element)

func _show_pickup_label(symbol: String) -> void:
	# Instantiate a floating pickup label above the player
	var el = ElementDB.get_element(symbol)
	var name_str = el.get("name", symbol)
	print("+1 %s (%s)" % [name_str, symbol])
