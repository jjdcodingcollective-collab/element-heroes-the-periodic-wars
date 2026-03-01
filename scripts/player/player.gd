extends CharacterBody2D

# Top-down 8-directional player controller.
#
# SPRITE SWAP GUIDE:
#   Replace the ColorRect placeholder by:
#   1. Add a SpriteFrames resource to the AnimatedSprite2D node in the editor
#   2. Add animations named: "idle_down","idle_up","idle_left","idle_right",
#      "walk_down","walk_up","walk_left","walk_right"
#   3. Delete the _spawn_placeholder() call in _ready()
#   The rest of the animation code is already wired up and will just work.

const SPEED: float = 120.0
const TILE_SIZE: int = 16
const DIG_RANGE: float = 48.0
const DIG_MIN: float = 0.25   # minimum grams/mL yielded per dig
const DIG_MAX: float = 2.5    # maximum grams/mL yielded per dig
const MAX_HP: float = 100.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var inventory: Node = $Inventory
@onready var equipment: Node = $Equipment
@onready var weapon: Node = $Weapon

var facing: Vector2 = Vector2.DOWN
var hp: float = MAX_HP
var _placeholder: ColorRect = null
var _invincible_timer: float = 0.0   # brief i-frames after taking a hit
const I_FRAME_DURATION: float = 0.5

func get_health() -> float:
	return hp

func get_max_health() -> float:
	return MAX_HP

func take_damage(amount: float) -> void:
	if _invincible_timer > 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_invincible_timer = I_FRAME_DURATION

func equip_weapon(item_name: String) -> void:
	weapon.equip(item_name)

func get_equipped_weapon() -> String:
	return weapon.get_weapon_name()

func _ready() -> void:
	add_to_group("player")
	_spawn_placeholder()

func _spawn_placeholder() -> void:
	_placeholder = ColorRect.new()
	_placeholder.color = Color(0.9, 0.2, 0.6)
	_placeholder.size = Vector2(12, 12)
	_placeholder.position = Vector2(-6, -6)
	_placeholder.name = "Placeholder"
	add_child(_placeholder)

func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)
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
	# Skip if no sprite frames loaded (placeholder mode)
	if animated_sprite.sprite_frames == null:
		return
	# Hide placeholder once real sprites are loaded
	if _placeholder:
		_placeholder.visible = false

	var moving = velocity.length() > 1.0
	var prefix = "walk_" if moving else "idle_"
	var dir_name := "down"
	if abs(facing.x) > abs(facing.y):
		dir_name = "right" if facing.x > 0 else "left"
	else:
		dir_name = "down" if facing.y > 0 else "up"
	animated_sprite.play(prefix + dir_name)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse button events need explicit type check in Godot 4
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_dig()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_attack()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack"):
		_try_attack()
	elif event.is_action_pressed("open_inventory"):
		get_tree().call_group("ui", "toggle_inventory")
	elif event.is_action_pressed("open_compendium"):
		get_tree().call_group("ui", "toggle_compendium")
	elif event.is_action_pressed("interact"):
		get_tree().call_group("npc", "try_interact", global_position)
	elif event.is_action_pressed("save_game"):
		SaveSystem.save_game(self)

func _try_attack() -> void:
	weapon.try_attack(facing)

func _try_dig() -> void:
	var mouse_pos := get_global_mouse_position()
	# Range check — must be close enough to dig
	if global_position.distance_to(mouse_pos) > DIG_RANGE:
		return
	var world_node := get_parent()
	if not world_node.has_method("dig_tile"):
		return
	var tile_coords: Vector2i = world_node.world_to_tile(mouse_pos)
	var element: String = world_node.dig_tile(tile_coords)
	if element != "":
		# Check player has correct container and handling equipment
		var missing: String = equipment.can_collect(element)
		if missing != "":
			_spawn_warning_label(missing, mouse_pos)
			return
		var amount: float = snappedf(randf_range(DIG_MIN, DIG_MAX), 0.01)
		equipment.consume_container_for(element)
		inventory.add_element(element, amount)
		_spawn_pickup_label(element, amount, mouse_pos)

func _spawn_warning_label(message: String, world_pos: Vector2) -> void:
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(1.0, 0.3, 0.3)
	label.position = world_pos + Vector2(-40, -16)
	label.z_index = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 20, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free).set_delay(1.5)

func _spawn_pickup_label(symbol: String, amount: float, world_pos: Vector2) -> void:
	var unit: String = inventory.unit_for(symbol)
	var label := Label.new()
	label.text = "+%.2f%s %s" % [amount, unit, symbol]
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(1.0, 1.0, 0.4)
	label.position = world_pos + Vector2(-20, -16)
	label.z_index = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 28, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free).set_delay(1.2)
