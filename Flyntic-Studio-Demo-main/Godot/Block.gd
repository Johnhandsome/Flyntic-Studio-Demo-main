extends Panel

signal drag_started
signal drag_ended
signal value_changed(new_value)

var dragging = false
var drag_offset = Vector2.ZERO
var block_type = "" 
var value = "50" 

@onready var label: Label = $L
var input_field: LineEdit = null
var _original_scale := Vector2.ONE
var _hover := false

func _ready():
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_original_scale = scale
	
	# If this block type supports input, find or create the input field
	if has_node("Input"):
		input_field = $Input
		input_field.text = value
		input_field.text_submitted.connect(_on_value_submitted)
		input_field.focus_exited.connect(func(): _on_value_submitted(input_field.text))
		# Stop dragging when typing
		input_field.gui_input.connect(func(event): 
			if event is InputEventMouseButton: 
				accept_event()
		)
	
	# Connect hover signals
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)

func _on_value_submitted(new_text):
	value = new_text
	value_changed.emit(value)

func _on_hover_enter():
	_hover = true
	if not dragging:
		# Subtle brightness boost via modulate
		modulate = Color(1.12, 1.12, 1.12)
		# Slight scale pop
		var tween = create_tween()
		tween.tween_property(self, "scale", _original_scale * 1.03, 0.1).set_ease(Tween.EASE_OUT)

func _on_hover_exit():
	_hover = false
	if not dragging:
		modulate = Color(1, 1, 1)
		var tween = create_tween()
		tween.tween_property(self, "scale", _original_scale, 0.1).set_ease(Tween.EASE_OUT)

func _gui_input(event):
	# Don't drag if interacting with input field
	if input_field and input_field.has_focus():
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = get_local_mouse_position()
				drag_started.emit()
				# Bring to front
				get_parent().move_child(self, get_parent().get_child_count() - 1)
				# Drag lift effect
				modulate = Color(1.2, 1.2, 1.2)
				var tween = create_tween()
				tween.tween_property(self, "scale", _original_scale * 1.05, 0.08).set_ease(Tween.EASE_OUT)
			else:
				dragging = false
				drag_ended.emit()
				# Reset visual
				modulate = Color(1, 1, 1)
				var tween = create_tween()
				tween.tween_property(self, "scale", _original_scale, 0.12).set_ease(Tween.EASE_OUT)

func _process(_delta):
	if dragging:
		# Smooth drag with lerp for polished feel
		var target_pos = get_global_mouse_position() - drag_offset
		global_position = global_position.lerp(target_pos, 0.45)
