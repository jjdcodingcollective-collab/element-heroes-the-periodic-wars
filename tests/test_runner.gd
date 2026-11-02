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
const NPC_SCENE    := preload("res://scenes/world/npc.tscn")
const WORLD_SCENE  := preload("res://scenes/world/world.tscn")
const SpriteLibrary := preload("res://scripts/world/sprite_library.gd")

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
	_test_sprite_integration()
	_test_audio_assets()
	await _test_world_draw_order()
	_test_enemy_rarity()
	_test_dash()
	_test_boss_scale()
	_test_bag_and_inventory()

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	# Let the audio server drop its playbacks before quitting, so the engine
	# does not report the test's sounds as leaked resources.
	AudioManager.release_all()
	await get_tree().process_frame
	await get_tree().process_frame
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

func _make_enemy(creature_id: String, tier: String = "basic", rarity: String = "normal") -> Node:
	var e: Node = ENEMY_SCENE.instantiate()
	e.creature_id = creature_id
	e.tier = tier
	e.rarity = rarity
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

# ── Sprite integration ────────────────────────────────────────────────────────

# Blank sheet of the given size; the cutter only cares about dimensions.
func _sheet(w: int, h: int) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(w, h, false, Image.FORMAT_RGBA8))

func _test_sprite_integration() -> void:
	print("- sprite integration")
	SpriteLibrary.clear_cache()
	var fs: Vector2i = SpriteLibrary.CHARACTER_FRAME

	# Sheet cutting follows SPRITE_SPEC.md
	var player_frames := SpriteLibrary.frames_from_texture(_sheet(4 * fs.x, 8 * fs.y), "character")
	_check("player sheet cuts", player_frames != null)
	if player_frames:
		_check_eq("player has 8 animations", player_frames.get_animation_names().size(), 8)
		_check_eq("idle_down has 2 frames", player_frames.get_frame_count("idle_down"), 2)
		_check_eq("walk_right has 4 frames", player_frames.get_frame_count("walk_right"), 4)
		_check_eq("walk_right fps", player_frames.get_animation_speed("walk_right"), 8.0)
		var region: Rect2 = (player_frames.get_frame_texture("walk_up", 3) as AtlasTexture).region
		_check_eq("walk_up frame 3 region", region, Rect2(3 * fs.x, 5 * fs.y, fs.x, fs.y))
	_check("undersized sheet rejected",
		SpriteLibrary.frames_from_texture(_sheet(4 * fs.x, 7 * fs.y), "character") == null)

	var boss_frames := SpriteLibrary.frames_from_texture(_sheet(192, 96), "boss")
	_check("boss sheet cuts", boss_frames != null)
	if boss_frames:
		_check_eq("boss idle has 4 frames", boss_frames.get_frame_count("idle"), 4)
		_check("boss attack does not loop", not boss_frames.get_animation_loop("attack"))

	# Missing art keeps the placeholder (today's normal state)
	_check("missing sheet returns null",
		SpriteLibrary.load_frames("res://assets/sprites/enemies/__none__.png", "enemy") == null)
	var e_ph: Node = _make_enemy("iron_hulk")
	_check("enemy without art uses placeholder", e_ph._placeholder != null and e_ph._sprite == null)
	e_ph.queue_free()

	# With a sheet present, every entity type switches to an AnimatedSprite2D.
	# Seed the cache directly so the test needs no imported PNGs.
	SpriteLibrary._cache[SpriteLibrary.enemy_path("iron_hulk") + "|enemy"] = \
		SpriteLibrary.frames_from_texture(_sheet(64, 32), "enemy")
	SpriteLibrary._cache[SpriteLibrary.boss_path("peroxis") + "|boss|112x112"] = \
		SpriteLibrary.frames_from_texture(_sheet(4 * 112, 2 * 112), "boss", Vector2i(112, 112))
	SpriteLibrary._cache[SpriteLibrary.player_path() + "|character"] = player_frames
	SpriteLibrary._cache[SpriteLibrary.npc_path("aldric") + "|npc"] = \
		SpriteLibrary.frames_from_texture(_sheet(2 * fs.x, fs.y), "npc")

	var e: Node = _make_enemy("iron_hulk", "expert")
	_check("enemy with art has sprite", e._sprite != null and e._placeholder == null)
	if e._sprite:
		e.velocity = Vector2(-20, 0)
		e._update_sprite()
		_check_eq("enemy faces its movement", e._sprite.animation, &"walk_left")
		_check("expert tier is brightened", e._sprite.modulate.r > 1.0)
	e.queue_free()

	var b: Node = BOSS_SCENE.instantiate()
	b.boss_id = "peroxis"
	add_child(b)
	_check("boss with art has sprite", b._sprite != null and b._placeholder == null)
	if b._sprite:
		_check_eq("boss starts idle", b._sprite.animation, &"idle")
		b._play_attack()
		_check_eq("boss plays attack", b._sprite.animation, &"attack")
	b.queue_free()

	var p: Node = PLAYER_SCENE.instantiate()
	add_child(p)
	_check("player with art has frames", p.animated_sprite.sprite_frames != null and p._placeholder == null)
	_check_eq("16x24 feet sit on the tile", p.animated_sprite.offset.y, 8.0 - fs.y / 2.0)
	p.velocity = Vector2(0, 50)
	p.facing = Vector2.DOWN
	p._update_animation()
	_check_eq("player walks down", p.animated_sprite.animation, &"walk_down")
	p.take_damage(9999.0)
	_check("death greys out the sprite", p.animated_sprite.modulate.a < 1.0)
	p.queue_free()

	var n: Node = NPC_SCENE.instantiate()
	add_child(n)
	_check("npc starts on placeholder", n._placeholder != null)
	_check("npc picks up sheet after _ready", n.use_sprite_sheet("aldric"))
	_check("npc placeholder released", n._placeholder == null and n._anim_sprite != null)
	n.queue_free()

	SpriteLibrary.clear_cache()

# ── Audio ─────────────────────────────────────────────────────────────────────

func _test_audio_assets() -> void:
	print("- audio assets")
	_check_eq("all music tracks load", AudioManager.MUSIC.size(), AudioManager.MUSIC_KEYS.size())
	_check_eq("all sfx load", AudioManager.SFX.size(), AudioManager.SFX_KEYS.size())
	for key: String in AudioManager.MUSIC:
		var m: AudioStream = AudioManager.MUSIC[key]
		if not (m is AudioStreamOggVorbis and m.get_length() > 10.0):
			_check("music '%s' is a real loop" % key, false)
	for key: String in AudioManager.SFX:
		var fx: AudioStream = AudioManager.SFX[key]
		if not (fx.get_length() > 0.02 and fx.get_length() < 2.0):
			_check("sfx '%s' is a short one-shot" % key, false)
	AudioManager.silent = false   # headless runs are silent by default
	AudioManager.play_music("surface_plains")
	_check("biome music loops", (AudioManager.MUSIC["surface_plains"] as AudioStreamOggVorbis).loop)
	AudioManager.play_sfx("pickup")
	var playing := AudioManager._sfx_pool.any(func(pl: AudioStreamPlayer) -> bool: return pl.playing)
	_check("sfx plays through the pool", playing)
	AudioManager.play_sfx("__missing__")   # must not error
	_check("unknown sfx is ignored", true)
	AudioManager.stop_music()
	AudioManager.release_all()
	AudioManager.silent = true

# ── World draw order ──────────────────────────────────────────────────────────

# Regression: tiles streamed in after the player used to draw over the player,
# Aldric and scene-placed enemies, making them invisible.
func _test_world_draw_order() -> void:
	print("- world draw order")
	var w: Node2D = WORLD_SCENE.instantiate()
	add_child(w)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node2D = w.get_node("Player")
	_check("world sorts by Y", w.y_sort_enabled)
	_check("tiles were streamed", w.tile_nodes.size() > 0)
	if w.tile_nodes.size() > 0:
		var tile: CanvasItem = w.tile_nodes.values()[0]
		_check("tiles draw beneath the player", tile.z_index < player.z_index)
	# Regression: the quiz's dim backdrop was visible from startup, darkening the
	# whole screen and swallowing mouse clicks (left-click digging).
	var overlays: Array = []
	_find_visible_overlays(w, overlays)
	_check("no full-screen overlay at startup", overlays.is_empty())
	var aldric: Node = w.get_node_or_null("Aldric")
	if aldric:
		_check_eq("Aldric's label shows his name", aldric._label.text, "Prof. Aldric Daedalus")
	w.queue_free()
	await get_tree().process_frame

# ── Enemy rarity (strong / shiny / prime) ─────────────────────────────────────

func _test_enemy_rarity() -> void:
	print("- enemy rarity")
	var saved: Dictionary = EncounterSystem.serialize()
	EncounterSystem.reset()

	# Rates: with a roll that never hits, pity guarantees each rarity at 2× its rate.
	var never := func() -> float: return 0.99
	var first_strong := -1
	for i: int in range(25):
		if EncounterSystem.roll_rarity("", never) == "strong" and first_strong < 0:
			first_strong = i + 1
	_check_eq("strong guaranteed by encounter 20", first_strong, 20)

	EncounterSystem.reset()
	var counts := { "normal": 0, "strong": 0, "shiny": 0, "prime": 0 }
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var roll := func() -> float: return rng.randf()
	for i: int in range(20000):
		var r: String = EncounterSystem.roll_rarity("", roll)
		counts[r] += 1
	# Expected ≈ 1 in 10 / 100 / 1000 (pity nudges each slightly higher).
	_check("strong ≈ 1 in 10", counts["strong"] > 1600 and counts["strong"] < 2400)
	_check("shiny ≈ 1 in 100", counts["shiny"] > 140 and counts["shiny"] < 280)
	_check("prime ≈ 1 in 1000", counts["prime"] >= 12 and counts["prime"] <= 40)
	_check_eq("encounters counted", EncounterSystem.encounters, 20000)

	# Strong enemies are bigger, tougher and reach further.
	var normal: Node = _make_enemy("iron_hulk")
	var strong: Node = _make_enemy("iron_hulk", "basic", "strong")
	_check_eq("rhino strong footprint is 2×1", strong.footprint, Vector2i(2, 1))
	_check("strong has more HP", strong.max_hp > normal.max_hp * 2.0)
	_check("strong reaches further", strong._attack_range > normal._attack_range)
	var shape: Shape2D = strong.get_node("CollisionShape2D").shape
	_check("strong collision grows", shape is RectangleShape2D and (shape as RectangleShape2D).size.x > 20.0)
	_check_eq("normal stays 1×1", normal.footprint, Vector2i.ONE)
	var gorilla: Node = _make_enemy("gold_golem", "basic", "prime")
	_check_eq("gorilla prime footprint is 2×2", gorilla.footprint, Vector2i(2, 2))
	var shiny: Node = _make_enemy("zinc_phantom", "basic", "shiny")
	_check_eq("shiny keeps normal size", shiny.footprint, Vector2i.ONE)
	for e: Node in [normal, strong, gorilla, shiny]:
		e.queue_free()

	# Every creature has a valid strong footprint.
	var bad: Array = []
	for c: String in ElementDB.enemies:
		var fp: Array = ElementDB.enemies[c].get("strong_footprint", [])
		if fp.size() != 2 or not ([1, 2] as Array).has(int(fp[0])) or not ([1, 2] as Array).has(int(fp[1])) or (int(fp[0]) == 1 and int(fp[1]) == 1):
			bad.append(c)
	_check("all 18 have a 2×2, 2×1 or 1×2 footprint", bad.is_empty())

	# Shiny loot: signature element bonus on top of normal drops.
	var player: Node = PLAYER_SCENE.instantiate()
	add_child(player)
	var inv: Node = player.get_node("Inventory")
	var before: float = float(inv.get_amount("Zn")) if inv.has_method("get_amount") else 0.0
	var s2: Node = _make_enemy("zinc_phantom", "basic", "shiny")
	s2._take_damage_raw(99999.0)
	var after: float = float(inv.get_amount("Zn")) if inv.has_method("get_amount") else 0.0
	_check("shiny drops ≥5 g of its signature element", after - before >= 5.0)

	# Prime Codex: duplicates ignored, completion fires once at 18.
	EncounterSystem.reset()
	var completed := [0]
	var on_done := func() -> void: completed[0] += 1
	EncounterSystem.prime_codex_completed.connect(on_done)
	EncounterSystem.record_defeat("iron_hulk", "prime")
	EncounterSystem.record_defeat("iron_hulk", "prime")
	_check_eq("duplicate prime counted once", EncounterSystem.prime_codex.size(), 1)
	for c: String in ElementDB.enemies:
		EncounterSystem.record_defeat(c, "prime")
	_check_eq("codex completes once", completed[0], 1)
	_check("codex survives save/load", _roundtrip_codex())
	EncounterSystem.prime_codex_completed.disconnect(on_done)

	player.queue_free()
	EncounterSystem.deserialize(saved)

func _roundtrip_codex() -> bool:
	var data: Dictionary = JSON.parse_string(JSON.stringify(EncounterSystem.serialize()))
	EncounterSystem.reset()
	EncounterSystem.deserialize(data)
	return EncounterSystem.prime_codex.size() == ElementDB.enemies.size() and EncounterSystem.codex_completed

# ── Hades-style dash ──────────────────────────────────────────────────────────

func _test_dash() -> void:
	print("- dash")
	var p: Node = PLAYER_SCENE.instantiate()
	add_child(p)
	_check("dash starts", p.try_dash())
	_check("dashing", p.is_dashing())
	_check("no second dash with one charge", not p.try_dash())
	var hp_before: float = p.hp
	p.take_damage(50.0)
	_check_eq("dash has i-frames", p.hp, hp_before)
	# Run the dash out and through the cooldown.
	for i: int in range(40):
		p._tick_dash(1.0 / 60.0)
	_check("dash ends", not p.is_dashing())
	_check("dash recharges", p.try_dash())
	# Dash-strike: attacking right after a dash multiplies damage once.
	p.equip_weapon("bronze_sword")
	_check("test sword equipped", p.weapon.has_weapon())
	var target: Node = _make_enemy("iron_hulk")
	target.global_position = p.global_position + Vector2(0, 12)
	p.facing = Vector2.DOWN
	var hp0: float = target.hp
	p.weapon._cooldown_timer = 0.0
	p._dash_strike_timer = 0.0   # the recharge test above just dashed
	p._try_attack()
	var plain: float = hp0 - target.hp
	target.hp = hp0
	target.global_position = p.global_position + Vector2(0, 12)   # undo knockback
	p.weapon._cooldown_timer = 0.0
	p._dash_strike_timer = 0.1
	p._try_attack()
	var strike: float = hp0 - target.hp
	_check("dash-strike hits harder", plain > 0.0 and strike > plain * 1.4)
	_check_eq("dash-strike bonus is used up", p.weapon.damage_mult, 1.0)
	target.queue_free()
	_check("dash action is bound", InputMap.has_action("dash"))
	p.queue_free()

# ── Boss scale ────────────────────────────────────────────────────────────────

func _test_boss_scale() -> void:
	print("- boss scale")
	var smallest: float = 9999.0
	for id: String in ["peroxis", "chalcor", "aurium", "azrael", "atacama", "uranox"]:
		var b: Node = BOSS_SCENE.instantiate()
		b.boss_id = id
		add_child(b)
		smallest = minf(smallest, b.body_size)
		if id == "uranox":
			_check("Uranox is the largest (≥160 px)", b.body_size >= 160.0)
			var shape: Shape2D = b.get_node("CollisionShape2D").shape
			_check("boss collision matches body", shape is CircleShape2D and (shape as CircleShape2D).radius >= 60.0)
			_check("boss reach covers its body", b._attack_range > b.body_size / 2.0)
		b.queue_free()
	_check("every boss is at least 7 tiles across", smallest >= 112.0)

func _find_visible_overlays(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is ColorRect and (n as ColorRect).size.x >= 1000.0 and (n as ColorRect).size.y >= 600.0 \
			and (n as ColorRect).z_index > -10 and (n as ColorRect).color.a > 0.2:
		out.append(n.get_path())
	for c: Node in n.get_children():
		_find_visible_overlays(c, out)

# ── Bag, Ashmarks and the inventory screen ────────────────────────────────────

func _test_bag_and_inventory() -> void:
	print("- bag and inventory")
	var p: Node = PLAYER_SCENE.instantiate()
	add_child(p)
	var bag: Node = p.get_node("Bag")
	_check_eq("item catalogue has 24 key items", bag.catalogue().get("key_items", {}).size(), 24)

	bag.add_ashmarks(30)
	_check("can spend Ashmarks", bag.spend_ashmarks(12))
	_check("cannot overspend", not bag.spend_ashmarks(100))
	_check_eq("Ashmarks balance", bag.ashmarks, 18)

	p.hp = 30.0
	bag.add_consumable("saline_tonic", 2)
	_check("tonic used", bag.use_consumable("saline_tonic"))
	_check_eq("tonic heals 40", p.hp, 70.0)
	_check_eq("one tonic left", bag.consumable_count("saline_tonic"), 1)
	p.apply_armor_corrode(0.3, 10.0)
	bag.add_consumable("buffer_solution")
	bag.use_consumable("buffer_solution")
	_check_eq("buffer clears corrosion", p._corrode_amount, 0.0)
	_check("empty consumable cannot be used", not bag.use_consumable("lead_draught"))

	# Boss Key needs all three fragments; fragments are absorbed, the key is permanent.
	bag.add_key_item("carbon_ember")
	bag.add_key_item("pressure_valve")
	_check("key needs all fragments", not bag.try_combine_boss_key("co2_canister"))
	bag.add_key_item("canister_shell")
	_check("key combines", bag.try_combine_boss_key("co2_canister"))
	_check("key held", bag.has_key_item("co2_canister"))
	_check("fragments absorbed", not bag.has_key_item("carbon_ember"))
	_check("cannot combine twice", not bag.try_combine_boss_key("co2_canister"))

	var data: Dictionary = JSON.parse_string(JSON.stringify(bag.serialize()))
	bag.deserialize({})
	bag.deserialize(data)
	_check("bag survives save/load", bag.has_key_item("co2_canister") and bag.ashmarks == 18 and bag.consumable_count("saline_tonic") == 1)
	_check_eq("save version is 5", SaveSystem.SAVE_VERSION, 5)
	_check("v4 save gains a bag", SaveSystem._migrate({"version": 4}, 4).has("bag"))

	# Kills pay Ashmarks, scaled by rarity. Earlier tests' players may still be
	# queued for deletion, so make sure loot goes to this one.
	for other: Node in get_tree().get_nodes_in_group("player"):
		if other != p:
			other.remove_from_group("player")
	bag.ashmarks = 0
	var e: Node = _make_enemy("carbon_crawler")
	e._take_damage_raw(99999.0)
	var normal_pay: int = bag.ashmarks
	bag.ashmarks = 0
	var shiny: Node = _make_enemy("carbon_crawler", "basic", "shiny")
	shiny._take_damage_raw(99999.0)
	_check("kills pay Ashmarks", normal_pay > 0)
	_check("shiny pays 5×", normal_pay > 0 and bag.ashmarks == normal_pay * 5)

	# Screen: four tabs, hidden by default, and its backdrop never blocks clicks while closed.
	var screen := CanvasLayer.new()
	screen.set_script(load("res://scripts/ui/inventory_screen.gd"))
	add_child(screen)
	_check("inventory starts closed", not screen.is_open() and not screen._dim.visible)
	_check_eq("four tabs", screen._tabs.get_tab_count(), 4)
	_check_eq("tab names", [screen._tabs.get_tab_title(2), screen._tabs.get_tab_title(3)], ["Consumables", "Key Items"])
	screen._player = p
	screen.toggle()
	_check("inventory opens", screen.is_open())
	_check("Ashmarks in header", screen._ashmarks_label.text.begins_with("%d Ashmarks" % bag.ashmarks))
	_check("key item listed", screen._lists["Key Items"].get_child_count() > 0)
	screen.toggle()
	screen.queue_free()
	p.queue_free()
