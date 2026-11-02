extends Node

# UIManager — autoload. One rule for every menu (SYSTEMS_UX_REVIEW.md §3.2):
#   • only one menu is open at a time (opening one closes the other)
#   • every menu pauses the game while open
#   • Esc closes whatever is open; with nothing open it emits `menu_requested`
#     (the journal Contents hub listens to that)
#
# A menu is any node that implements:
#   func _menu_set_open(open: bool) -> void   # show/hide itself
# and registers itself:  UIManager.register("journal", self)
# Menus must use PROCESS_MODE_ALWAYS so they keep working while paused.

signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)
signal menu_requested   # Esc pressed with no menu open

# Keys that open (and close) a menu directly. They work while paused because
# this autoload always processes; the player node does not.
const MENU_KEYS := {
	"open_inventory": "journal",
	"open_compendium": "compendium",
	"open_crafting": "crafting",
	"open_map": "map",
}

var _menus: Dictionary = {}   # name -> Node
var _open_name: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register(menu_name: String, menu: Node) -> void:
	_menus[menu_name] = menu
	menu.tree_exiting.connect(func() -> void:
		if _menus.get(menu_name) == menu:
			_menus.erase(menu_name)
			if _open_name == menu_name:
				_open_name = ""
				_set_paused(false))

func has_menu(menu_name: String) -> bool:
	return _menus.has(menu_name) and is_instance_valid(_menus[menu_name])

func get_menu(menu_name: String) -> Node:
	return _menus.get(menu_name) if has_menu(menu_name) else null

func open_menu_name() -> String:
	return _open_name

func is_open(menu_name: String = "") -> bool:
	return _open_name != "" if menu_name == "" else _open_name == menu_name

func open(menu_name: String) -> bool:
	if not has_menu(menu_name):
		return false
	if _open_name == menu_name:
		return true
	if _open_name != "":
		close(_open_name)
	_open_name = menu_name
	_menus[menu_name]._menu_set_open(true)
	_set_paused(true)
	menu_opened.emit(menu_name)
	return true

func close(menu_name: String = "") -> void:
	var target: String = _open_name if menu_name == "" else menu_name
	if target == "" or target != _open_name:
		return
	_open_name = ""
	if has_menu(target):
		_menus[target]._menu_set_open(false)
	_set_paused(false)
	menu_closed.emit(target)

func toggle(menu_name: String) -> void:
	if _open_name == menu_name:
		close(menu_name)
	else:
		open(menu_name)

func close_all() -> void:
	close()

func _set_paused(paused: bool) -> void:
	if is_inside_tree():
		get_tree().paused = paused

func _unhandled_input(event: InputEvent) -> void:
	for action: String in MENU_KEYS:
		if event.is_action_pressed(action) and has_menu(MENU_KEYS[action]):
			# Don't open menus over dialogue; it closes itself when read.
			if _open_name == "dialogue":
				return
			toggle(MENU_KEYS[action])
			get_viewport().set_input_as_handled()
			return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _open_name != "":
		close()
	else:
		menu_requested.emit()
	get_viewport().set_input_as_handled()
