extends Node2D

# Persistent ground hazard (puddle, fire trail, etc.)
# Properties set via meta by enemy.gd before add_child.

var _dps: float      = 5.0
var _radius: float   = 32.0
var _lifetime: float = 4.0
var _tick: float     = 0.0

func _ready() -> void:
	_dps      = float(get_meta("dps",      5.0))
	_radius   = float(get_meta("radius",   32.0))
	_lifetime = float(get_meta("lifetime", 4.0))

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25  # damage tick every 250 ms
	var players := get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p is Node2D:
			var n: Node2D = p as Node2D
			if global_position.distance_to(n.global_position) <= _radius:
				if p.has_method("take_damage"):
					p.take_damage(_dps * 0.25)
