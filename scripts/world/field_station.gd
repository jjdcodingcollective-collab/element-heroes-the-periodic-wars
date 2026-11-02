extends StaticBody2D

# Field Station — a lab tent and bench (SYSTEMS_UX_REVIEW.md §3.1).
# One sits in Ashvale, one near each biome's entrance and one just outside
# every boss arena. Walking up to it for the first time discovers it; pressing
# F next to it opens the station menu: Save, Rest (full heal) and Travel (fast
# travel to any discovered station).
#
# Also a crafting bench: the 3×3 crafting grid unlocks within interact_radius
# of any node in the "crafting_bench" group.
#
# SPRITE SWAP: replace _draw() with a Sprite2D once the tent art exists.

const DISCOVER_RADIUS: float = 56.0

@export var station_id: String = ""
@export var display_name: String = "Field Station"
@export var interact_radius: float = 36.0

var discovered: bool = false
var _hint: Label = null

func _ready() -> void:
	add_to_group("field_station")
	add_to_group("crafting_bench")
	collision_layer = 1
	collision_mask = 0
	_hint = Label.new()
	_hint.text = "[F] Field Station"
	_hint.add_theme_font_size_override("font_size", 7)
	_hint.modulate = Color.YELLOW
	_hint.position = Vector2(-26, -40)
	_hint.visible = false
	_hint.z_index = 2
	add_child(_hint)
	queue_redraw()

# Where a fast-travelling player arrives: just in front of the tent.
func arrival_position() -> Vector2:
	return global_position + Vector2(0, 22)

func set_discovered(value: bool) -> void:
	discovered = value
	queue_redraw()

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var dist: float = global_position.distance_to(player.global_position)
	_hint.visible = dist <= interact_radius
	if not discovered and dist <= DISCOVER_RADIUS and not bool(player.get("is_dead")):
		_discover()

func _discover() -> void:
	set_discovered(true)
	var world := get_parent()
	if world and world.has_method("on_station_discovered"):
		world.on_station_discovered(station_id)

# Called by player via call_group("field_station", "try_interact", player_pos)
func try_interact(player_pos: Vector2) -> void:
	if global_position.distance_to(player_pos) > interact_radius:
		return
	var dialogue_ui := get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui and dialogue_ui.has_method("is_open") and dialogue_ui.is_open():
		return
	if not discovered:
		_discover()
	var menu := UIManager.get_menu("station")
	if menu == null:
		return
	AudioManager.on_interact()
	menu.open_for(self)

# ── Placeholder art: canvas tent, bench with a flask, pennant ────────────────

func _draw() -> void:
	var outline := Color("#2e1a0e")
	var canvas := Color("#d9c9a0")
	var canvas_dark := Color("#a8956a")
	# Shadow
	draw_rect(Rect2(-17, 2, 34, 4), Color(0, 0, 0, 0.25))
	# Tent body (front triangle) with a darker door flap
	var tent := PackedVector2Array([Vector2(-16, 4), Vector2(0, -22), Vector2(16, 4)])
	draw_colored_polygon(tent, canvas)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(16, 4), Vector2(6, 4)]), canvas_dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 4), Vector2(0, -8), Vector2(5, 4)]), Color("#5b3520"))
	draw_polyline(PackedVector2Array([Vector2(-16, 4), Vector2(0, -22), Vector2(16, 4), Vector2(-16, 4)]), outline, 1.0)
	# Pole and pennant: brass once discovered, grey before
	draw_line(Vector2(0, -22), Vector2(0, -30), outline, 1.0)
	var flag := Color("#d6a040") if discovered else Color(0.55, 0.55, 0.55)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -30), Vector2(8, -27), Vector2(0, -24)]), flag)
	# Bench to the right with a green flask
	draw_rect(Rect2(14, -3, 12, 3), Color("#8a5a2b"))
	draw_rect(Rect2(15, 0, 2, 5), Color("#5b3520"))
	draw_rect(Rect2(23, 0, 2, 5), Color("#5b3520"))
	draw_rect(Rect2(18, -8, 4, 5), Color(0.45, 0.85, 0.5, 0.9))
	draw_rect(Rect2(19, -10, 2, 2), Color(0.85, 0.9, 0.9))
