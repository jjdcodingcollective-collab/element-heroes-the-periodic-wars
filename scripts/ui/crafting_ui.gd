extends Control

# CraftingUI — the crafting spread of Orion's field journal (R). D-018, §3.3.
#
# Left page: the crafting grid, output, equipment compare and Craft button.
# Right page: the Recipe Book (Minecraft-style). Every recipe is listed; the
# ones the player can make now sit at the top and fill the grid on click.
# Locked recipes are greyed silhouettes with a hint about what is missing.
#
# Two grid tiers: anywhere, only the top-left 2×2 "pocket" grid is usable.
# Within reach of any node in group "crafting_bench" (Aldric's desk, Field
# Stations; each may define `interact_radius`, default 40 px) the full 3×3
# opens. Recipes with more than 4 units need a bench.
#
# Each cell holds one ingredient; right-click stacks another unit into it so
# big recipes (U4O8, soap) fit nine cells. Grid evaluation is shapeless.
#
# Attached to the Panel node inside crafting_ui.tscn. Managed by UIManager
# ("crafting"): it never pauses the tree itself.
#
# USAGE: world.gd sets player_inventory after instancing; otherwise the
# player's Inventory node is looked up by group.

const JS := preload("res://scripts/ui/journal_style.gd")
const CATEGORY_COLOURS: Dictionary = preload("res://scripts/ui/inventory_screen.gd").CATEGORY_COLOURS
const ICON_DIR := "res://assets/sprites/items/"

const GRID_SIZE: int = 3
const POCKET_SIZE: int = 2
const POCKET_UNITS: int = POCKET_SIZE * POCKET_SIZE
const BENCH_GROUP: String = "crafting_bench"
const DEFAULT_BENCH_RADIUS: float = 40.0

const BOOK_SIZE := Vector2(1000, 600)
const SLOT_PX: float = 68.0
const SLOT_GAP: float = 6.0

const FAMILY_NAMES := {
	"alkali_metal": "alkali metal", "alkaline_earth": "alkaline earth metal",
	"transition_metal": "transition metal", "post_transition": "post-transition metal",
	"metalloid": "metalloid", "nonmetal": "nonmetal", "halogen": "halogen",
	"noble_gas": "noble gas", "lanthanide": "lanthanide", "actinide": "actinide",
}

var grid_slots: Array = []          # 9 Button nodes, row-major
var grid_contents: Array = []       # 3×3 array of ingredient ids ("" = empty)
var grid_counts: Array = []         # 3×3 array of stack sizes (0 when empty)
var player_inventory: Node = null
var near_bench: bool = false

var _book: Control
var _dim: ColorRect
var _tier_label: Label
var _lock_note: Label
var _output_slot: Button
var _out_name: Label
var _out_fact: Label
var _compare_box: VBoxContainer
var _status: Label
var _craft_button: Button
var _recipe_list: VBoxContainer
var _recipe_count: Label
var _picker: Panel
var _picker_grid: GridContainer
var _picker_target: int = -1
var _recipe_rows: Dictionary = {}   # game_item -> Button
var _chosen_key: String = ""        # recipe picked in the book (wins ties like Steel / Steel Sword)

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_init_grid_data()
	_build()
	UIManager.register("crafting", self)
	refresh()

func _init_grid_data() -> void:
	grid_contents = []
	grid_counts = []
	for _r: int in GRID_SIZE:
		grid_contents.append(["", "", ""])
		grid_counts.append([0, 0, 0])

# Called by UIManager.
func _menu_set_open(open: bool) -> void:
	visible = open
	_close_picker()
	if open:
		AudioManager.on_ui_open()
		refresh_bench()
		refresh()
		if grid_slots.size() > 0:
			_focus_later(grid_slots[0])
	else:
		AudioManager.on_ui_close()

# Esc closes the picker first, before UIManager closes the whole journal.
func _input(event: InputEvent) -> void:
	if visible and _picker.visible and event.is_action_pressed("ui_cancel"):
		_close_picker()
		get_viewport().set_input_as_handled()

# ── Player links ──────────────────────────────────────────────────────────────

func _player() -> Node:
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null

func _inventory() -> Node:
	if player_inventory != null and is_instance_valid(player_inventory):
		return player_inventory
	var p := _player()
	return p.get_node_or_null("Inventory") if p else null

func _equipment() -> Node:
	var p := _player()
	return p.get_node_or_null("Equipment") if p else null

# ── Bench tier ────────────────────────────────────────────────────────────────

func refresh_bench() -> void:
	near_bench = is_near_bench()
	if not near_bench:
		# Anything left in the outer ring would be unreachable; take it back.
		for i: int in GRID_SIZE * GRID_SIZE:
			if not is_slot_usable(i):
				_set_cell(i, "", 0)
	_apply_slot_looks()
	refresh()

func is_near_bench() -> bool:
	var p := _player() as Node2D
	if p == null:
		return false
	for b: Node in get_tree().get_nodes_in_group(BENCH_GROUP):
		if not (b is Node2D):
			continue
		var r: Variant = b.get("interact_radius")
		var radius: float = float(r) if r != null else DEFAULT_BENCH_RADIUS
		if (b as Node2D).global_position.distance_to(p.global_position) <= radius:
			return true
	return false

func is_slot_usable(idx: int) -> bool:
	if near_bench:
		return true
	@warning_ignore("integer_division")
	var row: int = idx / GRID_SIZE
	return row < POCKET_SIZE and idx % GRID_SIZE < POCKET_SIZE

func usable_slot_indices() -> Array:
	var out: Array = []
	for i: int in GRID_SIZE * GRID_SIZE:
		if is_slot_usable(i):
			out.append(i)
	return out

# ── Grid editing ──────────────────────────────────────────────────────────────

func _set_cell(idx: int, id: String, count: int) -> void:
	@warning_ignore("integer_division")
	var row: int = idx / GRID_SIZE
	var col: int = idx % GRID_SIZE
	grid_contents[row][col] = id
	grid_counts[row][col] = count if id != "" else 0
	if idx < grid_slots.size():
		_style_slot(idx)

func get_cell(idx: int) -> String:
	@warning_ignore("integer_division")
	return grid_contents[idx / GRID_SIZE][idx % GRID_SIZE]

func get_cell_count(idx: int) -> int:
	@warning_ignore("integer_division")
	return int(grid_counts[idx / GRID_SIZE][idx % GRID_SIZE])

# Kept for callers that place elements directly.
func set_slot(row: int, col: int, symbol: String) -> void:
	_set_cell(row * GRID_SIZE + col, symbol, 1)
	refresh()

func clear_grid() -> void:
	_chosen_key = ""
	for i: int in GRID_SIZE * GRID_SIZE:
		_set_cell(i, "", 0)
	refresh()

func _on_slot_pressed(idx: int) -> void:
	if not is_slot_usable(idx):
		return
	if get_cell(idx) != "":
		_set_cell(idx, "", 0)
		refresh()
	else:
		open_picker(idx)

func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		add_to_stack(idx)
		grid_slots[idx].accept_event()

# Right-click: one more unit of the same ingredient in that cell.
func add_to_stack(idx: int) -> bool:
	var id: String = get_cell(idx)
	if id == "" or not is_slot_usable(idx) or units_on_grid(id) >= units_held(id):
		return false
	_set_cell(idx, id, get_cell_count(idx) + 1)
	refresh()
	return true

func units_on_grid(id: String) -> int:
	var n: int = 0
	for i: int in GRID_SIZE * GRID_SIZE:
		if get_cell(i) == id:
			n += get_cell_count(i)
	return n

# Whole units the player holds (1 unit = 1 g / 1 mL of an element, or 1 item).
func units_held(id: String) -> int:
	if ElementDB.elements.has(id):
		var inv := _inventory()
		return int(floor(float(inv.get_amount(id)) + 0.0001)) if inv else 0
	var equip := _equipment()
	return int(equip.items.get(id, 0)) if equip else 0

# ── Element picker ────────────────────────────────────────────────────────────

# Everything that can go in a cell: held elements, then crafted items that
# recipes use as ingredients (Synthesizer polymers).
func get_pickable() -> Array:
	var out: Array = []
	var inv := _inventory()
	if inv:
		var syms: Array = inv.get_all().keys()
		syms.sort_custom(func(a: String, b: String) -> bool:
			return int(ElementDB.get_element(a).get("atomic_number", 0)) < int(ElementDB.get_element(b).get("atomic_number", 0)))
		for s: String in syms:
			if float(inv.get_amount(s)) > 0.0:
				out.append(s)
	var equip := _equipment()
	if equip:
		var ingredient_items: Dictionary = {}
		for c: Dictionary in ElementDB.compounds.values():
			for k: Variant in (c.get("elements", {}) as Dictionary):
				if not ElementDB.elements.has(str(k)):
					ingredient_items[str(k)] = true
		var keys: Array = ingredient_items.keys()
		keys.sort()
		for k: String in keys:
			if int(equip.items.get(k, 0)) > 0:
				out.append(k)
	return out

func open_picker(idx: int) -> void:
	_picker_target = idx
	for c: Node in _picker_grid.get_children():
		_picker_grid.remove_child(c)
		c.queue_free()
	var first: Button = null
	for id: String in get_pickable():
		var b := _ingredient_tile(id, Vector2(64, 56), true)
		b.disabled = units_on_grid(id) >= units_held(id)
		b.pressed.connect(pick.bind(id))
		_picker_grid.add_child(b)
		if first == null and not b.disabled:
			first = b
	if _picker_grid.get_child_count() == 0:
		var none := JS.label("No samples yet.\nDig ore tiles to collect elements.", 14, JS.INK_SOFT)
		_picker_grid.add_child(none)
	_picker.visible = true
	if first:
		_focus_later(first)

# Place one unit of `id` in the slot the picker was opened for.
func pick(id: String) -> bool:
	var idx: int = _picker_target
	_close_picker()
	if idx < 0 or not is_slot_usable(idx) or units_on_grid(id) >= units_held(id):
		return false
	_set_cell(idx, id, 1)
	refresh()
	if idx < grid_slots.size():
		_focus_later(grid_slots[idx])
	return true

# Keyboard focus a frame later, only if the control is still on screen.
func _focus_later(c: Control) -> void:
	call_deferred("_focus_now", c)

func _focus_now(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree() and visible:
		c.grab_focus()

func _close_picker() -> void:
	if _picker:
		_picker.visible = false
	_picker_target = -1

# ── Recipe Book ───────────────────────────────────────────────────────────────

func _discovered(symbol: String) -> bool:
	var inv := _inventory()
	if inv and float(inv.get_amount(symbol)) > 0.0:
		return true
	var comp := get_tree().get_first_node_in_group("compendium")
	return comp != null and bool((comp.get("discovered") as Dictionary).get(symbol, false))

func _ingredient_name(id: String) -> String:
	if ElementDB.elements.has(id):
		return str(ElementDB.get_element(id).get("name", id))
	return str(ElementDB.get_compound_by_item(id).get("name", id))

# Hints for what is missing; empty when the player holds every ingredient.
func missing_for(compound: Dictionary) -> Array:
	var out: Array = []
	var req: Dictionary = compound.get("elements", {}) as Dictionary
	for k: Variant in req:
		var id: String = str(k)
		var need: int = int(round(float(req[k])))
		var have: int = units_held(id)
		if have >= need:
			continue
		if ElementDB.elements.has(id):
			if _discovered(id):
				out.append("%s ×%d more" % [id, need - have])
			else:
				var fam: String = str(ElementDB.get_element(id).get("category", ""))
				out.append("?? (%s)" % FAMILY_NAMES.get(fam, "element"))
		else:
			out.append("%s from the Synthesizer" % _ingredient_name(id))
	return out

func _is_book_recipe(c: Dictionary) -> bool:
	if (c.get("elements", {}) as Dictionary).is_empty():
		return false                       # assembled, not crafted (Resonance Engine)
	if bool(c.get("synthesizer_only", false)):
		return false                       # polymers belong to the Synthesizer
	return true

# Every recipe with its state, sorted: craftable here, craftable at a bench,
# then locked. [{key, compound, craftable, needs_bench, blocked, missing}]
func get_recipes() -> Array:
	var out: Array = []
	for c: Dictionary in ElementDB.compounds.values():
		if not _is_book_recipe(c):
			continue
		var missing: Array = missing_for(c)
		var needs_bench: bool = CraftingSystem.recipe_units(c) > POCKET_UNITS
		out.append({
			"key": str(c.get("game_item", "")), "compound": c,
			"craftable": missing.is_empty(), "needs_bench": needs_bench,
			"blocked": needs_bench and not near_bench, "missing": missing,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = _recipe_rank(a)
		var rb: int = _recipe_rank(b)
		if ra != rb:
			return ra < rb
		var aa: int = int(a["compound"].get("act", 0))
		var ab: int = int(b["compound"].get("act", 0))
		if aa != ab:
			return aa < ab
		return str(a["compound"].get("name", "")) < str(b["compound"].get("name", "")))
	return out

func _recipe_rank(e: Dictionary) -> int:
	if e["craftable"]:
		return 1 if e["blocked"] else 0
	return 2

func get_recipe(key: String) -> Dictionary:
	for e: Dictionary in get_recipes():
		if e["key"] == key:
			return e
	return {}

# Fill the grid with a recipe's pattern. Only when the player holds every
# ingredient and the grid tier allows it.
func fill_from_recipe(key: String) -> bool:
	var e: Dictionary = get_recipe(key)
	if e.is_empty():
		return false
	if not e["craftable"]:
		_set_status("Needs " + ", ".join(e["missing"]), JS.STAMP_RED)
		return false
	if e["blocked"]:
		_set_status("Needs a bench: Aldric's desk or a Field Station.", JS.STAMP_RED)
		return false
	_close_picker()
	for i: int in GRID_SIZE * GRID_SIZE:
		_set_cell(i, "", 0)
	var slots: Array = usable_slot_indices()
	var cells: Array = layout_for(e["compound"], slots.size())
	for n: int in cells.size():
		_set_cell(slots[n], cells[n][0], cells[n][1])
	_chosen_key = key
	_set_status("", JS.INK)
	refresh()
	return true

# One unit per cell while it fits; otherwise the largest stacks share cells.
# Returns [[id, count], ...] with at most `capacity` entries.
static func layout_for(compound: Dictionary, capacity: int) -> Array:
	var cells: Array = []
	var req: Dictionary = compound.get("elements", {}) as Dictionary
	for k: Variant in req:
		cells.append([str(k), int(round(float(req[k])))])
	while cells.size() < capacity:
		var big: int = -1
		for i: int in cells.size():
			if int(cells[i][1]) > 1 and (big < 0 or int(cells[i][1]) > int(cells[big][1])):
				big = i
		if big < 0:
			break
		cells[big][1] = int(cells[big][1]) - 1
		cells.insert(big + 1, [cells[big][0], 1])
	return cells

func _on_recipe_pressed(key: String) -> void:
	if fill_from_recipe(key):
		AudioManager.on_interact()

# ── Output, compare and crafting ──────────────────────────────────────────────

func current_output() -> Dictionary:
	# A recipe picked in the book wins while the grid still matches it, so
	# "Steel" really makes Steel and not the Steel Sword that shares Fe×4 + C.
	if _chosen_key != "":
		var chosen: Dictionary = ElementDB.get_compound_by_item(_chosen_key)
		if CraftingSystem.grid_matches(chosen, grid_contents, grid_counts):
			return chosen
	var compound: Dictionary = CraftingSystem.evaluate_grid(grid_contents, grid_counts)
	# Synthesizer-only polymers can't be made on the crafting grid
	if not compound.is_empty() and bool(compound.get("synthesizer_only", false)):
		return {}
	return compound

func _can_craft(compound: Dictionary) -> bool:
	if compound.is_empty():
		return false
	if CraftingSystem.recipe_units(compound) > POCKET_UNITS and not near_bench:
		return false
	return missing_for(compound).is_empty()

# Stat change versus what is equipped. [{stat, old, new, better, text}];
# better is 1 (green), -1 (red) or 0 (no change / not comparable).
func compare_with_equipped(compound: Dictionary) -> Array:
	var out: Array = []
	var p := _player()
	var category: String = str(compound.get("category", ""))
	if compound.has("weapon") and category in ["weapon_melee", "weapon_ranged"]:
		var w: Dictionary = compound["weapon"] as Dictionary
		var cur: Dictionary = {}
		var wn: Node = p.get_node_or_null("Weapon") if p else null
		if wn and wn.has_weapon():
			cur = CraftingSystem.get_compound_by_item(wn.get_weapon_name()).get("weapon", {}) as Dictionary
		out.append(_cmp("Damage", float(cur.get("damage", 0.0)), float(w.get("damage", 0.0)), "%d"))
		out.append(_cmp("Tier", float(cur.get("tier", 0)), float(w.get("tier", 0)), "%d"))
		var old_t: String = str(cur.get("type", "none")).capitalize()
		var new_t: String = str(w.get("type", "melee")).capitalize()
		out.append({ "stat": "Type", "old": old_t, "new": new_t, "better": 0,
			"text": "Type  %s → %s" % [old_t, new_t] })
	elif compound.has("armor"):
		var a: Dictionary = compound["armor"] as Dictionary
		var an: Node = p.get_node_or_null("Armor") if p else null
		var old_dr: float = an.get_damage_reduction() if an else 0.0
		out.append(_cmp("Damage reduction", roundf(old_dr * 100.0), roundf(float(a.get("damage_reduction", 0.0)) * 100.0), "%d%%"))
	return out

func _cmp(stat: String, old_v: float, new_v: float, fmt: String) -> Dictionary:
	var better: int = 0
	if new_v > old_v + 0.001:
		better = 1
	elif new_v < old_v - 0.001:
		better = -1
	var delta: String = ""
	if better != 0:
		delta = "  (%s%s)" % ["+" if better > 0 else "−", fmt % absf(new_v - old_v)]
	return { "stat": stat, "old": old_v, "new": new_v, "better": better,
		"text": "%s  %s → %s%s" % [stat, fmt % old_v, fmt % new_v, delta] }

func _on_craft_pressed() -> void:
	var inv := _inventory()
	if inv == null:
		_set_status("No inventory linked!", JS.STAMP_RED)
		return
	var preview: Dictionary = current_output()
	if preview.is_empty():
		return
	if not _can_craft(preview):
		refresh()
		return

	# Elements from the inventory; tier 3-5 armour also spends polymer items
	var equip := _equipment()
	var compound: Dictionary = CraftingSystem.try_craft_compound(preview, inv, equip)
	if compound.is_empty():
		if bool(preview.get("synthesizer_required", false)):
			_set_status("Need polymer intermediates from the Synthesizer!", JS.STAMP_RED)
		else:
			_set_status("Not enough elements!", JS.STAMP_RED)
		return
	AudioManager.on_craft()
	var msg: String = "Crafted: %s!" % str(compound.get("name", ""))
	# Auto-equip weapons and armour when crafted
	var category: String = str(compound.get("category", ""))
	var item: String = str(compound.get("game_item", ""))
	var p := _player()
	if category in ["weapon_melee", "weapon_ranged"]:
		if p and p.has_method("equip_weapon"):
			p.equip_weapon(item)
			msg = "Equipped: %s!" % str(compound.get("name", ""))
	elif category == "armor":
		if p and p.has_method("equip_armor"):
			p.equip_armor(item)
			msg = "Equipped: %s!" % str(compound.get("name", ""))
	elif item != "" and equip:
		# Everything else (engine components, alloys, consumables, story
		# items) is stored as an equipment item.
		equip.add_item(item, 1)
		ResonanceSystem.notify_part_crafted(item, equip)
	clear_grid()
	_set_status(msg, JS.INK_GREEN)

func _set_status(text: String, colour: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", colour)

# ── Refresh ───────────────────────────────────────────────────────────────────

func refresh() -> void:
	if _book == null:
		return
	_tier_label.text = "At a bench: full 3×3 grid." if near_bench else "Pocket grid: 2×2."
	_lock_note.visible = not near_bench
	_refresh_output()
	_refresh_recipe_book()

func _refresh_output() -> void:
	var compound: Dictionary = current_output()
	for c: Node in _compare_box.get_children():
		_compare_box.remove_child(c)
		c.queue_free()
	if compound.is_empty():
		_output_slot.text = "?"
		_output_slot.icon = null
		_out_name.text = ""
		_out_fact.text = "Click a square to add an element, or pick a recipe." if _grid_empty() else "No recipe matches this mix."
		_craft_button.disabled = true
		return
	_output_slot.text = "" if _recipe_icon(compound) else str(compound.get("formula", "?"))
	_output_slot.icon = _recipe_icon(compound)
	_out_name.text = "%s   %s" % [compound.get("name", ""), compound.get("formula", "")]
	_out_fact.text = str(compound.get("real_world_use", ""))
	for line: Dictionary in compare_with_equipped(compound):
		var colour: Color = JS.INK
		if int(line["better"]) > 0:
			colour = JS.INK_GREEN
		elif int(line["better"]) < 0:
			colour = JS.STAMP_RED
		_compare_box.add_child(JS.label(String(line["text"]), 14, colour))
	_craft_button.disabled = not _can_craft(compound)
	if CraftingSystem.recipe_units(compound) > POCKET_UNITS and not near_bench:
		_set_status("Needs a bench: Aldric's desk or a Field Station.", JS.STAMP_RED)
	elif not missing_for(compound).is_empty():
		_set_status("Needs " + ", ".join(missing_for(compound)), JS.STAMP_RED)
	elif _status.text.begins_with("Needs"):
		_set_status("", JS.INK)

func _grid_empty() -> bool:
	for i: int in GRID_SIZE * GRID_SIZE:
		if get_cell(i) != "":
			return false
	return true

func _refresh_recipe_book() -> void:
	for c: Node in _recipe_list.get_children():
		_recipe_list.remove_child(c)
		c.queue_free()
	_recipe_rows.clear()
	var recipes: Array = get_recipes()
	var ready_n: int = 0
	for e: Dictionary in recipes:
		if e["craftable"] and not e["blocked"]:
			ready_n += 1
		var row := _recipe_row(e)
		_recipe_list.add_child(row)
		_recipe_rows[e["key"]] = row
	_recipe_count.text = "%d ready to craft · %d recipes" % [ready_n, recipes.size()]

func _recipe_row(e: Dictionary) -> Button:
	var c: Dictionary = e["compound"]
	var locked: bool = not e["craftable"]
	var is_part: bool = str(c.get("category", "")) == ResonanceSystem.PART_CATEGORY
	var any_unknown: bool = false
	for k: Variant in (c.get("elements", {}) as Dictionary):
		if ElementDB.elements.has(str(k)) and not _discovered(str(k)):
			any_unknown = true
	var title: String = str(c.get("name", ""))
	var formula: String = str(c.get("formula", ""))
	if locked and is_part:
		title = "??? · Resonance Engine part"   # silhouette: don't spoil the part
		formula = "?"
	elif locked and any_unknown:
		formula = "?"
	var sub: String = str(c.get("real_world_use", ""))
	if locked:
		sub = "Needs " + ", ".join(e["missing"])

	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 54)
	row.focus_mode = Control.FOCUS_ALL
	row.tooltip_text = str(c.get("real_world_use", "")) if not locked else sub
	row.add_theme_stylebox_override("normal", JS.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4))
	row.add_theme_stylebox_override("hover", JS.box(Color(0.36, 0.22, 0.12, 0.10), Color(0, 0, 0, 0), 0, 4))
	row.add_theme_stylebox_override("pressed", JS.box(Color(0.36, 0.22, 0.12, 0.18), Color(0, 0, 0, 0), 0, 4))
	row.add_theme_stylebox_override("focus", JS.box(Color(0.36, 0.22, 0.12, 0.10), JS.BRASS, 1, 4))
	row.pressed.connect(_on_recipe_pressed.bind(e["key"]))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -8
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)

	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(42, 42)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", JS.box(JS.PAGE_DARK, JS.PAGE_EDGE, 2, 4))
	var icon := _recipe_icon(c)
	if icon and not (locked and is_part):
		var tr := TextureRect.new()
		tr.texture = icon
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.position = Vector2(5, 5)
		tr.size = Vector2(32, 32)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if locked:
			tr.modulate = Color(0.1, 0.07, 0.04, 0.55)   # silhouette
		frame.add_child(tr)
	else:
		var t := JS.label(formula if formula.length() <= 5 else formula.substr(0, 4) + "…", 11, JS.INK_SOFT if locked else JS.INK)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(t)
	h.add_child(frame)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := JS.label("%s   %s" % [title, formula], 15, JS.INK_SOFT if locked else JS.INK)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_l)
	var sub_l := JS.label(sub, 12, JS.STAMP_RED.lerp(JS.INK_SOFT, 0.5) if locked else JS.INK_SOFT)
	sub_l.clip_text = true
	sub_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sub_l)
	h.add_child(v)

	if e["needs_bench"] and not near_bench:
		var tag := JS.label(" needs a bench ", 11, JS.STAMP_RED)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.add_theme_stylebox_override("normal", JS.box(Color(0, 0, 0, 0), JS.STAMP_RED, 1, 3))
		h.add_child(tag)
	if locked:
		row.modulate = Color(1, 1, 1, 0.75)
	return row

static func _recipe_icon(c: Dictionary) -> Texture2D:
	var paths: Array = [ICON_DIR + str(c.get("game_item", "")) + ".png"]
	if c.has("weapon"):
		paths.append(ICON_DIR + "_weapon.png")
	elif c.has("armor"):
		paths.append(ICON_DIR + "_armour.png")
	for path: String in paths:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

# ── Building the book ─────────────────────────────────────────────────────────

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
	JS.make_book(_book, BOOK_SIZE)

	var page_w: float = (BOOK_SIZE.x - 64.0) / 2.0
	var page_h: float = BOOK_SIZE.y - 76.0
	var left := JS.make_page(_book, Vector2(28, 24), Vector2(page_w, page_h), true)
	var right := JS.make_page(_book, Vector2(36 + page_w, 24), Vector2(page_w, page_h), false)
	_build_grid_page(left, page_w, page_h)
	_build_recipe_page(right, page_w, page_h)

	var hints := JS.label("Click a square: add / clear    Right-click: stack +1    Click a recipe: fill    [R / Esc] close", 12, JS.STITCH)
	hints.position = Vector2(40, BOOK_SIZE.y - 42)
	_book.add_child(hints)

func _build_grid_page(page: Control, page_w: float, page_h: float) -> void:
	var title := JS.label("Crafting", 22, JS.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 10)
	title.size = Vector2(page_w, 30)
	page.add_child(title)
	page.add_child(JS.ornament(Vector2(page_w / 2.0, 46)))
	_tier_label = JS.label("", 14, JS.INK_SOFT)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.position = Vector2(0, 56)
	_tier_label.size = Vector2(page_w, 20)
	page.add_child(_tier_label)

	var grid_origin := Vector2(34, 86)
	for i: int in GRID_SIZE * GRID_SIZE:
		var b := Button.new()
		@warning_ignore("integer_division")
		var row: int = i / GRID_SIZE
		b.position = grid_origin + Vector2(i % GRID_SIZE, row) * (SLOT_PX + SLOT_GAP)
		b.size = Vector2(SLOT_PX, SLOT_PX)
		b.focus_mode = Control.FOCUS_ALL
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_slot_pressed.bind(i))
		b.gui_input.connect(_on_slot_gui_input.bind(i))
		page.add_child(b)
		grid_slots.append(b)
	var grid_px: float = GRID_SIZE * SLOT_PX + (GRID_SIZE - 1) * SLOT_GAP
	_lock_note = JS.label("3×3 needs a bench", 12, JS.STAMP_RED)
	_lock_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_note.position = grid_origin + Vector2(0, grid_px + 4)
	_lock_note.size = Vector2(grid_px, 18)
	page.add_child(_lock_note)

	var arrow := JS.label("→", 34, JS.INK_SOFT)
	arrow.position = Vector2(grid_origin.x + grid_px + 18, grid_origin.y + grid_px / 2.0 - 26)
	page.add_child(arrow)
	_output_slot = Button.new()
	_output_slot.size = Vector2(88, 88)
	_output_slot.position = Vector2(grid_origin.x + grid_px + 66, grid_origin.y + grid_px / 2.0 - 44)
	_output_slot.focus_mode = Control.FOCUS_NONE
	_output_slot.expand_icon = true
	_output_slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_output_slot.add_theme_font_size_override("font_size", 15)
	var out_style := JS.box(JS.PAGE_DARK, JS.BRASS, 3, 6)
	out_style.set_content_margin_all(14)
	for s: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_output_slot.add_theme_stylebox_override(s, out_style)
	_output_slot.add_theme_color_override("font_color", JS.INK)
	_output_slot.add_theme_color_override("font_hover_color", JS.INK)
	_output_slot.pressed.connect(_on_craft_pressed)
	_output_slot.tooltip_text = "Craft"
	page.add_child(_output_slot)

	_out_name = JS.label("", 18, JS.INK)
	_out_name.position = Vector2(24, 336)
	_out_name.size = Vector2(page_w - 48, 26)
	_out_name.clip_text = true
	_out_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	page.add_child(_out_name)
	_out_fact = JS.label("", 13, JS.INK_SOFT)
	_out_fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_out_fact.position = Vector2(24, 362)
	_out_fact.size = Vector2(page_w - 48, 38)
	_out_fact.max_lines_visible = 2
	page.add_child(_out_fact)
	_compare_box = VBoxContainer.new()
	_compare_box.position = Vector2(24, 402)
	_compare_box.size = Vector2(page_w - 48, 60)
	_compare_box.add_theme_constant_override("separation", 0)
	page.add_child(_compare_box)

	_status = JS.label("", 13, JS.INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.position = Vector2(24, page_h - 56)
	_status.size = Vector2(page_w - 190, 44)
	_status.max_lines_visible = 2
	page.add_child(_status)
	_craft_button = JS.button("Craft", 16)
	_craft_button.position = Vector2(page_w - 150, page_h - 52)
	_craft_button.size = Vector2(124, 36)
	_craft_button.pressed.connect(_on_craft_pressed)
	page.add_child(_craft_button)

	# Picker overlay: a slip of paper laid over the grid.
	_picker = Panel.new()
	_picker.position = Vector2(16, 76)
	_picker.size = Vector2(page_w - 32, 300)
	var slip := JS.box(JS.PAGE, JS.INK_SOFT, 2, 6)
	slip.shadow_color = Color(0, 0, 0, 0.3)
	slip.shadow_size = 6
	_picker.add_theme_stylebox_override("panel", slip)
	_picker.visible = false
	page.add_child(_picker)
	var pt := JS.label("Choose an ingredient", 16, JS.INK)
	pt.position = Vector2(14, 8)
	_picker.add_child(pt)
	var cancel := JS.button("Cancel", 13)
	cancel.position = Vector2(_picker.size.x - 92, 8)
	cancel.size = Vector2(78, 26)
	cancel.pressed.connect(_close_picker)
	_picker.add_child(cancel)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 42)
	scroll.size = _picker.size - Vector2(24, 54)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_picker.add_child(scroll)
	_picker_grid = GridContainer.new()
	_picker_grid.columns = 6
	_picker_grid.add_theme_constant_override("h_separation", 6)
	_picker_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_picker_grid)

	_apply_slot_looks()

func _build_recipe_page(page: Control, page_w: float, page_h: float) -> void:
	var title := JS.label("Recipe Book", 22, JS.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 10)
	title.size = Vector2(page_w, 30)
	page.add_child(title)
	page.add_child(JS.ornament(Vector2(page_w / 2.0, 46)))
	_recipe_count = JS.label("", 13, JS.INK_SOFT)
	_recipe_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recipe_count.position = Vector2(0, 56)
	_recipe_count.size = Vector2(page_w, 20)
	page.add_child(_recipe_count)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 82)
	scroll.size = Vector2(page_w - 32, page_h - 96)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_recipe_list)

# A periodic-table tile for an element (coloured by family) or a parchment
# tile for a crafted ingredient. Used by the picker.
func _ingredient_tile(id: String, tile_size: Vector2, show_amount: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = tile_size
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = _ingredient_name(id)
	var bg: Color = _tile_colour(id)
	var txt: String = id if ElementDB.elements.has(id) else _ingredient_name(id)
	if show_amount:
		var inv := _inventory()
		if ElementDB.elements.has(id) and inv:
			txt += "\n" + inv.format_amount(id, inv.get_amount(id))
		else:
			txt += "  ×%d" % units_held(id)
	b.text = txt
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 14 if ElementDB.elements.has(id) else 10)
	var fg: Color = Color.WHITE if ElementDB.elements.has(id) else JS.INK
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))
	b.add_theme_stylebox_override("normal", JS.box(bg, bg.darkened(0.4), 2, 3))
	b.add_theme_stylebox_override("hover", JS.box(bg.lightened(0.12), bg.darkened(0.4), 2, 3))
	b.add_theme_stylebox_override("pressed", JS.box(bg.darkened(0.1), bg.darkened(0.4), 2, 3))
	b.add_theme_stylebox_override("focus", JS.box(bg.lightened(0.12), JS.BRASS, 3, 3))
	b.add_theme_stylebox_override("disabled", JS.box(bg.lerp(JS.PAGE_EDGE, 0.7), bg.darkened(0.2), 2, 3))
	return b

func _tile_colour(id: String) -> Color:
	if ElementDB.elements.has(id):
		var cat: String = str(ElementDB.get_element(id).get("category", ""))
		return Color(CATEGORY_COLOURS.get(cat, "#7a6248"))
	return JS.PAGE_DARK

func _apply_slot_looks() -> void:
	for i: int in grid_slots.size():
		_style_slot(i)

func _style_slot(idx: int) -> void:
	var b: Button = grid_slots[idx]
	var id: String = get_cell(idx)
	var usable: bool = is_slot_usable(idx)
	b.disabled = not usable
	b.focus_mode = Control.FOCUS_ALL if usable else Control.FOCUS_NONE
	var bg: Color = JS.PAGE_DARK
	var fg: Color = JS.INK_SOFT
	var text: String = ""
	if id != "":
		bg = _tile_colour(id)
		fg = Color.WHITE if ElementDB.elements.has(id) else JS.INK
		text = id if ElementDB.elements.has(id) else _ingredient_name(id)
		var n: int = get_cell_count(idx)
		if n > 1:
			text += "\n×%d" % n
	elif not usable:
		text = "locked"
	b.text = text
	b.tooltip_text = _ingredient_name(id) if id != "" else ("Needs a bench" if not usable else "Add an ingredient")
	b.add_theme_font_size_override("font_size", 20 if id != "" and ElementDB.elements.has(id) else 11)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(JS.INK_SOFT, 0.7))
	b.add_theme_stylebox_override("normal", JS.box(bg, JS.PAGE_EDGE if id == "" else bg.darkened(0.4), 2, 4))
	b.add_theme_stylebox_override("hover", JS.box(bg.lightened(0.1), JS.INK_SOFT, 2, 4))
	b.add_theme_stylebox_override("pressed", JS.box(bg.darkened(0.08), JS.INK_SOFT, 2, 4))
	b.add_theme_stylebox_override("focus", JS.box(Color(0, 0, 0, 0), JS.BRASS, 3, 4))
	b.add_theme_stylebox_override("disabled", JS.box(Color(0.36, 0.22, 0.12, 0.22), Color(0.36, 0.22, 0.12, 0.3), 1, 4))
