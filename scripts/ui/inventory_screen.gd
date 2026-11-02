extends CanvasLayer

# Inventory — Orion's leatherbound field journal (E). D-018.
#
# A two-page spread: the left page lists items vertically (icon, name, count),
# the right page shows the selected item large with its notes. Ribbon bookmarks
# down the left edge switch between four tabs:
#   Elements · Equipment · Consumables · Key Items
# Counts: stackable items show ×N (cap 99); Key Fragments show their set
# progress (1/3, 2/3); Boss Keys show a star. Ashmarks sit on the cover.
# The game pauses while the journal is open.
#
# Item icons: assets/sprites/items/<id>.png (tools/generate_item_icons.py).

const TAB_NAMES := ["Elements", "Equipment", "Consumables", "Key Items"]
const RIBBON_COLOURS := [Color("#7a2e2a"), Color("#3f6b3a"), Color("#2f4f7a"), Color("#a8822e")]
const BOSS_ORDER := ["peroxis", "chalcor", "aurium", "azrael", "atacama", "uranox"]
const ICON_DIR := "res://assets/sprites/items/"
const JS := preload("res://scripts/ui/journal_style.gd")

# Palette: tooled leather, brass, parchment and ink.
const LEATHER      := Color("#5b3520")
const LEATHER_DARK := Color("#2e1a0e")
const STITCH       := Color("#c9a26b")
const BRASS        := Color("#d6a040")
const PAGE         := Color("#efe3c6")
const PAGE_EDGE    := Color("#c9b58c")
const INK          := Color("#3b2a1a")
const INK_SOFT     := Color("#7a6248")
const STAMP_RED    := Color("#9a3324")

const BOOK_SIZE := Vector2(900, 540)

var _dim: ColorRect
var _book: Control
var _ribbons: Array[Button] = []
var _list: VBoxContainer
var _page_title: Label
var _ashmarks_label: Label
var _detail_icon: TextureRect
var _detail_tile: Label          # element tile shown instead of an icon
var _detail_name: Label
var _detail_kind: Label
var _detail_text: Label
var _detail_stat: Label
var _detail_stamp: Label
var _use_button: Button

var _tab: int = 0
var _entries: Array = []         # [{id, key, name, count_text, icon, kind, type, text, stat, stamp, usable, hotbar}]
var _selected: int = 0
var _player: Node = null

# Sorting (S or click): per tab, cycles Recent / Name / Type.
const SORT_NAMES := ["Recent", "Name", "Type"]
var _sort_mode: Dictionary = { "Elements": 0, "Equipment": 2, "Consumables": 0, "Key Items": 2 }
var _sort_button: Button
# "New" badges: keys that were unseen when this tab was opened. They keep their
# mark while the tab stays open; the Bag already counts them as seen.
var _shown_new: Dictionary = {}
var _ribbon_dots: Array[Control] = []
var _hotbar_row: Control
var _hotbar_buttons: Array[Button] = []

func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused
	add_to_group("inventory_screen")
	_build()
	_apply_visibility(false)
	UIManager.register("journal", self)

# ── Open / close (via UIManager: one menu at a time, pauses the game) ─────────

func is_open() -> bool:
	return _book.visible

func toggle() -> void:
	UIManager.toggle("journal")

func show_tab(tab_name: String) -> void:
	var tab: int = maxi(TAB_NAMES.find(tab_name), 0)
	if tab != _tab:
		_shown_new.clear()
	_tab = tab
	_selected = 0
	refresh()

# Called by UIManager.
func _menu_set_open(open: bool) -> void:
	_shown_new.clear()
	_apply_visibility(open)
	if open:
		AudioManager.on_ui_open()
		refresh()
	else:
		AudioManager.on_ui_close()

func _apply_visibility(open: bool) -> void:
	_book.visible = open
	_dim.visible = open   # hidden overlays must never block clicks (quiz bug, D-015)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_down"):
		_select(_selected + 1)
	elif event.is_action_pressed("ui_up"):
		_select(_selected - 1)
	elif event.is_action_pressed("ui_accept"):
		_use_selected()
	elif event is InputEventKey and event.pressed and event.shift_pressed and event.keycode >= KEY_1 and event.keycode <= KEY_4:
		assign_selected_to_hotbar(event.keycode - KEY_1)
	elif event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_4:
		show_tab(TAB_NAMES[event.keycode - KEY_1])
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S:
		cycle_sort()
	else:
		return
	get_viewport().set_input_as_handled()

# ── Building the book ─────────────────────────────────────────────────────────

func _box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s

func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_book = Control.new()
	_book.set_anchors_preset(Control.PRESET_CENTER)
	_book.size = BOOK_SIZE
	_book.position = -BOOK_SIZE / 2.0
	add_child(_book)

	# Ribbon bookmarks, tucked behind the left edge of the cover.
	for i: int in TAB_NAMES.size():
		var r := Button.new()
		r.text = TAB_NAMES[i]
		r.alignment = HORIZONTAL_ALIGNMENT_LEFT
		r.add_theme_font_size_override("font_size", 13)
		r.add_theme_color_override("font_color", Color("#f4e8cc"))
		r.add_theme_color_override("font_hover_color", Color.WHITE)
		r.focus_mode = Control.FOCUS_NONE
		r.size = Vector2(118, 34)
		r.position = Vector2(-96, 70 + i * 46)
		r.pressed.connect(show_tab.bind(TAB_NAMES[i]))
		_book.add_child(r)
		_ribbons.append(r)
		# Brass dot at the ribbon's tip: this tab holds unseen items.
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", _box(BRASS, LEATHER_DARK, 2, 6))
		dot.size = Vector2(12, 12)
		dot.position = Vector2(-16, 11)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		r.add_child(dot)
		_ribbon_dots.append(dot)

	# Leather cover with stitching and brass corners (drawn by JS.CoverDecor).
	var cover := Panel.new()
	cover.size = BOOK_SIZE
	var leather := _box(LEATHER, LEATHER_DARK, 4, 16)
	leather.shadow_color = Color(0, 0, 0, 0.5)
	leather.shadow_size = 12
	cover.add_theme_stylebox_override("panel", leather)
	_book.add_child(cover)
	var decor := JS.CoverDecor.new()
	decor.size = BOOK_SIZE
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(decor)

	# Pages.
	var page_w: float = (BOOK_SIZE.x - 64.0) / 2.0
	var page_h: float = BOOK_SIZE.y - 76.0
	var left := _make_page(Vector2(28, 24), Vector2(page_w, page_h), true)
	var right := _make_page(Vector2(36 + page_w, 24), Vector2(page_w, page_h), false)

	# Left page: title and the vertical item list.
	_page_title = _label("", 20, INK)
	_page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_title.position = Vector2(0, 12)
	_page_title.size = Vector2(page_w, 30)
	left.add_child(_page_title)
	left.add_child(_ornament(Vector2(page_w / 2.0, 48)))
	_sort_button = Button.new()
	_sort_button.flat = true
	_sort_button.focus_mode = Control.FOCUS_NONE
	_sort_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sort_button.add_theme_font_size_override("font_size", 12)
	_sort_button.add_theme_color_override("font_color", INK_SOFT)
	_sort_button.add_theme_color_override("font_hover_color", INK)
	_sort_button.add_theme_color_override("font_pressed_color", INK)
	_sort_button.position = Vector2(page_w - 170, 56)
	_sort_button.size = Vector2(152, 20)
	_sort_button.pressed.connect(cycle_sort)
	left.add_child(_sort_button)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, 78)
	scroll.size = Vector2(page_w - 36, page_h - 94)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	# Right page: large icon, name, notes, stamp.
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _box(Color("#e4d4ae"), PAGE_EDGE, 3, 6))
	frame.size = Vector2(120, 120)
	frame.position = Vector2((page_w - 120) / 2.0, 22)
	right.add_child(frame)
	_detail_icon = TextureRect.new()
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.position = Vector2(12, 12)
	_detail_icon.size = Vector2(96, 96)
	frame.add_child(_detail_icon)
	_detail_tile = _label("", 40, Color.WHITE)
	_detail_tile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_tile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_tile.position = Vector2(12, 12)
	_detail_tile.size = Vector2(96, 96)
	frame.add_child(_detail_tile)

	_detail_name = _label("", 22, INK)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.position = Vector2(0, 150)
	_detail_name.size = Vector2(page_w, 30)
	right.add_child(_detail_name)
	_detail_kind = _label("", 13, INK_SOFT)
	_detail_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_kind.position = Vector2(0, 180)
	_detail_kind.size = Vector2(page_w, 20)
	right.add_child(_detail_kind)
	right.add_child(_ornament(Vector2(page_w / 2.0, 210)))
	_detail_text = _label("", 15, INK)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.position = Vector2(26, 224)
	_detail_text.size = Vector2(page_w - 52, 140)
	right.add_child(_detail_text)
	_detail_stat = _label("", 15, Color("#4a5d2a"))
	_detail_stat.position = Vector2(26, 368)
	_detail_stat.size = Vector2(page_w - 52, 24)
	right.add_child(_detail_stat)
	_detail_stamp = _label("", 13, STAMP_RED)
	_detail_stamp.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), STAMP_RED, 2, 3))
	_detail_stamp.position = Vector2(26, page_h - 46)
	right.add_child(_detail_stamp)
	_use_button = Button.new()
	_use_button.text = "Use  [Enter]"
	_use_button.add_theme_stylebox_override("normal", _box(LEATHER, LEATHER_DARK, 2, 4))
	_use_button.add_theme_stylebox_override("hover", _box(LEATHER.lightened(0.15), LEATHER_DARK, 2, 4))
	_use_button.add_theme_color_override("font_color", Color("#f4e8cc"))
	_use_button.focus_mode = Control.FOCUS_NONE
	_use_button.position = Vector2(page_w - 150, page_h - 50)
	_use_button.size = Vector2(124, 32)
	_use_button.pressed.connect(_use_selected)
	right.add_child(_use_button)

	# Quick-slot row: put the selected consumable / Boss Key on hotbar 1–4.
	_hotbar_row = HBoxContainer.new()
	_hotbar_row.add_theme_constant_override("separation", 6)
	_hotbar_row.position = Vector2(26, 394)
	_hotbar_row.size = Vector2(page_w - 52, 22)
	right.add_child(_hotbar_row)
	var hb_label := _label("Quick slot", 13, INK_SOFT)
	hb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hotbar_row.add_child(hb_label)
	for i: int in 4:
		var b := JS.button(str(i + 1), 12)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(26, 22)
		b.tooltip_text = "Shift+%d" % (i + 1)
		b.pressed.connect(assign_selected_to_hotbar.bind(i))
		_hotbar_row.add_child(b)
		_hotbar_buttons.append(b)

	# Cover footer: Ashmarks (brass) and key hints.
	_ashmarks_label = _label("", 16, BRASS)
	_ashmarks_label.position = Vector2(40, BOOK_SIZE.y - 44)
	_book.add_child(_ashmarks_label)
	var hints := _label("[1–4] tabs   [Shift+1–4] quick slot   [S] sort   [↑↓] select   [Enter] use   [E / Esc] close", 12, STITCH)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hints.size = Vector2(640, 20)
	hints.position = Vector2(BOOK_SIZE.x - 40 - 640, BOOK_SIZE.y - 42)
	_book.add_child(hints)

func _make_page(pos: Vector2, page_size: Vector2, is_left: bool) -> Control:
	var page := Panel.new()
	page.position = pos
	page.size = page_size
	page.add_theme_stylebox_override("panel", _box(PAGE, PAGE_EDGE, 2, 4))
	_book.add_child(page)
	var grid := JS.PageDecor.new()
	grid.size = page_size
	grid.spine_on_right = is_left
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(grid)
	return page

func _ornament(centre: Vector2) -> Control:
	var o := JS.Ornament.new()
	o.position = centre - Vector2(90, 4)
	o.size = Vector2(180, 8)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return o

# ── Content ───────────────────────────────────────────────────────────────────

func refresh() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var bag: Node = _player.get_node_or_null("Bag") if _player else null
	if bag and not bag.bag_changed.is_connected(_on_bag_changed):
		bag.bag_changed.connect(_on_bag_changed)
	_ashmarks_label.text = "◈  %d Ashmarks" % (bag.ashmarks if bag else 0)
	for i: int in _ribbons.size():
		var active: bool = i == _tab
		var col: Color = RIBBON_COLOURS[i] if active else RIBBON_COLOURS[i].darkened(0.35)
		_ribbons[i].add_theme_stylebox_override("normal", _box(col, col.darkened(0.4), 2, 3))
		_ribbons[i].add_theme_stylebox_override("hover", _box(col.lightened(0.1), col.darkened(0.4), 2, 3))
		_ribbons[i].position.x = -110 if active else -92

	_entries = []
	match TAB_NAMES[_tab]:
		"Elements":    _collect_elements()
		"Equipment":   _collect_equipment()
		"Consumables": _collect_consumables(bag)
		"Key Items":   _collect_key_items(bag)
	_page_title.text = "%s  (%d)" % [TAB_NAMES[_tab], _entries.size()]
	_sort_entries(bag)
	_update_new_marks(bag)

	# Detach old rows now (not just queue_free) so row indices match _entries.
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for i: int in _entries.size():
		_list.add_child(_make_row(i))
	if _entries.is_empty():
		_list.add_child(_label(_empty_hint(), 14, INK_SOFT))
	_select(clampi(_selected, 0, maxi(_entries.size() - 1, 0)))

func _on_bag_changed() -> void:
	if is_open():
		refresh()

# ── Sorting, "new" badges and quick slots ─────────────────────────────────────

func sort_mode_name() -> String:
	return SORT_NAMES[int(_sort_mode.get(TAB_NAMES[_tab], 0))]

func cycle_sort() -> void:
	var tab: String = TAB_NAMES[_tab]
	_sort_mode[tab] = (int(_sort_mode.get(tab, 0)) + 1) % SORT_NAMES.size()
	_selected = 0
	refresh()

func entry_key(e: Dictionary) -> String:
	return str(e.get("key", e.get("id", "")))

# Recent: newest first. Name: A–Z. Type: by kind, keeping the journal's own
# order (atomic number, boss order) inside each kind. Ties keep that order too.
func _sort_entries(bag: Node) -> void:
	for i: int in _entries.size():
		_entries[i]["order"] = i
	var tab: String = TAB_NAMES[_tab]
	match sort_mode_name():
		"Recent":
			if bag == null:
				return
			for e: Dictionary in _entries:
				e["recent"] = bag.acquired_stamp(tab, entry_key(e))
			_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if a["recent"] != b["recent"]:
					return a["recent"] > b["recent"]
				return a["order"] < b["order"])
		"Name":
			_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var c: int = str(a["name"]).naturalnocasecmp_to(str(b["name"]))
				return c < 0 if c != 0 else a["order"] < b["order"])
		"Type":
			_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var ta: String = str(a.get("type", ""))
				var tb: String = str(b.get("type", ""))
				return ta < tb if ta != tb else a["order"] < b["order"])

# Marks this tab's unseen items for the rows, then tells the Bag they are seen.
func _update_new_marks(bag: Node) -> void:
	var tab: String = TAB_NAMES[_tab]
	if bag and is_open():
		for e: Dictionary in _entries:
			if bag.is_new(tab, entry_key(e)):
				_shown_new[entry_key(e)] = true
		bag.mark_tab_seen(tab)
	for e: Dictionary in _entries:
		e["new"] = _shown_new.has(entry_key(e))
	_sort_button.text = "Sort: %s  [S]" % sort_mode_name()
	for i: int in _ribbon_dots.size():
		_ribbon_dots[i].visible = bag != null and i != _tab and bag.tab_has_new(TAB_NAMES[i])

func ribbon_has_dot(tab_name: String) -> bool:
	var i: int = TAB_NAMES.find(tab_name)
	return i >= 0 and _ribbon_dots[i].visible

func entry_ids() -> Array:
	return _entries.map(func(e: Dictionary) -> String: return str(e["id"]))

func select_id(id: String) -> void:
	for i: int in _entries.size():
		if str(_entries[i]["id"]) == id:
			_select(i)
			return

# Puts the selected item in quick slot `slot`; pressing its own slot clears it.
func assign_selected_to_hotbar(slot: int) -> bool:
	if _entries.is_empty() or not bool(_entries[_selected].get("hotbar", false)):
		return false
	var bag: Node = _player.get_node_or_null("Bag") if _player else null
	if bag == null:
		return false
	var id: String = str(_entries[_selected]["id"])
	var ok: bool = bag.assign_hotbar(slot, "" if bag.hotbar_item(slot) == id else id)
	_update_hotbar_row(_entries[_selected])
	return ok

func _update_hotbar_row(e: Dictionary) -> void:
	var can: bool = bool(e.get("hotbar", false))
	_hotbar_row.visible = can
	if not can:
		return
	var bag: Node = _player.get_node_or_null("Bag") if _player else null
	var at: int = bag.hotbar_slot_of(str(e["id"])) if bag else -1
	for i: int in _hotbar_buttons.size():
		var on: bool = i == at
		_hotbar_buttons[i].add_theme_stylebox_override("normal",
			_box(BRASS if on else LEATHER, LEATHER_DARK, 2, 4))
		_hotbar_buttons[i].add_theme_color_override("font_color", INK if on else Color("#f4e8cc"))

func _empty_hint() -> String:
	match TAB_NAMES[_tab]:
		"Elements":    return "No samples yet.\nDig ore tiles to collect elements."
		"Consumables": return "No consumables yet.\nEnemies sometimes drop potions."
		"Key Items":   return "No key items yet.\nDefeat a Warden to earn a Key Fragment."
	return "Nothing here yet."

func _make_row(i: int) -> Button:
	var e: Dictionary = _entries[i]
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.focus_mode = Control.FOCUS_NONE
	row.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4))
	row.add_theme_stylebox_override("hover", _box(Color(0.36, 0.22, 0.12, 0.10), Color(0, 0, 0, 0), 0, 4))
	row.add_theme_stylebox_override("pressed", _box(Color(0.36, 0.22, 0.12, 0.18), Color(0, 0, 0, 0), 0, 4))
	row.pressed.connect(_select.bind(i))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -8
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	h.add_child(_small_icon(e))
	var name_l := _label(e["name"], 16, INK)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(name_l)
	if bool(e.get("new", false)):
		var new_l := _label(" new ", 11, STAMP_RED)
		new_l.name = "NewMark"
		new_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		new_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		new_l.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), STAMP_RED, 1, 3))
		h.add_child(new_l)
	var count_l := _label(e["count_text"], 16, INK_SOFT)
	count_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(count_l)
	return row

func _small_icon(e: Dictionary) -> Control:
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(40, 40)
	frame.add_theme_stylebox_override("panel", _box(Color("#e4d4ae"), PAGE_EDGE, 2, 4))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if e.has("tile"):
		frame.add_theme_stylebox_override("panel", _box(e["tile"], e["tile"].darkened(0.4), 2, 3))
		var t := _label(e["id"], 15, Color.WHITE)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(t)
	elif e["icon"] != null:
		var tr := TextureRect.new()
		tr.texture = e["icon"]
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.position = Vector2(4, 4)
		tr.size = Vector2(32, 32)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tr)
	return frame

func _select(i: int) -> void:
	if _entries.is_empty():
		_selected = 0
		_show_detail({})
		return
	_selected = clampi(i, 0, _entries.size() - 1)
	for r: int in _list.get_child_count():
		var row := _list.get_child(r) as Button
		if row:
			var on: bool = r == _selected
			row.add_theme_stylebox_override("normal", _box(Color(0.36, 0.22, 0.12, 0.16) if on else Color(0, 0, 0, 0),
				Color(0.36, 0.22, 0.12, 0.5) if on else Color(0, 0, 0, 0), 1 if on else 0, 4))
	_show_detail(_entries[_selected])

func _show_detail(e: Dictionary) -> void:
	_detail_icon.texture = e.get("icon", null) if not e.has("tile") else null
	_detail_tile.visible = e.has("tile")
	if e.has("tile"):
		_detail_tile.text = e["id"]
		_detail_tile.add_theme_stylebox_override("normal", _box(e["tile"], e["tile"].darkened(0.4), 3, 4))
	_detail_name.text = e.get("name", "")
	_detail_kind.text = e.get("kind", "")
	_detail_text.text = e.get("text", "")
	_detail_stat.text = e.get("stat", "")
	_detail_stamp.text = "  %s  " % e["stamp"] if e.get("stamp", "") != "" else ""
	_detail_stamp.visible = e.get("stamp", "") != ""
	_use_button.visible = bool(e.get("usable", false))
	_update_hotbar_row(e)

func _use_selected() -> void:
	if _entries.is_empty() or not bool(_entries[_selected].get("usable", false)):
		return
	var bag: Node = _player.get_node_or_null("Bag")
	if bag:
		bag.use_consumable(_entries[_selected]["id"])   # bag_changed → refresh

# ── Entry builders ────────────────────────────────────────────────────────────

static func _icon(id: String) -> Texture2D:
	var path := ICON_DIR + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

# Keys match data/elements.json "category".
const CATEGORY_COLOURS := {
	"alkali_metal": "#c0563a", "alkaline_earth": "#c98a2c", "transition_metal": "#5a7fa0",
	"post_transition": "#6f8f7a", "metalloid": "#7a8a3c", "nonmetal": "#3f8f5a",
	"halogen": "#3a8a8a", "noble_gas": "#7a5aa8", "lanthanide": "#a85a7a", "actinide": "#4f9a3a",
}

func _collect_elements() -> void:
	var inv: Node = _player.get_node_or_null("Inventory") if _player else null
	if inv == null:
		return
	var all: Dictionary = inv.get_all()
	var symbols: Array = all.keys()
	symbols.sort_custom(func(a: String, b: String) -> bool:
		return int(ElementDB.get_element(a).get("atomic_number", 0)) < int(ElementDB.get_element(b).get("atomic_number", 0)))
	for symbol: String in symbols:
		var el: Dictionary = ElementDB.get_element(symbol)
		var cat: String = str(el.get("category", ""))
		_entries.append({
			"id": symbol, "type": cat, "name": str(el.get("name", symbol)),
			"count_text": inv.format_amount(symbol, float(all[symbol])),
			"tile": Color(CATEGORY_COLOURS.get(cat, "#6a5a48")), "icon": null,
			"kind": "No. %d · %s" % [int(el.get("atomic_number", 0)), cat.replace("_", " ").capitalize()],
			"text": str(el.get("fun_fact", "")),
			"stat": "Atomic mass %s" % str(el.get("mass", "?")),
		})

func _collect_equipment() -> void:
	if _player == null:
		return
	var wpn: Node = _player.get_node_or_null("Weapon")
	if wpn and wpn.has_weapon():
		_entries.append({ "id": "weapon", "key": wpn.get_weapon_name(), "type": "0 weapon", "name": wpn.get_weapon_name().replace("_", " ").capitalize(), "count_text": "equipped",
			"icon": _icon("_weapon"), "kind": "Weapon", "text": "Your equipped weapon. Forge better ones from compounds at the crafting bench.",
			"stat": "Tier %d %s" % [wpn.get_tier(), wpn.get_weapon_type()] })
	var arm: Node = _player.get_node_or_null("Armor")
	if arm and arm.has_method("has_armor") and arm.has_armor():
		_entries.append({ "id": "armour", "key": arm.get_armor_name(), "type": "1 armour", "name": arm.get_armor_name().replace("_", " ").capitalize(), "count_text": "worn",
			"icon": _icon("_armour"), "kind": "Armour", "text": "Your worn armour.",
			"stat": "%d%% damage reduction" % int(arm.get_damage_reduction() * 100.0) })
	var eq: Node = _player.get_node_or_null("Equipment")
	var items: Dictionary = eq.get_all() if eq else {}
	for item: String in items:
		var worn: bool = item in eq.REUSABLE
		_entries.append({ "id": item, "type": "2 gear" if worn else "3 container", "name": item, "count_text": "worn" if worn else "×%d" % int(items[item]),
			"icon": _icon("_gloves" if worn else "_container"), "kind": "Lab gear",
			"text": "Protective gear for handling hazardous elements." if worn else "A container for one element sample. Used up when you collect.",
			"stat": "" })

func _collect_consumables(bag: Node) -> void:
	if bag == null:
		return
	for id: String in bag.consumables:
		var info: Dictionary = bag.item_info(id)
		_entries.append({ "id": id, "type": str(info.get("effect", "")), "hotbar": true, "name": str(info.get("name", id)), "count_text": "×%d" % bag.consumable_count(id),
			"icon": _icon(id), "kind": "Consumable", "text": str(info.get("description", "")),
			"stat": "Holding %d / %d" % [bag.consumable_count(id), bag.STACK_MAX], "usable": true })

func _collect_key_items(bag: Node) -> void:
	if bag == null:
		return
	var cat: Dictionary = bag.catalogue().get("key_items", {})
	for boss: String in BOSS_ORDER:
		var key_id: String = ""
		var frags: Array = []
		for id: String in cat:
			if cat[id].get("boss", "") == boss:
				if cat[id].get("kind", "") == "boss_key":
					key_id = id
				else:
					frags.append(id)
		if key_id != "" and bag.has_key_item(key_id):
			_entries.append({ "id": key_id, "type": "%d" % BOSS_ORDER.find(boss), "hotbar": true, "name": str(cat[key_id].get("name", key_id)), "count_text": "★",
				"icon": _icon(key_id), "kind": "Boss Key · %s" % boss.to_upper(), "text": str(cat[key_id].get("description", "")),
				"stat": "Opens %s's arena" % boss.capitalize(), "stamp": "KEY ITEM · PERMANENT" })
			continue
		var held: Array = frags.filter(func(f: String) -> bool: return bag.has_key_item(f))
		for f: String in held:
			_entries.append({ "id": f, "type": "%d" % BOSS_ORDER.find(boss), "name": str(cat[f].get("name", f)), "count_text": "%d/%d" % [held.size(), frags.size()],
				"icon": _icon(f), "kind": "Key Fragment · %s" % boss.to_upper(), "text": str(cat[f].get("description", "")),
				"stat": "Set: %d of %d fragments" % [held.size(), frags.size()], "stamp": "KEY ITEM · PERMANENT" })
