extends CanvasLayer

# Inventory screen (E). Four tabs:
#   Elements    — collected element samples (Inventory)
#   Equipment   — weapon, armour and lab gear (Weapon / Armor / Equipment)
#   Consumables — potions, usable from here (Bag)
#   Key Items   — Boss Keys and Key Fragments, grouped by boss; permanent (Bag)
# Ashmarks are shown in the header. Built in code, like the other UIs.

const TAB_NAMES := ["Elements", "Equipment", "Consumables", "Key Items"]
const BOSS_ORDER := ["peroxis", "chalcor", "aurium", "azrael", "atacama", "uranox"]

var _dim: ColorRect
var _panel: PanelContainer
var _tabs: TabContainer
var _ashmarks_label: Label
var _lists: Dictionary = {}   # tab name -> VBoxContainer
var _player: Node = null

func _ready() -> void:
	layer = 9
	add_to_group("inventory_screen")
	_build_ui()
	_set_open(false)

func is_open() -> bool:
	return _panel.visible

func toggle() -> void:
	_set_open(not is_open())
	if is_open():
		AudioManager.on_ui_open()
		refresh()
	else:
		AudioManager.on_ui_close()

func show_tab(tab_name: String) -> void:
	_tabs.current_tab = maxi(TAB_NAMES.find(tab_name), 0)

func _set_open(open: bool) -> void:
	_panel.visible = open
	_dim.visible = open   # hidden overlays must not block clicks (see quiz bug)

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

# ── Building ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(720, 460)
	_panel.offset_left = -360.0
	_panel.offset_right = 360.0
	_panel.offset_top = -230.0
	_panel.offset_bottom = 230.0
	add_child(_panel)

	var root := VBoxContainer.new()
	_panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_ashmarks_label = Label.new()
	_ashmarks_label.add_theme_font_size_override("font_size", 16)
	_ashmarks_label.modulate = Color(0.95, 0.75, 0.4)
	header.add_child(_ashmarks_label)
	var hint := Label.new()
	hint.text = "   [E / Esc] close"
	hint.modulate = Color(0.7, 0.7, 0.7)
	header.add_child(hint)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	for tab_name: String in TAB_NAMES:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tabs.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		_lists[tab_name] = list

# ── Content ───────────────────────────────────────────────────────────────────

func refresh() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	var bag: Node = _player.get_node_or_null("Bag")
	if bag and not bag.bag_changed.is_connected(_on_bag_changed):
		bag.bag_changed.connect(_on_bag_changed)
	_ashmarks_label.text = "%d Ashmarks" % (bag.ashmarks if bag else 0)
	for tab_name: String in TAB_NAMES:
		for c: Node in _lists[tab_name].get_children():
			c.queue_free()
	_fill_elements()
	_fill_equipment()
	_fill_consumables(bag)
	_fill_key_items(bag)

func _on_bag_changed() -> void:
	if is_open():
		refresh()

func _row(tab_name: String, text: String, colour := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = colour
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lists[tab_name].add_child(l)
	return l

func _fill_elements() -> void:
	var inv: Node = _player.get_node_or_null("Inventory")
	var all: Dictionary = inv.get_all() if inv else {}
	if all.is_empty():
		_row("Elements", "No samples yet. Dig ore tiles to collect elements.", Color(0.7, 0.7, 0.7))
		return
	var symbols: Array = all.keys()
	symbols.sort()
	for symbol: String in symbols:
		_row("Elements", "%s   %s" % [symbol, inv.format_amount(symbol, float(all[symbol]))])

func _fill_equipment() -> void:
	var wpn: Node = _player.get_node_or_null("Weapon")
	var arm: Node = _player.get_node_or_null("Armor")
	var eq: Node = _player.get_node_or_null("Equipment")
	var w_name: String = wpn.get_weapon_name().replace("_", " ").capitalize() if wpn and wpn.has_weapon() else "none"
	_row("Equipment", "Weapon:  %s" % w_name, Color(1.0, 0.9, 0.6))
	var a_name: String = "none"
	if arm and arm.has_method("has_armor") and arm.has_armor():
		a_name = "%s (%d%% damage reduction)" % [arm.get_armor_name().replace("_", " ").capitalize(), int(arm.get_damage_reduction() * 100.0)]
	_row("Equipment", "Armour:  %s" % a_name, Color(0.7, 0.9, 1.0))
	_row("Equipment", "")
	_row("Equipment", "Lab gear", Color(0.8, 0.8, 0.8))
	var items: Dictionary = eq.get_all() if eq else {}
	if items.is_empty():
		_row("Equipment", "  none", Color(0.6, 0.6, 0.6))
	for item: String in items:
		var worn: bool = item in eq.REUSABLE
		_row("Equipment", "  %s%s" % [item, "  (worn)" if worn else "  ×%d" % int(items[item])])

func _fill_consumables(bag: Node) -> void:
	if bag == null or bag.consumables.is_empty():
		_row("Consumables", "No consumables. Enemies sometimes drop potions.", Color(0.7, 0.7, 0.7))
		return
	for id: String in bag.consumables:
		var info: Dictionary = bag.item_info(id)
		var line := HBoxContainer.new()
		_lists["Consumables"].add_child(line)
		var l := Label.new()
		l.text = "%s ×%d\n  %s" % [info.get("name", id), bag.consumable_count(id), info.get("description", "")]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(l)
		var use := Button.new()
		use.text = "Use"
		use.pressed.connect(func() -> void: bag.use_consumable(id))
		line.add_child(use)

func _fill_key_items(bag: Node) -> void:
	var cat: Dictionary = bag.catalogue().get("key_items", {}) if bag else {}
	var any: bool = false
	for boss: String in BOSS_ORDER:
		var key_id: String = ""
		var frags: Array = []
		for id: String in cat:
			if cat[id].get("boss", "") != boss:
				continue
			if cat[id].get("kind", "") == "boss_key":
				key_id = id
			else:
				frags.append(id)
		if key_id == "":
			continue
		var boss_name: String = boss.to_upper()
		if bag.has_key_item(key_id):
			any = true
			_row("Key Items", "★ %s  (Boss Key: %s)" % [cat[key_id].get("name", key_id), boss_name], Color(1.0, 0.85, 0.4))
			_row("Key Items", "   " + str(cat[key_id].get("description", "")), Color(0.8, 0.8, 0.8))
			continue
		var held: Array = frags.filter(func(f: String) -> bool: return bag.has_key_item(f))
		if held.is_empty():
			continue
		any = true
		_row("Key Items", "%s fragments: %d / %d" % [boss_name, held.size(), frags.size()], Color(0.85, 0.75, 1.0))
		for f: String in held:
			_row("Key Items", "   • %s" % cat[f].get("name", f))
	if not any:
		_row("Key Items", "No key items yet. Defeat a Warden to earn a Key Fragment.", Color(0.7, 0.7, 0.7))
	else:
		_row("Key Items", "")
		_row("Key Items", "Key items are permanent: once earned, they are yours.", Color(0.6, 0.6, 0.6))
