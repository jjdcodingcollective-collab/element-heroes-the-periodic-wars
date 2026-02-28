extends CanvasLayer

# HUD — top-level in-game UI. Manages minimap, inventory bar, and biome label.
# All sub-UIs (crafting, compendium, dialogue) are children of this node.

@onready var minimap: Control         = $Minimap
@onready var inventory_bar: Control   = $InventoryBar
@onready var biome_label: Label       = $BiomeLabel
@onready var dialogue_ui: CanvasLayer = $DialogueUI

var _player: Node = null
var _world: Node = null
var _biome_timer: float = 0.0

func _ready() -> void:
	add_to_group("ui")
	dialogue_ui.add_to_group("dialogue_ui")

func init(player: Node, world: Node) -> void:
	_player = player
	_world = world
	minimap.player_ref = player

func _process(delta: float) -> void:
	if _world == null or _player == null:
		return
	# Update biome label every 0.5s
	_biome_timer += delta
	if _biome_timer >= 0.5:
		_biome_timer = 0.0
		var biome: String = _world.get_biome_at(_player.global_position)
		biome_label.text = biome.replace("_", " ").capitalize()

func toggle_inventory() -> void:
	inventory_bar.visible = not inventory_bar.visible

func toggle_compendium() -> void:
	var compendium := $Compendium
	if compendium:
		compendium.visible = not compendium.visible

func toggle_crafting() -> void:
	# CraftingUI is a sibling CanvasLayer instanced into world.tscn
	var crafting := get_tree().get_first_node_in_group("crafting_ui")
	if crafting:
		crafting.visible = not crafting.visible

func set_crafting_inventory(inv: Node) -> void:
	var crafting := get_tree().get_first_node_in_group("crafting_ui")
	if crafting:
		crafting.player_inventory = inv
