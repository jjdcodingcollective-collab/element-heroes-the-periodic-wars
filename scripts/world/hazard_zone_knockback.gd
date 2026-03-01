extends Node2D

# Wind column hazard — applies burst knockback when player enters.

var _radius: float    = 20.0
var _lifetime: float  = 4.0
var _knockback: float = 220.0
var _tick: float      = 0.0
var _triggered: bool  = false

func _ready() -> void:
	_radius    = float(get_meta("radius",    20.0))
	_lifetime  = float(get_meta("lifetime",  4.0))
	_knockback = float(get_meta("knockback", 220.0))

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.6
	_triggered = false
	var players := get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p is Node2D:
			var n: Node2D = p as Node2D
			if global_position.distance_to(n.global_position) <= _radius:
				if p.has_method("apply_knockback"):
					var dir: Vector2 = (n.global_position - global_position).normalized()
					p.apply_knockback(dir * _knockback)
				if p.has_method("take_damage"):
					p.take_damage(6.0)
