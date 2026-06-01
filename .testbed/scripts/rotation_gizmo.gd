class_name TestbedRotationGizmo
extends Control

signal rotation_changed(rotation_degrees: Vector3)
signal drag_state_changed(active: bool)

const AXIS_X := 0
const AXIS_Y := 1
const AXIS_Z := 2
const AXIS_COLORS := {
	AXIS_X: Color(0.95, 0.35, 0.35, 1.0),
	AXIS_Y: Color(0.45, 0.9, 0.45, 1.0),
	AXIS_Z: Color(0.45, 0.65, 1.0, 1.0)
}
const AXIS_LABELS := {
	AXIS_X: "X",
	AXIS_Y: "Y",
	AXIS_Z: "Z"
}
const AXIS_RING_FACTORS := {
	AXIS_X: 0.82,
	AXIS_Y: 0.62,
	AXIS_Z: 0.42
}
const RING_THICKNESS := 10.0
const LABEL_PADDING := 14.0

var _gizmo_rotation_degrees: Vector3 = Vector3.ZERO
var _drag_axis: int = -1
var _drag_last_angle: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(220.0, 220.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_gizmo_rotation_degrees(value: Vector3) -> void:
	_gizmo_rotation_degrees = value
	queue_redraw()

func get_gizmo_rotation_degrees() -> Vector3:
	return _gizmo_rotation_degrees

func is_dragging() -> bool:
	return _drag_axis != -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var axis: int = _pick_axis(event.position)
			if axis == -1:
				return
			_drag_axis = axis
			_drag_last_angle = _angle_for_point(event.position)
			drag_state_changed.emit(true)
			accept_event()
		else:
			if _drag_axis == -1:
				return
			_drag_axis = -1
			drag_state_changed.emit(false)
			accept_event()
	elif event is InputEventMouseMotion and _drag_axis != -1:
		var next_angle: float = _angle_for_point(event.position)
		var delta_angle: float = wrapf(next_angle - _drag_last_angle, -PI, PI)
		_drag_last_angle = next_angle
		if is_zero_approx(delta_angle):
			return
		var updated: Vector3 = _gizmo_rotation_degrees
		var delta_degrees: float = rad_to_deg(delta_angle)
		match _drag_axis:
			AXIS_X:
				updated.x = _wrap_rotation_degrees(updated.x + delta_degrees)
			AXIS_Y:
				updated.y = _wrap_rotation_degrees(updated.y + delta_degrees)
			AXIS_Z:
				updated.z = _wrap_rotation_degrees(updated.z + delta_degrees)
		set_gizmo_rotation_degrees(updated)
		rotation_changed.emit(_gizmo_rotation_degrees)
		accept_event()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius_base: float = minf(size.x, size.y) * 0.5 - LABEL_PADDING
	for axis in [AXIS_X, AXIS_Y, AXIS_Z]:
		var axis_color: Color = AXIS_COLORS[axis]
		var alpha: float = 1.0 if axis == _drag_axis else 0.75
		var radius: float = radius_base * float(AXIS_RING_FACTORS[axis])
		draw_arc(center, radius, 0.0, TAU, 64, Color(axis_color.r, axis_color.g, axis_color.b, alpha), RING_THICKNESS, true)
		var angle: float = _axis_angle_radians(axis)
		var handle_position: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		draw_circle(handle_position, 5.0 if axis == _drag_axis else 4.0, Color(axis_color.r, axis_color.g, axis_color.b, 1.0))
		_draw_axis_label(axis, center, radius)
	_draw_center_text(center)

func _draw_axis_label(axis: int, center: Vector2, radius: float) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var axis_color: Color = AXIS_COLORS[axis]
	var label := "%s %.1f°" % [AXIS_LABELS[axis], _axis_degrees(axis)]
	var label_position: Vector2 = center + Vector2(radius + 8.0, -radius + 6.0 + float(axis) * 18.0)
	draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, axis_color)

func _draw_center_text(center: Vector2) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var text := "Drag a ring to rotate"
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13)
	draw_string(font, center - Vector2(text_size.x * 0.5, -4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.9, 0.9, 0.95, 0.9))

func _pick_axis(point: Vector2) -> int:
	var center: Vector2 = size * 0.5
	var distance: float = point.distance_to(center)
	var radius_base: float = minf(size.x, size.y) * 0.5 - LABEL_PADDING
	for axis in [AXIS_X, AXIS_Y, AXIS_Z]:
		var radius: float = radius_base * float(AXIS_RING_FACTORS[axis])
		if absf(distance - radius) <= RING_THICKNESS:
			return axis
	return -1

func _angle_for_point(point: Vector2) -> float:
	var center: Vector2 = size * 0.5
	var offset: Vector2 = point - center
	return atan2(offset.y, offset.x)

func _axis_degrees(axis: int) -> float:
	match axis:
		AXIS_X:
			return _gizmo_rotation_degrees.x
		AXIS_Y:
			return _gizmo_rotation_degrees.y
		AXIS_Z:
			return _gizmo_rotation_degrees.z
		_:
			return 0.0

func _axis_angle_radians(axis: int) -> float:
	return deg_to_rad(_axis_degrees(axis) - 90.0)

func _wrap_rotation_degrees(value: float) -> float:
	return wrapf(value, -180.0, 180.0)
