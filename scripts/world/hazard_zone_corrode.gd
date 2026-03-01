extends Node2D

# Acid pool hazard — damages and corrodes player armor DR.

var _dps: float      = 5.0
var _radius: float   = 22.0
var _lifetime: float = 10.0
var _corrode_dr: float     = 0.08
var _corrode_dur: float    = 4.0
var _tick: float     = 0.0

func _ready() -> void:
	_dps         = float(get_meta("dps",              5.0))
	_radius      = float(get_meta("radius",           22.0))
	_lifetime    = float(get_meta("lifetime",         10.0))
	_corrode_dr  = float(get_meta("corrode_dr",       0.08))
	_corrode_dur = float(get_meta("corrode_duration", 4.0))

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	var players := get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p is Node2D:
			var n: Node2D = p as Node2D
			if global_position.distance_to(n.global_position) <= _radius:
				if p.has_method("take_damage"):
					p.take_damage(_dps * 0.5)
				if p.has_method("apply_armor_corrode"):
					p.apply_armor_corrode(_corrode_dr, _corrode_dur)
