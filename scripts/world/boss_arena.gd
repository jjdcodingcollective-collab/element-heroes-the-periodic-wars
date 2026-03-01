extends Node2D

# ── BossArena — manages arena-wide hazards during a boss fight ────────────────
# Spawned alongside each boss by world.gd.
# The boss calls set_hazard() on phase transition and clear_hazards() on death.
#
# Hazard types:
#   water_puddles   — random water tiles that explode with PEROXIS's O2 burst
#   sulfur_vents    — poison gas vents that deal periodic damage
#   acid_pools      — dissolving pools that corrode player DR
#   wind_columns    — knockback columns (Sky Islands)
#   brine_tide      — rising brine that slows and poisons
#   radiation_zones — irradiate zones that persist for a long time

var _hazard_type: String = ""
var _hazard_interval: float = 3.5
var _hazard_timer: float = 0.0
var _active_zones: Array = []
var _arena_center: Vector2 = Vector2.ZERO
var _arena_radius: float = 160.0

var _player: Node2D = null

func _ready() -> void:
	set_process(true)

func init(center: Vector2, radius: float) -> void:
	_arena_center = center
	_arena_radius = radius

func set_hazard(hazard_type: String, interval: float) -> void:
	_hazard_type     = hazard_type
	_hazard_interval = interval
	_hazard_timer    = interval * 0.5  # first spawn slightly delayed

func clear_hazards() -> void:
	for zone in _active_zones:
		if is_instance_valid(zone):
			zone.queue_free()
	_active_zones.clear()
	_hazard_type = ""

func _process(delta: float) -> void:
	if _hazard_type == "":
		return
	if _player == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0] as Node2D
	_hazard_timer -= delta
	if _hazard_timer > 0.0:
		return
	_hazard_timer = _hazard_interval
	_spawn_hazard()

func _spawn_hazard() -> void:
	var pos: Vector2 = _arena_center + Vector2(
		randf_range(-_arena_radius, _arena_radius),
		randf_range(-_arena_radius, _arena_radius)
	)

	match _hazard_type:
		"water_puddles":
			_spawn_zone(pos, 20.0, 2.0, 12.0, Color(0.2, 0.5, 0.9, 0.5))
		"sulfur_vents":
			_spawn_zone(pos, 18.0, 8.0, 8.0, Color(0.8, 0.9, 0.1, 0.4))
		"acid_pools":
			var zone := _spawn_zone(pos, 22.0, 5.0, 10.0, Color(0.3, 0.9, 0.2, 0.4))
			zone.set_meta("corrode_dr",       0.08)
			zone.set_meta("corrode_duration", 4.0)
			_rewire_zone_corrode(zone)
		"wind_columns":
			_spawn_knockback_column(pos)
		"brine_tide":
			_spawn_zone(pos, 28.0, 4.0, 9.0, Color(0.2, 0.6, 0.5, 0.4))
		"radiation_zones":
			_spawn_zone(pos, 24.0, 14.0, 20.0, Color(0.1, 0.9, 0.1, 0.35))
		"flood":
			# Larger zones, shorter life
			_spawn_zone(pos, 40.0, 6.0, 5.0, Color(0.2, 0.5, 0.9, 0.45))

func _spawn_zone(pos: Vector2, radius: float, dps: float, lifetime: float, col: Color) -> Node2D:
	var zone := Node2D.new()
	var rect := ColorRect.new()
	rect.color    = col
	rect.size     = Vector2(radius * 2.0, radius * 2.0)
	rect.position = Vector2(-radius, -radius)
	zone.add_child(rect)
	zone.global_position = pos
	zone.z_index = 3
	zone.set_meta("dps",      dps)
	zone.set_meta("radius",   radius)
	zone.set_meta("lifetime", lifetime)
	zone.set_script(load("res://scripts/world/hazard_zone.gd"))
	get_parent().add_child(zone)
	_active_zones.append(zone)
	return zone

func _rewire_zone_corrode(zone: Node2D) -> void:
	# Extend hazard_zone to also apply corrode on tick
	# We do this by replacing the script with an inline-extended one.
	# Since we can't extend at runtime, we store the corrode data in meta
	# and the hazard_zone.gd already handles it via process — just add the logic check
	# Actually hazard_zone only does take_damage. We handle corrode separately here:
	zone.set_script(null)
	zone.set_script(load("res://scripts/world/hazard_zone_corrode.gd"))

func _spawn_knockback_column(pos: Vector2) -> void:
	var zone := Node2D.new()
	var rect := ColorRect.new()
	rect.color    = Color(0.7, 0.9, 1.0, 0.4)
	rect.size     = Vector2(20, 80)
	rect.position = Vector2(-10, -40)
	zone.add_child(rect)
	zone.global_position = pos
	zone.z_index = 3
	zone.set_meta("dps",       0.0)
	zone.set_meta("radius",    20.0)
	zone.set_meta("lifetime",  4.0)
	zone.set_meta("knockback", 220.0)
	zone.set_script(load("res://scripts/world/hazard_zone_knockback.gd"))
	get_parent().add_child(zone)
	_active_zones.append(zone)
