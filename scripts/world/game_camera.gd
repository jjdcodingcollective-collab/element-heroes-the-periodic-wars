extends Camera2D

# GameCamera — follows the player and clamps to world bounds.
# Attach to the Camera2D node inside the Player scene.
#
# SPRITE SWAP: no changes needed here when upgrading to sprites.

const ZOOM_LEVEL := Vector2(3.0, 3.0)
const BOSS_ZOOM_LEVEL := Vector2(2.0, 2.0)   # pull back so a huge boss and its arena fit
const SMOOTH_SPEED := 8.0

# World bounds in pixels — must match world.gd constants
const WORLD_PX_W: float = 200 * 16
const WORLD_PX_H: float = 200 * 16

func _ready() -> void:
	add_to_group("game_camera")
	zoom = ZOOM_LEVEL
	position_smoothing_enabled = true
	position_smoothing_speed = SMOOTH_SPEED

func set_boss_zoom(in_fight: bool) -> void:
	var target := BOSS_ZOOM_LEVEL if in_fight else ZOOM_LEVEL
	create_tween().tween_property(self, "zoom", target, 0.8).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	_clamp_to_world()

func _clamp_to_world() -> void:
	# Half-viewport size in world coords (accounting for zoom)
	var vp := get_viewport_rect().size
	var half_w := vp.x / (2.0 * zoom.x)
	var half_h := vp.y / (2.0 * zoom.y)

	var clamped := global_position
	clamped.x = clamp(global_position.x, half_w, WORLD_PX_W - half_w)
	clamped.y = clamp(global_position.y, half_h, WORLD_PX_H - half_h)
	global_position = clamped
