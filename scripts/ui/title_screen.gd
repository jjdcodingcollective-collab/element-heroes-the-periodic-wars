extends Control

# Title screen — the game's main scene (SYSTEMS_UX_REVIEW §3.1).
# Left page: Continue · New Game · Load · Options · Quit.
# Right page: save-slot cards (3 manual slots, plus Autosave and Suspend when
# they exist), used for both New Game (choose a slot) and Load.

const JS := preload("res://scripts/ui/journal_style.gd")
const WORLD_SCENE := "res://scenes/world/world.tscn"
const BOOK_SIZE := Vector2(900, 540)

enum Mode { NONE, NEW, LOAD }

var _mode: int = Mode.NONE
var _right: Panel
var _cards: VBoxContainer
var _right_title: Label
var _continue_btn: Button
var _load_btn: Button
var _options_btn: Button
var _confirm_slot: String = ""   # New Game over an existing save needs a second click
var _status: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	_build()
	_refresh_buttons()
	if SaveSystem.save_exists():
		_continue_btn.grab_focus()
	else:
		_set_mode(Mode.NEW)

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1d140d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var book := Control.new()
	book.set_anchors_preset(Control.PRESET_CENTER)
	book.size = BOOK_SIZE
	book.position = -BOOK_SIZE / 2.0
	add_child(book)
	JS.make_book(book, BOOK_SIZE)

	var page_w: float = (BOOK_SIZE.x - 64.0) / 2.0
	var page_h: float = BOOK_SIZE.y - 76.0
	var left := JS.make_page(book, Vector2(28, 24), Vector2(page_w, page_h), true)
	_right = JS.make_page(book, Vector2(36 + page_w, 24), Vector2(page_w, page_h), false)

	var title := JS.label("Element Heroes", 30, JS.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(page_w, 40)
	left.add_child(title)
	var sub := JS.label("The Periodic Wars", 18, JS.INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 72)
	sub.size = Vector2(page_w, 24)
	left.add_child(sub)
	left.add_child(JS.ornament(Vector2(page_w / 2.0, 108)))

	var menu := VBoxContainer.new()
	menu.position = Vector2(page_w / 2.0 - 110, 140)
	menu.size = Vector2(220, 260)
	menu.add_theme_constant_override("separation", 12)
	left.add_child(menu)
	_continue_btn = _menu_button(menu, "Continue", _on_continue)
	_menu_button(menu, "New Game", _set_mode.bind(Mode.NEW))
	_load_btn = _menu_button(menu, "Load", _set_mode.bind(Mode.LOAD))
	_options_btn = _menu_button(menu, "Options", _on_options)
	if OS.get_name() != "Web":
		_menu_button(menu, "Quit", func() -> void: get_tree().quit())

	_status = JS.label("", 13, JS.STAMP_RED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(0, page_h - 40)
	_status.size = Vector2(page_w, 20)
	left.add_child(_status)

	_right_title = JS.label("", 20, JS.INK)
	_right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_title.position = Vector2(0, 12)
	_right_title.size = Vector2(page_w, 30)
	_right.add_child(_right_title)
	_right.add_child(JS.ornament(Vector2(page_w / 2.0, 48)))
	_cards = VBoxContainer.new()
	_cards.position = Vector2(20, 62)
	_cards.size = Vector2(page_w - 40, page_h - 80)
	_cards.add_theme_constant_override("separation", 8)
	_right.add_child(_cards)

	var footer := JS.label("Saves: field stations, autosave and Suspend keep your journal safe.", 12, JS.STITCH)
	footer.position = Vector2(40, BOOK_SIZE.y - 42)
	book.add_child(footer)

func _menu_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := JS.button(text, 18)
	b.custom_minimum_size = Vector2(220, 40)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _refresh_buttons() -> void:
	var any := SaveSystem.save_exists()
	_continue_btn.disabled = not any
	_load_btn.disabled = not any
	_options_btn.visible = UIManager.has_menu("options")

# ── Slot cards ────────────────────────────────────────────────────────────────

func _set_mode(mode: int) -> void:
	_mode = mode
	_confirm_slot = ""
	_status.text = ""
	for c: Node in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	_right_title.text = { Mode.NEW: "New Game: choose a slot", Mode.LOAD: "Load a journal" }.get(mode, "")
	if mode == Mode.NONE:
		return
	var slots: Array = SaveSystem.MANUAL_SLOTS.duplicate()
	if mode == Mode.LOAD:
		for extra: String in ["autosave", "suspend"]:
			if SaveSystem.slot_exists(extra):
				slots.append(extra)
	for slot: String in slots:
		_cards.add_child(_slot_card(slot))

func _slot_card(slot: String) -> Button:
	var info := SaveSystem.slot_summary(slot)
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 74)
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_theme_stylebox_override("normal", JS.box(JS.PAGE_DARK, JS.PAGE_EDGE, 2, 6))
	card.add_theme_stylebox_override("hover", JS.box(JS.PAGE_DARK.darkened(0.06), JS.LEATHER, 2, 6))
	card.add_theme_stylebox_override("focus", JS.box(JS.PAGE_DARK.darkened(0.06), JS.BRASS, 2, 6))
	card.add_theme_color_override("font_color", JS.INK)
	card.add_theme_color_override("font_hover_color", JS.INK)
	card.add_theme_color_override("font_focus_color", JS.INK)
	card.add_theme_stylebox_override("disabled", JS.box(JS.PAGE.darkened(0.03), JS.PAGE_EDGE, 1, 6))
	card.add_theme_color_override("font_disabled_color", JS.INK_SOFT)
	card.add_theme_font_size_override("font_size", 13)
	card.clip_text = true
	card.custom_minimum_size.x = _cards.size.x
	var heading: String = { "autosave": "Autosave", "suspend": "Suspended game" }.get(slot, "Journal %s" % slot.trim_prefix("slot"))
	if info.is_empty():
		card.text = "  %s\n  (empty)" % heading
		card.disabled = _mode == Mode.LOAD
	else:
		var biome: String = str(info["biome"]).replace("_", " ").capitalize()
		card.text = "  %s  ·  %s\n  %s played · %d Ashmarks · Codex %d/18\n  %s" % [
			heading, biome if biome != "" else "Ashvale", SaveSystem.format_play_time(int(info["play_seconds"])),
			int(info["ashmarks"]), int(info["codex"]), str(info["timestamp"]).replace("T", " ").left(16)]
	card.pressed.connect(_on_slot_chosen.bind(slot))
	return card

func _on_slot_chosen(slot: String) -> void:
	if _mode == Mode.LOAD:
		_start_load(slot)
	elif _mode == Mode.NEW:
		if SaveSystem.slot_exists(slot) and _confirm_slot != slot:
			_confirm_slot = slot
			_status.text = "That journal has a save. Click it again to start over."
			return
		_start_new(slot)

# ── Actions ───────────────────────────────────────────────────────────────────

func _on_continue() -> void:
	var slot := SaveSystem.most_recent_slot()
	if slot != "":
		_start_load(slot)

func _on_options() -> void:
	UIManager.open("options")

func _start_new(slot: String) -> void:
	SaveSystem.begin_new_game(slot)
	get_tree().change_scene_to_file(WORLD_SCENE)

func _start_load(slot: String) -> void:
	if SaveSystem.begin_load(slot):
		get_tree().change_scene_to_file(WORLD_SCENE)
	else:
		_status.text = "That save could not be read."
