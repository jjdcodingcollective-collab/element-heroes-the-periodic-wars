extends Node

# SaveSystem — autoload. Save slots, loading, autosave and suspend.
# Design: SYSTEMS_UX_REVIEW.md §3.1.
#
# Slots: "slot1".."slot3" (manual), "autosave" (never overwrites a manual
# slot) and "suspend" (quit-anywhere; consumed when resumed).
# Files live in `save_dir` (user://saves/ by default; EH_SAVE_DIR overrides it
# so parallel test runs never share files).
#
# Loading a game: the title screen calls begin_load(slot) and changes to the
# world scene. world.gd reads the pending data for its seed and defeated
# bosses before generating, then calls apply_pending(player) once the player
# and HUD exist.

signal saved(slot: String, ok: bool)
signal loaded(slot: String)

const SAVE_VERSION: int = 6
const MANUAL_SLOTS: Array[String] = ["slot1", "slot2", "slot3"]
const ALL_SLOTS: Array[String] = ["slot1", "slot2", "slot3", "autosave", "suspend"]
const LEGACY_PATH := "user://savegame.json"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

var save_dir: String = "user://saves/"
var active_slot: String = "slot1"     # the manual slot this playthrough saves to
var play_seconds: float = 0.0          # this playthrough's play time
var in_game: bool = false              # world sets this; play time only counts in game
var pending_data: Dictionary = {}      # loaded save waiting to be applied to a new world
var pending_slot: String = ""
var title_scene: String = TITLE_SCENE  # where Suspend goes ("" = stay; tests use this)

func _ready() -> void:
	var override := OS.get_environment("EH_SAVE_DIR")
	if override != "":
		save_dir = override
	_ensure_dir()
	_adopt_legacy_save()

func _process(delta: float) -> void:
	if in_game and not get_tree().paused:
		play_seconds += delta

# ── Paths ─────────────────────────────────────────────────────────────────────

func slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")

func slot_exists(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))

func save_exists() -> bool:
	for s: String in ALL_SLOTS:
		if slot_exists(s):
			return true
	return false

func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)

# Saves from before slots (user://savegame.json) become slot 1.
func _adopt_legacy_save() -> void:
	if FileAccess.file_exists(LEGACY_PATH) and not slot_exists("slot1"):
		DirAccess.copy_absolute(LEGACY_PATH, slot_path("slot1"))
		DirAccess.remove_absolute(LEGACY_PATH)

# ── Saving ────────────────────────────────────────────────────────────────────

func build_save_data(player: Node) -> Dictionary:
	var equip_node := player.get_node_or_null("Equipment")
	var weapon_node := player.get_node_or_null("Weapon")
	var armor_node := player.get_node_or_null("Armor")
	var world_node := player.get_parent()
	var bag := player.get_node_or_null("Bag")
	var biome: String = world_node.get_biome_at(player.global_position) if world_node and world_node.has_method("get_biome_at") else ""
	return {
		"version": SAVE_VERSION,
		"summary": {
			"biome": biome,
			"play_seconds": int(play_seconds),
			"ashmarks": bag.ashmarks if bag else 0,
			"codex": EncounterSystem.prime_codex.size(),
			"hp": int(player.hp) if "hp" in player else 0,
			"timestamp": Time.get_datetime_string_from_system(false, true),
			"unix": Time.get_unix_time_from_system(),
		},
		"world_seed": world_node.world_seed if world_node and "world_seed" in world_node else -1,
		"defeated_bosses": world_node.defeated_bosses.duplicate() if world_node and "defeated_bosses" in world_node else [],
		# Optional field (no version bump): older saves load with none discovered.
		"stations": world_node.serialize_stations() if world_node and world_node.has_method("serialize_stations") else [],
		"ashmark_caches": _serialize_caches(),
		"inventory": player.get_node("Inventory").serialize(),
		"equipment": equip_node.serialize() if equip_node else {},
		"weapon": weapon_node.get_weapon_name() if weapon_node and weapon_node.has_method("get_weapon_name") else "",
		"armor": armor_node.serialize() if armor_node and armor_node.has_method("serialize") else "",
		"position": { "x": player.global_position.x, "y": player.global_position.y },
		"discovered": _get_compendium_discovered(),
		"dug_tiles": world_node.serialize_dug_tiles() if world_node and world_node.has_method("serialize_dug_tiles") else [],
		"resonance": ResonanceSystem.serialize(),
		"encounters": EncounterSystem.serialize(),
		"bag": bag.serialize() if bag else {},
		"timestamp": Time.get_datetime_string_from_system(),
	}

# Writes the player's game to `slot` (default: the active manual slot).
func save_game(player: Node, slot: String = "") -> bool:
	var target: String = active_slot if slot == "" else slot
	var ok := write_slot(target, build_save_data(player))
	saved.emit(target, ok)
	return ok

func autosave(player: Node) -> bool:
	return save_game(player, "autosave")

# Suspend (the classroom-bell button): save to the "suspend" slot and go back
# to the title. Continue resumes it once, then it is deleted (apply_pending).
func suspend_and_quit(player: Node) -> bool:
	var ok := save_game(player, "suspend")
	if not ok:
		return false
	UIManager.close_all()
	get_tree().paused = false
	if title_scene != "":
		get_tree().change_scene_to_file.call_deferred(title_scene)
	return true

func write_slot(slot: String, data: Dictionary) -> bool:
	_ensure_dir()
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: could not open %s for writing" % slot_path(slot))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func delete_slot(slot: String) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(slot_path(slot))

# ── Reading ───────────────────────────────────────────────────────────────────

# Parsed, migrated save data, or {} if missing or corrupt.
func read_slot(slot: String) -> Dictionary:
	if not slot_exists(slot):
		return {}
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK or not (json.data is Dictionary):
		push_warning("SaveSystem: %s is corrupt and was ignored" % slot)
		return {}
	var data: Dictionary = json.data
	var v: int = int(data.get("version", 1))
	return _migrate(data, v) if v < SAVE_VERSION else data

# Summary for a slot card on the title / load screen ({} when empty).
func slot_summary(slot: String) -> Dictionary:
	var data := read_slot(slot)
	if data.is_empty():
		return {}
	var s: Dictionary = data.get("summary", {})
	return {
		"slot": slot,
		"biome": str(s.get("biome", "")),
		"play_seconds": int(s.get("play_seconds", 0)),
		"ashmarks": int(s.get("ashmarks", 0)),
		"codex": int(s.get("codex", 0)),
		"timestamp": str(s.get("timestamp", data.get("timestamp", ""))),
		"unix": float(s.get("unix", 0.0)),
	}

# The slot "Continue" should resume: a suspend file first, else the newest save.
func most_recent_slot() -> String:
	if slot_exists("suspend"):
		return "suspend"
	var best := ""
	var best_t := -1.0
	for s: String in ALL_SLOTS:
		var info := slot_summary(s)
		if not info.is_empty() and float(info["unix"]) > best_t:
			best_t = float(info["unix"])
			best = s
	return best

static func format_play_time(seconds: int) -> String:
	@warning_ignore("integer_division")
	return "%d:%02d" % [seconds / 3600, (seconds / 60) % 60]

# ── Loading ───────────────────────────────────────────────────────────────────

# Prepares `slot` to be applied by the next world. Returns false if empty.
func begin_load(slot: String) -> bool:
	var data := read_slot(slot)
	if data.is_empty():
		return false
	pending_data = data
	pending_slot = slot
	# Manual slots keep saving where they came from; autosave and suspend
	# resume into the slot that playthrough was last manually saved to.
	if slot in MANUAL_SLOTS:
		active_slot = slot
	play_seconds = float(data.get("summary", {}).get("play_seconds", 0))
	return true

func begin_new_game(slot: String) -> void:
	pending_data = {}
	pending_slot = ""
	active_slot = slot if slot in MANUAL_SLOTS else "slot1"
	play_seconds = 0.0
	EncounterSystem.reset()

func has_pending() -> bool:
	return not pending_data.is_empty()

# World asks for its seed before generating (-1 = make a new one).
func pending_world_seed() -> int:
	return int(pending_data.get("world_seed", -1)) if has_pending() else -1

func pending_defeated_bosses() -> Array:
	return pending_data.get("defeated_bosses", []) if has_pending() else []

# Applies the pending save to a freshly built world's player. Called by world.gd.
func apply_pending(player: Node) -> bool:
	if not has_pending():
		return false
	var ok := apply_data(player, pending_data)
	var slot := pending_slot
	pending_data = {}
	pending_slot = ""
	if slot == "suspend":
		delete_slot("suspend")   # a suspend is a one-time resume
	loaded.emit(slot)
	return ok

func apply_data(player: Node, data: Dictionary) -> bool:
	player.get_node("Inventory").deserialize(data.get("inventory", {}) as Dictionary)
	var equip_node := player.get_node_or_null("Equipment")
	if equip_node:
		equip_node.deserialize(data.get("equipment", {}) as Dictionary)
	var weapon_node := player.get_node_or_null("Weapon")
	var saved_weapon: String = str(data.get("weapon", ""))
	if weapon_node and saved_weapon != "" and weapon_node.has_method("equip"):
		weapon_node.equip(saved_weapon)
	var armor_node := player.get_node_or_null("Armor")
	var saved_armor: String = str(data.get("armor", ""))
	if armor_node and saved_armor != "" and armor_node.has_method("deserialize"):
		armor_node.deserialize(saved_armor)
	var pos: Dictionary = data.get("position", {"x": 0, "y": 0}) as Dictionary
	player.global_position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
	var world_node := player.get_parent()
	var dug: Array = data.get("dug_tiles", []) as Array
	if world_node and world_node.has_method("restore_dug_tiles") and dug.size() > 0:
		world_node.restore_dug_tiles(dug)
	if world_node and world_node.has_method("restore_stations"):
		world_node.restore_stations(data.get("stations", []) as Array)
	_restore_caches(world_node, data.get("ashmark_caches", []) as Array)
	var compendium := get_tree().get_first_node_in_group("compendium")
	if compendium and compendium.has_method("restore_discovered"):
		compendium.restore_discovered(data.get("discovered", {}) as Dictionary)
	ResonanceSystem.deserialize(data.get("resonance", {}) as Dictionary)
	EncounterSystem.deserialize(data.get("encounters", {}) as Dictionary)
	if player.has_node("Bag"):
		player.get_node("Bag").deserialize(data.get("bag", {}) as Dictionary)
	return true

# Old API, kept for callers and tests: load the active slot straight into a running world.
func load_game(player: Node) -> bool:
	var data := read_slot(active_slot)
	if data.is_empty():
		return false
	return apply_data(player, data)

# ── Migration ─────────────────────────────────────────────────────────────────

# Incrementally migrate old saves up to SAVE_VERSION.
# Add a new "if file_version < N" block each time SAVE_VERSION bumps.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var d := data.duplicate(true)
	if from_version < 2:
		# v1 → v2: added dug_tiles and version stamp
		if not d.has("dug_tiles"):
			d["dug_tiles"] = []
		d["version"] = 2
		push_warning("SaveSystem: migrated save from v1 → v2")
	if from_version < 3:
		# v2 → v3: added Resonance Engine (Act 3) progress
		if not d.has("resonance"):
			d["resonance"] = { "is_assembled": false, "ready_announced": false }
		d["version"] = 3
		push_warning("SaveSystem: migrated save from v2 → v3")
	if from_version < 4:
		# v3 → v4: added encounter counters and the Prime Codex
		if not d.has("encounters"):
			d["encounters"] = {}
		d["version"] = 4
		push_warning("SaveSystem: migrated save from v3 → v4")
	if from_version < 5:
		# v4 → v5: added the Bag (Ashmarks, consumables, key items)
		if not d.has("bag"):
			d["bag"] = {}
		d["version"] = 5
		push_warning("SaveSystem: migrated save from v4 → v5")
	if from_version < 6:
		# v5 → v6: world seed, defeated bosses, slot summary. Older saves had
		# no seed, so their dug tiles belong to a lost map: drop them.
		if not d.has("world_seed"):
			d["world_seed"] = -1
			d["dug_tiles"] = []
		if not d.has("defeated_bosses"):
			d["defeated_bosses"] = []
		if not d.has("summary"):
			d["summary"] = { "timestamp": str(d.get("timestamp", "")) }
		d["version"] = 6
		push_warning("SaveSystem: migrated save from v5 → v6")
	return d

func _get_compendium_discovered() -> Dictionary:
	var compendium := get_tree().get_first_node_in_group("compendium")
	if compendium and compendium.has_method("serialize_discovered"):
		return compendium.serialize_discovered()
	return {}

# Dropped Ashmark caches (Keep Inventory off) survive save and load, so a
# recovery run is never lost by quitting. Optional field: older saves have none.
func _serialize_caches() -> Array:
	var out: Array = []
	for c: Node in get_tree().get_nodes_in_group("ashmark_cache"):
		if c.is_queued_for_deletion() or int(c.amount) <= 0:
			continue
		out.append({ "x": (c as Node2D).global_position.x, "y": (c as Node2D).global_position.y, "amount": int(c.amount) })
	return out

func _restore_caches(world_node: Node, caches: Array) -> void:
	if world_node == null:
		return
	for c: Node in get_tree().get_nodes_in_group("ashmark_cache"):
		c.queue_free()
	var cache_script: Script = load("res://scripts/world/ashmark_cache.gd")
	for entry in caches:
		if not (entry is Dictionary) or int(entry.get("amount", 0)) <= 0:
			continue
		var cache: Node2D = cache_script.new()
		cache.amount = int(entry["amount"])
		cache.global_position = Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
		world_node.add_child(cache)

