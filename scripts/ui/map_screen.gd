extends CanvasLayer

# Map (M): Orion's sketch map of the six biomes, a journal spread
# (SYSTEMS_UX_REVIEW.md §3.1–3.2). The left page draws the biomes as bands
# from west to east, with discovered Field Stations, the bosses (struck
# through once beaten) and Orion's position. The right page lists the
# discovered stations.
#
# Opened at a Field Station (its Travel option, or M while standing at one)
# the list becomes fast travel; anywhere else the map is view-only.
# UIManager menu "map": one menu at a time, pauses the game while open.

const JS := preload("res://scripts/ui/journal_style.gd")
const BOOK_SIZE := Vector2(900, 540)
const MAP_SIZE := Vector2(400, 400)

# Watercolour wash per biome, west to east.
const BIOME_WASH := {
	"surface_plains":    Color(0.42, 0.66, 0.30, 0.45),
	"underground_mines": Color(0.52, 0.40, 0.28, 0.45),
	"crystal_caverns":   Color(0.58, 0.42, 0.72, 0.42),
	"sky_islands":       Color(0.52, 0.74, 0.90, 0.48),
	"ocean_floor":       Color(0.25, 0.55, 0.62, 0.45),
	"magma_layer":       Color(0.82, 0.36, 0.20, 0.45),
}

var _dim: ColorRect
var _book: Control
var _canvas: MapCanvas
var _mode_label: Label
var _list: VBoxContainer
var _travel_from: String = ""    # station id we are travelling from ("" = view only)

func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused
	add_to_group("map_screen")
	_build()
	_apply_visibility(false)
	UIManager.register("map", self)

func is_open() -> bool:
	return _book.visible

func can_travel() -> bool:
	return _travel_from != ""

# Opened from a Field Station's Travel option.
func open_travel(from_station: String) -> void:
	_travel_from = from_station
	if UIManager.is_open("map"):
		refresh()
	else:
		UIManager.open("map")

# Called by UIManager.
func _menu_set_open(open: bool) -> void:
	_apply_visibility(open)
	if open:
		if _travel_from == "":
			# M pressed while standing at a discovered station: travel too.
			var world := _world()
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if world and player and world.has_method("station_near"):
				var st: Node = world.station_near(player.global_position)
				if st:
					_travel_from = st.station_id
		AudioManager.on_ui_open()
		refresh()
	else:
		_travel_from = ""
		AudioManager.on_ui_close()

func _apply_visibility(open: bool) -> void:
	_dim.visible = open
	_book.visible = open

func travel_to(station_id: String) -> bool:
	var world := _world()
	if not can_travel() or station_id == _travel_from or world == null:
		return false
	if not world.travel_to_station(station_id):
		return false
	AudioManager.on_interact()
	UIManager.close("map")
	return true

func _world() -> Node:
	return get_parent() if get_parent() and get_parent().has_method("travel_to_station") else null

func refresh() -> void:
	var world := _world()
	_canvas.world = world
	_canvas.queue_redraw()
	for c: Node in _list.get_children():
		c.queue_free()
	_mode_label.text = "Choose a station to travel to." if can_travel() \
		else "Visit a Field Station to travel."
	if world == null:
		return
	var ids: Array = world.discovered_stations.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return world.stations[a].global_position.x < world.stations[b].global_position.x \
			if world.stations.has(a) and world.stations.has(b) else a < b)
	if ids.is_empty():
		_list.add_child(JS.label("No stations found yet.", 13, JS.INK_SOFT))
	var first_btn: Button = null
	for id: String in ids:
		var st: Node = world.stations.get(id)
		if st == null:
			continue
		var b := JS.button("  " + st.display_name +("  (here)" if id == _travel_from else ""), 13)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 30)
		b.disabled = not can_travel() or id == _travel_from
		b.pressed.connect(travel_to.bind(id))
		b.mouse_entered.connect(func() -> void: _canvas.highlight = id; _canvas.queue_redraw())
		b.focus_entered.connect(func() -> void: _canvas.highlight = id; _canvas.queue_redraw())
		_list.add_child(b)
		if first_btn == null and not b.disabled:
			first_btn = b
	if first_btn:
		first_btn.grab_focus()

# ── Building ──────────────────────────────────────────────────────────────────

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_book = Control.new()
	_book.set_anchors_preset(Control.PRESET_CENTER)
	_book.size = BOOK_SIZE
	_book.position = -BOOK_SIZE / 2.0
	add_child(_book)
	JS.make_book(_book, BOOK_SIZE)
	var page_size := Vector2(BOOK_SIZE.x / 2.0 - 30, BOOK_SIZE.y - 40)
	var left := JS.make_page(_book, Vector2(24, 20), page_size, true)
	var right := JS.make_page(_book, Vector2(BOOK_SIZE.x / 2.0 + 6, 20), page_size, false)

	var title := JS.label("Map", 22, JS.INK)
	title.position = Vector2(20, 8)
	left.add_child(title)
	_canvas = MapCanvas.new()
	_canvas.position = Vector2((page_size.x - MAP_SIZE.x) / 2.0, 52)
	_canvas.size = MAP_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_canvas)

	var head := JS.label("Field Stations", 20, JS.INK)
	head.position = Vector2(24, 8)
	right.add_child(head)
	right.add_child(JS.ornament(Vector2(page_size.x / 2.0, 46)))
	_mode_label = JS.label("", 13, JS.INK_GREEN)
	_mode_label.position = Vector2(24, 56)
	right.add_child(_mode_label)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 82)
	scroll.size = Vector2(page_size.x - 48, 290)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var legend := JS.label("▲ Field Station    ● Boss (✕ beaten)    ◆ Orion\nM or Esc closes the map.", 12, JS.INK_SOFT)
	legend.position = Vector2(24, page_size.y - 56)
	right.add_child(legend)

# The sketch map itself, drawn from the world's data each time it opens.
class MapCanvas extends Control:
	var world: Node = null
	var highlight: String = ""

	func _to_map(world_px: Vector2) -> Vector2:
		var w: float = 200.0 * 16.0
		var h: float = 200.0 * 16.0
		if world:
			w = float(world.WORLD_PX_W)
			h = float(world.WORLD_PX_H)
		return Vector2(world_px.x / w * size.x, world_px.y / h * size.y)

	func _draw() -> void:
		var ink := Color("#3b2a1a")
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.9, 0.78))
		if world == null:
			return
		var ts: float = float(world.TILE_SIZE)
		# Biome bands with their names written down the band
		for b: Dictionary in world.BIOMES:
			var x0: float = _to_map(Vector2(int(b.x_start) * ts, 0)).x
			var x1: float = _to_map(Vector2((int(b.x_end) + 1) * ts, 0)).x
			draw_rect(Rect2(x0, 0, x1 - x0, size.y), BIOME_WASH.get(b.name, Color(0.6, 0.6, 0.6, 0.4)))
			draw_line(Vector2(x0, 0), Vector2(x0, size.y), Color(ink, 0.35), 1.0)
			var words: PackedStringArray = str(b.name).capitalize().split(" ")
			for i: int in words.size():
				draw_string(font, Vector2(x0 + 3, 14 + i * 12), words[i], HORIZONTAL_ALIGNMENT_LEFT, x1 - x0 - 4, 10, Color(ink, 0.85))
		draw_rect(Rect2(Vector2.ZERO, size), ink, false, 2.0)
		# Ashvale
		var village: Vector2 = _to_map(Vector2(16 * ts, 14 * ts))
		draw_rect(Rect2(village - Vector2(5, 4), Vector2(10, 8)), Color("#8a5a2b"))
		draw_string(font, village + Vector2(-20, 16), "Ashvale", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ink)
		# Bosses: red dot, crossed out once beaten
		for boss_id: String in world.boss_tiles:
			var t: Vector2i = world.boss_tiles[boss_id]
			var p: Vector2 = _to_map(Vector2(t) * ts)
			var beaten: bool = boss_id in world.defeated_bosses
			draw_circle(p, 6.0, Color("#9a3324") if not beaten else Color(0.55, 0.5, 0.45))
			draw_arc(p, 6.0, 0, TAU, 16, ink, 1.0)
			if beaten:
				draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), ink, 2.0)
				draw_line(p + Vector2(-7, 7), p + Vector2(7, -7), ink, 2.0)
			draw_string(font, p + Vector2(-24, -9), boss_id.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 48, 8, ink)
		# Discovered stations: little tents
		for id: String in world.discovered_stations:
			var st: Node2D = world.stations.get(id)
			if st == null:
				continue
			var p: Vector2 = _to_map(st.global_position)
			var col := Color("#d6a040") if id != highlight else Color("#fff0a0")
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 4), p + Vector2(0, -7), p + Vector2(6, 4)]), col)
			draw_polyline(PackedVector2Array([p + Vector2(-6, 4), p + Vector2(0, -7), p + Vector2(6, 4), p + Vector2(-6, 4)]), ink, 1.0)
			if id == highlight:
				draw_arc(p, 10.0, 0, TAU, 20, Color("#9a3324"), 2.0)
		# Orion
		var player := world.get_node_or_null("Player") as Node2D
		if player:
			var p: Vector2 = _to_map(player.global_position)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0)]), Color("#2f4f7a"))
			draw_polyline(PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0), p + Vector2(0, -6)]), Color.WHITE, 1.0)
