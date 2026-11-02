extends Node

# Crafting usability (SYSTEMS_UX_REVIEW.md §3.3): element picker, Recipe Book,
# 2×2 pocket grid vs 3×3 bench grid, equipment compare.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

func run(t: Node) -> void:
	var w: Node = WORLD_SCENE.instantiate()
	add_child(w)
	await _frames(3)
	var ui: Node = UIManager.get_menu("crafting")
	var p: Node2D = w.get_node("Player") as Node2D
	var inv: Node = p.get_node("Inventory")
	inv.clear()
	# Park the player far from every bench (the lab desk sits in the village).
	p.global_position = Vector2(-5000, -5000)
	UIManager.open("crafting")
	await _frames(1)
	t._check("crafting menu is a field-journal spread", ui.visible and ui.get_node_or_null("../Panel") == ui)
	t._check("crafting keeps PROCESS_MODE_ALWAYS", ui.process_mode == Node.PROCESS_MODE_ALWAYS)

	_test_picker(t, ui, inv)
	_test_tiers(t, ui, w, p, inv)
	_test_recipe_book(t, ui, p, inv)
	_test_compare(t, ui, p)

	UIManager.close_all()
	w.queue_free()
	await _frames(2)

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _test_picker(t: Node, ui: Node, inv: Node) -> void:
	ui.clear_grid()
	inv.add_element("H", 2.0)
	inv.add_element("O", 1.0)
	ui._on_slot_pressed(0)
	t._check("clicking an empty slot opens the picker", ui._picker.visible)
	t._check("picker lists held elements", ui.get_pickable().has("H") and ui.get_pickable().has("O"))
	t._check("picker places an element", ui.pick("H") and ui.get_cell(0) == "H")
	t._check("picker closes after a pick", not ui._picker.visible)
	ui._on_slot_pressed(1)
	ui.pick("H")
	ui._on_slot_pressed(3)
	ui.pick("O")
	t._check_eq("H, H, O makes water", str(ui.current_output().get("game_item", "")), "water_flask")
	ui._on_slot_pressed(2)
	t._check("can't pick more H than held", not ui.pick("H"))
	ui._on_slot_pressed(1)
	t._check("clicking a filled slot clears it", ui.get_cell(1) == "")
	t._check("right-click stacks a second unit", ui.add_to_stack(0) and ui.get_cell_count(0) == 2)
	t._check_eq("stacked H×2 + O still makes water", str(ui.current_output().get("game_item", "")), "water_flask")
	ui.clear_grid()

func _test_tiers(t: Node, ui: Node, w: Node, p: Node2D, inv: Node) -> void:
	ui.refresh_bench()
	t._check("away from a bench: pocket grid", not ui.near_bench)
	t._check("top-left 2×2 usable", ui.is_slot_usable(0) and ui.is_slot_usable(1) and ui.is_slot_usable(3) and ui.is_slot_usable(4))
	t._check("outer ring locked", not ui.is_slot_usable(2) and not ui.is_slot_usable(5) and not ui.is_slot_usable(8))
	t._check_eq("4 usable slots", ui.usable_slot_indices().size(), 4)
	ui._on_slot_pressed(8)
	t._check("locked slot ignores clicks", not ui._picker.visible)

	inv.add_element("Fe", 4.0)
	inv.add_element("C", 1.0)
	var steel: Dictionary = ui.get_recipe("steel_ingot")
	t._check("steel (5 units) needs a bench", steel["craftable"] and steel["needs_bench"] and steel["blocked"])
	t._check("steel can't fill the pocket grid", not ui.fill_from_recipe("steel_ingot"))

	var desk: Node = get_tree().get_first_node_in_group("lab_desk")
	t._check("lab desk is a crafting bench", desk != null and desk.is_in_group("crafting_bench"))
	p.global_position = (desk as Node2D).global_position + Vector2(20, 0)
	ui.refresh_bench()
	t._check("near the desk: full 3×3", ui.near_bench and ui.usable_slot_indices().size() == 9)
	t._check("steel fills at the bench", ui.fill_from_recipe("steel_ingot"))
	t._check_eq("bench output is steel", str(ui.current_output().get("game_item", "")), "steel_ingot")
	ui._on_craft_pressed()
	var equip: Node = p.get_node("Equipment")
	t._check("book's Steel crafts Steel, not the Steel Sword", int(equip.items.get("steel_ingot", 0)) == 1 and not inv.has_element("Fe", 0.5))

	# A custom bench with its own interact_radius (Field Stations do this).
	var station := Node2D.new()
	station.set_script(_radius_script())
	station.add_to_group("crafting_bench")
	w.add_child(station)
	station.global_position = Vector2(4000, 4000)
	p.global_position = Vector2(4000 + 70, 4000)
	ui.refresh_bench()
	t._check("interact_radius 80 reaches 70 px", ui.near_bench)
	p.global_position = Vector2(4000 + 120, 4000)
	ui.refresh_bench()
	t._check("out of range: pocket again, outer cells cleared", not ui.near_bench and ui.get_cell(8) == "")
	station.queue_free()
	ui.clear_grid()

func _radius_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node2D\nvar interact_radius: float = 80.0\n"
	s.reload()
	return s

func _test_recipe_book(t: Node, ui: Node, p: Node2D, inv: Node) -> void:
	p.global_position = Vector2(-5000, -5000)
	ui.refresh_bench()
	var recipes: Array = ui.get_recipes()
	t._check("recipe book lists recipes", recipes.size() > 40)
	t._check("first recipe is craftable here", recipes[0]["craftable"] and not recipes[0]["blocked"])
	var seen_locked: bool = false
	var order_ok: bool = true
	for e: Dictionary in recipes:
		if not e["craftable"]:
			seen_locked = true
		elif seen_locked:
			order_ok = false
	t._check("craftable recipes sit above locked ones", order_ok)
	var keys: Array = recipes.map(func(e: Dictionary) -> String: return e["key"])
	t._check("no Synthesizer polymers or engine assembly in the book",
		not keys.has("resonance_engine") and not keys.has("pvc_sheet"))

	t._check("water fills the grid", ui.fill_from_recipe("water_flask"))
	t._check_eq("auto-fill output is water", str(ui.current_output().get("game_item", "")), "water_flask")
	t._check("craft enabled after auto-fill", not ui._craft_button.disabled)

	var salt: Dictionary = ui.get_recipe("salt_crystal")
	t._check("salt not craftable without Na, Cl", not salt["craftable"])
	t._check("locked recipe won't fill", not ui.fill_from_recipe("salt_crystal"))
	var comp: Node = get_tree().get_first_node_in_group("compendium")
	if comp:
		comp.discovered.erase("Cl")
		comp.discovered["Na"] = true
	salt = ui.get_recipe("salt_crystal")
	var hint: String = ", ".join(salt["missing"])
	t._check("hint names a discovered element", hint.contains("Na ×1 more"))
	t._check("hint hides an undiscovered element as ?? + family", hint.contains("?? (halogen)") and not hint.contains("Cl"))

	# Crafting from the book consumes the elements.
	ui._on_craft_pressed()
	t._check("crafting water spends H and O", not inv.has_element("H", 0.5) and not inv.has_element("O", 0.5))

	# U4O8 is 12 units: stacks let it fit nine cells at a bench.
	var cells: Array = ui.layout_for(ElementDB.get_compound_by_item("uranium_cell"), 9)
	var total: int = 0
	for c: Array in cells:
		total += int(c[1])
	t._check("12-unit recipe lays out in 9 cells", cells.size() == 9 and total == 12)

func _test_compare(t: Node, ui: Node, p: Node2D) -> void:
	p.equip_weapon("bronze_sword")
	var lines: Array = ui.compare_with_equipped(ElementDB.get_compound_by_item("steel_sword"))
	var dmg: Dictionary = lines[0]
	var steel_dmg: float = float(ElementDB.get_compound_by_item("steel_sword")["weapon"]["damage"])
	t._check_eq("compare damage: old is bronze sword", float(dmg["old"]), 12.0)
	t._check_eq("compare damage: new is steel sword", float(dmg["new"]), steel_dmg)
	t._check_eq("steel sword is better (green)", int(dmg["better"]), 1)
	t._check_eq("tier goes up", int(lines[1]["better"]), 1)
	t._check_eq("type line present", str(lines[2]["stat"]), "Type")
	p.equip_weapon("steel_sword")
	lines = ui.compare_with_equipped(ElementDB.get_compound_by_item("bronze_sword"))
	t._check_eq("bronze vs steel is worse (red)", int(lines[0]["better"]), -1)

	p.get_node("Armor").unequip()
	var arm: Array = ui.compare_with_equipped(ElementDB.get_compound_by_item("limestone_jerkin"))
	var jerkin_dr: float = roundf(float(ElementDB.get_compound_by_item("limestone_jerkin")["armor"]["damage_reduction"]) * 100.0)
	t._check("armour compare shows damage-reduction %", arm.size() == 1 and float(arm[0]["new"]) == jerkin_dr and int(arm[0]["better"]) == 1)
	p.equip_armor("iron_plate_armor")
	arm = ui.compare_with_equipped(ElementDB.get_compound_by_item("limestone_jerkin"))
	t._check_eq("jerkin vs iron plate is worse", int(arm[0]["better"]), -1)
	t._check("non-equipment has no compare", ui.compare_with_equipped(ElementDB.get_compound_by_item("water_flask")).is_empty())
