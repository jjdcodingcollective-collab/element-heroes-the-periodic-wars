extends Node2D

# Lightweight projectile fired by enemy ranged_attack special.
# Properties set via meta by enemy.gd before add_child.

var _damage: float    = 10.0
var _speed: float     = 150.0
var _direction: Vector2 = Vector2.RIGHT
var _lifetime: float  = 3.0

func _ready() -> void:
	_damage    = float(get_meta("damage",    10.0))
	_speed     = float(get_meta("speed",     150.0))
	_direction = get_meta("direction", Vector2.RIGHT)
	_lifetime  = float(get_meta("lifetime",  3.0))

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	global_position += _direction * _speed * delta
	# Check player hit
	var players := get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p is Node2D:
			var n: Node2D = p as Node2D
			if global_position.distance_to(n.global_position) <= 14.0:
				if p.has_method("take_damage"):
					p.take_damage(_damage)
				queue_free()
				return
