extends Node

# CraftingSystem — validates crafting grid input against compound recipes.
# Autoload as "CraftingSystem" or attach to a crafting UI node.

const GRID_SIZE: int = 3

# grid_contents: 3x3 Array of element symbols (or "" for empty)
# stacks (optional): matching 3x3 Array of ints, how many units each cell
# holds (default 1). Stacks let big recipes such as U4O8 fit nine cells.
# Returns the matched compound dict, or {} if no match.
func evaluate_grid(grid_contents: Array, stacks: Array = []) -> Dictionary:
	var ingredient_map: Dictionary = _grid_to_ingredient_map(grid_contents, stacks)
	if ingredient_map.is_empty():
		return {}
	return ElementDB.match_recipe(ingredient_map)

func _grid_to_ingredient_map(grid: Array, stacks: Array = []) -> Dictionary:
	var counts: Dictionary = {}
	for r: int in grid.size():
		var row: Array = grid[r]
		for c: int in row.size():
			var cell: String = row[c]
			if cell != "":
				var n: int = 1
				if r < stacks.size() and c < (stacks[r] as Array).size():
					n = maxi(int(stacks[r][c]), 1)
				counts[cell] = counts.get(cell, 0) + n
	return counts

# Total units a recipe needs (H2O = 3). More than 4 needs the full 3x3 bench grid.
func recipe_units(compound: Dictionary) -> int:
	var total: int = 0
	var req: Dictionary = compound.get("elements", {}) as Dictionary
	for k: Variant in req:
		total += int(round(float(req[k])))
	return total

# Look up a compound by its game_item key.
func get_compound_by_item(item_name: String) -> Dictionary:
	return ElementDB.get_compound_by_item(item_name)

# Return all compounds as an Array (for iteration).
func get_all_compounds() -> Array:
	return ElementDB.compounds.values()

# Attempt to craft using the player's inventory (elements only).
# Returns the compound dict on success, {} on failure.
func try_craft(grid_contents: Array, inventory: Node, stacks: Array = []) -> Dictionary:
	var compound: Dictionary = evaluate_grid(grid_contents, stacks)
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
func try_craft_with_items(grid_contents: Array, inventory: Node, equipment: Node, stacks: Array = []) -> Dictionary:
	var compound: Dictionary = evaluate_grid(grid_contents, stacks)
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

# True when the grid holds exactly this compound's ingredients.
func grid_matches(compound: Dictionary, grid_contents: Array, stacks: Array = []) -> bool:
	var req: Dictionary = compound.get("elements", {}) as Dictionary
	return not req.is_empty() and ElementDB._ingredients_match(req, _grid_to_ingredient_map(grid_contents, stacks))

# Craft one specific compound, e.g. the one chosen in the Recipe Book when two
# recipes share ingredients (Steel and Steel Sword are both Fe×4 + C).
# Elements come from `inventory`, item ingredients (polymers) from `equipment`.
# Returns the compound on success, {} (and spends nothing) on failure.
func try_craft_compound(compound: Dictionary, inventory: Node, equipment: Node = null) -> Dictionary:
	var required: Dictionary = compound.get("elements", {}) as Dictionary
	if required.is_empty():
		return {}
	var elem_req: Dictionary = {}
	var item_req: Dictionary = {}
	for k: Variant in required:
		var key: String = str(k)
		if ElementDB.elements.has(key):
			elem_req[key] = float(required[k])
		else:
			item_req[key] = int(required[k])
	if not inventory.has_elements(elem_req):
		return {}
	for item_key: String in item_req:
		if equipment == null or int(equipment.items.get(item_key, 0)) < int(item_req[item_key]):
			return {}
	inventory.remove_elements(elem_req)
	for item_key: String in item_req:
		for _i: int in range(int(item_req[item_key])):
			equipment.use_container(item_key)
	return compound
