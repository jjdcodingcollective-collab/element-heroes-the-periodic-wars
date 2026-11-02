extends "res://scripts/ui/journal_menu.gd"

# Specimen Cabinet page (UIManager "cabinet"), opened from the cabinet in
# Aldric's workshop. Left page: the Prime Codex shelf (18 jars, lit once
# recorded) and rare defeat counts. Right page: boss relics and the Prime set
# pieces unlocked so far (BOSS_DESIGN.md §4a).

const PrimeSet := preload("res://scripts/world/prime_set.gd")
const BOSS_DATA := "res://data/boss_data.json"
const PRIME_INK := Color("#6a4a8a")

var _shelf: GridContainer
var _codex_label: Label
var _defeats_label: Label
var _relics_label: Label
var _set_label: Label

func _ready() -> void:
	add_to_group("specimen_cabinet_ui")
	_setup_menu("cabinet")

func _build_pages() -> void:
	_add_cover_and_pages()
	_footer_left.text = "✦  Specimen Cabinet"
	_footer_hints.text = "[Esc] close"
	_heading(_left, "Prime Codex shelf")
	_codex_label = JS.label("", 15, PRIME_INK)
	_codex_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_codex_label.position = Vector2(0, 58)
	_codex_label.size = Vector2(_page_w, 22)
	_left.add_child(_codex_label)
	_shelf = GridContainer.new()
	_shelf.columns = 6
	_shelf.position = Vector2(34, 88)
	_shelf.add_theme_constant_override("h_separation", 10)
	_shelf.add_theme_constant_override("v_separation", 10)
	_left.add_child(_shelf)
	_left.add_child(JS.ornament(Vector2(_page_w / 2.0, 270)))
	_defeats_label = _text(_left, "", Vector2(30, 284), _page_w - 60, 15)

	_heading(_right, "Trophies")
	_relics_label = _text(_right, "", Vector2(30, 62), _page_w - 60, 14)
	_set_label = _text(_right, "", Vector2(30, 250), _page_w - 60, 14, PRIME_INK)

func _on_opened() -> void:
	refresh()

func refresh() -> void:
	var t := trophies()
	var codex: Dictionary = EncounterSystem.prime_codex
	_codex_label.text = "%d of 18 Primes recorded" % int(t["codex"])
	_clear(_shelf)
	for id: String in PrimeSet.ordered_creatures():
		var have := codex.has(id)
		var jar := Panel.new()
		jar.custom_minimum_size = Vector2(46, 46)
		var col := Color(str(ElementDB.get_enemy_data(id).get("color", "#6a5a48")))
		jar.add_theme_stylebox_override("panel", JS.box(col if have else JS.PAGE_DARK,
			PRIME_INK if have else JS.PAGE_EDGE, 3 if have else 2, 8))
		jar.tooltip_text = str(ElementDB.get_enemy_data(id).get("name", id)) if have else "Empty jar"
		var l := JS.label("#%02d" % PrimeSet.file_number(id), 11, Color.WHITE if have else JS.INK_SOFT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = jar.custom_minimum_size
		jar.add_child(l)
		_shelf.add_child(jar)
	_defeats_label.text = "Rare specimens defeated\n   ★ Prime: %d\n   ✦ Shiny: %d\n   ▲ Strong: %d" % [
		int(t["prime"]), int(t["shiny"]), int(t["strong"])]
	var relic_lines: Array = ["Boss relics (%d/6)" % (t["bosses"] as Array).size()]
	for b: Dictionary in boss_list():
		var beaten: bool = b["id"] in t["bosses"]
		relic_lines.append("   %s  %s" % ["✔" if beaten else "—", ("%s, %s" % [b["name"], b["title"]]) if beaten else "Not yet defeated"])
	_relics_label.text = "\n".join(relic_lines)
	var pieces: Array = t["prime_set"]
	_set_label.text = "Prime set pieces (%d/9)\n" % pieces.size() + (
		"\n".join(pieces.map(func(p: String) -> String: return "   ✔  " + p)) if not pieces.is_empty()
		else "   Record your first Prime to earn the Prime Lens.")

# Everything the cabinet displays, as data (used by refresh and tests).
func trophies() -> Dictionary:
	var world := get_tree().get_first_node_in_group("player")
	world = world.get_parent() if world else null
	var bosses: Array = world.defeated_bosses.duplicate() if world and "defeated_bosses" in world else []
	return {
		"codex": EncounterSystem.prime_codex.size(),
		"codex_ids": EncounterSystem.prime_codex.keys(),
		"prime": int(EncounterSystem.defeated_by_rarity.get("prime", 0)),
		"shiny": int(EncounterSystem.defeated_by_rarity.get("shiny", 0)),
		"strong": int(EncounterSystem.defeated_by_rarity.get("strong", 0)),
		"bosses": bosses,
		"prime_set": PrimeSet.unlocked_names(EncounterSystem.prime_codex),
	}

static var _bosses: Array = []

static func boss_list() -> Array:
	if _bosses.is_empty():
		var f := FileAccess.open(BOSS_DATA, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for b in parsed.get("bosses", []):
					_bosses.append({ "id": str(b.get("id", "")), "name": str(b.get("name", "")).capitalize(),
						"title": str(b.get("title", "")) })
	return _bosses
