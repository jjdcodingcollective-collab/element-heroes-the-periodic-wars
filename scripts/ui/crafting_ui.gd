extends Control

# CraftingUI — 3x3 crafting grid UI.
# Attach to a CanvasLayer/Control node in the crafting scene.

const GRID_SIZE: int = 3

@onready var grid_slots: Array = []   # Array of Button nodes, row-major
@onready var output_slot: Button = $OutputSlot
@onready var result_label: Label = $ResultLabel
@onready var craft_button: Button = $CraftButton

var grid_contents: Array = []   # 3x3 array of symbols
var player_inventory: Node = null

func _ready() -> void:
	# Initialise empty grid
	grid_contents = []
	for r in range(GRID_SIZE):
		var row = []
		for c in range(GRID_SIZE):
			row.append("")
		grid_contents.append(row)

	craft_button.pressed.connect(_on_craft_pressed)
	_refresh_output()

# Call this after placing an element in a slot
func set_slot(row: int, col: int, symbol: String) -> void:
	grid_contents[row][col] = symbol
	_refresh_output()

func clear_grid() -> void:
	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			grid_contents[r][c] = ""
	_refresh_output()

func _refresh_output() -> void:
	var compound = CraftingSystem.evaluate_grid(grid_contents)
	if compound.is_empty():
		result_label.text = ""
		output_slot.text = "?"
		craft_button.disabled = true
	else:
		result_label.text = "%s\n%s" % [compound.get("name", ""), compound.get("formula", "")]
		output_slot.text = compound.get("formula", "?")
		craft_button.disabled = false

func _on_craft_pressed() -> void:
	if player_inventory == null:
		push_error("CraftingUI: player_inventory not set")
		return
	var compound = CraftingSystem.try_craft(grid_contents, player_inventory)
	if compound.is_empty():
		result_label.text = "Not enough elements!"
	else:
		result_label.text = "Crafted: %s!" % compound.get("name", "")
		clear_grid()
