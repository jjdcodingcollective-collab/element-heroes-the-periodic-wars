extends CanvasLayer

# Science Mini-Game UI — Aldric's Lab Quiz
#
# Triggered when the player interacts with Aldric's desk (lab_office world object).
# Shows a random chemistry question with 4 multiple-choice answers.
# Correct answer rewards element drops directly into inventory.
# Wrong answer costs 5 HP (minor penalty) and skips to next question.
#
# State machine:
#   IDLE  → INTRO  → QUESTION  → FEEDBACK  → IDLE (or next question)
#
# Integration:
#   • add_to_group("science_minigame_ui")
#   • Called via call_group("science_minigame_ui", "open_minigame", player_node)
#   • Reads data/quiz_questions.json via ElementDB autoload (or direct FileAccess)

signal minigame_closed

const QUESTIONS_PER_SESSION: int = 3
const WRONG_PENALTY_HP: float    = 5.0
const PANEL_COLOR: Color         = Color(0.08, 0.10, 0.14, 0.96)
const CORRECT_COLOR: Color       = Color(0.2,  0.85, 0.35)
const WRONG_COLOR: Color         = Color(0.90, 0.25, 0.25)
const NEUTRAL_COLOR: Color       = Color(0.25, 0.55, 0.90)
const HINT_COLOR: Color          = Color(0.75, 0.75, 0.75)

# UI nodes — built programmatically; no .tscn needed for structural layout.
var _root_panel:        PanelContainer
var _title_label:       Label
var _category_label:    Label
var _question_label:    RichTextLabel
var _choice_buttons:    Array[Button] = []
var _feedback_label:    RichTextLabel
var _continue_btn:      Button
var _score_label:       Label
var _close_btn:         Button

# Runtime state
var _questions: Array         = []   # all loaded questions
var _session_pool: Array      = []   # shuffled subset for this session
var _current_q: Dictionary    = {}
var _current_idx: int         = 0
var _score: int               = 0
var _player: Node             = null
var _answered: bool           = false

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("science_minigame_ui")
	_build_ui()
	_root_panel.visible = false
	_load_questions()

func _load_questions() -> void:
	var path := "res://data/quiz_questions.json"
	if not FileAccess.file_exists(path):
		push_warning("ScienceMinigame: quiz_questions.json not found at %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		_questions = parsed
	else:
		push_warning("ScienceMinigame: failed to parse quiz_questions.json")

# ── Public API ─────────────────────────────────────────────────────────────────

func open_minigame(player: Node) -> void:
	if _root_panel.visible:
		return
	if _questions.is_empty():
		push_warning("ScienceMinigame: no questions loaded")
		return
	_player        = player
	_score         = 0
	_current_idx   = 0
	_session_pool  = _pick_session_questions()
	_root_panel.visible = true
	get_tree().paused = false   # don't pause physics — Aldric's office is safe
	_show_question()

func is_open() -> bool:
	return _root_panel.visible

# ── Question flow ──────────────────────────────────────────────────────────────

func _pick_session_questions() -> Array:
	# Shuffle and pick QUESTIONS_PER_SESSION, mixing difficulties
	var pool := _questions.duplicate()
	pool.shuffle()
	var result: Array = []
	# Prefer at least one of each difficulty 1/2/3 if available
	var by_diff: Dictionary = {1: [], 2: [], 3: []}
	for q: Dictionary in pool:
		var d: int = int(q.get("difficulty", 1))
		if by_diff.has(d):
			by_diff[d].append(q)
	var ordered: Array = []
	for d in [1, 2, 3]:
		ordered.append_array(by_diff[d])
	# Fill session
	for i in range(QUESTIONS_PER_SESSION):
		if i < ordered.size():
			result.append(ordered[i])
		elif i < pool.size():
			result.append(pool[i])
	result.shuffle()
	return result

func _show_question() -> void:
	if _current_idx >= _session_pool.size():
		_show_end_screen()
		return
	_current_q = _session_pool[_current_idx]
	_answered  = false

	_title_label.text    = "Prof. Aldric's Lab Challenge"
	_category_label.text = "Topic: %s   |   Q %d / %d   |   Score: %d" % [
		_format_category(_current_q.get("category", "general")),
		_current_idx + 1,
		_session_pool.size(),
		_score
	]
	_question_label.text = _current_q.get("question", "???")
	_feedback_label.text = ""
	_feedback_label.visible = false
	_continue_btn.visible   = false
	_score_label.visible    = false

	var choices: Array = _current_q.get("choices", [])
	for i in range(_choice_buttons.size()):
		var btn: Button = _choice_buttons[i]
		if i < choices.size():
			btn.text    = choices[i]
			btn.visible = true
			btn.disabled = false
			btn.modulate = Color.WHITE
			_set_button_color(btn, NEUTRAL_COLOR)
		else:
			btn.visible = false

func _on_choice_pressed(choice_idx: int) -> void:
	if _answered:
		return
	_answered = true

	var correct: int = int(_current_q.get("answer", 0))
	var is_correct: bool = (choice_idx == correct)

	# Visually highlight correct/wrong
	for i in range(_choice_buttons.size()):
		var btn: Button = _choice_buttons[i]
		btn.disabled = true
		if i == correct:
			_set_button_color(btn, CORRECT_COLOR)
		elif i == choice_idx and not is_correct:
			_set_button_color(btn, WRONG_COLOR)

	var explanation: String = _current_q.get("explanation", "")

	if is_correct:
		_score += 1
		AudioManager.on_quiz_correct()
		_feedback_label.modulate = CORRECT_COLOR
		var reward_el: String  = _current_q.get("reward_element", "")
		var reward_amt: float  = float(_current_q.get("reward_amount", 1.0))
		var reward_text := ""
		if reward_el != "" and _player != null:
			var inv: Node = _player.get_node_or_null("Inventory")
			if inv and inv.has_method("add_element"):
				inv.add_element(reward_el, reward_amt)
				var unit := "g"
				if inv.has_method("unit_for"):
					unit = inv.unit_for(reward_el)
				reward_text = "\n[color=yellow]+%.2f%s %s added to inventory![/color]" % [reward_amt, unit, reward_el]
		_feedback_label.text = "[color=#33d958]✓ Correct![/color]\n%s%s" % [explanation, reward_text]
	else:
		# Wrong answer — minor HP penalty
		AudioManager.on_quiz_wrong()
		_feedback_label.modulate = Color.WHITE
		if _player != null and _player.has_method("take_damage"):
			_player.take_damage(WRONG_PENALTY_HP)
		_feedback_label.text = "[color=#e84040]✗ Incorrect.[/color]\n%s\n[color=#aaaaaa](-%.0f HP penalty)[/color]" % [explanation, WRONG_PENALTY_HP]

	_feedback_label.visible = true
	_continue_btn.text      = "Next Question →" if _current_idx + 1 < _session_pool.size() else "Finish"
	_continue_btn.visible   = true

func _on_continue_pressed() -> void:
	_current_idx += 1
	_show_question()

func _show_end_screen() -> void:
	_question_label.text = "Lab session complete!"
	_feedback_label.visible = true
	_feedback_label.modulate = Color.WHITE
	var grade := _grade_score(_score, _session_pool.size())
	_feedback_label.text = (
		"Final Score: [color=yellow]%d / %d[/color]\nGrade: [color=yellow]%s[/color]\n\n%s" % [
			_score, _session_pool.size(), grade[0], grade[1]
		]
	)
	_score_label.text    = "Score: %d / %d" % [_score, _session_pool.size()]
	_score_label.visible = true
	for btn in _choice_buttons:
		btn.visible = false
	_continue_btn.visible = false
	_category_label.text = "Thank you for your help, young alchemist!"

func _grade_score(got: int, total: int) -> Array:
	var pct: float = float(got) / float(total) if total > 0 else 0.0
	if pct >= 1.0:
		return ["S — Perfect!", "\"Outstanding! Even I couldn't do better.\" — Prof. Aldric"]
	elif pct >= 0.67:
		return ["A — Excellent", "\"Impressive knowledge. The elements yield to those who understand them.\" — Prof. Aldric"]
	elif pct >= 0.34:
		return ["B — Good", "\"A solid effort. Study your compounds, and you'll master this.\" — Prof. Aldric"]
	else:
		return ["C — Keep Trying", "\"Don't lose heart. Every great alchemist once knew nothing.\" — Prof. Aldric"]

func _format_category(cat: String) -> String:
	return cat.capitalize().replace("_", " ")

# ── UI Construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	layer = 10  # above HUD (layer 5), below nothing

	# Semi-transparent dim background
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Main panel — centred, 640×420
	_root_panel = PanelContainer.new()
	_root_panel.custom_minimum_size = Vector2(640, 420)
	_root_panel.set_anchors_preset(Control.PRESET_CENTER)
	_root_panel.anchor_left   = 0.5
	_root_panel.anchor_right  = 0.5
	_root_panel.anchor_top    = 0.5
	_root_panel.anchor_bottom = 0.5
	_root_panel.offset_left   = -320.0
	_root_panel.offset_right  =  320.0
	_root_panel.offset_top    = -210.0
	_root_panel.offset_bottom =  210.0

	var style := StyleBoxFlat.new()
	style.bg_color         = PANEL_COLOR
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	_root_panel.add_theme_stylebox_override("panel", style)
	add_child(_root_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_root_panel.add_child(vbox)

	# Header row
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	_title_label = Label.new()
	_title_label.text = "Prof. Aldric's Lab Challenge"
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.modulate = Color(0.7, 0.9, 1.0)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.pressed.connect(_on_close_pressed)
	header_row.add_child(_close_btn)

	# Category / progress bar
	_category_label = Label.new()
	_category_label.add_theme_font_size_override("font_size", 10)
	_category_label.modulate = HINT_COLOR
	vbox.add_child(_category_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Question text
	_question_label = RichTextLabel.new()
	_question_label.bbcode_enabled = true
	_question_label.custom_minimum_size = Vector2(0, 60)
	_question_label.add_theme_font_size_override("normal_font_size", 13)
	_question_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_question_label.fit_content = true
	_question_label.scroll_active = false
	vbox.add_child(_question_label)

	# 4 choice buttons
	var choice_grid := VBoxContainer.new()
	choice_grid.add_theme_constant_override("separation", 6)
	vbox.add_child(choice_grid)

	_choice_buttons.clear()
	for i in range(4):
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 11)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i  # capture for lambda
		btn.pressed.connect(func() -> void: _on_choice_pressed(idx))
		choice_grid.add_child(btn)
		_choice_buttons.append(btn)

	# Feedback text
	_feedback_label = RichTextLabel.new()
	_feedback_label.bbcode_enabled = true
	_feedback_label.custom_minimum_size = Vector2(0, 56)
	_feedback_label.add_theme_font_size_override("normal_font_size", 11)
	_feedback_label.fit_content = true
	_feedback_label.scroll_active = false
	_feedback_label.visible = false
	vbox.add_child(_feedback_label)

	# Bottom row — score + continue button
	var bottom_row := HBoxContainer.new()
	vbox.add_child(bottom_row)

	_score_label = Label.new()
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_label.modulate = Color(1.0, 0.85, 0.2)
	_score_label.add_theme_font_size_override("font_size", 11)
	_score_label.visible = false
	bottom_row.add_child(_score_label)

	_continue_btn = Button.new()
	_continue_btn.text = "Next Question →"
	_continue_btn.add_theme_font_size_override("font_size", 11)
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_on_continue_pressed)
	bottom_row.add_child(_continue_btn)

func _set_button_color(btn: Button, color: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color * 0.4
	s.border_color = color
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal",   s)
	btn.add_theme_stylebox_override("hover",    s)
	btn.add_theme_stylebox_override("pressed",  s)
	btn.add_theme_stylebox_override("disabled", s)

func _on_close_pressed() -> void:
	_root_panel.visible = false
	emit_signal("minigame_closed")

func _unhandled_input(event: InputEvent) -> void:
	if not _root_panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()
