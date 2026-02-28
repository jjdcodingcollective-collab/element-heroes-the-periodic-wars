## Player.gd
## Attach to a CharacterBody2D node
extends CharacterBody2D

# Movement
const SPEED := 120.0
const JUMP_VELOCITY := -320.0
const GRAVITY := 980.0

# Stats
@export var max_health: int = 100
var health: int = max_health

# Inventory
var inventory: Dictionary = {}   # { "symbol": count } for elements
var hotbar: Array = []           # Quick-access slots (up to 8)
var selected_slot: int = 0

# State
var is_on_floor_last: bool = false

# Signals
signal health_changed(new_health: int, max_health: int)
signal element_collected(symbol: String, count: int)
signal died()

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_movement()
	_handle_jump()
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _handle_movement() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * SPEED
		$Sprite2D.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		# TODO: toggle inventory UI
		pass
	if event.is_action_pressed("open_compendium"):
		# TODO: toggle compendium UI
		pass
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("dig"):
		_try_dig()
	if event.is_action_pressed("place"):
		_try_place()

# ── Inventory ──────────────────────────────────────────────────────────────────

func collect_element(symbol: String, amount: int = 1) -> void:
	inventory[symbol] = inventory.get(symbol, 0) + amount
	emit_signal("element_collected", symbol, inventory[symbol])

func has_element(symbol: String, amount: int = 1) -> bool:
	return inventory.get(symbol, 0) >= amount

func consume_element(symbol: String, amount: int = 1) -> bool:
	if not has_element(symbol, amount):
		return false
	inventory[symbol] -= amount
	if inventory[symbol] <= 0:
		inventory.erase(symbol)
	return true

func consume_elements(required: Dictionary) -> bool:
	# Check all first
	for symbol in required:
		if not has_element(symbol, required[symbol]):
			return false
	# Then consume
	for symbol in required:
		consume_element(symbol, required[symbol])
	return true

# ── Health ─────────────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	emit_signal("health_changed", health, max_health)
	if health <= 0:
		_die()

func heal(amount: int) -> void:
	health = min(max_health, health + amount)
	emit_signal("health_changed", health, max_health)

func _die() -> void:
	emit_signal("died")
	# TODO: death animation and respawn logic

# ── World Interaction ──────────────────────────────────────────────────────────

func _try_dig() -> void:
	# TODO: raycast to tile under cursor, break it and drop element
	pass

func _try_place() -> void:
	# TODO: place selected hotbar item at cursor tile
	pass

func _try_interact() -> void:
	# TODO: interact with nearby NPC or crafting station
	pass
