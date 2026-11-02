extends "res://scripts/ui/journal_menu.gd"

# OptionsMenu — autoload. The Options page of the journal (SYSTEMS_UX_REVIEW
# §3.2, §3.5) and the game's settings store. Being an autoload, the same menu
# opens from the title screen and from the Contents hub (UIManager "options").
#
# Settings (user://settings.cfg, loaded on startup):
#   music_volume, sfx_volume   0..1, applied live through AudioManager
#   text_speed                 "slow" / "normal" / "fast" (dialogue typing)
#   keep_inventory             default ON; when OFF, dying drops half your
#                              Ashmarks where you fell (recover by walking over them)
# Tests point `settings_path` at a private file (EH_SETTINGS_PATH, or
# settings.cfg inside EH_SAVE_DIR, does the same for whole runs).
#
# Right page: Controls reference, and Journal transfer (export / import a save
# as a file or a code; see scripts/data/save_transfer.gd).

signal settings_changed

const SaveTransfer := preload("res://scripts/data/save_transfer.gd")
const DEFAULT_PATH := "user://settings.cfg"
const TEXT_SPEEDS := { "slow": 20.0, "normal": 40.0, "fast": 80.0 }
const TEXT_SPEED_ORDER := ["slow", "normal", "fast"]
const RIGHT_TABS := ["Controls", "Journal transfer"]
const CONTROLS := [
	["Move", "WASD / arrow keys"], ["Attack", "Space / right mouse"], ["Dash", "Shift"],
	["Dig", "Left mouse"], ["Talk / use", "F"], ["Quick slots", "1 – 4"],
	["Items", "E"], ["Compendium", "C"], ["Crafting", "R"], ["Map", "M"],
	["Contents / close", "Esc"],
]

var settings_path: String = DEFAULT_PATH
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var text_speed: String = "normal"
var keep_inventory: bool = true

var music_slider: HSlider
var sfx_slider: HSlider
var keep_check: CheckButton
var _music_pct: Label
var _sfx_pct: Label
var _speed_buttons: Dictionary = {}   # speed -> Button
var _keep_note: Label
var _tab_buttons: Array[Button] = []
var _controls_box: Control
var _transfer_box: Control
var _right_tab: int = 0
var _syncing: bool = false

# Journal transfer widgets
var export_slot_pick: OptionButton
var import_slot_pick: OptionButton
var import_code: LineEdit
var export_code: LineEdit
var transfer_status: Label
var _import_file_btn: Button
var _confirm_import_slot: String = ""

func _ready() -> void:
	var env_path := OS.get_environment("EH_SETTINGS_PATH")
	var env_dir := OS.get_environment("EH_SAVE_DIR")
	if env_path != "":
		settings_path = env_path
	elif env_dir != "":
		settings_path = env_dir.path_join("settings.cfg")
	_setup_menu("options", 12)
	load_settings()

# ── Settings store ────────────────────────────────────────────────────────────

func reset_to_defaults() -> void:
	music_volume = 1.0
	sfx_volume = 1.0
	text_speed = "normal"
	keep_inventory = true
	apply_audio()
	_sync_widgets()
	settings_changed.emit()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(settings_path)
	if err == OK:
		music_volume = clampf(float(cfg.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)
		var speed := str(cfg.get_value("text", "speed", "normal"))
		text_speed = speed if TEXT_SPEEDS.has(speed) else "normal"
		keep_inventory = bool(cfg.get_value("gameplay", "keep_inventory", true))
	apply_audio()
	_sync_widgets()
	settings_changed.emit()

func save_settings() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("text", "speed", text_speed)
	cfg.set_value("gameplay", "keep_inventory", keep_inventory)
	var dir := settings_path.get_base_dir()
	if dir != "" and not dir.ends_with(":/"):
		DirAccess.make_dir_recursive_absolute(dir)
	return cfg.save(settings_path) == OK

func apply_audio() -> void:
	AudioManager.set_music_volume(music_volume)
	AudioManager.set_sfx_volume(sfx_volume)
	# linear_to_db(0) is -inf; mute the bus outright at zero.
	AudioManager.mute_music(music_volume <= 0.001)
	AudioManager.mute_sfx(sfx_volume <= 0.001)

func set_music_volume(linear: float, persist: bool = true) -> void:
	music_volume = clampf(linear, 0.0, 1.0)
	apply_audio()
	_after_change(persist)

func set_sfx_volume(linear: float, persist: bool = true) -> void:
	sfx_volume = clampf(linear, 0.0, 1.0)
	apply_audio()
	_after_change(persist)

func set_text_speed(speed: String, persist: bool = true) -> void:
	if TEXT_SPEEDS.has(speed):
		text_speed = speed
		_after_change(persist)

func set_keep_inventory(on: bool, persist: bool = true) -> void:
	keep_inventory = on
	_after_change(persist)

# Typing speed for dialogue_ui.
func chars_per_second() -> float:
	return float(TEXT_SPEEDS.get(text_speed, 40.0))

func _after_change(persist: bool) -> void:
	_sync_widgets()
	if persist:
		save_settings()
	settings_changed.emit()

# ── Menu ──────────────────────────────────────────────────────────────────────

# Opens Options at the Journal transfer tab (title screen Load page).
func show_transfer() -> void:
	UIManager.open("options")
	_show_right_tab(1)

func _on_opened() -> void:
	_sync_widgets()
	_refresh_transfer()

func _on_closed() -> void:
	save_settings()   # slider drags only apply live; keep them on close

func _build_pages() -> void:
	_add_cover_and_pages()
	_footer_hints.text = "Changes apply at once   [Esc] close"
	_footer_left.text = "✎  Options"

	# Left page: settings.
	_heading(_left, "Options")
	var y := 70.0
	music_slider = _slider_row("Music volume", y, func(v: float) -> void: set_music_volume(v / 100.0, false))
	_music_pct = music_slider.get_meta("readout")
	y += 62
	sfx_slider = _slider_row("Sound effects", y, func(v: float) -> void:
		set_sfx_volume(v / 100.0, false)
		AudioManager.on_ui_open())   # a little preview of the new level
	_sfx_pct = sfx_slider.get_meta("readout")
	y += 70
	_left.add_child(_label_at("Text speed", Vector2(26, y), 15))
	var hb := HBoxContainer.new()
	hb.position = Vector2(26, y + 24)
	hb.add_theme_constant_override("separation", 8)
	_left.add_child(hb)
	for speed: String in TEXT_SPEED_ORDER:
		var b := JS.button(speed.capitalize(), 14)
		b.custom_minimum_size = Vector2(110, 30)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(set_text_speed.bind(speed))
		hb.add_child(b)
		_speed_buttons[speed] = b
	y += 80
	keep_check = CheckButton.new()
	keep_check.text = "Keep Inventory on death"
	keep_check.add_theme_font_size_override("font_size", 15)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		keep_check.add_theme_color_override(c, JS.INK)
	keep_check.focus_mode = Control.FOCUS_NONE
	keep_check.position = Vector2(20, y)
	keep_check.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			set_keep_inventory(on))
	_left.add_child(keep_check)
	_keep_note = _text(_left, "", Vector2(26, y + 36), _page_w - 52, 12, JS.INK_SOFT)

	# Right page: Controls / Journal transfer.
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(20, 14)
	tabs.add_theme_constant_override("separation", 8)
	_right.add_child(tabs)
	for i: int in RIGHT_TABS.size():
		var b := JS.button(RIGHT_TABS[i], 14)
		b.custom_minimum_size = Vector2(170, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_show_right_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	_right.add_child(JS.ornament(Vector2(_page_w / 2.0, 56)))
	_controls_box = Control.new()
	_controls_box.position = Vector2(0, 66)
	_right.add_child(_controls_box)
	var cy := 0.0
	for pair: Array in CONTROLS:
		_controls_box.add_child(_label_at(pair[0], Vector2(36, cy), 15))
		var k := _label_at(pair[1], Vector2(_page_w / 2.0, cy), 15)
		k.add_theme_color_override("font_color", JS.INK_GREEN)
		_controls_box.add_child(k)
		cy += 30
	_transfer_box = Control.new()
	_transfer_box.position = Vector2(0, 66)
	_right.add_child(_transfer_box)
	_build_transfer()
	_show_right_tab(0)

func _label_at(text: String, pos: Vector2, size: int) -> Label:
	var l := JS.label(text, size, JS.INK)
	l.position = pos
	return l

# Label, slider (0–100) and a percentage readout (slider meta "readout").
func _slider_row(title: String, y: float, on_change: Callable) -> HSlider:
	_left.add_child(_label_at(title, Vector2(26, y), 15))
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.position = Vector2(26, y + 26)
	s.size = Vector2(_page_w - 120, 20)
	s.focus_mode = Control.FOCUS_NONE
	s.add_theme_stylebox_override("slider", JS.box(JS.PAGE_EDGE, JS.INK_SOFT, 1, 3))
	s.add_theme_stylebox_override("grabber_area", JS.box(JS.LEATHER, JS.LEATHER_DARK, 1, 3))
	s.add_theme_stylebox_override("grabber_area_highlight", JS.box(JS.LEATHER.lightened(0.15), JS.LEATHER_DARK, 1, 3))
	s.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			on_change.call(v))
	s.drag_ended.connect(func(_changed: bool) -> void: save_settings())
	_left.add_child(s)
	var pct := _label_at("", Vector2(_page_w - 84, y + 22), 15)
	_left.add_child(pct)
	s.set_meta("readout", pct)
	return s

func _show_right_tab(i: int) -> void:
	_right_tab = i
	_controls_box.visible = i == 0
	_transfer_box.visible = i == 1
	for t: int in _tab_buttons.size():
		var on: bool = t == i
		_tab_buttons[t].add_theme_stylebox_override("normal", JS.box(JS.LEATHER if on else JS.LEATHER.darkened(0.3), JS.BRASS if on else JS.LEATHER_DARK, 2, 4))
	if i == 1:
		_refresh_transfer()

func _sync_widgets() -> void:
	if music_slider == null:
		return
	_syncing = true
	music_slider.value = round(music_volume * 100.0)
	sfx_slider.value = round(sfx_volume * 100.0)
	_music_pct.text = "%d%%" % int(round(music_volume * 100.0))
	_sfx_pct.text = "%d%%" % int(round(sfx_volume * 100.0))
	for speed: String in _speed_buttons:
		var b: Button = _speed_buttons[speed]
		b.button_pressed = speed == text_speed
		b.add_theme_stylebox_override("normal", JS.box(JS.LEATHER if speed == text_speed else JS.LEATHER.darkened(0.3),
			JS.BRASS if speed == text_speed else JS.LEATHER_DARK, 2, 4))
		b.add_theme_stylebox_override("pressed", b.get_theme_stylebox("normal"))
	keep_check.button_pressed = keep_inventory
	_keep_note.text = ("On: when you fall you wake in Ashvale with everything you carried." if keep_inventory else
		"Off: when you fall you drop half your Ashmarks where you fell. Walk back to the spot to pick them up.")
	_syncing = false

# ── Journal transfer ──────────────────────────────────────────────────────────

func _build_transfer() -> void:
	var w := _page_w - 52
	var b := _transfer_box
	b.add_child(_label_at("Export a journal", Vector2(26, 0), 16))
	export_slot_pick = _slot_picker(Vector2(26, 26), Vector2(190, 30))
	b.add_child(export_slot_pick)
	var ex := JS.button("Export", 14)
	ex.position = Vector2(226, 26)
	ex.size = Vector2(w - 200, 30)
	ex.focus_mode = Control.FOCUS_NONE
	ex.pressed.connect(_on_export)
	b.add_child(ex)
	export_code = _line_edit(Vector2(26, 62), Vector2(w, 28), "The journal code appears here after export.")
	export_code.editable = false
	export_code.focus_entered.connect(func() -> void: export_code.select_all())
	b.add_child(export_code)

	b.add_child(_label_at("Import a journal", Vector2(26, 112), 16))
	import_code = _line_edit(Vector2(26, 138), Vector2(w, 28), "Paste a journal code (or journal file text)")
	b.add_child(import_code)
	import_slot_pick = _slot_picker(Vector2(26, 174), Vector2(190, 30))
	import_slot_pick.item_selected.connect(func(_i: int) -> void: _confirm_import_slot = "")
	b.add_child(import_slot_pick)
	var im := JS.button("Import", 14)
	im.position = Vector2(226, 174)
	im.size = Vector2(w - 200, 30)
	im.focus_mode = Control.FOCUS_NONE
	im.pressed.connect(_on_import_code)
	b.add_child(im)
	_import_file_btn = JS.button("Import newest file in user://imports/", 13)
	_import_file_btn.position = Vector2(26, 212)
	_import_file_btn.size = Vector2(w, 28)
	_import_file_btn.focus_mode = Control.FOCUS_NONE
	_import_file_btn.pressed.connect(_on_import_file)
	_import_file_btn.visible = not OS.has_feature("web")
	b.add_child(_import_file_btn)
	transfer_status = JS.label("", 13, JS.INK_SOFT)
	transfer_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transfer_status.position = Vector2(26, 250)
	transfer_status.size = Vector2(w, 60)
	b.add_child(transfer_status)

func _slot_picker(pos: Vector2, size: Vector2) -> OptionButton:
	var o := OptionButton.new()
	o.position = pos
	o.size = size
	o.focus_mode = Control.FOCUS_NONE
	o.add_theme_font_size_override("font_size", 14)
	o.add_theme_stylebox_override("normal", JS.box(JS.PAGE_DARK, JS.PAGE_EDGE, 2, 4))
	o.add_theme_stylebox_override("hover", JS.box(JS.PAGE_DARK.darkened(0.05), JS.LEATHER, 2, 4))
	o.add_theme_stylebox_override("pressed", JS.box(JS.PAGE_DARK.darkened(0.08), JS.LEATHER, 2, 4))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		o.add_theme_color_override(c, JS.INK)
	return o

func _line_edit(pos: Vector2, size: Vector2, hint: String) -> LineEdit:
	var e := LineEdit.new()
	e.position = pos
	e.size = size
	e.placeholder_text = hint
	e.add_theme_font_size_override("font_size", 13)
	e.add_theme_stylebox_override("normal", JS.box(JS.PAGE_DARK, JS.PAGE_EDGE, 2, 4))
	e.add_theme_stylebox_override("focus", JS.box(JS.PAGE_DARK, JS.BRASS, 2, 4))
	e.add_theme_stylebox_override("read_only", JS.box(JS.PAGE.darkened(0.03), JS.PAGE_EDGE, 1, 4))
	e.add_theme_color_override("font_color", JS.INK)
	e.add_theme_color_override("font_uneditable_color", JS.INK_SOFT)
	e.add_theme_color_override("font_placeholder_color", Color(JS.INK_SOFT, 0.7))
	return e

static func slot_label(slot: String) -> String:
	return { "autosave": "Autosave", "suspend": "Suspended game" }.get(slot, "Journal %s" % slot.trim_prefix("slot"))

func _refresh_transfer() -> void:
	if export_slot_pick == null:
		return
	export_slot_pick.clear()
	for slot: String in SaveSystem.ALL_SLOTS:
		if SaveSystem.slot_exists(slot):
			export_slot_pick.add_item(slot_label(slot))
			export_slot_pick.set_item_metadata(export_slot_pick.item_count - 1, slot)
	if export_slot_pick.item_count == 0:
		export_slot_pick.add_item("(no journals yet)")
		export_slot_pick.set_item_metadata(0, "")
	var keep := import_slot_pick.selected
	import_slot_pick.clear()
	for slot: String in SaveSystem.MANUAL_SLOTS:
		import_slot_pick.add_item(slot_label(slot) + ("  (in use)" if SaveSystem.slot_exists(slot) else "  (empty)"))
		import_slot_pick.set_item_metadata(import_slot_pick.item_count - 1, slot)
	import_slot_pick.select(keep if keep >= 0 and keep < import_slot_pick.item_count else _first_empty_manual())
	_confirm_import_slot = ""

func _first_empty_manual() -> int:
	for i: int in SaveSystem.MANUAL_SLOTS.size():
		if not SaveSystem.slot_exists(SaveSystem.MANUAL_SLOTS[i]):
			return i
	return 0

func _set_transfer_status(text: String, ok: bool) -> void:
	transfer_status.text = text
	transfer_status.add_theme_color_override("font_color", JS.INK_GREEN if ok else JS.STAMP_RED)

func _on_export() -> void:
	var slot := str(export_slot_pick.get_selected_metadata()) if export_slot_pick.selected >= 0 else ""
	if slot == "" or slot == "<null>":
		_set_transfer_status("There is no journal to export yet.", false)
		return
	var r := SaveTransfer.export_slot(slot)
	if not r["ok"]:
		_set_transfer_status(r["error"], false)
		return
	export_code.text = r["code"]
	if OS.has_feature("web"):
		_set_transfer_status("Downloaded %s. The code above works too: copy it somewhere safe." % r["path"], true)
	else:
		_set_transfer_status("Saved to %s and copied the code to the clipboard." % ProjectSettings.globalize_path(r["path"]), true)

func _on_import_code() -> void:
	_import_text(import_code.text)

func _on_import_file() -> void:
	var path := SaveTransfer.newest_import_file()
	if path == "":
		DirAccess.make_dir_recursive_absolute(SaveTransfer.imports_dir)
		_set_transfer_status("Put a journal .json file in %s first." % ProjectSettings.globalize_path(SaveTransfer.imports_dir), false)
		return
	_import_text(SaveTransfer.read_text_file(path))

# Imports into the chosen slot; a slot that holds a journal needs a second press.
func _import_text(text: String) -> bool:
	var slot := str(import_slot_pick.get_selected_metadata()) if import_slot_pick.selected >= 0 else "slot1"
	var check := SaveTransfer.decode(text)
	if not check["ok"]:
		_set_transfer_status(check["error"], false)
		return false
	if SaveSystem.slot_exists(slot) and _confirm_import_slot != slot:
		_confirm_import_slot = slot
		_set_transfer_status("%s already holds a journal. Press Import again to replace it." % slot_label(slot), false)
		return false
	var r := SaveTransfer.import_into(slot, text)
	if r["ok"]:
		_set_transfer_status("Imported into %s." % slot_label(slot), true)
		import_code.text = ""
		var keep_status := transfer_status.text
		_refresh_transfer()
		transfer_status.text = keep_status
	else:
		_set_transfer_status(r["error"], false)
	return r["ok"]
