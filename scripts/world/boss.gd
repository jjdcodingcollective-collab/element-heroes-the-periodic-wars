extends CharacterBody2D

# ── Boss — Multi-phase compound titan ────────────────────────────────────────
# Loaded from data/boss_data.json. Each boss has 3 phases triggered by HP%.
# Phases change: color, aura radius/dps, arena hazard rate, special ability.
#
# Special abilities:
#   caustic_spray       — ranged caustic cone, leaves hazard zone
#   oxygen_burst        — AoE that ignites existing water hazards
#   caustic_nova        — full-radius caustic explosion
#   shockwave           — radial knockback + damage
#   flake_burst         — scatter projectiles + blind
#   ranged_acid_bolt    — multi-bolt ranged attack
#   gold_prison         — AoE stun around boss
#   ruby_cloud          — AoE blind + damage cloud
#   reactive_detonation — triggers on every hit received (AZRAEL)
#   nitrogen_lance      — directional piercing beam
#   chain_detonation    — sequential explosions across arena
#   corrosive_spit      — ranged projectile with armor corrode
#   tide_surge          — knockback wave + flood
#   copper_implosion    — pull + burst damage
#   gamma_burst         — AoE irradiate zone
#   fission_beam        — long directional irradiate beam
#   meltdown            — full arena supercritical explosion

@export var boss_id: String = "peroxis"

# ── Runtime ───────────────────────────────────────────────────────────────────
var _data: Dictionary = {}
var _phases: Array = []
var _current_phase_index: int = 0

var hp: float = 300.0
var max_hp: float = 300.0
var base_damage: float = 22.0
var move_speed: float = 55.0
var sight_range: float = 140.0
var passive_dr: float = 0.0
var resistances: Dictionary = {}
var min_weapon_tier: int = 1

var _player: Node2D = null
var _arena: Node = null         # BossArena node, wired after spawn
var _state: String = "idle"     # "idle" | "combat" | "dead"
var _patrol_dir: Vector2 = Vector2.RIGHT
var _patrol_timer: float = 0.0
var _attack_timer: float = 0.0
var _special_timer: float = 0.0
var _phase_transitioning: bool = false

var _placeholder: ColorRect = null
var _hp_label: Label = null

const ATTACK_COOLDOWN: float = 1.2
const ATTACK_RANGE: float = 20.0
const IDLE_WANDER_SPEED: float = 20.0

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("boss")
	_load_data()
	_apply_phase(0)
	_spawn_visuals()

func _load_data() -> void:
	var f := FileAccess.open("res://data/boss_data.json", FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null or not parsed.has("bosses"):
		return
	for b: Dictionary in parsed["bosses"]:
		if b.get("id", "") == boss_id:
			_data = b
			_phases = b.get("phases", [])
			break

func _apply_phase(phase_index: int) -> void:
	if _data.is_empty() or phase_index >= _phases.size():
		return
	_current_phase_index = phase_index
	var ph: Dictionary = _phases[phase_index]

	# Base stats from root data, then scale with phase multipliers
	max_hp       = float(_data.get("base_hp",     300))
	base_damage  = float(_data.get("base_damage", 22))
	move_speed   = float(_data.get("base_speed",  55))
	sight_range  = float(_data.get("sight_range", 140))
	resistances  = _data.get("resistances", {})
	min_weapon_tier = int(_data.get("min_weapon_tier", 1))

	# Phase passive DR
	var passive: String = ph.get("passive", "")
	if passive == "damage_reduction":
		passive_dr = float(ph.get("passive_params", {}).get("dr", 0.0))
	else:
		passive_dr = 0.0

	# Special cooldown from phase data
	var sp_params: Dictionary = ph.get("special_params", {})
	var trigger: String = sp_params.get("trigger", "")
	if trigger != "on_hit":
		_special_timer = float(sp_params.get("cooldown", 4.0))

	# Update placeholder colour
	if _placeholder != null:
		_placeholder.color = Color(ph.get("color", _data.get("color", "#FF2020")))

	# Notify arena to change hazard rate
	if _arena and _arena.has_method("set_hazard"):
		_arena.set_hazard(ph.get("arena_hazard", ""), float(ph.get("hazard_interval", 3.0)))

func _spawn_visuals() -> void:
	var sz: int = int(_data.get("size", 32))
	_placeholder = ColorRect.new()
	_placeholder.color = Color(_data.get("color", "#FF2020"))
	_placeholder.size  = Vector2(sz, sz)
	_placeholder.position = Vector2(-sz / 2.0, -sz / 2.0)
	_placeholder.z_index = 2
	add_child(_placeholder)

	# HP bar above boss
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 8)
	_hp_label.modulate = Color(1.0, 0.3, 0.3)
	_hp_label.position = Vector2(-30, -float(sz) / 2.0 - 18)
	_hp_label.z_index = 10
	add_child(_hp_label)
	_refresh_hp_label()

	# Boss name label
	var name_lbl := Label.new()
	name_lbl.text = "%s — %s" % [_data.get("name", "BOSS"), _data.get("title", "")]
	name_lbl.add_theme_font_size_override("font_size", 7)
	name_lbl.modulate = Color(1.0, 0.8, 0.2)
	name_lbl.position = Vector2(-50, -float(sz) / 2.0 - 28)
	name_lbl.z_index = 10
	add_child(name_lbl)

func _refresh_hp_label() -> void:
	if _hp_label:
		_hp_label.text = "HP: %d / %d  [%s]" % [int(hp), int(max_hp), _phases[_current_phase_index].get("name", "")]

# ── Physics ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _state == "dead":
		return

	_attack_timer  = maxf(_attack_timer  - delta, 0.0)
	_special_timer = maxf(_special_timer - delta, 0.0)

	_tick_burn(delta)
	_tick_aura(delta)
	_tick_hp_regen(delta)
	_find_player()
	_check_phase_transition()

	match _state:
		"idle":   _do_wander(delta)
		"combat": _do_combat(delta)

	move_and_slide()

func _find_player() -> void:
	if _player == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0] as Node2D
	if _player == null:
		return
	var dist: float = global_position.distance_to(_player.global_position)
	if dist <= sight_range:
		_state = "combat"

func _do_wander(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_patrol_timer = randf_range(2.0, 4.0)
		_patrol_dir   = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	velocity = _patrol_dir * IDLE_WANDER_SPEED

func _do_combat(delta: float) -> void:
	if _player == null:
		return
	var to_player: Vector2 = (_player.global_position - global_position).normalized()
	var dist: float = global_position.distance_to(_player.global_position)
	velocity = to_player * move_speed

	# Special
	if _special_timer <= 0.0:
		var ph: Dictionary = _phases[_current_phase_index]
		var special: String = ph.get("special", "")
		if special != "" and special != "reactive_detonation":
			_trigger_special(special, ph.get("special_params", {}), dist)

	# Contact damage
	if dist <= ATTACK_RANGE and _attack_timer <= 0.0:
		if _player.has_method("take_damage"):
			_player.take_damage(base_damage)
		_attack_timer = ATTACK_COOLDOWN
		_spawn_damage_label(base_damage)

func _tick_burn(delta: float) -> void:
	if not has_meta("burn_timer"):
		return
	var t: float = float(get_meta("burn_timer")) - delta
	if t <= 0.0:
		remove_meta("burn_timer")
		remove_meta("burn_dps")
		return
	set_meta("burn_timer", t)
	var dps: float = float(get_meta("burn_dps", 0.0))
	var resist: float = float(resistances.get("burn", 1.0))
	if resist < 999.0:
		_take_damage_raw(dps * delta * (1.0 - resist))

func _tick_aura(delta: float) -> void:
	if _player == null or _phases.is_empty():
		return
	var ph: Dictionary = _phases[_current_phase_index]
	var aura: String = ph.get("aura", "")
	if aura == "":
		return
	var ap: Dictionary = ph.get("aura_params", {})
	var radius: float = float(ap.get("radius", 60))
	var dps: float    = float(ap.get("dps", 8))
	var dist: float   = global_position.distance_to(_player.global_position)
	if dist <= radius and _player.has_method("take_damage"):
		_player.take_damage(dps * delta)

	# Concussive aura (AZRAEL phase 3)
	if aura == "concussive":
		var kb: float = float(ap.get("knockback", 150))
		if dist <= radius and _player.has_method("apply_knockback"):
			var dir: Vector2 = (_player.global_position - global_position).normalized()
			_player.apply_knockback(dir * kb * delta)

func _tick_hp_regen(delta: float) -> void:
	if _phases.is_empty():
		return
	var ph: Dictionary = _phases[_current_phase_index]
	var passive: String = ph.get("passive", "")
	if passive == "absorb_water":
		var regen: float = float(ph.get("passive_params", {}).get("hp_regen_per_sec", 0.0))
		hp = minf(hp + regen * delta, max_hp)
		_refresh_hp_label()

# ── Phase transitions ─────────────────────────────────────────────────────────

func _check_phase_transition() -> void:
	if _phase_transitioning or _phases.is_empty():
		return
	var hp_pct: float = hp / max_hp
	# Find the deepest phase whose threshold we've crossed
	for i: int in range(_phases.size() - 1, _current_phase_index, -1):
		var threshold: float = float(_phases[i].get("hp_threshold", 1.0))
		if hp_pct <= threshold and i > _current_phase_index:
			_transition_to_phase(i)
			break

func _transition_to_phase(phase_index: int) -> void:
	_phase_transitioning = true
	# Flash white
	if _placeholder:
		_placeholder.color = Color.WHITE
	var tween: Tween = get_tree().create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func() -> void:
		_apply_phase(phase_index)
		_phase_transitioning = false
		_refresh_hp_label()
		_spawn_phase_label(_phases[phase_index].get("name", "Phase %d" % phase_index))
	)

func _spawn_phase_label(phase_name: String) -> void:
	var label := Label.new()
	label.text = "— %s —" % phase_name
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1.0, 0.6, 0.0)
	label.position = global_position + Vector2(-60, -60)
	label.z_index  = 200
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(label.queue_free).set_delay(2.0)

# ── Special abilities ─────────────────────────────────────────────────────────

func _trigger_special(special: String, sp: Dictionary, dist: float) -> void:
	var cd: float = float(sp.get("cooldown", 4.0))

	match special:
		"caustic_spray", "corrosive_spit":
			if _player == null:
				return
			var dir: Vector2 = (_player.global_position - global_position).normalized()
			_fire_boss_projectile(dir, float(sp.get("damage", 20)),
				float(sp.get("speed", 160)), sp)
			_special_timer = cd

		"oxygen_burst", "caustic_nova", "gamma_burst", "copper_implosion":
			var radius: float = float(sp.get("radius", 80))
			_do_boss_aoe(radius, float(sp.get("damage", 30)), sp)
			_special_timer = cd

		"shockwave", "gold_prison", "aoe_stun":
			var radius: float = float(sp.get("radius", 60))
			_do_boss_aoe(radius, float(sp.get("damage", 0)), sp)
			if _player and _player.has_method("apply_stun"):
				var stun: float = float(sp.get("stun_duration", 0.0))
				if stun > 0.0:
					_player.apply_stun(stun)
			_special_timer = cd

		"flake_burst":
			var count: int = int(sp.get("count", 8))
			for i: int in range(count):
				var angle: float = (TAU / count) * i
				var dir2: Vector2 = Vector2(cos(angle), sin(angle))
				_fire_boss_projectile(dir2, float(sp.get("damage", 14)), 140.0, {})
			if _player and _player.has_method("apply_stun"):
				_player.apply_stun(float(sp.get("blind_duration", 1.0)))
			_special_timer = cd

		"ranged_acid_bolt":
			if _player == null:
				return
			var base_dir: Vector2 = (_player.global_position - global_position).normalized()
			var count2: int = int(sp.get("count", 3))
			var spread: float = float(sp.get("spread", 0.3))
			for i: int in range(count2):
				var offset: float = (i - count2 / 2.0) * spread
				var rot_dir: Vector2 = base_dir.rotated(offset)
				_fire_boss_projectile(rot_dir, float(sp.get("damage", 20)),
					float(sp.get("speed", 180)), {})
			_special_timer = cd

		"ruby_cloud":
			_do_boss_aoe(float(sp.get("radius", 80)), float(sp.get("damage", 35)), sp)
			if _player and _player.has_method("apply_stun"):
				_player.apply_stun(float(sp.get("blind_duration", 2.0)))
			_special_timer = cd

		"nitrogen_lance":
			if _player == null:
				return
			_fire_boss_projectile(
				(_player.global_position - global_position).normalized(),
				float(sp.get("damage", 30)), 300.0,
				{ "knockback": sp.get("knockback", 200) }
			)
			_special_timer = cd

		"chain_detonation":
			var count3: int = int(sp.get("count", 4))
			var delay: float = float(sp.get("delay", 0.4))
			var radius2: float = float(sp.get("radius", 56))
			var dmg: float = float(sp.get("damage", 40))
			for i: int in range(count3):
				var pos: Vector2 = global_position + Vector2(
					randf_range(-120, 120), randf_range(-120, 120))
				_schedule_explosion(pos, radius2, dmg, delay * i)
			_special_timer = cd

		"tide_surge":
			_do_boss_aoe(160.0, float(sp.get("wave_damage", 28)), sp)
			if _player and _player.has_method("apply_knockback"):
				var dir3: Vector2 = (_player.global_position - global_position).normalized()
				_player.apply_knockback(dir3 * float(sp.get("knockback", 250)))
			_special_timer = cd

		"fission_beam":
			if _player == null:
				return
			_fire_boss_projectile(
				(_player.global_position - global_position).normalized(),
				float(sp.get("damage", 45)), 250.0,
				{ "irradiate_dps": sp.get("irradiate_dps", 15), "duration": sp.get("duration", 6.0) }
			)
			_special_timer = cd

		"meltdown":
			_do_boss_aoe(float(sp.get("radius", 120)), float(sp.get("damage", 70)), sp)
			_special_timer = cd

func _do_boss_aoe(radius: float, damage: float, sp: Dictionary) -> void:
	if _player:
		var dist: float = global_position.distance_to(_player.global_position)
		if dist <= radius:
			if damage > 0 and _player.has_method("take_damage"):
				_player.take_damage(damage)
			# Knockback if specified
			var kb: float = float(sp.get("knockback", sp.get("pull_force", 0)))
			if kb > 0 and _player.has_method("apply_knockback"):
				var dir: Vector2 = (_player.global_position - global_position).normalized()
				# pull_force is inward
				if sp.has("pull_force"):
					dir = -dir
				_player.apply_knockback(dir * kb)
			# Apply irradiate DoT zone
			var irr_dps: float = float(sp.get("irradiate_dps", 0))
			if irr_dps > 0:
				_spawn_hazard(global_position, radius, irr_dps, float(sp.get("duration", 5.0)),
					Color(0.2, 1.0, 0.2, 0.4))
			# Corrode
			var corrode: float = float(sp.get("corrode_dr", 0))
			if corrode > 0 and _player.has_method("apply_armor_corrode"):
				_player.apply_armor_corrode(corrode, float(sp.get("corrode_duration", 5.0)))
	_spawn_shockwave_vfx(global_position, radius, Color(1.0, 0.6, 0.1, 0.5))

func _fire_boss_projectile(dir: Vector2, damage: float, speed: float, extra: Dictionary) -> void:
	var proj := Node2D.new()
	var rect := ColorRect.new()
	rect.color = Color(_data.get("color", "#FF4040"))
	rect.size  = Vector2(8, 8)
	rect.position = Vector2(-4, -4)
	proj.add_child(rect)
	proj.z_index = 10
	proj.set_meta("damage",    damage)
	proj.set_meta("speed",     speed)
	proj.set_meta("direction", dir)
	proj.set_meta("lifetime",  4.0)
	if extra.has("knockback"):
		proj.set_meta("knockback", extra["knockback"])
	if extra.has("corrode_dr"):
		proj.set_meta("corrode_dr",       extra["corrode_dr"])
		proj.set_meta("corrode_duration",  extra.get("corrode_duration", 5.0))
	proj.set_script(load("res://scripts/world/enemy_projectile.gd"))
	proj.global_position = global_position + dir * 24.0
	get_parent().add_child(proj)

func _schedule_explosion(pos: Vector2, radius: float, damage: float, delay: float) -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		_spawn_shockwave_vfx(pos, radius, Color(0.8, 0.8, 1.0, 0.7))
		if _player:
			if pos.distance_to(_player.global_position) <= radius:
				if _player.has_method("take_damage"):
					_player.take_damage(damage)
				if _player.has_method("apply_knockback"):
					var dir: Vector2 = (_player.global_position - pos).normalized()
					_player.apply_knockback(dir * 280.0)
	)

# ── Damage / Death ────────────────────────────────────────────────────────────

func take_damage(amount: float, damage_type: String = "physical") -> void:
	if _state == "dead":
		return
	var resist: float = float(resistances.get(damage_type, 1.0))
	if resist >= 999.0:
		_spawn_hit_label(0.0)
		return

	# Minimum damage based on weapon tier gate
	# (world.gd should not spawn bosses until player is ready — this is just a soft floor)
	var reduced: float = amount * (1.0 - resist) * (1.0 - passive_dr)
	_take_damage_raw(reduced)

	# AZRAEL reactive_detonation — triggers on EVERY hit
	if not _phases.is_empty():
		var ph: Dictionary = _phases[_current_phase_index]
		var special: String = ph.get("special", "")
		if special == "reactive_detonation":
			var sp: Dictionary = ph.get("special_params", {})
			_do_boss_aoe(float(sp.get("radius", 72)), float(sp.get("damage", 28)), sp)
			if _player and _player.has_method("apply_knockback"):
				var dir: Vector2 = (_player.global_position - global_position).normalized()
				_player.apply_knockback(dir * float(sp.get("knockback", 300)))

func _take_damage_raw(amount: float) -> void:
	if _state == "dead":
		return
	hp = maxf(hp - amount, 0.0)
	_spawn_hit_label(amount)
	_refresh_hp_label()
	if hp <= 0.0:
		_die()

func _die() -> void:
	_state = "dead"
	velocity = Vector2.ZERO
	if _arena and _arena.has_method("clear_hazards"):
		_arena.clear_hazards()
	_drop_loot()
	_spawn_death_vfx()
	queue_free()

func _drop_loot() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p: Node = players[0]

	# Drop elements
	var drop_elements: Array = _data.get("drop_elements", [])
	var inv: Node = p.get_node_or_null("Inventory") if p.has_method("get_node") else null
	for sym: String in drop_elements:
		if inv and inv.has_method("add_element"):
			inv.add_element(sym, snappedf(randf_range(1.0, 3.0), 0.01))
		_spawn_drop_label(sym)

	# Drop boss item
	var bonus_item: String = _data.get("drop_item", "")
	if bonus_item != "":
		var equip: Node = p.get_node_or_null("Equipment") if p.has_method("get_node") else null
		if equip and equip.has_method("add_item"):
			equip.add_item(bonus_item, 1)
		_spawn_drop_label(bonus_item)

	# Unlock lore
	var lore: String = _data.get("unlock_lore", "")
	if lore != "" and p.has_method("get_node"):
		var hud: Node = get_tree().get_nodes_in_group("hud")[0] if get_tree().get_nodes_in_group("hud").size() > 0 else null
		if hud and hud.has_method("show_lore"):
			hud.show_lore(_data.get("name", ""), lore)

func _spawn_death_vfx() -> void:
	for i: int in range(6):
		var delay: float = i * 0.15
		var pos: Vector2 = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		var tween: Tween = get_tree().create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void:
			_spawn_shockwave_vfx(pos, 40.0, Color(_data.get("color", "#FF8020")).lightened(0.3))
		)

# ── VFX ───────────────────────────────────────────────────────────────────────

func _spawn_shockwave_vfx(pos: Vector2, radius: float, col: Color) -> void:
	var circle := ColorRect.new()
	circle.color    = col
	circle.size     = Vector2(radius * 2.0, radius * 2.0)
	circle.position = pos - Vector2(radius, radius)
	circle.z_index  = 50
	get_parent().add_child(circle)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(circle, "modulate:a", 0.0, 0.45)
	tween.tween_callback(circle.queue_free).set_delay(0.45)

func _spawn_hazard(pos: Vector2, radius: float, dps: float, duration: float, col: Color) -> void:
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

func _spawn_hit_label(amount: float) -> void:
	var label := Label.new()
	label.text     = "-%.0f" % amount if amount > 0.0 else "IMMUNE"
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(1.0, 0.5, 0.0) if amount > 0.0 else Color(0.5, 0.8, 1.0)
	label.position = global_position + Vector2(-10, -28)
	label.z_index  = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 22, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free).set_delay(0.8)

func _spawn_damage_label(amount: float) -> void:
	if _player == null:
		return
	var label := Label.new()
	label.text     = "-%d HP" % int(amount)
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(1.0, 0.1, 0.1)
	label.position = _player.global_position + Vector2(-24, -28)
	label.z_index  = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free).set_delay(1.0)

func _spawn_drop_label(text: String) -> void:
	var label := Label.new()
	label.text     = "+%s" % text
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(1.0, 0.9, 0.2)
	label.position = global_position + Vector2(-16, -16)
	label.z_index  = 100
	get_parent().add_child(label)
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 32, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free).set_delay(1.5)
