extends Node

# AudioManager — autoload singleton for all game audio.
#
# HOW TO ADD YOUR AUDIO FILES:
#   Music:  drop .ogg files into  res://assets/audio/music/
#   SFX:    drop .ogg files into  res://assets/audio/sfx/
#   Then uncomment the matching preload lines below.
#
# MUSIC FILES EXPECTED (one loop per biome + UI):
#   surface_plains.ogg    underground_mines.ogg   crystal_caverns.ogg
#   sky_islands.ogg       ocean_floor.ogg          magma_layer.ogg
#   boss_battle.ogg       title.ogg
#
# SFX FILES EXPECTED:
#   dig.ogg           pickup.ogg        attack_melee.ogg   attack_ranged.ogg
#   player_hit.ogg    enemy_hit.ogg     enemy_die.ogg      boss_hit.ogg
#   boss_phase.ogg    craft_success.ogg quiz_correct.ogg   quiz_wrong.ogg
#   interact.ogg      ui_open.ogg       ui_close.ogg

# ── Preloads (uncomment as you add files) ─────────────────────────────────────

# const MUSIC := {
# 	"surface_plains":    preload("res://assets/audio/music/surface_plains.ogg"),
# 	"underground_mines": preload("res://assets/audio/music/underground_mines.ogg"),
# 	"crystal_caverns":   preload("res://assets/audio/music/crystal_caverns.ogg"),
# 	"sky_islands":       preload("res://assets/audio/music/sky_islands.ogg"),
# 	"ocean_floor":       preload("res://assets/audio/music/ocean_floor.ogg"),
# 	"magma_layer":       preload("res://assets/audio/music/magma_layer.ogg"),
# 	"boss_battle":       preload("res://assets/audio/music/boss_battle.ogg"),
# 	"title":             preload("res://assets/audio/music/title.ogg"),
# }

# const SFX := {
# 	"dig":           preload("res://assets/audio/sfx/dig.ogg"),
# 	"pickup":        preload("res://assets/audio/sfx/pickup.ogg"),
# 	"attack_melee":  preload("res://assets/audio/sfx/attack_melee.ogg"),
# 	"attack_ranged": preload("res://assets/audio/sfx/attack_ranged.ogg"),
# 	"player_hit":    preload("res://assets/audio/sfx/player_hit.ogg"),
# 	"enemy_hit":     preload("res://assets/audio/sfx/enemy_hit.ogg"),
# 	"enemy_die":     preload("res://assets/audio/sfx/enemy_die.ogg"),
# 	"boss_hit":      preload("res://assets/audio/sfx/boss_hit.ogg"),
# 	"boss_phase":    preload("res://assets/audio/sfx/boss_phase.ogg"),
# 	"craft_success": preload("res://assets/audio/sfx/craft_success.ogg"),
# 	"quiz_correct":  preload("res://assets/audio/sfx/quiz_correct.ogg"),
# 	"quiz_wrong":    preload("res://assets/audio/sfx/quiz_wrong.ogg"),
# 	"interact":      preload("res://assets/audio/sfx/interact.ogg"),
# 	"ui_open":       preload("res://assets/audio/sfx/ui_open.ogg"),
# 	"ui_close":      preload("res://assets/audio/sfx/ui_close.ogg"),
# }

# Placeholder dicts — replaced by the preload dicts above once files exist
const MUSIC: Dictionary = {}
const SFX: Dictionary   = {}

# ── Volume settings ────────────────────────────────────────────────────────────

const MUSIC_BUS: String = "Music"
const SFX_BUS:   String = "SFX"

var music_volume_db: float = 0.0    # -40 to 0
var sfx_volume_db:   float = 0.0
var _music_muted: bool     = false
var _sfx_muted:   bool     = false

# ── Internal nodes ─────────────────────────────────────────────────────────────

var _music_player_a: AudioStreamPlayer   # crossfade channel A
var _music_player_b: AudioStreamPlayer   # crossfade channel B
var _active_music:   AudioStreamPlayer   # which channel is currently "on"
var _sfx_pool:       Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 12
const CROSSFADE_TIME: float = 1.5

var _current_track: String = ""

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_ensure_audio_buses()
	_build_music_players()
	_build_sfx_pool()

func _ensure_audio_buses() -> void:
	# Create Music and SFX buses if they don't exist in the project's AudioServer
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, MUSIC_BUS)
		AudioServer.set_bus_send(AudioServer.get_bus_count() - 1, "Master")
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, SFX_BUS)
		AudioServer.set_bus_send(AudioServer.get_bus_count() - 1, "Master")

func _build_music_players() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = MUSIC_BUS
	_music_player_a.volume_db = music_volume_db
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = MUSIC_BUS
	_music_player_b.volume_db = -80.0  # start silent
	add_child(_music_player_b)

	_active_music = _music_player_a

func _build_sfx_pool() -> void:
	for _i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_pool.append(p)

# ── Public API — Music ─────────────────────────────────────────────────────────

## Play a music track by key. Crossfades if a different track is already playing.
## Call this whenever the player enters a new biome or a boss fight starts.
func play_music(track_key: String, loop: bool = true) -> void:
	if track_key == _current_track:
		return
	if not MUSIC.has(track_key):
		# No file yet — silently skip (game still runs without audio)
		_current_track = track_key
		return
	_current_track = track_key
	var stream: AudioStream = MUSIC[track_key]
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	_crossfade_to(stream)

func stop_music() -> void:
	_current_track = ""
	_crossfade_to(null)

func set_music_volume(linear: float) -> void:
	music_volume_db = linear_to_db(clampf(linear, 0.0, 1.0))
	var bus_idx := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, music_volume_db)

func mute_music(muted: bool) -> void:
	_music_muted = muted
	var bus_idx := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, muted)

# ── Public API — SFX ──────────────────────────────────────────────────────────

## Play a one-shot sound effect by key. Safe to call even if file not yet added.
func play_sfx(sfx_key: String, volume_scale: float = 1.0) -> void:
	if not SFX.has(sfx_key):
		return
	var player := _get_free_sfx_player()
	if player == null:
		return
	player.stream    = SFX[sfx_key]
	player.volume_db = music_volume_db + linear_to_db(clampf(volume_scale, 0.01, 2.0))
	player.play()

func set_sfx_volume(linear: float) -> void:
	sfx_volume_db = linear_to_db(clampf(linear, 0.0, 1.0))
	var bus_idx := AudioServer.get_bus_index(SFX_BUS)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, sfx_volume_db)

func mute_sfx(muted: bool) -> void:
	_sfx_muted = muted
	var bus_idx := AudioServer.get_bus_index(SFX_BUS)
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, muted)

# ── Convenience shortcuts ──────────────────────────────────────────────────────
# Call these from other scripts instead of remembering key strings.

func on_dig()          -> void: play_sfx("dig")
func on_pickup()       -> void: play_sfx("pickup")
func on_attack_melee() -> void: play_sfx("attack_melee")
func on_attack_ranged()-> void: play_sfx("attack_ranged")
func on_player_hit()   -> void: play_sfx("player_hit")
func on_enemy_hit()    -> void: play_sfx("enemy_hit")
func on_enemy_die()    -> void: play_sfx("enemy_die")
func on_boss_hit()     -> void: play_sfx("boss_hit")
func on_boss_phase()   -> void: play_sfx("boss_phase", 1.4)
func on_craft()        -> void: play_sfx("craft_success")
func on_quiz_correct() -> void: play_sfx("quiz_correct")
func on_quiz_wrong()   -> void: play_sfx("quiz_wrong")
func on_interact()     -> void: play_sfx("interact")
func on_ui_open()      -> void: play_sfx("ui_open")
func on_ui_close()     -> void: play_sfx("ui_close")

## Called by world/HUD when player moves into a new biome.
func on_biome_changed(biome_name: String) -> void:
	play_music(biome_name)

## Called by boss.gd when a boss fight begins.
func on_boss_fight_start() -> void:
	play_music("boss_battle")

## Called by boss.gd when the boss is defeated — resume biome music.
func on_boss_fight_end(biome_name: String) -> void:
	play_music(biome_name)

# ── Internal ───────────────────────────────────────────────────────────────────

func _crossfade_to(new_stream: AudioStream) -> void:
	var incoming: AudioStreamPlayer
	var outgoing: AudioStreamPlayer

	if _active_music == _music_player_a:
		incoming = _music_player_b
		outgoing = _music_player_a
	else:
		incoming = _music_player_a
		outgoing = _music_player_b

	if new_stream != null:
		incoming.stream = new_stream
		incoming.volume_db = -80.0
		incoming.play()
		_active_music = incoming

	# Tween volumes
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	if new_stream != null:
		tween.tween_property(incoming, "volume_db", music_volume_db, CROSSFADE_TIME)
	tween.tween_property(outgoing, "volume_db", -80.0, CROSSFADE_TIME)
	tween.tween_callback(outgoing.stop).set_delay(CROSSFADE_TIME)

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _sfx_pool:
		if not p.playing:
			return p
	# All busy — reuse the oldest (first in pool)
	return _sfx_pool[0]
