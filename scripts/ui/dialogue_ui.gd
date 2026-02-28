extends CanvasLayer

# DialogueUI — displays NPC dialogue in a bottom panel.
# Shows portrait placeholder, speaker name, and paged text.
#
# SPRITE SWAP: replace portrait ColorRect with a TextureRect
# and assign portrait textures per NPC without touching any other logic.

signal dialogue_finished

const CHARS_PER_SECOND: float = 40.0

@onready var panel: PanelContainer    = $Panel
@onready var portrait_slot: Control   = $Panel/HBox/PortraitSlot
@onready var name_label: Label        = $Panel/HBox/VBox/NameLabel
@onready var text_label: RichTextLabel = $Panel/HBox/VBox/TextLabel
@onready var continue_hint: Label     = $Panel/HBox/VBox/ContinueHint

var _lines: Array[String] = []
var _current_line: int = 0
var _typing: bool = false
var _char_timer: float = 0.0
var _displayed_chars: int = 0
var _portrait_rect: ColorRect = null

func _ready() -> void:
	panel.visible = false
	continue_hint.text = "[ Press F or Click to continue ]"

func show_dialogue(speaker: String, lines: Array[String], portrait_color: Color = Color(0.3, 0.5, 0.7)) -> void:
	_lines = lines
	_current_line = 0
	panel.visible = true
	get_tree().paused = false  # dialogue doesn't pause physics

	name_label.text = speaker

	# Placeholder portrait — swap with TextureRect + texture in Phase 2
	if _portrait_rect == null:
		_portrait_rect = ColorRect.new()
		_portrait_rect.custom_minimum_size = Vector2(48, 48)
		portrait_slot.add_child(_portrait_rect)
	_portrait_rect.color = portrait_color

	_show_line(_current_line)

func _show_line(idx: int) -> void:
	text_label.text = ""
	_displayed_chars = 0
	_char_timer = 0.0
	_typing = true
	continue_hint.visible = false

func _process(delta: float) -> void:
	if not panel.visible or not _typing:
		return
	_char_timer += delta
	var chars_to_show: int = int(_char_timer * CHARS_PER_SECOND)
	if chars_to_show != _displayed_chars:
		_displayed_chars = chars_to_show
		var full: String = _lines[_current_line]
		text_label.text = full.substr(0, min(_displayed_chars, full.length()))
		if _displayed_chars >= full.length():
			_typing = false
			continue_hint.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	var advance: bool = event.is_action_pressed("interact") or \
				   (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not advance:
		return

	get_viewport().set_input_as_handled()

	if _typing:
		# Skip to end of current line
		text_label.text = _lines[_current_line]
		_typing = false
		continue_hint.visible = true
		return

	_current_line += 1
	if _current_line >= _lines.size():
		panel.visible = false
		emit_signal("dialogue_finished")
	else:
		_show_line(_current_line)

func is_open() -> bool:
	return panel.visible
