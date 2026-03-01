extends Node

# CraftingSystem — validates crafting grid input against compound recipes.
# Autoload as "CraftingSystem" or attach to a crafting UI node.

const GRID_SIZE: int = 3

# grid_contents: 3x3 Array of element symbols (or "" for empty)
# Returns the matched compound dict, or {} if no match.
func evaluate_grid(grid_contents: Array) -> Dictionary:
	var ingredient_map: Dictionary = _grid_to_ingredient_map(grid_contents)
	if ingredient_map.is_empty():
		return {}
	return ElementDB.match_recipe(ingredient_map)

func _grid_to_ingredient_map(grid: Array) -> Dictionary:
	var counts: Dictionary = {}
	for row: Array in grid:
		for cell: String in row:
			if cell != "":
				counts[cell] = counts.get(cell, 0) + 1
	return counts

# Look up a compound by its game_item key.
func get_compound_by_item(item_name: String) -> Dictionary:
	for c: Dictionary in ElementDB.compounds.values():
		if str(c.get("game_item", "")) == item_name:
			return c
	return {}

# Return all compounds as an Array (for iteration).
func get_all_compounds() -> Array:
	return ElementDB.compounds.values()

# Attempt to craft using the player's inventory (elements only).
# Returns the compound dict on success, {} on failure.
func try_craft(grid_contents: Array, inventory: Node) -> Dictionary:
	var compound: Dictionary = evaluate_grid(grid_contents)
	if compound.is_empty():
		return {}

	var required: Dictionary = compound.get("elements", {}) as Dictionary
	# Separate element keys from item keys (polymers stored in equipment)
	var elem_req: Dictionary = {}
	for k: Variant in required:
		var key: String = str(k)
		if ElementDB.elements.has(key):
			elem_req[key] = float(required[k])

	if inventory.remove_elements(elem_req):
		return compound
	return {}

# Craft using both element inventory and equipment items.
# Used for Tier 3-5 armor recipes that require polymer intermediates.
func try_craft_with_items(grid_contents: Array, inventory: Node, equipment: Node) -> Dictionary:
	var compound: Dictionary = evaluate_grid(grid_contents)
	if compound.is_empty():
		return {}

	var required: Dictionary = compound.get("elements", {}) as Dictionary
	var elem_req: Dictionary = {}
	var item_req: Dictionary = {}
	for k: Variant in required:
		var key: String = str(k)
		if ElementDB.elements.has(key):
			elem_req[key] = float(required[k])
		else:
			item_req[key] = int(required[k])

	# Check elements
	if not inventory.has_elements(elem_req):
		return {}
	# Check equipment items
	for item_key: String in item_req:
		var needed: int = item_req[item_key]
		var have: int = int(equipment.items.get(item_key, 0))
		if have < needed:
			return {}

	# Consume elements
	inventory.remove_elements(elem_req)
	# Consume equipment items
	for item_key: String in item_req:
		var needed: int = item_req[item_key]
		for _i: int in range(needed):
			equipment.use_container(item_key)

	return compound
