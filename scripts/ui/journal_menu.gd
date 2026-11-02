extends CanvasLayer

# Base for the small journal-style menus (Contents, Options, Bestiary,
# Specimen Cabinet): a leather book with two parchment pages, registered with
# UIManager so only one menu is open at a time and the game pauses.
#
# Subclasses call _setup_menu("name") from _ready(), build their pages in
# _build_pages(), and refresh content in _on_opened().

const JS := preload("res://scripts/ui/journal_style.gd")
const BOOK_SIZE := Vector2(900, 540)

var menu_name: String = ""
var _dim: ColorRect
var _book: Control
var _left: Panel
var _right: Panel
var _page_w: float = (BOOK_SIZE.x - 64.0) / 2.0
var _page_h: float = BOOK_SIZE.y - 76.0
var _footer_left: Label
var _footer_hints: Label
var _ribbons: Array[Button] = []

func _setup_menu(registered_name: String, layer_no: int = 9) -> void:
	menu_name = registered_name
	layer = layer_no
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused
	_build_book()
	_build_pages()
	_apply_visibility(false)
	UIManager.register(menu_name, self)

func is_open() -> bool:
	return _book.visible

# Called by UIManager.
func _menu_set_open(open: bool) -> void:
	_apply_visibility(open)
	if open:
		AudioManager.on_ui_open()
		_on_opened()
	else:
		AudioManager.on_ui_close()
		_on_closed()

func _apply_visibility(open: bool) -> void:
	_book.visible = open
	_dim.visible = open   # hidden overlays must never block clicks (D-015)

# ── Overridables ──────────────────────────────────────────────────────────────

func _build_pages() -> void:
	pass

func _on_opened() -> void:
	pass

func _on_closed() -> void:
	pass

# ── Building ──────────────────────────────────────────────────────────────────

func _build_book() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_book = Control.new()
	_book.set_anchors_preset(Control.PRESET_CENTER)
	_book.size = BOOK_SIZE
	_book.position = -BOOK_SIZE / 2.0
	add_child(_book)

# Ribbons must be added before the cover so they tuck behind it.
func _add_ribbons(names: Array, colours: Array, on_pressed: Callable) -> void:
	for i: int in names.size():
		var r := Button.new()
		r.text = names[i]
		r.alignment = HORIZONTAL_ALIGNMENT_LEFT
		r.add_theme_font_size_override("font_size", 13)
		r.add_theme_color_override("font_color", JS.CREAM_TEXT)
		r.add_theme_color_override("font_hover_color", Color.WHITE)
		r.focus_mode = Control.FOCUS_NONE
		r.size = Vector2(118, 34)
		r.position = Vector2(-96, 70 + i * 46)
		r.pressed.connect(on_pressed.bind(i))
		_book.add_child(r)
		_ribbons.append(r)

func _style_ribbons(active: int, colours: Array) -> void:
	for i: int in _ribbons.size():
		var on: bool = i == active
		var col: Color = colours[i] if on else (colours[i] as Color).darkened(0.35)
		_ribbons[i].add_theme_stylebox_override("normal", JS.box(col, col.darkened(0.4), 2, 3))
		_ribbons[i].add_theme_stylebox_override("hover", JS.box(col.lightened(0.1), col.darkened(0.4), 2, 3))
		_ribbons[i].position.x = -110 if on else -92

func _add_cover_and_pages() -> void:
	JS.make_book(_book, BOOK_SIZE)
	_left = JS.make_page(_book, Vector2(28, 24), Vector2(_page_w, _page_h), true)
	_right = JS.make_page(_book, Vector2(36 + _page_w, 24), Vector2(_page_w, _page_h), false)
	_footer_left = JS.label("", 16, JS.BRASS)
	_footer_left.position = Vector2(40, BOOK_SIZE.y - 44)
	_book.add_child(_footer_left)
	_footer_hints = JS.label("", 12, JS.STITCH)
	_footer_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer_hints.position = Vector2(BOOK_SIZE.x - 470, BOOK_SIZE.y - 42)
	_footer_hints.size = Vector2(430, 20)
	_book.add_child(_footer_hints)

# Centred heading with an inked divider under it.
func _heading(page: Control, text: String, y: float = 12.0, size: int = 20) -> Label:
	var l := JS.label(text, size, JS.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(_page_w, 30)
	page.add_child(l)
	page.add_child(JS.ornament(Vector2(_page_w / 2.0, y + 36)))
	return l

func _text(page: Control, text: String, pos: Vector2, width: float, size: int = 14, colour: Color = JS.INK) -> Label:
	var l := JS.label(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = pos
	l.size = Vector2(width, 0)
	page.add_child(l)
	return l

# A transparent list row (name on the left, note on the right) like the
# inventory's. Selection is drawn by _mark_row().
func _row(text: String, note: String, on_pressed: Callable, ink: Color = JS.INK) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.focus_mode = Control.FOCUS_NONE
	row.add_theme_stylebox_override("normal", JS.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4))
	row.add_theme_stylebox_override("hover", JS.box(Color(0.36, 0.22, 0.12, 0.10), Color(0, 0, 0, 0), 0, 4))
	row.add_theme_stylebox_override("pressed", JS.box(Color(0.36, 0.22, 0.12, 0.18), Color(0, 0, 0, 0), 0, 4))
	row.add_theme_stylebox_override("disabled", JS.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4))
	row.pressed.connect(on_pressed)
	var h := HBoxContainer.new()
	h.name = "Box"
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var name_l := JS.label(text, 15, ink)
	name_l.name = "Name"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	h.add_child(name_l)
	var note_l := JS.label(note, 14, JS.INK_SOFT)
	note_l.name = "Note"
	note_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(note_l)
	return row

func _row_name(row: Button) -> Label:
	return row.get_node("Box/Name") as Label

func _row_note(row: Button) -> Label:
	return row.get_node("Box/Note") as Label

func _mark_row(row: Button, on: bool) -> void:
	row.add_theme_stylebox_override("normal", JS.box(Color(0.36, 0.22, 0.12, 0.16) if on else Color(0, 0, 0, 0),
		Color(0.36, 0.22, 0.12, 0.5) if on else Color(0, 0, 0, 0), 1 if on else 0, 4))

func _clear(container: Node) -> void:
	for c: Node in container.get_children():
		container.remove_child(c)
		c.queue_free()

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")
