extends RefCounted

# Shared look for every journal-style screen (D-018): the inventory, title
# screen, Contents hub, options, recipe book. Use via
#   const JS := preload("res://scripts/ui/journal_style.gd")
# and build with JS.box(), JS.label(), JS.make_book(), JS.make_page().

const LEATHER      := Color("#5b3520")
const LEATHER_DARK := Color("#2e1a0e")
const STITCH       := Color("#c9a26b")
const BRASS        := Color("#d6a040")
const PAGE         := Color("#efe3c6")
const PAGE_EDGE    := Color("#c9b58c")
const PAGE_DARK    := Color("#e4d4ae")
const INK          := Color("#3b2a1a")
const INK_SOFT     := Color("#7a6248")
const INK_GREEN    := Color("#4a5d2a")
const STAMP_RED    := Color("#9a3324")
const CREAM_TEXT   := Color("#f4e8cc")

static func box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s

static func label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l

# A leather button (cream text) for actions on a page.
static func button(text: String, size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", box(LEATHER, LEATHER_DARK, 2, 4))
	b.add_theme_stylebox_override("hover", box(LEATHER.lightened(0.15), LEATHER_DARK, 2, 4))
	b.add_theme_stylebox_override("pressed", box(LEATHER.darkened(0.15), LEATHER_DARK, 2, 4))
	b.add_theme_stylebox_override("focus", box(LEATHER.lightened(0.15), BRASS, 2, 4))
	b.add_theme_stylebox_override("disabled", box(LEATHER.darkened(0.3), LEATHER_DARK, 2, 4))
	b.add_theme_color_override("font_color", CREAM_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.55, 0.45))
	return b

# Leather cover of `size` with stitching and brass corners, added to `parent`.
static func make_book(parent: Control, book_size: Vector2) -> void:
	var cover := Panel.new()
	cover.size = book_size
	var leather := box(LEATHER, LEATHER_DARK, 4, 16)
	leather.shadow_color = Color(0, 0, 0, 0.5)
	leather.shadow_size = 12
	cover.add_theme_stylebox_override("panel", leather)
	parent.add_child(cover)
	var decor := CoverDecor.new()
	decor.size = book_size
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(decor)

# A parchment page with the graph-paper grid; spine shading on one side.
static func make_page(parent: Control, pos: Vector2, page_size: Vector2, spine_on_right: bool) -> Panel:
	var page := Panel.new()
	page.position = pos
	page.size = page_size
	page.add_theme_stylebox_override("panel", box(PAGE, PAGE_EDGE, 2, 4))
	parent.add_child(page)
	var grid := PageDecor.new()
	grid.size = page_size
	grid.spine_on_right = spine_on_right
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(grid)
	return page

static func ornament(centre: Vector2) -> Control:
	var o := Ornament.new()
	o.position = centre - Vector2(90, 4)
	o.size = Vector2(180, 8)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return o

# ── Decorative drawing ────────────────────────────────────────────────────────

# Stitching just inside the cover edge, brass corner caps and a spine groove.
class CoverDecor extends Control:
	func _draw() -> void:
		var inset := 9.0
		var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		for edge: Array in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
				[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
			draw_dashed_line(edge[0], edge[1], Color("#c9a26b"), 1.5, 6.0)
		var brass := Color("#d6a040")
		var dark := Color("#8c6022")
		for c: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
			var sx: float = 1.0 if c.x == 0.0 else -1.0
			var sy: float = 1.0 if c.y == 0.0 else -1.0
			var tri := PackedVector2Array([c, c + Vector2(34 * sx, 0), c + Vector2(0, 34 * sy)])
			draw_colored_polygon(tri, brass)
			draw_polyline(PackedVector2Array([c + Vector2(34 * sx, 0), c + Vector2(0, 34 * sy)]), dark, 2.0)
			draw_circle(c + Vector2(11 * sx, 11 * sy), 3.0, dark)
		var mid := size.x / 2.0
		draw_rect(Rect2(mid - 4, 14, 8, size.y - 60), Color(0, 0, 0, 0.35))

# Faint graph-paper grid (Orion's lab notebook) and a shadow toward the spine.
class PageDecor extends Control:
	var spine_on_right: bool = true
	func _draw() -> void:
		var line := Color(0.48, 0.38, 0.24, 0.10)
		var step := 14.0
		var x := step
		while x < size.x:
			draw_line(Vector2(x, 4), Vector2(x, size.y - 4), line, 1.0)
			x += step
		var y := step
		while y < size.y:
			draw_line(Vector2(4, y), Vector2(size.x - 4, y), line, 1.0)
			y += step
		for i: int in 10:
			var a: float = 0.16 * (1.0 - i / 10.0)
			var px: float = size.x - 2 - i * 2 if spine_on_right else 2 + i * 2
			draw_line(Vector2(px, 2), Vector2(px, size.y - 2), Color(0.25, 0.15, 0.05, a), 2.0)

# A small inked divider: line, diamond, line.
class Ornament extends Control:
	func _draw() -> void:
		var ink := Color("#7a6248")
		var c := size / 2.0
		draw_line(Vector2(0, c.y), Vector2(c.x - 10, c.y), ink, 1.5)
		draw_line(Vector2(c.x + 10, c.y), Vector2(size.x, c.y), ink, 1.5)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(6, 0), c + Vector2(0, 5), c + Vector2(-6, 0)]), ink)
