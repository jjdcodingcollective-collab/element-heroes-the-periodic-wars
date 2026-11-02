extends "res://scripts/ui/journal_menu.gd"

# Contents — the journal's hub page (SYSTEMS_UX_REVIEW.md §3.2). Esc with no
# menu open opens it (UIManager.menu_requested). Left page: the sections;
# right page: what the selected section holds, and its action. Opening a
# section opens that menu (UIManager closes Contents, one menu at a time).
#
# Save & Quit: Save only at a Field Station (a "field_station" node within its
# interact range), Suspend (SaveSystem.suspend_and_quit, when available) and
# Quit to Title.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const DEFAULT_STATION_RANGE: float = 40.0

const SECTIONS := [
	{ "id": "items", "title": "Items", "menu": "journal", "key": "E",
		"text": "Everything you carry: element samples, equipment, consumables and key items such as Boss Keys and their fragments." },
	{ "id": "crafting", "title": "Crafting", "menu": "crafting", "key": "R",
		"text": "The crafting grid. Combine element samples into compounds, then forge them into weapons and armour." },
	{ "id": "compendium", "title": "Compendium", "menu": "compendium", "key": "C",
		"text": "Your periodic table. Every element you discover is filled in with its facts." },
	{ "id": "bestiary", "title": "Bestiary", "menu": "bestiary", "key": "",
		"text": "The CHIMERA files: notes on every creature you have met, what it once was, and how many you have beaten. Includes the Prime Codex." },
	{ "id": "map", "title": "Map", "menu": "map", "key": "M",
		"text": "The six biomes, Field Stations, and marked Warden and boss sites." },
	{ "id": "options", "title": "Options", "menu": "options", "key": "",
		"text": "Music and sound volume, text speed, Keep Inventory, the controls, and exporting or importing your journal." },
	{ "id": "save", "title": "Save & Quit", "menu": "", "key": "",
		"text": "Save your journal at a Field Station, suspend the game to carry on later, or return to the title page." },
]
const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]

var _list: VBoxContainer
var _rows: Array[Button] = []
var _selected: int = 0
var _detail_title: Label
var _detail_text: Label
var _actions: VBoxContainer
var _status: Label
var save_button: Button
var suspend_button: Button
var quit_button: Button
var open_button: Button

func _ready() -> void:
	add_to_group("contents_hub")
	_setup_menu("contents")
	UIManager.menu_requested.connect(_on_menu_requested)

func _on_menu_requested() -> void:
	# Not over the death screen or when there is no player to pause.
	var p := _player()
	if p == null or ("is_dead" in p and p.is_dead):
		return
	UIManager.open("contents")

func _build_pages() -> void:
	_add_cover_and_pages()
	_heading(_left, "Contents")
	_list = VBoxContainer.new()
	_list.position = Vector2(26, 66)
	_list.size = Vector2(_page_w - 52, _page_h - 90)
	_list.add_theme_constant_override("separation", 6)
	_left.add_child(_list)
	for i: int in SECTIONS.size():
		var s: Dictionary = SECTIONS[i]
		var row := _row("%s.  %s" % [NUMERALS[i], s["title"]], "[%s]" % s["key"] if s["key"] != "" else "", _activate.bind(i))
		row.custom_minimum_size = Vector2(0, 40)
		_row_name(row).add_theme_font_size_override("font_size", 18)
		row.mouse_entered.connect(_select.bind(i))
		_list.add_child(row)
		_rows.append(row)

	_detail_title = _heading(_right, "", 18, 24)
	_detail_text = _text(_right, "", Vector2(30, 80), _page_w - 60, 15)
	_actions = VBoxContainer.new()
	_actions.position = Vector2(_page_w / 2.0 - 120, 230)
	_actions.size = Vector2(240, 160)
	_actions.add_theme_constant_override("separation", 10)
	_right.add_child(_actions)
	open_button = _action_button("Open  [Enter]", func() -> void: _activate(_selected))
	save_button = _action_button("Save", _on_save)
	suspend_button = _action_button("Suspend", _on_suspend)
	quit_button = _action_button("Quit to Title", _on_quit_to_title)
	_status = JS.label("", 13, JS.STAMP_RED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(20, _page_h - 62)
	_status.size = Vector2(_page_w - 40, 40)
	_right.add_child(_status)
	_footer_hints.text = "[↑↓] choose   [Enter] open   [Esc] close"

func _action_button(text: String, cb: Callable) -> Button:
	var b := JS.button(text, 16)
	b.custom_minimum_size = Vector2(240, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_actions.add_child(b)
	return b

func _on_opened() -> void:
	_status.text = ""
	var p := _player()
	var bag: Node = p.get_node_or_null("Bag") if p else null
	_footer_left.text = "◈  %d Ashmarks    ✎ %s played" % [bag.ashmarks if bag else 0,
		SaveSystem.format_play_time(int(SaveSystem.play_seconds))]
	for i: int in SECTIONS.size():
		var on := section_enabled(i)
		_rows[i].disabled = not on
		_row_name(_rows[i]).add_theme_color_override("font_color", JS.INK if on else JS.INK_SOFT.lightened(0.25))
	_select(_selected)

# Sections whose menu has not been built yet (e.g. the Map) are greyed out.
func section_enabled(i: int) -> bool:
	var menu: String = SECTIONS[i]["menu"]
	return menu == "" or UIManager.has_menu(menu)

func section_index(id: String) -> int:
	for i: int in SECTIONS.size():
		if SECTIONS[i]["id"] == id:
			return i
	return -1

func _select(i: int) -> void:
	_selected = clampi(i, 0, SECTIONS.size() - 1)
	for r: int in _rows.size():
		_mark_row(_rows[r], r == _selected)
	var s: Dictionary = SECTIONS[_selected]
	_detail_title.text = s["title"]
	var text: String = s["text"]
	if not section_enabled(_selected):
		text += "\n\nThis section of the journal is still blank."
	elif s["key"] != "":
		text += "\n\nShortcut: press %s during play." % s["key"]
	_detail_text.text = text
	var is_save: bool = s["id"] == "save"
	open_button.visible = not is_save and section_enabled(_selected)
	save_button.visible = is_save
	suspend_button.visible = is_save
	quit_button.visible = is_save
	if is_save:
		_refresh_save_buttons()
	else:
		_status.text = ""

func _refresh_save_buttons() -> void:
	var at_station := station_in_range()
	save_button.disabled = not at_station
	save_button.text = "Save" if at_station else "Save at a Field Station"
	suspend_button.disabled = not SaveSystem.has_method("suspend_and_quit")
	_status.add_theme_color_override("font_color", JS.STAMP_RED)
	_status.text = "" if at_station else "Find a Field Station to save. Suspend keeps your place until you return."

# Opens a section's menu, or for Save & Quit shows its buttons.
func _activate(i: int) -> void:
	_select(i)
	var s: Dictionary = SECTIONS[_selected]
	if s["menu"] == "" or not section_enabled(_selected):
		return
	UIManager.open(s["menu"])

func open_section(id: String) -> bool:
	var i := section_index(id)
	if i < 0:
		return false
	_activate(i)
	return UIManager.is_open(SECTIONS[i]["menu"]) if SECTIONS[i]["menu"] != "" else true

func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_down"):
		_select(_next_enabled(_selected, 1))
	elif event.is_action_pressed("ui_up"):
		_select(_next_enabled(_selected, -1))
	elif event.is_action_pressed("ui_accept"):
		if SECTIONS[_selected]["id"] == "save":
			if not save_button.disabled:
				_on_save()
		else:
			_activate(_selected)
	else:
		return
	get_viewport().set_input_as_handled()

func _next_enabled(from: int, step: int) -> int:
	var i := from
	for _n: int in SECTIONS.size():
		i = wrapi(i + step, 0, SECTIONS.size())
		if section_enabled(i):
			return i
	return from

# ── Save & Quit ───────────────────────────────────────────────────────────────

# True when the player stands within a Field Station's interact range.
func station_in_range() -> bool:
	var p := _player() as Node2D
	if p == null:
		return false
	for s: Node in get_tree().get_nodes_in_group("field_station"):
		if s is Node2D and (s as Node2D).global_position.distance_to(p.global_position) <= _station_range(s):
			return true
	return false

static func _station_range(station: Node) -> float:
	for prop: String in ["interact_radius", "interact_range"]:
		if prop in station:
			return float(station.get(prop))
	var script: Script = station.get_script()
	if script:
		var consts: Dictionary = script.get_script_constant_map()
		for c: String in ["INTERACT_RADIUS", "INTERACT_RANGE"]:
			if consts.has(c):
				return float(consts[c])
	return DEFAULT_STATION_RANGE

func _on_save() -> void:
	var p := _player()
	if p == null or not station_in_range():
		return
	var ok := SaveSystem.save_game(p)
	_status.text = "Journal saved." if ok else "Could not save!"
	_status.add_theme_color_override("font_color", JS.INK_GREEN if ok else JS.STAMP_RED)

func _on_suspend() -> void:
	if not SaveSystem.has_method("suspend_and_quit"):
		return
	var p := _player()
	UIManager.close_all()
	SaveSystem.call("suspend_and_quit", p)

func _on_quit_to_title() -> void:
	UIManager.close_all()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
