extends Node

# Armor — manages the player's single equipped armor piece.
# Mirrors weapon.gd pattern. Reads stats from compounds.json "armor" sub-dict.
# Damage reduction is applied in player.gd take_damage().

signal armor_changed(armor_name: String)

var equipped_item: String = ""
var _stats: Dictionary = {}

func equip(item_name: String) -> void:
	var compound: Dictionary = CraftingSystem.get_compound_by_item(item_name)
	if compound.is_empty() or not compound.has("armor"):
		return
	equipped_item = item_name
	_stats = compound["armor"] as Dictionary
	armor_changed.emit(item_name)

func unequip() -> void:
	equipped_item = ""
	_stats = {}
	armor_changed.emit("")

func has_armor() -> bool:
	return not _stats.is_empty()

func get_armor_name() -> String:
	return equipped_item

func get_tier() -> int:
	return int(_stats.get("tier", 0))

func get_damage_reduction() -> float:
	return float(_stats.get("damage_reduction", 0.0))

func get_color() -> Color:
	var c: Array = _stats.get("color", [0.5, 0.5, 0.5]) as Array
	return Color(float(c[0]), float(c[1]), float(c[2]))

func serialize() -> String:
	return equipped_item

func deserialize(item_name: String) -> void:
	if item_name != "":
		equip(item_name)
