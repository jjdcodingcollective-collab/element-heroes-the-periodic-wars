extends Node

# SaveSystem — handles save/load of game state to disk.
# Autoload as "SaveSystem".

const SAVE_PATH: String = "user://savegame.json"

func save_game(player: Node) -> void:
	var data = {
		"inventory": player.get_node("Inventory").serialize(),
		"position": {
			"x": player.global_position.x,
			"y": player.global_position.y
		},
		"discovered": _get_compendium_discovered(),
		"timestamp": Time.get_datetime_string_from_system()
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: could not open save file for writing")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Game saved.")

func load_game(player: Node) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("SaveSystem: failed to parse save file")
		return false

	var data = json.data
	player.get_node("Inventory").deserialize(data.get("inventory", {}))
	var pos = data.get("position", {"x": 0, "y": 0})
	player.global_position = Vector2(pos["x"], pos["y"])
	return true

func _get_compendium_discovered() -> Dictionary:
	var compendium = get_tree().get_first_node_in_group("compendium")
	if compendium and compendium.has_method("serialize_discovered"):
		return compendium.serialize_discovered()
	return {}

func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
