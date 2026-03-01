extends CharacterBody2D

# Enemy — basic patrol AI that chases the player on sight and damages on contact.
# Drops 1-2 element pickups (DropItem scene) on death.
#
# SPRITE SWAP: replace ColorRect placeholder with AnimatedSprite2D.

const SPEED_PATROL: float = 40.0
const SPEED_CHASE:  float = 80.0
const SIGHT_RANGE:  float = 96.0   # pixels, detect player within this range
const ATTACK_RANGE: float = 12.0   # pixels, deal damage when this close
const ATTACK_DAMAGE: float = 10.0
const ATTACK_COOLDOWN: float = 1.0
const MAX_HP: float = 30.0

# Elements this enemy can drop (set via export or by spawner)
@export var drop_elements: Array[String] = ["Na", "K"]
@export var drop_count_min: int = 1
@export var drop_count_max: int = 2

var hp: float = MAX_HP
var _player: Node2D = null
var _state: String = "patrol"       # "patrol" | "chase" | "dead"
var _patrol_dir: Vector2 = Vector2.RIGHT
var _patrol_timer: float = 0.0
var _attack_timer: float = 0.0
var _placeholder: ColorRect = null

func _ready() -> void:
	add_to_group("enemy")
	_spawn_placeholder()
	_patrol_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _spawn_placeholder() -> void:
	_placeholder = ColorRect.new()
	_placeholder.color = Color(0.8, 0.15, 0.15)
	_placeholder.size = Vector2(12, 12)
	_placeholder.position = Vector2(-6, -6)
	add_child(_placeholder)

func _physics_process(delta: float) -> void:
	if _state == "dead":
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_tick_burn(delta)
	_find_player()

	match _state:
		"patrol":  _do_patrol(delta)
		"chase":   _do_chase(delta)

	move_and_slide()

func _tick_burn(delta: float) -> void:
	if not has_meta("burn_timer"):
		return
	var t: float = float(get_meta("burn_timer")) - delta
	if t <= 0.0:
		remove_meta("burn_timer")
		if has_meta("burn_dps"):
			remove_meta("burn_dps")
		return
	set_meta("burn_timer", t)
	var dps: float = float(get_meta("burn_dps", 0.0))
	take_damage(dps * delta)

func _find_player() -> void:
	if _player == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0] as Node2D
	if _player == null:
		return
	var dist: float = global_position.distance_to(_player.global_position)
	if dist <= SIGHT_RANGE:
		_state = "chase"
	elif _state == "chase":
		_state = "patrol"

func _do_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_patrol_timer = randf_range(1.5, 3.5)
		_patrol_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	velocity = _patrol_dir * SPEED_PATROL

func _do_chase(delta: float) -> void:
	if _player == null:
		return
	var to_player: Vector2 = (_player.global_position - global_position).normalized()
	var dist: float = global_position.distance_to(_player.global_position)
	velocity = to_player * SPEED_CHASE

	# Deal contact damage
	if dist <= ATTACK_RANGE and _attack_timer <= 0.0:
		if _player.has_method("take_damage"):
			_player.take_damage(ATTACK_DAMAGE)
		_attack_timer = ATTACK_COOLDOWN
		_spawn_damage_label()

func take_damage(amount: float) -> void:
	if _state == "dead":
		return
	hp = maxf(hp - amount, 0.0)
	_spawn_hit_label(amount)
	if hp <= 0.0:
		_die()

func _die() -> void:
	_state = "dead"
	velocity = Vector2.ZERO
	_drop_elements()
	queue_free()

func _drop_elements() -> void:
	var count: int = int(randf_range(drop_count_min, drop_count_max + 1))
	for i: int in range(count):
		var symbol: String = drop_elements[randi() % drop_elements.size()]
		_spawn_drop_label(symbol)
		# Add directly to player inventory if in range
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p: Node = players[0]
			if p.has_method("get_node"):
				var inv := p.get_node_or_null("Inventory")
				if inv and inv.has_method("add_element"):
					var amount: float = snappedf(randf_range(0.1, 1.0), 0.01)
					inv.add_element(symbol, amount)

func _spawn_hit_label(amount: float) -> void:
	var label := Label.new()
	label.text = "-%.0f" % amount
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(1.0, 0.5, 0.0)
	label.position = global_position + Vector2(-8, -20)
	label.z_index = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 18, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free).set_delay(0.8)

func _spawn_damage_label() -> void:
	if _player == null:
		return
	var label := Label.new()
	label.text = "-%d HP" % int(ATTACK_DAMAGE)
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(1.0, 0.2, 0.2)
	label.position = _player.global_position + Vector2(-20, -24)
	label.z_index = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 20, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free).set_delay(1.0)

func _spawn_drop_label(symbol: String) -> void:
	var label := Label.new()
	label.text = "+%s" % symbol
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(0.5, 1.0, 0.5)
	label.position = global_position + Vector2(-8, -16)
	label.z_index = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free).set_delay(1.2)
