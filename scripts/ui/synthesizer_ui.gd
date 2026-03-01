extends PanelContainer

# SynthesizerUI — crafting station for polymer/plastic intermediates.
# Only shows and crafts compounds where synthesizer_only == true.
# Items produced are stored in equipment.items (like lab containers).

const GRID_SIZE: int = 3

@onready var _grid: GridContainer = $VBox/GridContainer
@onready var output_slot: Button  = $VBox/HBox/OutputSlot
@onready var result_label: Label  = $VBox/HBox/ResultLabel
@onready var craft_button: Button = $VBox/CraftButton

var grid_slots: Array = []
var grid_contents: Array = []
var player_inventory: Node = null
var player_equipment: Node = null

func _ready() -> void:
	add_to_group("synthesizer_ui")
	visible = false

	for child in _grid.get_children():
		if child is Button:
			grid_slots.append(child)

	for i: int in range(grid_slots.size()):
		var slot: Button = grid_slots[i]
		slot.pressed.connect(_on_slot_pressed.bind(i))

	craft_button.pressed.connect(_on_craft_pressed)

	grid_contents = []
	for _r: int in range(GRID_SIZE):
		var row: Array = []
		for _c: int in range(GRID_SIZE):
			row.append("")
		grid_contents.append(row)

	_refresh_output()

func toggle_visible() -> void:
	visible = not visible
	if visible:
		_refresh_output()

func _on_slot_pressed(idx: int) -> void:
	@warning_ignore("integer_division")
	var row: int = idx / GRID_SIZE
	var col: int = idx % GRID_SIZE
	if grid_contents[row][col] != "":
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
	# Only show synthesizer_only compounds
	if compound.is_empty() or not bool(compound.get("synthesizer_only", false)):
		result_label.text = ""
		output_slot.text = "?"
		craft_button.disabled = true
		return
	result_label.text = "%s\n%s" % [compound.get("name", ""), compound.get("formula", "")]
	output_slot.text = str(compound.get("game_item", "?")).left(6)
	craft_button.disabled = false

func _on_craft_pressed() -> void:
	if player_inventory == null:
		result_label.text = "No inventory linked!"
		return
	var compound: Dictionary = CraftingSystem.evaluate_grid(grid_contents)
	if compound.is_empty() or not bool(compound.get("synthesizer_only", false)):
		result_label.text = "Invalid recipe!"
		return
	# Consume elements from inventory
	var crafted: Dictionary = CraftingSystem.try_craft(grid_contents, player_inventory)
	if crafted.is_empty():
		result_label.text = "Not enough elements!"
		return
	# Deliver polymer as an equipment item
	var item: String = str(crafted.get("game_item", ""))
	if player_equipment and item != "":
		player_equipment.add_item(item, 1)
	result_label.text = "Synthesized: %s!" % str(crafted.get("name", ""))
	clear_grid()
