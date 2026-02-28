extends Node

# Equipment — tracks lab equipment items the player is carrying.
# Separate from the element inventory so UI can display them distinctly.
# Attach to Player as child named "Equipment".
#
# Equipment item names match ElementDB.CONTAINER_ITEMS / HANDLING_ITEMS values.
# Items are consumed when used (containers) or are reusable (gloves/suits).

# Reusable equipment — player "wears" these; they don't get consumed
const REUSABLE := [
	"Nitrile Gloves",
	"Heavy Gloves",
	"Glove Box Kit",
	"Radiation Suit",
]

# Container items are consumed on pickup (one per element collected)
const CONTAINERS := [
	"Standard Vial",
	"Glass Vial",
	"Sealed Ampule",
	"Pressure Canister",
	"Inert Container",
	"Lead Container",
]

# Container hierarchy — higher index can substitute for lower
# e.g. Inert Container can store anything a Standard Vial can
const CONTAINER_TIER := {
	"Standard Vial":        0,
	"Glass Vial":           1,
	"Sealed Ampule":        2,
	"Pressure Canister":    2,
	"Inert Container":      3,
	"Lead Container":       4,
}

# Handling hierarchy
const HANDLING_TIER := {
	"":                0,
	"Nitrile Gloves":  1,
	"Heavy Gloves":    2,
	"Glove Box Kit":   3,
	"Radiation Suit":  4,
}

signal equipment_changed

var items: Dictionary = {}  # { "Nitrile Gloves": 1, "Standard Vial": 5, ... }

func add_item(item_name: String, count: int = 1) -> void:
	items[item_name] = int(items.get(item_name, 0)) + count
	emit_signal("equipment_changed")

func has_item(item_name: String) -> bool:
	return int(items.get(item_name, 0)) > 0

func use_container(item_name: String) -> bool:
	if not has_item(item_name):
		return false
	if item_name in REUSABLE:
		return true  # reusable — don't consume
	items[item_name] = int(items[item_name]) - 1
	if int(items[item_name]) <= 0:
		items.erase(item_name)
	emit_signal("equipment_changed")
	return true

# Check if player can collect element — returns "" on success, or
# a human-readable string describing what's missing.
func can_collect(symbol: String) -> String:
	var h: Dictionary = ElementDB.get_handling(symbol)
	var needed_container: String = str(h.get("container_item", "Standard Vial"))
	var needed_handling: String  = str(h.get("handling_item", ""))

	# Check handling (gloves/suit) — must have equal or higher tier
	if needed_handling != "":
		var required_tier: int = int(HANDLING_TIER.get(needed_handling, 0))
		var has_tier: bool = false
		for item: String in items:
			if int(items[item]) > 0 and HANDLING_TIER.has(item):
				if int(HANDLING_TIER[item]) >= required_tier:
					has_tier = true
					break
		if not has_tier:
			return "Need %s to handle %s" % [needed_handling, symbol]

	# Check container — must have equal or higher tier
	var required_ctier: int = int(CONTAINER_TIER.get(needed_container, 0))
	var has_ctier: bool = false
	for item: String in items:
		if int(items[item]) > 0 and CONTAINER_TIER.has(item):
			if int(CONTAINER_TIER[item]) >= required_ctier:
				has_ctier = true
				break
	if not has_ctier:
		return "Need %s to store %s" % [needed_container, symbol]

	return ""  # all good

# Consume the appropriate container for an element (called after successful dig)
func consume_container_for(symbol: String) -> void:
	var h: Dictionary = ElementDB.get_handling(symbol)
	var needed_container: String = str(h.get("container_item", "Standard Vial"))
	var required_tier: int = int(CONTAINER_TIER.get(needed_container, 0))
	# Find lowest-tier container that still satisfies requirement (conserves higher ones)
	var best_item: String = ""
	var best_tier: int = 9999
	for item: String in items:
		if int(items[item]) > 0 and CONTAINER_TIER.has(item) and item not in REUSABLE:
			var t: int = int(CONTAINER_TIER[item])
			if t >= required_tier and t < best_tier:
				best_tier = t
				best_item = item
	if best_item != "":
		use_container(best_item)

func get_all() -> Dictionary:
	return items.duplicate()

func serialize() -> Dictionary:
	return items.duplicate()

func deserialize(data: Dictionary) -> void:
	items = data.duplicate()
