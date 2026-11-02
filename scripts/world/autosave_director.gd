extends Node

# Autosave director (SYSTEMS_UX_REVIEW.md §3.1): writes the "autosave" slot,
# which never overwrites a manual save, when the player
#   • enters a biome for the first time this session,
#   • defeats a boss,
#   • discovers a Field Station,
#   • has played for 5 minutes since the last save.
# Never while the player is dead or a boss fight is on: the request waits
# until it is safe. Spawned by world.gd as the "Autosave" child.
# Pausable (the default), so the timer only counts unpaused play.

const INTERVAL: float = 300.0

var interval: float = INTERVAL
var last_reason: String = ""     # why the most recent autosave happened
var _elapsed: float = 0.0
var _pending: String = ""
var _visited: Dictionary = {}    # biome name -> true, this session
var _world: Node = null
var _player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE   # explicit: menus must stop the clock

func setup(world: Node, player: Node) -> void:
	_world = world
	_player = player
	if not SaveSystem.saved.is_connected(_on_saved):
		SaveSystem.saved.connect(_on_saved)

func request(reason: String) -> void:
	_pending = reason
	_try_autosave()

func can_autosave() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if bool(_player.get("is_dead")):
		return false
	if _world and _world.has_method("is_boss_fight_active") and _world.is_boss_fight_active():
		return false
	return true

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_elapsed += delta
	var biome: String = _world.get_biome_at((_player as Node2D).global_position)
	if not _visited.has(biome):
		var first: bool = _visited.is_empty()   # where the session starts doesn't count
		_visited[biome] = true
		if not first:
			_pending = "biome"
	if _elapsed >= interval and _pending == "":
		_pending = "timer"
	_try_autosave()

func _try_autosave() -> void:
	if _pending == "" or not can_autosave():
		return
	var reason := _pending
	_pending = ""
	if SaveSystem.autosave(_player):
		last_reason = reason

# Any save (manual or auto) restarts the 5-minute clock.
func _on_saved(_slot: String, ok: bool) -> void:
	if ok:
		_elapsed = 0.0
