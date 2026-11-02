extends CanvasLayer

# Field Station menu (SYSTEMS_UX_REVIEW.md §3.1): a small journal page opened
# by pressing F at a station. Save · Rest · Travel · Leave.
# UIManager menu "station": one menu at a time, pauses the game while open.

const JS := preload("res://scripts/ui/journal_style.gd")
const BOOK_SIZE := Vector2(440, 400)

var _dim: ColorRect
var _book: Control
var _name_label: Label
var _status: Label
var _save_btn: Button
var _rest_btn: Button
var _travel_btn: Button
var _leave_btn: Button
var _station: Node = null

func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused
	add_to_group("station_menu")
	_build()
	_apply_visibility(false)
	UIManager.register("station", self)

func is_open() -> bool:
	return _book.visible

func current_station() -> Node:
	return _station if is_instance_valid(_station) else null

# Called by field_station.gd when the player presses F beside it.
func open_for(station: Node) -> void:
	_station = station
	UIManager.open("station")

# Called by UIManager.
func _menu_set_open(open: bool) -> void:
	_apply_visibility(open)
	if open:
		AudioManager.on_ui_open()
		_refresh()
		_save_btn.grab_focus()
	else:
		AudioManager.on_ui_close()

func _apply_visibility(open: bool) -> void:
	_dim.visible = open
	_book.visible = open

# ── Actions ───────────────────────────────────────────────────────────────────

func do_save() -> bool:
	var player := _player()
	if player == null or _blocked():
		return false
	var ok: bool = SaveSystem.save_game(player)
	_status.text = ("Journal saved to %s." % _slot_name(SaveSystem.active_slot)) if ok else "The ink smudged: could not save!"
	return ok

func do_rest() -> bool:
	var player := _player()
	if player == null or _blocked():
		return false
	if player.has_method("clear_debuffs"):
		player.clear_debuffs()
	if player.has_method("get_max_health"):
		player.heal(float(player.get_max_health()))
	_status.text = "You brew some tea and rest. Fully healed."
	return true

func do_travel() -> void:
	var map := UIManager.get_menu("map")
	if map == null or current_station() == null or _blocked():
		return
	map.open_travel(_station.station_id)

func _blocked() -> bool:
	var world := _world()
	if world and world.has_method("is_boss_fight_active") and world.is_boss_fight_active():
		_status.text = "Not now: a boss is on the prowl!"
		return true
	return false

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _world() -> Node:
	var st := current_station()
	return st.get_parent() if st else get_parent()

static func _slot_name(slot: String) -> String:
	return "Slot %s" % slot.trim_prefix("slot") if slot.begins_with("slot") else slot.capitalize()

func _refresh() -> void:
	var st := current_station()
	_name_label.text = st.display_name if st else "Field Station"
	_status.text = "Saves go to %s." % _slot_name(SaveSystem.active_slot)
	var world := _world()
	var others: int = 0
	if world and "discovered_stations" in world:
		others = world.discovered_stations.size() - 1
	_travel_btn.disabled = others <= 0
	_travel_btn.tooltip_text = "" if others > 0 else "Discover another station first."

# ── Building ──────────────────────────────────────────────────────────────────

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_book = Control.new()
	_book.set_anchors_preset(Control.PRESET_CENTER)
	_book.position = -BOOK_SIZE / 2.0
	_book.size = BOOK_SIZE
	add_child(_book)
	JS.make_book(_book, BOOK_SIZE)
	var page := JS.make_page(_book, Vector2(22, 20), BOOK_SIZE - Vector2(44, 40), false)

	var col := VBoxContainer.new()
	col.position = Vector2(30, 18)
	col.size = Vector2(page.size.x - 60, page.size.y - 30)
	col.add_theme_constant_override("separation", 8)
	page.add_child(col)

	var title := JS.label("Field Station", 24, JS.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_name_label = JS.label("", 14, JS.INK_SOFT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_name_label)
	var orn_holder := Control.new()
	orn_holder.custom_minimum_size = Vector2(0, 12)
	col.add_child(orn_holder)
	orn_holder.add_child(JS.ornament(Vector2(col.size.x / 2.0, 6)))

	_save_btn = _action("Save journal", do_save, col)
	_rest_btn = _action("Rest", do_rest, col)
	_travel_btn = _action("Travel", do_travel, col)
	_leave_btn = _action("Leave", func() -> void: UIManager.close("station"), col)

	_status = JS.label("", 12, JS.INK_GREEN)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(col.size.x, 36)
	col.add_child(_status)

func _action(text: String, cb: Callable, parent: Control) -> Button:
	var b := JS.button(text, 16)
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(func() -> void: cb.call())
	parent.add_child(b)
	return b
