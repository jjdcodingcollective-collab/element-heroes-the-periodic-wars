extends Node

# SaveSystem — handles save/load of game state to disk.
# Autoload as "SaveSystem".

const SAVE_PATH: String = "user://savegame.json"

const SAVE_VERSION: int = 2

func save_game(player: Node) -> void:
	var equip_node := player.get_node_or_null("Equipment")
	var weapon_node := player.get_node_or_null("Weapon")
	var armor_node := player.get_node_or_null("Armor")
	var world_node := player.get_parent()
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"inventory": player.get_node("Inventory").serialize(),
		"equipment": equip_node.serialize() if equip_node else {},
		"weapon": weapon_node.get_weapon_name() if weapon_node and weapon_node.has_method("get_weapon_name") else "",
		"armor": armor_node.serialize() if armor_node and armor_node.has_method("serialize") else "",
		"position": {
			"x": player.global_position.x,
			"y": player.global_position.y
		},
		"discovered": _get_compendium_discovered(),
		"dug_tiles": world_node.serialize_dug_tiles() if world_node and world_node.has_method("serialize_dug_tiles") else [],
		"timestamp": Time.get_datetime_string_from_system()
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: could not open save file for writing")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Game saved.")

func load_game(player: Node) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("SaveSystem: failed to parse save file — deleting corrupt save")
		DirAccess.remove_absolute(SAVE_PATH)
		return false

	var data: Dictionary = json.data as Dictionary
	var file_version: int = int(data.get("version", 1))

	# Version migration
	if file_version < SAVE_VERSION:
		data = _migrate(data, file_version)

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
	return true

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
	return d

func _get_compendium_discovered() -> Dictionary:
	var compendium := get_tree().get_first_node_in_group("compendium")
	if compendium and compendium.has_method("serialize_discovered"):
		return compendium.serialize_discovered()
	return {}

func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
