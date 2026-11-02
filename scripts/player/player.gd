extends CharacterBody2D

# Top-down 8-directional player controller.
#
# SPRITES: drop assets/sprites/player/orion.png (layout in SPRITE_SPEC.md) and
# SpriteLibrary fills the AnimatedSprite2D at startup. Without the sheet the
# ColorRect placeholder is used instead.

const SPEED: float = 120.0
const TILE_SIZE: int = 16
const DIG_RANGE: float = 48.0
const DIG_MIN: float = 0.25   # minimum grams/mL yielded per dig
const DIG_MAX: float = 2.5    # maximum grams/mL yielded per dig
const MAX_HP: float = 100.0

const SpriteLibrary := preload("res://scripts/world/sprite_library.gd")
const AshmarkCache := preload("res://scripts/world/ashmark_cache.gd")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var inventory: Node = $Inventory
@onready var equipment: Node = $Equipment
@onready var weapon: Node = $Weapon
@onready var armor: Node = $Armor

var facing: Vector2 = Vector2.DOWN
var hp: float = MAX_HP
var _placeholder: ColorRect = null
var _invincible_timer: float = 0.0   # brief i-frames after taking a hit
var _stun_timer: float = 0.0         # enemy stun/blind duration
var _corrode_timer: float = 0.0      # armor corrode debuff
var _corrode_amount: float = 0.0     # DR reduction while corroded
const I_FRAME_DURATION: float = 0.5

# Hades-style dash: a short burst with invulnerability, then a brief cooldown.
# Attacking just after a dash is a dash-strike for bonus damage.
const DASH_SPEED: float = 380.0          # px/s, ~3.5 tiles per dash
const DASH_TIME: float = 0.15
const DASH_COOLDOWN: float = 0.35
const DASH_STRIKE_WINDOW: float = 0.2    # seconds after a dash that count as a dash-strike
const DASH_STRIKE_MULT: float = 1.5
var dash_charges_max: int = 1            # kit/upgrades can raise this
var _dash_charges: int = 1
var _dash_timer: float = 0.0             # >0 while dashing
var _dash_recharge: float = 0.0
var _dash_dir: Vector2 = Vector2.DOWN
var _dash_strike_timer: float = 0.0

signal dashed

func is_dashing() -> bool:
	return _dash_timer > 0.0

func try_dash() -> bool:
	if is_dead or _stun_timer > 0.0 or _dash_charges <= 0 or is_dashing():
		return false
	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	).normalized()
	_dash_dir = dir if dir != Vector2.ZERO else facing
	facing = _dash_dir
	_dash_charges -= 1
	_dash_timer = DASH_TIME
	_dash_strike_timer = DASH_TIME + DASH_STRIKE_WINDOW
	if _dash_recharge <= 0.0:
		_dash_recharge = DASH_COOLDOWN
	emit_signal("dashed")
	return true

func _tick_dash(delta: float) -> void:
	_dash_timer        = maxf(_dash_timer - delta, 0.0)
	_dash_strike_timer = maxf(_dash_strike_timer - delta, 0.0)
	if _dash_charges < dash_charges_max and _dash_timer <= 0.0:
		_dash_recharge -= delta
		if _dash_recharge <= 0.0:
			_dash_charges += 1
			_dash_recharge = DASH_COOLDOWN if _dash_charges < dash_charges_max else 0.0

signal died
signal respawned
signal ashmarks_dropped(amount: int, where: Vector2)

var is_dead: bool = false

func get_health() -> float:
	return hp

func get_max_health() -> float:
	return MAX_HP

func take_damage(amount: float) -> void:
	if is_dead:
		return
	if _invincible_timer > 0.0 or is_dashing():
		return
	var dr: float = 0.0
	if armor and armor.has_method("get_damage_reduction"):
		dr = armor.get_damage_reduction()
	dr = maxf(dr - _corrode_amount, 0.0)  # corrode reduces effective DR
	var final_damage: float = amount * (1.0 - dr)
	hp = maxf(hp - final_damage, 0.0)
	_invincible_timer = I_FRAME_DURATION
	AudioManager.on_player_hit()
	if hp <= 0.0:
		_die()

func heal(amount: float) -> void:
	if is_dead:
		return
	hp = minf(hp + amount, MAX_HP)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	_stun_timer = 0.0
	_corrode_timer = 0.0
	_corrode_amount = 0.0
	_visual().modulate = Color(0.4, 0.4, 0.4, 0.6)
	_drop_ashmarks_on_death()
	emit_signal("died")

# Options → Keep Inventory off (SYSTEMS_UX_REVIEW §3.5): drop half the
# Ashmarks (rounded up) in a cache where you fell; walk over it to recover them.
func _drop_ashmarks_on_death() -> void:
	var opts := get_node_or_null("/root/OptionsMenu")
	if opts == null or opts.keep_inventory:
		return
	var bag := get_node_or_null("Bag")
	if bag == null or bag.ashmarks <= 0 or get_parent() == null:
		return
	var dropped: int = ceili(bag.ashmarks / 2.0)
	bag.spend_ashmarks(dropped)
	var cache := AshmarkCache.new()
	cache.amount = dropped
	cache.position = get_parent().to_local(global_position) if get_parent() is Node2D else global_position
	get_parent().add_child.call_deferred(cache)
	ashmarks_dropped.emit(dropped, global_position)

# Zelda-style recovery: full health, debuffs cleared, inventory retained.
# Progress is never destroyed — losing collected elements would punish the
# exploration the game is trying to teach.
func respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	hp = MAX_HP
	is_dead = false
	velocity = Vector2.ZERO
	facing = Vector2.DOWN
	_invincible_timer = I_FRAME_DURATION * 4.0  # grace period on respawn
	_dash_timer = 0.0
	_dash_strike_timer = 0.0
	_dash_charges = dash_charges_max
	_stun_timer = 0.0
	_corrode_timer = 0.0
	_corrode_amount = 0.0
	_visual().modulate = Color(1, 1, 1, 1)
	emit_signal("respawned")

# Buffer Solution / Lead Draught: clear stun and armour corrosion.
func clear_debuffs() -> void:
	_stun_timer = 0.0
	_corrode_timer = 0.0
	_corrode_amount = 0.0

func apply_stun(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)

func apply_knockback(impulse: Vector2) -> void:
	velocity += impulse

func apply_armor_corrode(dr_reduction: float, duration: float) -> void:
	_corrode_amount = maxf(_corrode_amount, dr_reduction)
	_corrode_timer  = maxf(_corrode_timer, duration)

func equip_weapon(item_name: String) -> void:
	weapon.equip(item_name)

func get_equipped_weapon() -> String:
	return weapon.get_weapon_name()

func equip_armor(item_name: String) -> void:
	armor.equip(item_name)

func get_equipped_armor() -> String:
	return armor.get_armor_name()

func _ready() -> void:
	add_to_group("player")
	if SpriteLibrary.attach(self, SpriteLibrary.player_path(), "character", animated_sprite) == null:
		_spawn_placeholder()

# Whatever is currently drawing the player: the sprite, or the placeholder.
func _visual() -> CanvasItem:
	if animated_sprite.sprite_frames != null:
		return animated_sprite
	return _placeholder if _placeholder != null else animated_sprite

func _spawn_placeholder() -> void:
	_placeholder = ColorRect.new()
	_placeholder.color = Color(0.9, 0.2, 0.6)
	# Same footprint as a 16×24 sprite: feet at +8, head 16px above the tile.
	_placeholder.size = Vector2(10, 22)
	_placeholder.position = Vector2(-5, -14)
	_placeholder.name = "Placeholder"
	add_child(_placeholder)

func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_stun_timer       = maxf(_stun_timer       - delta, 0.0)
	_corrode_timer    = maxf(_corrode_timer    - delta, 0.0)
	if _corrode_timer <= 0.0:
		_corrode_amount = 0.0
	_tick_dash(delta)
	if is_dashing():
		velocity = _dash_dir * DASH_SPEED
	elif _stun_timer <= 0.0:
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

	var moving = velocity.length() > 1.0
	var prefix = "walk_" if moving else "idle_"
	var dir_name := "down"
	if abs(facing.x) > abs(facing.y):
		dir_name = "right" if facing.x > 0 else "left"
	else:
		dir_name = "down" if facing.y > 0 else "up"
	animated_sprite.play(prefix + dir_name)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
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
	elif event.is_action_pressed("dash"):
		try_dash()
	elif event.is_action_pressed("interact"):
		get_tree().call_group("npc",       "try_interact", global_position)
		get_tree().call_group("synthesizer","try_interact", global_position)
		get_tree().call_group("lab_desk",  "try_interact", global_position)
		get_tree().call_group("specimen_cabinet", "try_interact", global_position)
	elif event.is_action_pressed("save_game"):
		SaveSystem.save_game(self)
	else:
		for i: int in 4:
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				use_hotbar_slot(i)
				get_viewport().set_input_as_handled()
				return

# Quick slots 1–4: used without pausing, never while a menu is open.
func use_hotbar_slot(slot: int) -> bool:
	if is_dead or UIManager.is_open():
		return false
	var bag := get_node_or_null("Bag")
	return bag != null and bag.use_hotbar(slot)

func _try_attack() -> void:
	if _dash_strike_timer > 0.0:
		weapon.damage_mult = DASH_STRIKE_MULT
	if not weapon.try_attack(facing):
		weapon.damage_mult = 1.0
		return
	_dash_strike_timer = 0.0
	if weapon.get_weapon_type() == "ranged":
		AudioManager.on_attack_ranged()
	else:
		AudioManager.on_attack_melee()

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
	AudioManager.on_dig()
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
		AudioManager.on_pickup()

func _spawn_warning_label(message: String, world_pos: Vector2) -> void:
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(1.0, 0.3, 0.3)
	label.position = world_pos + Vector2(-40, -26)
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
	label.position = world_pos + Vector2(-20, -26)
	label.z_index = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 28, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free).set_delay(1.2)
