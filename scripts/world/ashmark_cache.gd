extends Node2D

# Ashmark cache — what you drop when you fall with Keep Inventory off
# (SYSTEMS_UX_REVIEW §3.5, Minecraft-style recovery run). Walk over it to
# pick the Ashmarks back up. Placeholder art in the game palette.

const PICKUP_RADIUS: float = 14.0
const BRASS      := Color("#d6a040")
const BRASS_DARK := Color("#8c6022")
const SATCHEL    := Color("#5b3520")

var amount: int = 0
var _t: float = 0.0
var _label: Label

func _ready() -> void:
	add_to_group("ashmark_cache")
	z_index = 1
	_label = Label.new()
	_label.text = "◈ %d" % amount
	_label.add_theme_font_size_override("font_size", 7)
	_label.modulate = BRASS
	_label.position = Vector2(-10, -26)
	add_child(_label)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or ("is_dead" in player and player.is_dead):
		return
	if global_position.distance_to(player.global_position) <= PICKUP_RADIUS:
		collect(player)

func collect(player: Node) -> void:
	if amount <= 0 or is_queued_for_deletion():
		return
	var bag := player.get_node_or_null("Bag")
	if bag == null:
		return
	bag.add_ashmarks(amount)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_toast"):
		hud.show_toast("◈ Recovered %d Ashmarks" % amount, BRASS)
	AudioManager.on_pickup()
	amount = 0
	queue_free()

func _draw() -> void:
	var bob := sin(_t * 3.0) * 1.5
	draw_circle(Vector2(0, 4), 7.0, Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-6, -8 + bob, 12, 10), SATCHEL)
	draw_rect(Rect2(-6, -8 + bob, 12, 3), SATCHEL.darkened(0.3))
	var c := Vector2(0, -3 + bob)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(3, 0), c + Vector2(0, 4), c + Vector2(-3, 0)]), BRASS)
	draw_polyline(PackedVector2Array([c + Vector2(0, -4), c + Vector2(3, 0), c + Vector2(0, 4), c + Vector2(-3, 0), c + Vector2(0, -4)]), BRASS_DARK, 1.0)
