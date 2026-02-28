extends PanelContainer

# CraftingUI — 3×3 crafting grid.
# Attached to the Panel node inside crafting_ui.tscn.
# Toggle visibility via get_parent() from HUD's toggle_crafting().
#
# USAGE: set player_inventory reference after instancing:
#   crafting_ui.player_inventory = player.get_node("Inventory")

const GRID_SIZE: int = 3

@onready var _grid: GridContainer   = $VBox/GridContainer
@onready var output_slot: Button    = $VBox/HBox/OutputSlot
@onready var result_label: Label    = $VBox/HBox/ResultLabel
@onready var craft_button: Button   = $VBox/CraftButton

var grid_slots: Array = []          # 9 Button nodes, row-major
var grid_contents: Array = []       # 3×3 array of element symbols
var player_inventory: Node = null

func _ready() -> void:
	# Collect grid slot buttons from GridContainer
	for child in _grid.get_children():
		if child is Button:
			grid_slots.append(child)

	# Wire each slot button to set its own cell
	for i: int in range(grid_slots.size()):
		var slot: Button = grid_slots[i]
		slot.pressed.connect(_on_slot_pressed.bind(i))

	craft_button.pressed.connect(_on_craft_pressed)

	# Initialise empty 3×3 grid
	grid_contents = []
	for _r: int in range(GRID_SIZE):
		var row: Array = []
		for _c: int in range(GRID_SIZE):
			row.append("")
		grid_contents.append(row)

	_refresh_output()

func _on_slot_pressed(idx: int) -> void:
	# TODO Phase 2: open element-picker popup instead of click-to-clear
	@warning_ignore("integer_division")
	var row: int = idx / GRID_SIZE
	var col: int = idx % GRID_SIZE
	var current: String = grid_contents[row][col]
	# Clear slot on click
	if current != "":
		grid_contents[row][col] = ""
		grid_slots[idx].text = ""
	_refresh_output()

func set_slot(row: int, col: int, symbol: String) -> void:
	grid_contents[row][col] = symbol
	grid_slots[row * GRID_SIZE + col].text = symbol
	_refresh_output()

func clear_grid() -> void:
	for r: int in range(GRID_SIZE):
		for c: int in range(GRID_SIZE):
			grid_contents[r][c] = ""
			grid_slots[r * GRID_SIZE + c].text = ""
	_refresh_output()

func _refresh_output() -> void:
	var compound: Dictionary = CraftingSystem.evaluate_grid(grid_contents)
	if compound.is_empty():
		result_label.text = ""
		output_slot.text = "?"
		craft_button.disabled = true
	else:
		result_label.text = "%s\n%s" % [compound.get("name", ""), compound.get("formula", "")]
		output_slot.text = str(compound.get("formula", "?"))
		craft_button.disabled = false

func _on_craft_pressed() -> void:
	if player_inventory == null:
		result_label.text = "No inventory linked!"
		return
	var compound: Dictionary = CraftingSystem.try_craft(grid_contents, player_inventory)
	if compound.is_empty():
		result_label.text = "Not enough elements!"
	else:
		result_label.text = "Crafted: %s!" % str(compound.get("name", ""))
		clear_grid()
