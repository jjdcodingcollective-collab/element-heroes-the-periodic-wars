extends "res://scripts/ui/journal_menu.gd"

# Bestiary — the CHIMERA files (SYSTEMS_UX_REVIEW §3.2). UIManager "bestiary".
# Ribbons: Creatures · Prime Codex.
#   Creatures: left page lists all 18 files (seen ones by name, the rest as
#   "???"); right page shows the file: lore, base animal, elements, biome and
#   how many you have defeated by rarity.
#   Prime Codex: left page lists the 18 Primes (◆ recorded, ◇ not yet); right
#   page shows progress toward the Prime cosmetic set (BOSS_DESIGN.md §4a).
# Seen / defeated tracking lives in EncounterSystem.

const PrimeSet := preload("res://scripts/world/prime_set.gd")
const TAB_NAMES := ["Creatures", "Prime Codex"]
const RIBBON_COLOURS := [Color("#3f6b3a"), Color("#6a4a8a")]
const PRIME_INK := Color("#6a4a8a")

var _tab: int = 0
var _ids: Array = []
var _selected: int = 0
var _list: VBoxContainer
var _rows: Array[Button] = []
var _page_title: Label

# Right page, creature file
var _file_box: Control
var _sketch: Panel
var _sketch_mark: Label
var _detail_name: Label
var _detail_kind: Label
var _detail_meta: Label
var _detail_text: Label
var _detail_stat: Label
var _detail_stamp: Label

# Right page, codex overview
var _codex_box: Control
var _codex_count: Label
var _codex_bar: ProgressBar
var _milestone_list: VBoxContainer

func _ready() -> void:
	add_to_group("bestiary_ui")
	_setup_menu("bestiary")

func _build_pages() -> void:
	_add_ribbons(TAB_NAMES, RIBBON_COLOURS, show_tab)
	_add_cover_and_pages()
	_footer_hints.text = "[1–2] tabs   [↑↓] select   [Esc] close"

	_page_title = _heading(_left, "")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, 60)
	scroll.size = Vector2(_page_w - 36, _page_h - 76)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	# Creature file.
	_file_box = Control.new()
	_right.add_child(_file_box)
	_sketch = Panel.new()
	_sketch.size = Vector2(96, 96)
	_sketch.position = Vector2((_page_w - 96) / 2.0, 16)
	_file_box.add_child(_sketch)
	_sketch_mark = JS.label("", 40, Color.WHITE)
	_sketch_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sketch_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sketch_mark.size = _sketch.size
	_sketch.add_child(_sketch_mark)
	_detail_name = JS.label("", 22, JS.INK)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.position = Vector2(0, 118)
	_detail_name.size = Vector2(_page_w, 30)
	_file_box.add_child(_detail_name)
	_detail_kind = JS.label("", 13, JS.INK_SOFT)
	_detail_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_kind.position = Vector2(0, 148)
	_detail_kind.size = Vector2(_page_w, 20)
	_file_box.add_child(_detail_kind)
	_file_box.add_child(JS.ornament(Vector2(_page_w / 2.0, 176)))
	_detail_meta = _text(_file_box, "", Vector2(26, 188), _page_w - 52, 13, JS.INK)
	_detail_text = _text(_file_box, "", Vector2(26, 232), _page_w - 52, 13, JS.INK)
	_detail_stat = _text(_file_box, "", Vector2(26, _page_h - 84), _page_w - 52, 14, JS.INK_GREEN)
	_detail_stamp = JS.label("", 13, PRIME_INK)
	_detail_stamp.add_theme_stylebox_override("normal", JS.box(Color(0, 0, 0, 0), PRIME_INK, 2, 3))
	_detail_stamp.position = Vector2(26, _page_h - 46)
	_file_box.add_child(_detail_stamp)

	# Prime Codex overview.
	_codex_box = Control.new()
	_right.add_child(_codex_box)
	var h := JS.label("Prime Codex", 22, PRIME_INK)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.position = Vector2(0, 12)
	h.size = Vector2(_page_w, 30)
	_codex_box.add_child(h)
	_codex_count = JS.label("", 15, JS.INK)
	_codex_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_codex_count.position = Vector2(0, 44)
	_codex_count.size = Vector2(_page_w, 22)
	_codex_box.add_child(_codex_count)
	_codex_bar = ProgressBar.new()
	_codex_bar.max_value = 18
	_codex_bar.show_percentage = false
	_codex_bar.position = Vector2(40, 72)
	_codex_bar.size = Vector2(_page_w - 80, 14)
	_codex_bar.add_theme_stylebox_override("background", JS.box(JS.PAGE_DARK, JS.PAGE_EDGE, 1, 4))
	_codex_bar.add_theme_stylebox_override("fill", JS.box(PRIME_INK, PRIME_INK.darkened(0.3), 1, 4))
	_codex_box.add_child(_codex_bar)
	_codex_box.add_child(JS.ornament(Vector2(_page_w / 2.0, 100)))
	_text(_codex_box, "The Prime set is cosmetic only. Pieces unlock as the Codex fills:",
		Vector2(26, 110), _page_w - 52, 12, JS.INK_SOFT)
	_milestone_list = VBoxContainer.new()
	_milestone_list.position = Vector2(26, 146)
	_milestone_list.size = Vector2(_page_w - 52, _page_h - 160)
	_milestone_list.add_theme_constant_override("separation", 3)
	_codex_box.add_child(_milestone_list)

func _on_opened() -> void:
	refresh()

func show_tab(i: int) -> void:
	_tab = clampi(i, 0, TAB_NAMES.size() - 1)
	_selected = 0
	refresh()

func refresh() -> void:
	_style_ribbons(_tab, RIBBON_COLOURS)
	_ids = PrimeSet.ordered_creatures()
	var seen_count := _ids.filter(func(id: String) -> bool: return EncounterSystem.is_seen(id)).size()
	var codex: Dictionary = EncounterSystem.prime_codex
	_footer_left.text = "◈  %d of %d creatures seen    ◆ %d/%d Primes" % [seen_count, _ids.size(), codex.size(), _ids.size()]
	_page_title.text = ("CHIMERA files  (%d/%d)" % [seen_count, _ids.size()]) if _tab == 0 else ("Prime Codex  (%d/%d)" % [codex.size(), _ids.size()])
	_clear(_list)
	_rows.clear()
	for i: int in _ids.size():
		var id: String = _ids[i]
		var seen := EncounterSystem.is_seen(id)
		var note := ""
		if _tab == 0:
			var total := _total_defeats(id)
			note = ("×%d" % total) if total > 0 else ""
		else:
			note = "◆" if codex.has(id) else "◇"
		var row := _row("#%03d  %s" % [PrimeSet.file_number(id), entry_name(id)], note, _select.bind(i),
			JS.INK if seen else JS.INK_SOFT)
		if _tab == 1 and codex.has(id):
			_row_note(row).add_theme_color_override("font_color", PRIME_INK)
		_list.add_child(row)
		_rows.append(row)
	_file_box.visible = _tab == 0
	_codex_box.visible = _tab == 1
	if _tab == 1:
		_show_codex()
	_select(clampi(_selected, 0, maxi(_ids.size() - 1, 0)))

# Name shown in the list: "???" until the creature has been seen.
func entry_name(id: String) -> String:
	return str(ElementDB.get_enemy_data(id).get("name", id)) if EncounterSystem.is_seen(id) else "???"

func _total_defeats(id: String) -> int:
	var n := 0
	var per: Dictionary = EncounterSystem.defeats_of(id)
	for r: String in per:
		n += int(per[r])
	return n

func _select(i: int) -> void:
	if _ids.is_empty():
		return
	_selected = clampi(i, 0, _ids.size() - 1)
	for r: int in _rows.size():
		_mark_row(_rows[r], r == _selected)
	if _tab == 0:
		_show_file(_ids[_selected])

# Text of a creature file, as shown on the right page (also used by tests).
func file_text(id: String) -> Dictionary:
	var d: Dictionary = ElementDB.get_enemy_data(id)
	var biome := PrimeSet.biome_name(str(d.get("biome", "")))
	if not EncounterSystem.is_seen(id):
		return { "name": "???", "kind": "CHIMERA File #%03d · %s" % [PrimeSet.file_number(id), biome],
			"meta": "", "text": "No sighting recorded yet. Something lurks in the %s." % biome, "stat": "", "stamp": "" }
	var animal := PrimeSet.base_animal(id)
	var elements: Array = d.get("elements", [])
	var per: Dictionary = EncounterSystem.defeats_of(id)
	var parts: Array = []
	for r: String in ["strong", "shiny", "prime"]:
		if int(per.get(r, 0)) > 0:
			parts.append("%d %s" % [int(per[r]), r])
	var total := _total_defeats(id)
	var stat := "Defeated: %d" % total
	if not parts.is_empty():
		stat += "  (%s)" % ", ".join(parts)
	return {
		"name": str(d.get("name", id)),
		"kind": "CHIMERA File #%03d · %s" % [PrimeSet.file_number(id), biome],
		"meta": ("Base animal: %s\n" % animal if animal != "" else "") + "Elements: %s" % ", ".join(elements),
		"text": str(d.get("lore", "")).trim_prefix("CHIMERA File #%03d. " % PrimeSet.file_number(id)),
		"stat": stat,
		"stamp": "PRIME RECORDED" if EncounterSystem.prime_codex.has(id) else "",
	}

func _show_file(id: String) -> void:
	var f := file_text(id)
	var seen := EncounterSystem.is_seen(id)
	var col := Color(str(ElementDB.get_enemy_data(id).get("color", "#6a5a48"))) if seen else JS.INK_SOFT
	_sketch.add_theme_stylebox_override("panel", JS.box(col if seen else JS.PAGE_DARK, col.darkened(0.4), 3, 48))
	_sketch_mark.text = "?" if not seen else str(f["name"]).left(1)
	_sketch_mark.add_theme_color_override("font_color", Color.WHITE if seen else JS.INK_SOFT)
	_detail_name.text = f["name"]
	_detail_kind.text = f["kind"]
	_detail_meta.text = f["meta"]
	_detail_text.position.y = 232 if f["meta"] != "" else 192
	_detail_text.text = f["text"]
	_detail_stat.text = f["stat"]
	_detail_stamp.text = "  %s  " % f["stamp"] if f["stamp"] != "" else ""
	_detail_stamp.visible = f["stamp"] != ""

func _show_codex() -> void:
	var codex: Dictionary = EncounterSystem.prime_codex
	_codex_count.text = "%d of 18 Primes recorded" % codex.size()
	_codex_bar.value = codex.size()
	_clear(_milestone_list)
	for m: Dictionary in PrimeSet.milestones(codex):
		var on: bool = m["unlocked"]
		var l := JS.label("%s  %s: %s" % ["✔" if on else "○", m["name"], m["rule"]], 13, PRIME_INK if on else JS.INK_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(_page_w - 52, 0)
		_milestone_list.add_child(l)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_down"):
		_select(_selected + 1)
	elif event.is_action_pressed("ui_up"):
		_select(_selected - 1)
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_1 or event.keycode == KEY_2):
		show_tab(event.keycode - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()
