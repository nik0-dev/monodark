class_name MDConsoleUI extends Control

@onready var output_container : ScrollContainer = %OutputContainer
@onready var input : LineEdit = %Input
@onready var output : RichTextLabel = %Output
@onready var main_bar_container : HBoxContainer = %MainBarContainer
@onready var window_handle : Button = %WindowHandle
@onready var close_button : Button = %CloseButton
@onready var collapse_button : Button = %CollapseButton
@onready var main_container : VBoxContainer = %MainContainer
@onready var top_bar_container : HBoxContainer = %TopBarContainer
@onready var resize_diagonal : Button = %ResizeDiagonal
@onready var resize_horizontal : Button = %ResizeHorizontal
@onready var resize_vertical = %ResizeVertical
@onready var focus_button = %FocusButton

var is_resizing : bool = false
var is_dragging : bool = false
var collapsed : bool = false
var _mouse_delta : Vector2 = Vector2.ZERO

@onready var root : Window

func _ready():
	handle_component_signals()
	root = get_tree().root

func set_active(active: bool): enable() if active else disable()

func handle_component_signals():
	# buttons
	collapse_button.button_down.connect(collapse_toggle)
	focus_button.button_down.connect(focus)
	close_button.button_down.connect(disable)
	
	# handles
	window_handle.button_down.connect(func(): is_dragging = true)
	window_handle.button_up.connect(func(): is_dragging = false)
	initialize_resize_handle(resize_diagonal, CursorShape.CURSOR_FDIAGSIZE)
	initialize_resize_handle(resize_horizontal, CursorShape.CURSOR_HSIZE)
	initialize_resize_handle(resize_vertical, CursorShape.CURSOR_VSIZE)

func _physics_process(delta):
	var off_screen : bool = position < Vector2.ZERO || Vector2i(position + get_rect().size) > root.size
	var size_diff : bool = Vector2i(size) > root.size
	if off_screen || size_diff : fit_to_screen()

func focus():
	position = Vector2.ZERO
	size = Vector2(root.size)

func fit_to_screen():
	var used_height = top_bar_container.size.y if collapsed else size.y
	var vp_size = get_viewport_rect().size
	position.x = clamp(position.x, 0, vp_size.x - size.x)
	position.y = clamp(position.y, 0, vp_size.y - used_height)
	
	var new_size = Vector2.ZERO
	new_size.x = clamp(size.x, 0, vp_size.x)
	new_size.y = clamp(size.y, 0, vp_size.y)
	set_deferred("size", new_size)

func _input(event):
	if event is InputEventMouseMotion:
		_mouse_delta = event.relative
		if is_dragging: position += _mouse_delta
		if is_resizing: 
			if resize_horizontal.button_pressed:
				size.x += _mouse_delta.x
			elif resize_diagonal.button_pressed:
				size += _mouse_delta
			elif resize_vertical.button_pressed:
				size.y += _mouse_delta.y
		if is_dragging || is_resizing: fit_to_screen.call_deferred()
	_mouse_delta = Vector2.ZERO
			
func cls(): output.text = ""

func change_opacity(value: float):
	value = clampf(value, 0.0, 1.0)
	var sb : StyleBoxFlat = output_container.get_theme_stylebox("panel").duplicate()
	sb.bg_color.a = value
	output_container.add_theme_stylebox_override("panel", sb)

func write(msg: String): output.append_text(msg)

func scroll_to_newest():
	var v_scroll := output_container.get_v_scroll_bar()
	await v_scroll.changed
	v_scroll.set_deferred("value", v_scroll.max_value)

func enable():
	show()
	input.grab_focus()
	fit_to_screen.call_deferred()
	
func disable():
	hide()
	input.release_focus()
	
func collapse_toggle():
	collapsed = !collapsed
	if collapsed:
		output_container.hide()
		resize_diagonal.hide()
		main_bar_container.hide()
		input.release_focus()
	else:
		output_container.show()
		resize_diagonal.show()
		main_bar_container.show()
		input.grab_focus()
		fit_to_screen.call_deferred()

func initialize_resize_handle(handle: Button, shape: CursorShape):
	handle.button_down.connect(func(): is_resizing = true)
	handle.button_up.connect(func(): is_resizing = false)
	handle.mouse_default_cursor_shape = shape
