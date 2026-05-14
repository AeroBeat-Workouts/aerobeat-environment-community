extends Camera3D

@export var move_speed: float = 6.0
@export var sprint_multiplier: float = 2.0
@export var mouse_sensitivity: float = 0.0035

var _yaw: float = 0.0
var _pitch: float = 0.0
var _mouse_captured: bool = false

func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x
	set_process(true)
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_mouse_captured = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_mouse_captured = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseMotion and _mouse_captured:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))
		rotation = Vector3(_pitch, _yaw, 0.0)

func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		move -= transform.basis.z
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		move += transform.basis.z
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		move -= transform.basis.x
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		move += transform.basis.x
	if Input.is_key_pressed(KEY_Q):
		move -= transform.basis.y
	if Input.is_key_pressed(KEY_E):
		move += transform.basis.y
	if move == Vector3.ZERO:
		return
	var speed := move_speed * (sprint_multiplier if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	global_position += move.normalized() * speed * delta
