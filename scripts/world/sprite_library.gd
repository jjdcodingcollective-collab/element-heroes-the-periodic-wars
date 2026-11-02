extends RefCounted

# Sprite integration layer — turns the sheets described in
# assets/sprites/SPRITE_SPEC.md into SpriteFrames at runtime.
#
# Every entity calls attach(): if the sheet exists and is big enough it gets an
# AnimatedSprite2D, otherwise it gets null and keeps its ColorRect placeholder.
# Dropping a correctly laid-out PNG into the right folder is the whole art
# hand-off; no scene or SpriteFrames editing is needed.
#
# Usage (preload rather than class_name, so headless runs need no class cache):
#   const SpriteLibrary := preload("res://scripts/world/sprite_library.gd")
#   var spr := SpriteLibrary.attach(self, SpriteLibrary.player_path(), "character")

const ROOT := "res://assets/sprites/"

# Human/creature frame size. The 16×16 vs 16×24 decision is still open
# (ART_STYLE.md); changing this one constant re-cuts every character sheet.
const CHARACTER_FRAME := Vector2i(16, 16)

# Each layout: frame size, one row per animation [name, frames, fps, loop],
# and where the bottom edge of a frame sits relative to the node origin
# (null = centred, used by bosses whose placeholder is centred).
const LAYOUTS := {
	"character": {
		"frame": CHARACTER_FRAME,
		"bottom": 8.0,
		"rows": [
			["idle_down",  2, 4.0, true],
			["idle_up",    2, 4.0, true],
			["idle_left",  2, 4.0, true],
			["idle_right", 2, 4.0, true],
			["walk_down",  4, 8.0, true],
			["walk_up",    4, 8.0, true],
			["walk_left",  4, 8.0, true],
			["walk_right", 4, 8.0, true],
		],
	},
	"npc": {
		"frame": CHARACTER_FRAME,
		"bottom": 0.0,   # NPC origin is at the feet
		"rows": [
			["idle", 2, 2.0, true],
		],
	},
	"enemy": {
		"frame": Vector2i(16, 16),
		"bottom": 8.0,
		"rows": [
			["walk_left",  4, 8.0, true],
			["walk_right", 4, 8.0, true],
		],
	},
	"boss": {
		"frame": Vector2i(48, 48),
		"bottom": null,
		"rows": [
			["idle",   4, 4.0, true],
			["attack", 2, 8.0, false],
		],
	},
}

static var _cache: Dictionary = {}   # path -> SpriteFrames (or null when missing)

static func player_path() -> String:
	return ROOT + "player/orion.png"

static func enemy_path(creature_id: String) -> String:
	return ROOT + "enemies/%s.png" % creature_id

static func boss_path(boss_id: String) -> String:
	return ROOT + "bosses/%s.png" % boss_id

static func npc_path(sprite_id: String) -> String:
	return ROOT + "npc/%s.png" % sprite_id

# Cached SpriteFrames for a sheet on disk, or null if the file is absent or the
# wrong size. Missing art is the normal state today, so it is silent.
static func load_frames(path: String, layout_name: String) -> SpriteFrames:
	var key := "%s|%s" % [path, layout_name]
	if _cache.has(key):
		return _cache[key]
	var frames: SpriteFrames = null
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			frames = frames_from_texture(tex, layout_name)
			if frames == null:
				push_warning("SpriteLibrary: %s is too small for the '%s' layout" % [path, layout_name])
	_cache[key] = frames
	return frames

# Cuts a sheet into animations, one row per animation, left to right.
# Returns null when the texture cannot hold every frame the layout needs.
static func frames_from_texture(tex: Texture2D, layout_name: String) -> SpriteFrames:
	var layout: Dictionary = LAYOUTS[layout_name]
	var fs: Vector2i = layout["frame"]
	var rows: Array = layout["rows"]
	var widest: int = 0
	for row: Array in rows:
		widest = maxi(widest, int(row[1]))
	if tex.get_width() < widest * fs.x or tex.get_height() < rows.size() * fs.y:
		return null

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for r: int in rows.size():
		var row: Array = rows[r]
		var anim: String = row[0]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(row[2]))
		frames.set_animation_loop(anim, bool(row[3]))
		for c: int in int(row[1]):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(c * fs.x, r * fs.y, fs.x, fs.y)
			frames.add_frame(anim, atlas)
	return frames

# Adds (or fills) an AnimatedSprite2D on owner when the sheet exists.
# Pass an existing node as `sprite` to reuse it (the player scene has one).
static func attach(owner: Node2D, path: String, layout_name: String,
		sprite: AnimatedSprite2D = null) -> AnimatedSprite2D:
	var frames := load_frames(path, layout_name)
	if frames == null:
		return null
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "Sprite"
		owner.add_child(sprite)
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	var bottom: Variant = LAYOUTS[layout_name]["bottom"]
	if bottom != null:
		var fh: float = float(LAYOUTS[layout_name]["frame"].y)
		sprite.offset = Vector2(0.0, float(bottom) - fh / 2.0)
	sprite.play(LAYOUTS[layout_name]["rows"][0][0])
	return sprite

static func clear_cache() -> void:
	_cache.clear()
