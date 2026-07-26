extends Node

# Headless test runner for the systems that carry game-loop risk.
#
# Run with:
#   godot --headless res://tests/test_runner.tscn
#
# Exits with code 0 when every assertion passes, 1 otherwise, so it can be
# wired into CI. Autoloads are available because this runs as a real scene.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_SCENE  := preload("res://scenes/world/enemy.tscn")
const BOSS_SCENE   := preload("res://scenes/world/boss.tscn")

var _passed: int = 0
var _failed: int = 0

func _ready() -> void:
	print("=== Element Heroes — test run ===")
	_test_data_integrity()
	_test_compound_keying()
	_test_crafting_pipeline()
	_test_null_sanitization()
	_test_combat_damage()
	_test_player_death_and_respawn()
	_test_resonance_data()
	_test_resonance_assembly()
	_test_save_migration()

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)

# ── Assertions ────────────────────────────────────────────────────────────────

func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		printerr("  FAIL  %s" % label)

func _check_eq(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		printerr("  FAIL  %s  (got %s, expected %s)" % [label, str(actual), str(expected)])

# ── Tests ─────────────────────────────────────────────────────────────────────

func _test_data_integrity() -> void:
	print("- data integrity")
	_check_eq("118 elements loaded", ElementDB.elements.size(), 118)
	_check_eq("118 handling entries loaded", ElementDB.handling.size(), 118)
	_check_eq("18 creatures loaded", ElementDB.enemies.size(), 18)
	_check("tier multipliers loaded", ElementDB.enemy_tier_multipliers.has("expert"))

func _test_compound_keying() -> void:
	print("- compound keying (no silent recipe loss)")
	# compounds.json holds 64 recipes. Keying by formula previously collapsed
	# five duplicate-formula pairs and dropped them entirely.
	_check_eq("all 64 recipes loaded", ElementDB.compounds.size(), 64)

	# Both halves of every formula collision must survive.
	for pair: Array in [
		["steel_ingot", "steel_sword"],
		["bronze_ingot", "bronze_sword"],
		["thermite_charge", "thermite_blade"],
		["chlorine_canister", "chlorine_bomb"],
		["uranium_cell", "uranium_shell"],
	]:
		_check("both survive: %s / %s" % [pair[0], pair[1]],
			not ElementDB.get_compound_by_item(str(pair[0])).is_empty()
			and not ElementDB.get_compound_by_item(str(pair[1])).is_empty())

	_check("formula lookup still works",
		not ElementDB.get_compound("H2O").is_empty())

	# The engine's fuel cell must no longer collide with the uranium shell,
	# otherwise the Act 3 endgame is unreachable.
	var cell: Dictionary = ElementDB.get_compound_by_item("uranium_cell")
	var shell: Dictionary = ElementDB.get_compound_by_item("uranium_shell")
	_check("fuel cell and shell have distinct recipes",
		cell.get("elements", {}) != shell.get("elements", {}))

	# Ambiguous ingredient maps must resolve deterministically to the ranked
	# winner (the weapon), not to whichever entry iteration happened to hit.
	var bronze_match: Dictionary = ElementDB.match_recipe({"Cu": 3, "Sn": 1})
	_check_eq("ambiguous recipe resolves to weapon",
		str(bronze_match.get("game_item", "")), "bronze_sword")
	var repeat: Dictionary = ElementDB.match_recipe({"Cu": 3, "Sn": 1})
	_check_eq("recipe matching is stable across calls",
		str(repeat.get("game_item", "")), str(bronze_match.get("game_item", "")))

	# The fuel cell recipe must be reachable via normal crafting.
	var cell_match: Dictionary = ElementDB.match_recipe(cell.get("elements", {}))
	_check_eq("fuel cell is craftable", str(cell_match.get("game_item", "")), "uranium_cell")

func _test_crafting_pipeline() -> void:
	print("- crafting pipeline (grid -> recipe -> inventory)")
	var player: Node = PLAYER_SCENE.instantiate()
	add_child(player)
	var inv: Node = player.get_node("Inventory")

	# JSON parses recipe counts as FLOAT; the crafting grid tallies them as
	# INT. Dictionary `==` is type-strict, so before the numeric comparison
	# fix this path matched nothing and the game was uncraftable.
	var bronze_grid: Array = [["Cu", "Cu", "Cu"], ["Sn", "", ""], ["", "", ""]]
	var matched: Dictionary = CraftingSystem.evaluate_grid(bronze_grid)
	_check("grid matches a recipe at all", not matched.is_empty())
	_check_eq("grid resolves to bronze sword", str(matched.get("game_item", "")), "bronze_sword")

	# Crafting must fail without the ingredients...
	_check("craft blocked without elements",
		CraftingSystem.try_craft(bronze_grid, inv).is_empty())

	# ...and succeed with them, consuming exactly what the recipe requires.
	inv.add_element("Cu", 3.0)
	inv.add_element("Sn", 1.0)
	var crafted: Dictionary = CraftingSystem.try_craft(bronze_grid, inv)
	_check("craft succeeds with elements", not crafted.is_empty())
	_check_eq("correct item crafted", str(crafted.get("game_item", "")), "bronze_sword")
	_check_eq("copper consumed", inv.get_amount("Cu"), 0.0)
	_check_eq("tin consumed", inv.get_amount("Sn"), 0.0)

	# Water is the canonical teaching recipe — it must work.
	var water_grid: Array = [["H", "O", "H"], ["", "", ""], ["", "", ""]]
	inv.add_element("H", 2.0)
	inv.add_element("O", 1.0)
	var water: Dictionary = CraftingSystem.try_craft(water_grid, inv)
	_check_eq("H2O craftable", str(water.get("formula", "")), "H2O")

	# An unknown combination must not match anything.
	var junk_grid: Array = [["Au", "Au", "Au"], ["Au", "Au", "Au"], ["Au", "Au", "Au"]]
	_check("nonsense recipe rejected", CraftingSystem.evaluate_grid(junk_grid).is_empty())

	# An empty grid must not match the Resonance Engine (elements: {}).
	var empty_grid: Array = [["", "", ""], ["", "", ""], ["", "", ""]]
	_check("empty grid matches nothing", CraftingSystem.evaluate_grid(empty_grid).is_empty())

	# Every engine component must be craftable from its own recipe.
	var uncraftable: Array = []
	for c: Dictionary in ResonanceSystem.get_part_compounds():
		var m: Dictionary = ElementDB.match_recipe(c.get("elements", {}) as Dictionary)
		if str(m.get("game_item", "")) != str(c.get("game_item", "")):
			uncraftable.append(str(c.get("game_item", "")))
	_check_eq("all 6 engine components craftable", uncraftable.size(), 0)

	player.queue_free()

func _test_null_sanitization() -> void:
	print("- JSON null sanitization")
	# 14 of 18 creatures carry an explicit "aura": null in enemy_data.json.
	# Unsanitized this returns nil and breaks `var s: String = d.get(...)`.
	var nulls_found: int = 0
	for creature_id: String in ElementDB.enemies:
		var d: Dictionary = ElementDB.enemies[creature_id]
		if typeof(d.get("aura")) == TYPE_NIL:
			nulls_found += 1
	_check_eq("no nil aura values survive load", nulls_found, 0)

	var shambler: Dictionary = ElementDB.get_enemy_data("ashburn_shambler")
	_check("known creature resolves", not shambler.is_empty())
	var aura: String = shambler.get("aura", "")
	_check_eq("null aura reads as empty string", aura, "")

	var djinn: Dictionary = ElementDB.get_enemy_data("static_djinn")
	_check_eq("real aura value preserved", str(djinn.get("aura", "")), "lightning")

	var nested: Dictionary = ElementDB.sanitize_nulls({"a": null, "b": {"c": null}, "d": [null, 1]})
	_check_eq("nested dict null sanitized", (nested["b"] as Dictionary)["c"], "")
	_check_eq("array null sanitized", (nested["d"] as Array)[0], "")
	_check_eq("non-null preserved", (nested["d"] as Array)[1], 1)

func _make_enemy(creature_id: String, tier: String = "basic") -> Node:
	var e: Node = ENEMY_SCENE.instantiate()
	e.creature_id = creature_id
	e.tier = tier
	add_child(e)
	return e

func _test_combat_damage() -> void:
	print("- combat damage resolution")

	# No creature or boss declares a "physical" resistance. When a missing key
	# defaulted to 1.0 (fully immune) every ordinary attack dealt zero damage,
	# so nothing in the game could actually be killed.
	var e: Node = _make_enemy("ashburn_shambler")
	var start_hp: float = e.hp
	_check("enemy has HP", start_hp > 0.0)
	e.take_damage(10.0)
	_check("physical damage applies", e.hp < start_hp)
	_check_eq("physical damage is unreduced", e.hp, start_hp - 10.0)
	e.queue_free()

	# Declared resistance still reduces damage: iron_hulk has poison 1.0.
	var hulk: Node = _make_enemy("iron_hulk")
	var hulk_hp: float = hulk.hp
	hulk.take_damage(50.0, "poison")
	_check_eq("full resistance blocks damage", hulk.hp, hulk_hp)
	# burn 0.5 halves the hit; the creature's passive DR then applies on top.
	hulk.take_damage(20.0, "burn")
	_check_eq("partial resistance halves damage",
		hulk.hp, hulk_hp - 20.0 * 0.5 * (1.0 - hulk.passive_dr))
	hulk.queue_free()

	# Negative resistance is a weakness and must amplify damage.
	var crawler: Node = _make_enemy("carbon_crawler")
	var crawler_hp: float = crawler.hp
	crawler.take_damage(10.0, "burn")   # burn -0.5 -> 150%
	_check_eq("weakness amplifies damage",
		crawler.hp, crawler_hp - 10.0 * 1.5 * (1.0 - crawler.passive_dr))
	_check("weakness deals more than base", crawler_hp - crawler.hp > 10.0)
	crawler.queue_free()

	# Tier scaling must raise HP.
	var basic: Node = _make_enemy("iron_hulk", "basic")
	var expert: Node = _make_enemy("iron_hulk", "expert")
	_check("expert tier has more HP than basic", expert.max_hp > basic.max_hp)
	basic.queue_free()
	expert.queue_free()

	# Bosses share the same resistance path.
	var boss: Node = BOSS_SCENE.instantiate()
	boss.boss_id = "peroxis"
	add_child(boss)
	var boss_hp: float = boss.hp
	_check("boss has HP", boss_hp > 0.0)
	# With no player present the weapon tier reads 0, so the sub-tier gate
	# applies a 10% multiplier rather than blocking damage outright.
	boss.take_damage(100.0)
	_check("boss takes physical damage", boss.hp < boss_hp)
	boss.queue_free()

func _test_player_death_and_respawn() -> void:
	print("- player death / respawn")
	var player: Node = PLAYER_SCENE.instantiate()
	add_child(player)

	_check("starts alive", not player.is_dead)
	_check_eq("starts at full HP", player.get_health(), player.get_max_health())

	var died_fired: Array = [false]
	player.died.connect(func() -> void: died_fired[0] = true)

	# Overkill in one hit — i-frames must not prevent the killing blow.
	player.take_damage(9999.0)
	_check("dies at 0 HP", player.is_dead)
	_check_eq("HP floors at 0", player.get_health(), 0.0)
	_check("died signal fired", died_fired[0])

	# Damage while dead must not re-fire death.
	died_fired[0] = false
	player.take_damage(50.0)
	_check("no double death", not died_fired[0])

	var respawned_fired: Array = [false]
	player.respawned.connect(func() -> void: respawned_fired[0] = true)
	player.respawn(Vector2(192, 192))
	_check("alive after respawn", not player.is_dead)
	_check_eq("HP restored", player.get_health(), player.get_max_health())
	_check_eq("moved to spawn", player.global_position, Vector2(192, 192))
	_check("respawned signal fired", respawned_fired[0])

	# Healing must clamp at max.
	player.take_damage(10.0)
	player.heal(9999.0)
	_check_eq("heal clamps to max", player.get_health(), player.get_max_health())

	player.queue_free()

func _test_resonance_data() -> void:
	print("- resonance data")
	ResonanceSystem.reset()
	_check_eq("six engine components defined", ResonanceSystem.total_parts(), 6)
	var keys: Array = ResonanceSystem.get_part_keys()
	_check("uranium_cell is a component", "uranium_cell" in keys)
	_check("engine compound resolves", not ResonanceSystem.get_engine_compound().is_empty())
	_check_eq("component display name",
		ResonanceSystem.display_name_for("uranium_cell"), "Uranium Fuel Cell")
	_check("non-component rejected", not ResonanceSystem.is_part("bronze_sword"))
	# The Act 3 fuel cell must sort last.
	_check_eq("components ordered by act", str(keys[keys.size() - 1]), "uranium_cell")

func _test_resonance_assembly() -> void:
	print("- resonance assembly")
	ResonanceSystem.reset()
	var player: Node = PLAYER_SCENE.instantiate()
	add_child(player)
	var equip: Node = player.get_node("Equipment")

	_check("not assembled initially", not ResonanceSystem.is_assembled)
	_check("has no parts initially", not ResonanceSystem.has_all_parts(equip))
	_check_eq("all six missing", ResonanceSystem.missing_parts(equip).size(), 6)
	_check("assembly blocked without parts", ResonanceSystem.assemble(equip).is_empty())

	var keys: Array = ResonanceSystem.get_part_keys()
	# Add five of six — assembly must still be blocked.
	for i: int in range(keys.size() - 1):
		equip.add_item(str(keys[i]), 1)
	_check("five parts is not enough", not ResonanceSystem.has_all_parts(equip))
	_check("assembly blocked at 5/6", ResonanceSystem.assemble(equip).is_empty())

	var ready_fired: Array = [false]
	ResonanceSystem.engine_ready.connect(func() -> void: ready_fired[0] = true)

	var last_key: String = str(keys[keys.size() - 1])
	equip.add_item(last_key, 1)
	ResonanceSystem.notify_part_crafted(last_key, equip)
	_check("all parts held", ResonanceSystem.has_all_parts(equip))
	_check("engine_ready fired", ready_fired[0])

	var assembled_name: Array = [""]
	ResonanceSystem.engine_assembled.connect(func(n: String) -> void: assembled_name[0] = n)

	var engine: Dictionary = ResonanceSystem.assemble(equip)
	_check("assembly succeeds", not engine.is_empty())
	_check("is_assembled set", ResonanceSystem.is_assembled)
	_check_eq("engine name broadcast", assembled_name[0], "Resonance Engine")
	_check_eq("engine item granted", int(equip.items.get("resonance_engine", 0)), 1)

	var leftover: int = 0
	for k: String in keys:
		leftover += int(equip.items.get(str(k), 0))
	_check_eq("all components consumed", leftover, 0)

	_check("cannot assemble twice", ResonanceSystem.assemble(equip).is_empty())

	player.queue_free()

func _test_save_migration() -> void:
	print("- save migration")
	ResonanceSystem.reset()
	ResonanceSystem.is_assembled = true
	var blob: Dictionary = ResonanceSystem.serialize()
	ResonanceSystem.reset()
	_check("reset clears flag", not ResonanceSystem.is_assembled)
	ResonanceSystem.deserialize(blob)
	_check("assembled flag round-trips", ResonanceSystem.is_assembled)

	var migrated: Dictionary = SaveSystem._migrate({"version": 1}, 1)
	_check_eq("v1 migrates to current", int(migrated.get("version", 0)), SaveSystem.SAVE_VERSION)
	_check("v1 gains dug_tiles", migrated.has("dug_tiles"))
	_check("v1 gains resonance block", migrated.has("resonance"))

	var migrated2: Dictionary = SaveSystem._migrate({"version": 2, "dug_tiles": [1]}, 2)
	_check("v2 gains resonance block", migrated2.has("resonance"))
	_check_eq("v2 preserves existing data", (migrated2.get("dug_tiles") as Array).size(), 1)

	ResonanceSystem.reset()
