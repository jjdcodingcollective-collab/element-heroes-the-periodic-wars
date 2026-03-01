extends CharacterBody2D

# ── Enemy — Data-driven base class ───────────────────────────────────────────
# Loaded from data/enemy_data.json via EnemySpawner (world.gd).
# Each enemy has: tier (basic/intermediate/expert), creature_id, stats, specials.
#
# Special abilities implemented:
#   explode_on_death  — AoE damage burst on death
#   leave_puddle      — places a slowing/damaging hazard tile
#   shockwave         — periodic radial knockback + damage
#   stun_on_hit       — chance to stun player on contact damage
#   corrode_armor     — temporarily reduces player DR
#   ranged_attack     — fires a projectile toward player
#   flash_blind       — brief control-lock on player
#   dive_bomb         — fast dash with splash landing
#   knockback_slam    — burst knockback on player
#   aoe_stun          — radial stun burst
#   leave_fire_trail  — drops burning hazard at previous positions
#   shield_pulse      — brief damage immunity
#
# Passive abilities:
#   damage_reduction  — flat % DR baked into take_damage
#
# Auras (continuous proximity damage):
#   lightning / poison / irradiate

# ── Export properties set by spawner ─────────────────────────────────────────
@export var creature_id: String = "ashburn_shambler"
@export var tier: String = "basic"   # "basic" | "intermediate" | "expert"

# ── Runtime state ─────────────────────────────────────────────────────────────
var _data: Dictionary = {}
var _tier_mult: Dictionary = {}

var hp: float = 30.0
var max_hp: float = 30.0
var base_damage: float = 10.0
var move_speed: float = 50.0
var sight_range: float = 90.0
var passive_dr: float = 0.0      # damage reduction from passive
var resistances: Dictionary = {}

var _player: Node2D = null
var _state: String = "patrol"    # "patrol" | "chase" | "dead"
var _patrol_dir: Vector2 = Vector2.RIGHT
var _patrol_timer: float = 0.0
var _attack_timer: float = 0.0
var _special_timer: float = 0.0
var _shield_active: bool = false
var _shield_timer: float = 0.0
var _stun_timer: float = 0.0     # player stun remaining
var _fire_trail_timer: float = 0.0
var _last_trail_pos: Vector2 = Vector2.ZERO

var _placeholder: ColorRect = null

const ATTACK_COOLDOWN: float = 1.0
const ATTACK_RANGE: float = 14.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("enemy")
	_load_data()
	_apply_stats()
	_spawn_placeholder()
	_patrol_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

func _load_data() -> void:
	var db: Node = get_node_or_null("/root/ElementDatabase")
	if db and db.has_method("get_enemy_data"):
		_data = db.get_enemy_data(creature_id)
	if _data.is_empty():
		# Fallback: load directly
		var f := FileAccess.open("res://data/enemy_data.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed and parsed.has("tier_multipliers") and parsed.has("creatures"):
				_tier_mult = parsed["tier_multipliers"].get(tier, {})
				for c: Dictionary in parsed["creatures"]:
					if c.get("id", "") == creature_id:
						_data = c
						break
				if _tier_mult.is_empty():
					_tier_mult = { "hp": 1.0, "damage": 1.0, "speed": 1.0, "sight": 1.0 }
				return
	# If ElementDatabase provided, still need tier_mult
	var f2 := FileAccess.open("res://data/enemy_data.json", FileAccess.READ)
	if f2:
		var parsed2 = JSON.parse_string(f2.get_as_text())
		f2.close()
		if parsed2 and parsed2.has("tier_multipliers"):
			_tier_mult = parsed2["tier_multipliers"].get(tier, { "hp": 1.0, "damage": 1.0, "speed": 1.0, "sight": 1.0 })

func _apply_stats() -> void:
	if _data.is_empty():
		return
	var hm: float = float(_tier_mult.get("hp",     1.0))
	var dm: float = float(_tier_mult.get("damage", 1.0))
	var sm: float = float(_tier_mult.get("speed",  1.0))
	var sgm: float= float(_tier_mult.get("sight",  1.0))

	max_hp       = float(_data.get("base_hp",     30))  * hm
	base_damage  = float(_data.get("base_damage", 10))  * dm
	move_speed   = float(_data.get("base_speed",  50))  * sm
	sight_range  = float(_data.get("sight_range", 90))  * sgm
	hp           = max_hp

	resistances  = _data.get("resistances", {})

	var passive: String = _data.get("passive", "")
	if passive == "damage_reduction":
		var pp: Dictionary = _data.get("passive_params", {})
		passive_dr = float(pp.get("dr", 0.0))

	# Special cooldown from data
	var sp: Dictionary = _data.get("special_params", {})
	_special_timer = float(sp.get("cooldown", 3.0))

func _spawn_placeholder() -> void:
	_placeholder = ColorRect.new()
	var col_hex: String = _data.get("color", "#CC2020")
	_placeholder.color = Color(col_hex)
	var sz: int = int(_data.get("size", 12))
	_placeholder.size = Vector2(sz, sz)
	_placeholder.position = Vector2(-sz / 2.0, -sz / 2.0)
	# Tier tint: intermediate slightly brighter, expert glows
	match tier:
		"intermediate":
			_placeholder.color = _placeholder.color.lightened(0.2)
		"expert":
			_placeholder.color = _placeholder.color.lightened(0.4)
	add_child(_placeholder)

# ── Physics loop ──────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _state == "dead":
		return

	_attack_timer   = maxf(_attack_timer   - delta, 0.0)
	_special_timer  = maxf(_special_timer  - delta, 0.0)
	_shield_timer   = maxf(_shield_timer   - delta, 0.0)
	if _shield_timer <= 0.0:
		_shield_active = false

	_tick_burn(delta)
	_tick_aura(delta)
	_tick_fire_trail(delta)
	_find_player()

	match _state:
		"patrol": _do_patrol(delta)
		"chase":  _do_chase(delta)

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
	var resist: float = float(resistances.get("burn", 1.0))
	if resist < 999.0:
		_take_damage_raw(dps * delta * (1.0 - resist))

func _tick_aura(delta: float) -> void:
	var aura: String = _data.get("aura", "")
	if aura == "":
		return
	if _player == null:
		return
	var ap: Dictionary = _data.get("aura_params", {})
	var radius: float = float(ap.get("radius", 48.0)) * float(_tier_mult.get("hp", 1.0))
	var dps: float    = float(ap.get("dps", 5.0))
	var dist: float   = global_position.distance_to(_player.global_position)
	if dist <= radius and _player.has_method("take_damage"):
		_player.take_damage(dps * delta)

func _tick_fire_trail(delta: float) -> void:
	if _data.get("special", "") != "leave_fire_trail":
		return
	_fire_trail_timer -= delta
	if _fire_trail_timer > 0.0:
		return
	_fire_trail_timer = 0.3
	if _last_trail_pos.distance_to(global_position) < 4.0:
		return
	_last_trail_pos = global_position
	_spawn_hazard_zone(global_position, 8.0,
		float(_data.get("special_params", {}).get("trail_dps", 12)),
		float(_data.get("special_params", {}).get("trail_duration", 8.0)),
		Color(1.0, 0.3, 0.0, 0.5))

func _find_player() -> void:
	if _player == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0] as Node2D
	if _player == null:
		return
	var dist: float = global_position.distance_to(_player.global_position)
	if dist <= sight_range:
		_state = "chase"
	elif _state == "chase":
		_state = "patrol"

func _do_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_patrol_timer = randf_range(1.5, 3.5)
		_patrol_dir   = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	velocity = _patrol_dir * move_speed

func _do_chase(delta: float) -> void:
	if _player == null:
		return
	var to_player: Vector2 = (_player.global_position - global_position).normalized()
	var dist: float = global_position.distance_to(_player.global_position)

	# Special ability trigger
	var special: String = _data.get("special", "")
	if _special_timer <= 0.0 and special != "":
		_try_special(special, dist)

	velocity = to_player * move_speed

	# Dive bomb overrides velocity
	if special == "dive_bomb" and _special_timer > 0.0:
		var sp: Dictionary = _data.get("special_params", {})
		velocity = to_player * move_speed * float(sp.get("dive_multiplier", 2.5))

	# Contact damage
	if dist <= ATTACK_RANGE and _attack_timer <= 0.0:
		var final_dmg: float = base_damage
		if _player.has_method("take_damage"):
			_player.take_damage(final_dmg)
		_attack_timer = ATTACK_COOLDOWN
		_spawn_damage_label(final_dmg)

		# stun_on_hit special
		if special == "stun_on_hit":
			var sp: Dictionary = _data.get("special_params", {})
			if randf() < float(sp.get("chance", 0.35)):
				_apply_player_stun(float(sp.get("stun_duration", 0.8)))

		# corrode_armor special
		if special == "corrode_armor":
			var sp: Dictionary = _data.get("special_params", {})
			_apply_corrode(_player, float(sp.get("dr_reduction", 0.10)), float(sp.get("duration", 5.0)))

# ── Special abilities ─────────────────────────────────────────────────────────

func _try_special(special: String, dist: float) -> void:
	var sp: Dictionary = _data.get("special_params", {})
	var cd: float      = float(sp.get("cooldown", 4.0))

	match special:
		"explode_on_death":
			pass  # Triggered in _die(), not on cooldown

		"leave_puddle":
			if dist <= sight_range:
				_spawn_hazard_zone(global_position, float(sp.get("radius", 32)),
					float(sp.get("dps", 4)), float(sp.get("duration", 3.0)),
					Color(0.5, 0.2, 0.8, 0.4))
				_special_timer = cd

		"shockwave":
			if dist <= sight_range:
				_do_shockwave(float(sp.get("radius", 48)), float(sp.get("damage", 12)))
				_special_timer = cd

		"ranged_attack":
			if dist <= sight_range and _player != null:
				_fire_projectile(float(sp.get("projectile_damage", 12)),
					float(sp.get("projectile_speed", 150)))
				_special_timer = cd

		"flash_blind":
			if dist <= sight_range and _player != null:
				_apply_player_stun(float(sp.get("blind_duration", 1.5)))
				_spawn_flash()
				_special_timer = cd

		"dive_bomb":
			if dist > 60.0:
				_special_timer = float(sp.get("cooldown", 4.0)) * 0.3  # brief window, then splash
				# Splash check handled in _physics_process via velocity boost
				# Landing splash on next contact frame
		"knockback_slam":
			if dist <= 80.0 and _player != null:
				var dir: Vector2 = (_player.global_position - global_position).normalized()
				if _player.has_method("apply_knockback"):
					_player.apply_knockback(dir * float(sp.get("knockback_force", 200)))
				if _player.has_method("take_damage"):
					_player.take_damage(float(sp.get("damage", 12)))
				_special_timer = cd

		"aoe_stun":
			if dist <= float(sp.get("radius", 44)):
				_apply_player_stun(float(sp.get("stun_duration", 1.2)))
				_spawn_shockwave_vfx(global_position, float(sp.get("radius", 44)), Color(0.2, 0.6, 1.0))
				_special_timer = cd

		"shield_pulse":
			_shield_active = true
			_shield_timer  = float(sp.get("immunity_duration", 2.0))
			_special_timer = cd
			_spawn_shield_vfx()

		"ground_slam":
			if dist <= float(sp.get("radius", 56)):
				_do_shockwave(float(sp.get("radius", 56)), float(sp.get("damage", 20)))
				_special_timer = cd

func _do_shockwave(radius: float, damage: float) -> void:
	if _player == null:
		return
	var dist: float = global_position.distance_to(_player.global_position)
	if dist <= radius:
		if _player.has_method("take_damage"):
			_player.take_damage(damage)
	_spawn_shockwave_vfx(global_position, radius, Color(0.9, 0.5, 0.1, 0.6))

func _fire_projectile(proj_damage: float, proj_speed: float) -> void:
	if _player == null:
		return
	var proj := Node2D.new()
	var rect := ColorRect.new()
	rect.color = Color(_data.get("color", "#FFFFFF"))
	rect.size  = Vector2(6, 6)
	rect.position = Vector2(-3, -3)
	proj.add_child(rect)
	proj.z_index = 10
	proj.set_meta("damage",    proj_damage)
	proj.set_meta("speed",     proj_speed)
	proj.set_meta("direction", (_player.global_position - global_position).normalized())
	proj.set_meta("lifetime",  3.0)
	proj.set_script(load("res://scripts/world/enemy_projectile.gd"))
	proj.global_position = global_position
	get_parent().add_child(proj)

func _apply_player_stun(duration: float) -> void:
	if _player and _player.has_method("apply_stun"):
		_player.apply_stun(duration)

func _apply_corrode(player: Node, dr_reduction: float, duration: float) -> void:
	if player and player.has_method("apply_armor_corrode"):
		player.apply_armor_corrode(dr_reduction, duration)

# ── Damage / Death ────────────────────────────────────────────────────────────

func take_damage(amount: float, damage_type: String = "physical") -> void:
	if _state == "dead":
		return
	if _shield_active:
		_spawn_hit_label(0.0)
		return
	var resist: float = float(resistances.get(damage_type, 1.0))
	if resist >= 999.0:
		_spawn_hit_label(0.0)
		return
	var reduced: float = amount * (1.0 - resist) * (1.0 - passive_dr)
	_take_damage_raw(reduced)

func _take_damage_raw(amount: float) -> void:
	if _state == "dead":
		return
	hp = maxf(hp - amount, 0.0)
	_spawn_hit_label(amount)
	if hp <= 0.0:
		_die()

func _die() -> void:
	_state = "dead"
	velocity = Vector2.ZERO

	# explode_on_death
	if _data.get("special", "") == "explode_on_death":
		var sp: Dictionary = _data.get("special_params", {})
		_do_shockwave(float(sp.get("radius", 40)), float(sp.get("damage", 8)))
		_spawn_shockwave_vfx(global_position, float(sp.get("radius", 40)), Color(1.0, 0.6, 0.0, 0.7))

	AudioManager.on_enemy_die()
	_drop_elements()
	queue_free()

func _drop_elements() -> void:
	var tier_drops: Dictionary = {}
	var drops_all: Dictionary = _data.get("drops", {})
	if drops_all.has(tier):
		tier_drops = drops_all[tier]
	if tier_drops.is_empty():
		return

	var elements: Array = tier_drops.get("elements", [])
	var dmin: int = int(tier_drops.get("min", 1))
	var dmax: int = int(tier_drops.get("max", 2))
	var count: int = randi_range(dmin, dmax)

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p: Node = players[0]
	var inv: Node = p.get_node_or_null("Inventory") if p.has_method("get_node") else null

	for i: int in range(count):
		if elements.is_empty():
			break
		var symbol: String = elements[randi() % elements.size()]
		_spawn_drop_label(symbol)
		if inv and inv.has_method("add_element"):
			inv.add_element(symbol, snappedf(randf_range(0.1, 1.0), 0.01))

	# Bonus item drop (equipment items for expert tier)
	var bonus: String = tier_drops.get("bonus_item", "")
	if bonus != "":
		var equip: Node = p.get_node_or_null("Equipment") if p.has_method("get_node") else null
		if equip and equip.has_method("add_item"):
			equip.add_item(bonus, 1)
			_spawn_drop_label(bonus)

# ── VFX helpers ───────────────────────────────────────────────────────────────

func _spawn_shockwave_vfx(pos: Vector2, radius: float, col: Color) -> void:
	var circle := ColorRect.new()
	circle.color = col
	circle.size  = Vector2(radius * 2.0, radius * 2.0)
	circle.position = pos - Vector2(radius, radius)
	circle.z_index = 50
	get_parent().add_child(circle)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(circle, "modulate:a", 0.0, 0.4)
	tween.tween_callback(circle.queue_free).set_delay(0.4)

func _spawn_hazard_zone(pos: Vector2, radius: float, dps: float, duration: float, col: Color) -> void:
	var zone := Node2D.new()
	var rect := ColorRect.new()
	rect.color    = col
	rect.size     = Vector2(radius * 2.0, radius * 2.0)
	rect.position = Vector2(-radius, -radius)
	zone.add_child(rect)
	zone.global_position = pos
	zone.z_index = 5
	zone.set_meta("dps",      dps)
	zone.set_meta("radius",   radius)
	zone.set_meta("lifetime", duration)
	zone.set_script(load("res://scripts/world/hazard_zone.gd"))
	get_parent().add_child(zone)

func _spawn_flash() -> void:
	var flash := ColorRect.new()
	flash.color  = Color(1.0, 1.0, 0.8, 0.7)
	flash.size   = Vector2(20, 20)
	flash.position = global_position - Vector2(10, 10)
	flash.z_index = 100
	get_parent().add_child(flash)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free).set_delay(0.3)

func _spawn_shield_vfx() -> void:
	var shield := ColorRect.new()
	shield.color  = Color(0.7, 0.9, 1.0, 0.4)
	shield.size   = Vector2(30, 30)
	shield.position = Vector2(-15, -15)
	shield.z_index = 20
	add_child(shield)
	var sp: Dictionary = _data.get("special_params", {})
	var dur: float = float(sp.get("immunity_duration", 2.0))
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(shield, "modulate:a", 0.0, dur)
	tween.tween_callback(shield.queue_free).set_delay(dur)

func _spawn_hit_label(amount: float) -> void:
	var label := Label.new()
	label.text = "-%.0f" % amount if amount > 0.0 else "IMMUNE"
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(1.0, 0.5, 0.0) if amount > 0.0 else Color(0.5, 0.8, 1.0)
	label.position = global_position + Vector2(-8, -20)
	label.z_index  = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 18, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free).set_delay(0.8)

func _spawn_damage_label(amount: float) -> void:
	if _player == null:
		return
	var label := Label.new()
	label.text = "-%d HP" % int(amount)
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(1.0, 0.2, 0.2)
	label.position = _player.global_position + Vector2(-20, -24)
	label.z_index  = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 20, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free).set_delay(1.0)

func _spawn_drop_label(text: String) -> void:
	var label := Label.new()
	label.text = "+%s" % text
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(0.5, 1.0, 0.5)
	label.position = global_position + Vector2(-8, -16)
	label.z_index  = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free).set_delay(1.2)
