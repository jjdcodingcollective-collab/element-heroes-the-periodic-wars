extends Node

# Weapon — manages the player's currently equipped weapon.
# Handles melee swings (Area2D hitbox flash) and ranged firing (projectile spawn).
# Reads weapon stats from the compound's "weapon" dictionary via CraftingSystem.

signal weapon_changed(weapon_name: String)

const PROJECTILE_SCENE: String = "res://scenes/world/projectile.tscn"

# Currently equipped weapon item name (matches compounds.json game_item)
var equipped_item: String = ""
var _stats: Dictionary = {}        # weapon sub-dict from compounds.json
var _cooldown_timer: float = 0.0
var _burn_timers: Dictionary = {}  # { enemy_node: time_remaining }

# Visual swing arc (ColorRect that flashes briefly)
var _swing_rect: ColorRect = null

func _ready() -> void:
	_spawn_swing_rect()

func _spawn_swing_rect() -> void:
	_swing_rect = ColorRect.new()
	_swing_rect.size = Vector2(20, 6)
	_swing_rect.position = Vector2(8, -3)
	_swing_rect.visible = false
	_swing_rect.z_index = 5
	add_child(_swing_rect)

func _process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_tick_burns(delta)

func equip(item_name: String) -> void:
	var compound: Dictionary = _find_compound(item_name)
	if compound.is_empty() or not compound.has("weapon"):
		return
	equipped_item = item_name
	_stats = compound["weapon"] as Dictionary
	# Tint swing rect to weapon colour
	var c: Array = _stats.get("color", [1.0, 1.0, 1.0]) as Array
	_swing_rect.color = Color(float(c[0]), float(c[1]), float(c[2]), 0.85)
	weapon_changed.emit(item_name)

func unequip() -> void:
	equipped_item = ""
	_stats = {}
	weapon_changed.emit("")

func has_weapon() -> bool:
	return not _stats.is_empty()

func get_weapon_name() -> String:
	return equipped_item

func get_tier() -> int:
	return int(_stats.get("tier", 0))

# Called by player on attack input. Returns true if attack fired.
func try_attack(player_facing: Vector2) -> bool:
	if _stats.is_empty() or _cooldown_timer > 0.0:
		return false
	_cooldown_timer = float(_stats.get("cooldown", 0.5))
	var weapon_type: String = str(_stats.get("type", "melee"))
	if weapon_type == "melee":
		_do_melee(player_facing)
	else:
		_do_ranged(player_facing)
	return true

# ── Melee ─────────────────────────────────────────────────────────────────────

func _do_melee(facing: Vector2) -> void:
	var player: Node2D = get_parent() as Node2D
	var range_px: float = float(_stats.get("range", 48.0))
	var damage: float   = float(_stats.get("damage", 10.0))
	var kb: float       = float(_stats.get("knockback", 60.0))

	# Flash the swing rect in facing direction
	_swing_rect.visible = true
	_swing_rect.position = facing * (range_px * 0.4) + Vector2(-10, -3)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(_swing_rect, "visible", false, 0.12).set_delay(0.12)

	# Hit all enemies within range in a 120° arc facing the swing direction
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e: Node in enemies:
		var en: Node2D = e as Node2D
		var to_enemy: Vector2 = en.global_position - player.global_position
		if to_enemy.length() > range_px:
			continue
		# Arc check: dot product with facing (cos 60° = 0.5)
		if facing.dot(to_enemy.normalized()) < 0.4:
			continue
		_apply_hit(en, damage, kb, facing)

# ── Ranged ────────────────────────────────────────────────────────────────────

func _do_ranged(facing: Vector2) -> void:
	var proj_scene: PackedScene = load(PROJECTILE_SCENE)
	if proj_scene == null:
		return
	var player: Node2D = get_parent() as Node2D
	var proj: Node2D = proj_scene.instantiate() as Node2D
	proj.global_position = player.global_position + facing * 10.0

	# Pass stats to projectile
	proj.set_meta("damage",          float(_stats.get("damage", 10.0)))
	proj.set_meta("speed",           float(_stats.get("projectile_speed", 180.0)))
	proj.set_meta("max_range",       float(_stats.get("range", 200.0)))
	proj.set_meta("direction",       facing)
	proj.set_meta("knockback",       float(_stats.get("knockback", 40.0)))
	proj.set_meta("splash_radius",   float(_stats.get("splash_radius", 0.0)))
	proj.set_meta("piercing",        bool(_stats.get("piercing", false)))
	proj.set_meta("burn_dps",        float(_stats.get("burn_dps", 0.0)))
	proj.set_meta("burn_duration",   float(_stats.get("burn_duration", 0.0)))
	var c: Array = _stats.get("color", [1.0, 1.0, 0.3]) as Array
	proj.set_meta("color", Color(float(c[0]), float(c[1]), float(c[2])))

	player.get_parent().add_child(proj)

# ── Hit application ────────────────────────────────────────────────────────────

func _apply_hit(enemy: Node2D, damage: float, knockback: float, direction: Vector2) -> void:
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	# Knockback: push enemy away from player
	if enemy is CharacterBody2D:
		var cb: CharacterBody2D = enemy as CharacterBody2D
		cb.velocity += direction * knockback

	# DoT (burn / radiation)
	var burn_dps: float = float(_stats.get("burn_dps", 0.0))
	var burn_dur: float = float(_stats.get("burn_duration", 0.0))
	if burn_dps > 0.0 and burn_dur > 0.0:
		_burn_timers[enemy] = burn_dur
		if not enemy.has_meta("burn_dps"):
			enemy.set_meta("burn_dps", burn_dps)

func _tick_burns(delta: float) -> void:
	var to_remove: Array = []
	for enemy: Variant in _burn_timers.keys():
		var node: Node = enemy as Node
		if not is_instance_valid(node):
			to_remove.append(enemy)
			continue
		_burn_timers[enemy] = float(_burn_timers[enemy]) - delta
		var dps: float = float(node.get_meta("burn_dps", 0.0))
		if dps > 0.0 and node.has_method("take_damage"):
			node.take_damage(dps * delta)
		if float(_burn_timers[enemy]) <= 0.0:
			to_remove.append(enemy)
			if node.has_meta("burn_dps"):
				node.remove_meta("burn_dps")
	for key: Variant in to_remove:
		_burn_timers.erase(key)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _find_compound(item_name: String) -> Dictionary:
	# CraftingSystem exposes all_recipes() or we search by game_item
	if CraftingSystem.has_method("get_compound_by_item"):
		return CraftingSystem.get_compound_by_item(item_name)
	# Fallback: search compounds list if exposed
	if CraftingSystem.has_method("get_all_compounds"):
		var all: Array = CraftingSystem.get_all_compounds()
		for c: Dictionary in all:
			if str(c.get("game_item", "")) == item_name:
				return c
	return {}
