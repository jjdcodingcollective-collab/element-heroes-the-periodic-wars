extends RefCounted

# SaveTransfer — export and import a save ("journal") as a file or a code.
# SYSTEMS_UX_REVIEW.md §3.1 (7): browser saves vanish when site storage is
# cleared, so players can carry their journal out and back in.
#
#   Code format:  EHJ1.<base64 of gzipped save JSON>.<first 8 hex of the base64's MD5>
#   File format:  the plain save JSON (what SaveSystem writes to a slot)
#
# decode() accepts either. Everything is validated (JSON, a Dictionary, a
# known save version, the checksum) and migrated through SaveSystem before
# it is written, so a corrupt or foreign paste can never break a slot.
#
# Use via:  const SaveTransfer := preload("res://scripts/data/save_transfer.gd")

const CODE_PREFIX := "EHJ1."

# Desktop folders; tests point these somewhere private.
static var exports_dir: String = "user://exports/"
static var imports_dir: String = "user://imports/"

# ── Pure encode / decode (unit-testable, no files) ────────────────────────────

static func encode(data: Dictionary) -> String:
	var json := JSON.stringify(data)
	var b64 := Marshalls.raw_to_base64(json.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	return CODE_PREFIX + b64 + "." + b64.md5_text().left(8)

# Returns { "ok": bool, "data": Dictionary, "error": String }. On success the
# data is migrated to the current SaveSystem.SAVE_VERSION.
static func decode(text: String) -> Dictionary:
	var src := text.strip_edges()
	if src == "":
		return _fail("Nothing to import: paste a journal code first.")
	var json_text := src
	if src.begins_with(CODE_PREFIX):
		var parts := src.trim_prefix(CODE_PREFIX).replace("\n", "").replace(" ", "").split(".")
		if parts.size() != 2:
			return _fail("That code is incomplete. Copy the whole code and try again.")
		# Checksum first, so a damaged code never reaches the decompressor.
		if parts[0].md5_text().left(8) != parts[1]:
			return _fail("That code does not match its checksum; part of it is missing or changed.")
		var packed := Marshalls.base64_to_raw(parts[0])
		if packed.size() < 18 or packed[0] != 0x1f or packed[1] != 0x8b:   # gzip magic
			return _fail("That code is damaged and could not be read.")
		var raw := packed.decompress_dynamic(16 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
		if raw.is_empty():
			return _fail("That code is damaged and could not be read.")
		json_text = raw.get_string_from_utf8()
	elif not src.begins_with("{"):
		return _fail("That is not a journal code or a journal file.")
	var json := JSON.new()
	if json.parse(json_text) != OK or not (json.data is Dictionary):
		return _fail("That journal is corrupt and could not be read.")
	return validate(json.data)

# Checks a parsed save and migrates it. Same rules as SaveSystem.read_slot.
static func validate(data: Dictionary) -> Dictionary:
	if not data.has("version") or not data.has("inventory"):
		return _fail("That file is not an Element Heroes journal.")
	var v := int(data.get("version", 0))
	var current: int = _save_system().SAVE_VERSION if _save_system() else v
	if v < 1:
		return _fail("That journal has an unknown version.")
	if v > current:
		return _fail("That journal comes from a newer version of the game.")
	var d: Dictionary = data
	if v < current:
		d = _save_system()._migrate(data, v)
	return { "ok": true, "data": d, "error": "" }

static func _fail(message: String) -> Dictionary:
	return { "ok": false, "data": {}, "error": message }

static func _save_system() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("SaveSystem") if loop else null

# ── Export ────────────────────────────────────────────────────────────────────

static func export_file_name(slot: String) -> String:
	var date := Time.get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_")
	return "%s-%s.json" % [slot, date]

# Exports `slot`. Web: downloads a .json file. Desktop: writes
# exports_dir/<slot>-<date>.json and copies the compact code to the clipboard.
# Returns { "ok", "code", "path", "error" }.
static func export_slot(slot: String) -> Dictionary:
	var ss := _save_system()
	var data: Dictionary = ss.read_slot(slot) if ss else {}
	if data.is_empty():
		return { "ok": false, "code": "", "path": "", "error": "That journal is empty." }
	var code := encode(data)
	var json := JSON.stringify(data, "\t")
	var file_name := export_file_name(slot)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(json.to_utf8_buffer(), "element-heroes-" + file_name, "application/json")
		return { "ok": true, "code": code, "path": file_name, "error": "" }
	DirAccess.make_dir_recursive_absolute(exports_dir)
	var path := exports_dir.path_join(file_name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return { "ok": false, "code": code, "path": "", "error": "Could not write the export file." }
	f.store_string(json)
	f.close()
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(code)
	return { "ok": true, "code": code, "path": path, "error": "" }

# ── Import ────────────────────────────────────────────────────────────────────

# Validates `text` (a code or journal JSON) and writes it into `slot`.
# Returns { "ok", "error" }.
static func import_into(slot: String, text: String) -> Dictionary:
	var result := decode(text)
	if not result["ok"]:
		return { "ok": false, "error": result["error"] }
	var ss := _save_system()
	if ss == null or not ss.write_slot(slot, result["data"]):
		return { "ok": false, "error": "Could not write that journal slot." }
	return { "ok": true, "error": "" }

# Newest .json or .txt in imports_dir ("" if none). Desktop only.
static func newest_import_file() -> String:
	var dir := DirAccess.open(imports_dir)
	if dir == null:
		return ""
	var best := ""
	var best_t := -1
	for f: String in dir.get_files():
		if not (f.ends_with(".json") or f.ends_with(".txt")):
			continue
		var p := imports_dir.path_join(f)
		var t := FileAccess.get_modified_time(p)
		if t > best_t:
			best_t = t
			best = p
	return best

static func read_text_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s
