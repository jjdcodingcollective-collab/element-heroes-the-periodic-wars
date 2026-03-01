extends Node2D

# Projectile — fired by ranged weapons.
# Stats are passed in via set_meta() by weapon.gd before add_child().
#
# SPRITE SWAP: replace ColorRect with a Sprite2D for real art.

var _speed: float       = 180.0
var _max_range: float   = 200.0
var _direction: Vector2 = Vector2.RIGHT
var _damage: float      = 10.0
var _knockback: float   = 40.0
var _splash_radius: float = 0.0
var _piercing: bool     = false
var _burn_dps: float    = 0.0
var _burn_duration: float = 0.0
var _traveled: float    = 0.0
var _hit_enemies: Array = []   # track piercing hits so we don't double-damage

var _rect: ColorRect = null

func _ready() -> void:
	# Read stats baked in by weapon.gd
	_damage        = float(get_meta("damage",        10.0))
	_speed         = float(get_meta("speed",         180.0))
	_max_range     = float(get_meta("max_range",     200.0))
	_direction     = get_meta("direction",           Vector2.RIGHT)
	_knockback     = float(get_meta("knockback",     40.0))
	_splash_radius = float(get_meta("splash_radius", 0.0))
	_piercing      = bool(get_meta("piercing",       false))
	_burn_dps      = float(get_meta("burn_dps",      0.0))
	_burn_duration = float(get_meta("burn_duration", 0.0))
	var col: Color  = get_meta("color", Color(1, 1, 0.3))

	_rect = ColorRect.new()
	_rect.size = Vector2(6, 4)
	_rect.position = Vector2(-3, -2)
	_rect.color = col
	add_child(_rect)

	# Rotate visual to match direction
	rotation = _direction.angle()

func _process(delta: float) -> void:
	var move: Vector2 = _direction * _speed * delta
	position += move
	_traveled += move.length()

	_check_hits()

	if _traveled >= _max_range:
		_explode_if_splash()
		queue_free()

func _check_hits() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e: Node in enemies:
		var en: Node2D = e as Node2D
		if _hit_enemies.has(en):
			continue
		if global_position.distance_to(en.global_position) <= 10.0:
			_hit_enemy(en)
			if not _piercing:
				_explode_if_splash()
				queue_free()
				return
			_hit_enemies.append(en)

func _hit_enemy(enemy: Node2D) -> void:
	if enemy.has_method("take_damage"):
		enemy.take_damage(_damage)
	if enemy is CharacterBody2D:
		var cb: CharacterBody2D = enemy as CharacterBody2D
		cb.velocity += _direction * _knockback
	_apply_burn(enemy)

	# Splash — hits nearby enemies too
	if _splash_radius > 0.0:
		var all_enemies := get_tree().get_nodes_in_group("enemy")
		for se: Node in all_enemies:
			var sen: Node2D = se as Node2D
			if sen == enemy or _hit_enemies.has(sen):
				continue
			if global_position.distance_to(sen.global_position) <= _splash_radius:
				if sen.has_method("take_damage"):
					sen.take_damage(_damage * 0.5)
				_apply_burn(sen)
				_hit_enemies.append(sen)

func _explode_if_splash() -> void:
	if _splash_radius <= 0.0:
		return
	# Visual ring flash
	var ring := ColorRect.new()
	ring.size = Vector2(_splash_radius * 2.0, _splash_radius * 2.0)
	ring.position = global_position - Vector2(_splash_radius, _splash_radius)
	ring.color = _rect.color
	ring.color.a = 0.35
	ring.z_index = 10
	get_parent().add_child(ring)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free).set_delay(0.3)
	# Damage anything in radius not already hit
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e: Node in enemies:
		var en: Node2D = e as Node2D
		if _hit_enemies.has(en):
			continue
		if global_position.distance_to(en.global_position) <= _splash_radius:
			if en.has_method("take_damage"):
				en.take_damage(_damage * 0.6)
			_apply_burn(en)

func _apply_burn(enemy: Node2D) -> void:
	if _burn_dps <= 0.0 or _burn_duration <= 0.0:
		return
	# Store burn on enemy node; enemy.gd's _process picks this up via meta
	enemy.set_meta("burn_dps",      _burn_dps)
	enemy.set_meta("burn_timer",    _burn_duration)
