extends Node3D

const Paths := preload("res://scripts/testbed_paths.gd")
const ConfigUtils := preload("res://scripts/transform_config.gd")
const FreeLookCameraScript := preload("res://scripts/free_look_camera.gd")
const RotationGizmoScript := preload("res://scripts/rotation_gizmo.gd")
const AeroGLTFLoaderScript := preload("res://addons/aerobeat-tool-gltf-loader/src/AeroGLTFLoader.gd")

const DEFAULT_POSITION := Vector3.ZERO
const DEFAULT_ROTATION_DEGREES := Vector3.ZERO
const DEFAULT_SCALE := Vector3.ONE
const LIVE_MOVE_SPEED := 2.0
const LIVE_FAST_MULTIPLIER := 4.0
const LIVE_SCALE_RATE := 0.75
const LIVE_MIN_SCALE := 0.05

var _gltf_loader
var _current_load_result: Dictionary = {}
var _display_root: Node3D
var _loaded_instance: Node3D
var _current_asset_path: String = ""
var _status_label: Label
var _path_label: Label
var _file_dialog: FileDialog
var _world_environment: WorldEnvironment
var _position_edits: Array[LineEdit] = []
var _scale_edits: Array[LineEdit] = []
var _rotation_edits: Array[LineEdit] = []
var _rotation_gizmo: TestbedRotationGizmo

func _ready() -> void:
	_gltf_loader = AeroGLTFLoaderScript.new()
	_setup_3d()
	_setup_ui()
	set_process(true)

func _process(delta: float) -> void:
	if not _is_live_transform_input_allowed():
		return
	_apply_live_transform_delta(_read_live_move_input(), _read_live_scale_input(), delta, Input.is_key_pressed(KEY_SHIFT))

func _setup_3d() -> void:
	_display_root = Node3D.new()
	add_child(_display_root)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.2, 4.0)
	camera.script = FreeLookCameraScript
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	add_child(light)

	_world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.08, 0.1)
	_world_environment.environment = environment
	add_child(_world_environment)

	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	floor.scale = Vector3(4.0, 1.0, 4.0)
	add_child(floor)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 360
	panel.offset_bottom = 620
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "GLB test scene"
	vbox.add_child(title)

	var pick_button := Button.new()
	pick_button.text = "Choose GLB from assets/models"
	pick_button.pressed.connect(_open_file_dialog)
	vbox.add_child(pick_button)

	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.text = "No GLB selected."
	vbox.add_child(_path_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "WASD move the loaded object, Q/E move vertically, Shift boosts movement and scale, Up/Down scale the object. Right-click captures the free-look camera; Esc releases it. Selecting a GLB auto-loads any sibling .config.yaml transform sidecar."
	vbox.add_child(_status_label)

	vbox.add_child(_make_vector3_editor("Position", _position_edits, DEFAULT_POSITION))
	vbox.add_child(_make_vector3_editor("Scale", _scale_edits, DEFAULT_SCALE))
	vbox.add_child(_make_vector3_editor("Rotation Degrees", _rotation_edits, DEFAULT_ROTATION_DEGREES))

	var gizmo_title := Label.new()
	gizmo_title.text = "Rotation Gizmo"
	vbox.add_child(gizmo_title)

	var gizmo_hint := Label.new()
	gizmo_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gizmo_hint.text = "Drag the colored rings to rotate around the local X/Y/Z axes like Godot's inspector control."
	vbox.add_child(gizmo_hint)

	_rotation_gizmo = RotationGizmoScript.new()
	_rotation_gizmo.custom_minimum_size = Vector2(220.0, 220.0)
	_rotation_gizmo.rotation_changed.connect(_on_rotation_gizmo_changed)
	vbox.add_child(_rotation_gizmo)

	var apply_button := Button.new()
	apply_button.text = "Apply transform"
	apply_button.pressed.connect(_apply_transform_from_ui)
	vbox.add_child(apply_button)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var save_button := Button.new()
	save_button.text = "Save Config"
	save_button.pressed.connect(_save_config)
	buttons.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Load Config"
	load_button.pressed.connect(_load_config)
	buttons.add_child(load_button)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.root_subfolder = Paths.default_global_dir("models")
	_file_dialog.current_dir = Paths.default_global_dir("models")
	_file_dialog.filters = PackedStringArray(["*.glb ; GLB scenes"])
	_file_dialog.file_selected.connect(_load_glb)
	layer.add_child(_file_dialog)

func get_current_sidecar_path() -> String:
	return Paths.sidecar_path_for(_current_asset_path)

func get_current_config_payload() -> Dictionary:
	var target := _get_transform_target()
	if target == null:
		return ConfigUtils.build_transform_config(_vector3_from_edits(_position_edits), _vector3_from_edits(_rotation_edits), _vector3_from_edits(_scale_edits))
	return ConfigUtils.build_transform_config(target.position, target.rotation_degrees, target.scale)

func save_current_config() -> Dictionary:
	var result := ConfigUtils.save_sidecar(_current_asset_path, "glb", get_current_config_payload())
	_status_label.text = "Saved %s" % String(result.get("path", get_current_sidecar_path())) if result.get("ok", false) else String(result.get("message", "Save failed"))
	return result

func _make_vector3_editor(label_text: String, target: Array[LineEdit], defaults: Vector3) -> Control:
	var wrapper := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	wrapper.add_child(label)
	var row := HBoxContainer.new()
	wrapper.add_child(row)
	for value in [defaults.x, defaults.y, defaults.z]:
		var edit := LineEdit.new()
		edit.text = str(value)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(edit)
		target.append(edit)
	return wrapper

func _open_file_dialog() -> void:
	_file_dialog.popup_centered_ratio(0.8)

func _load_glb(path: String) -> void:
	_current_asset_path = path
	_path_label.text = path
	_reset_transform_ui_to_defaults()
	_unload_current_glb()

	var local_path := Paths.localize_if_possible(path)
	var request := {
		"instance": {
			"name": "GLBPreviewRoot",
			"transform": ConfigUtils.normalize_transform_config(get_current_config_payload()).get("transform", {})
		}
	}
	var result: Dictionary = _gltf_loader.load_scene_instance_from_path(local_path, request)
	if not result.get("ok", false):
		_status_label.text = String(result.get("message", "Failed to load GLB through AeroGLTFLoader"))
		return

	_current_load_result = result.duplicate(true)
	var instance_root: Variant = result.get("instance_root", null)
	if instance_root is Node3D:
		_loaded_instance = instance_root
	elif instance_root is Node:
		var wrapper := Node3D.new()
		wrapper.name = "GLBPreviewRoot"
		wrapper.add_child(instance_root)
		_loaded_instance = wrapper
	else:
		_status_label.text = "AeroGLTFLoader did not return a transformable instance root for: %s" % local_path
		return

	_display_root.add_child(_loaded_instance)
	var config_result := ConfigUtils.load_sidecar(_current_asset_path, "glb")
	if config_result.get("has_config", false):
		_apply_loaded_config_result(config_result)
	else:
		_apply_transform_from_ui()
		_status_label.text = "Loaded GLB with no sibling .config.yaml sidecar."

func _apply_transform_from_ui() -> void:
	var target := _get_transform_target()
	if target == null:
		if _rotation_gizmo != null:
			_rotation_gizmo.set_gizmo_rotation_degrees(_vector3_from_edits(_rotation_edits))
		return
	var config := ConfigUtils.normalize_transform_config({
		"transform": {
			"position": _vector3_to_array(_vector3_from_edits(_position_edits)),
			"rotation_degrees": _vector3_to_array(_vector3_from_edits(_rotation_edits)),
			"scale": _vector3_to_array(_vector3_from_edits(_scale_edits))
		}
	})
	_apply_transform_dictionary(target, config.get("transform", {}))
	_sync_transform_ui_from_target()

func _save_config() -> void:
	if _current_asset_path.is_empty():
		_status_label.text = "Choose a GLB first."
		return
	_apply_transform_from_ui()
	save_current_config()

func _load_config() -> void:
	if _current_asset_path.is_empty():
		_status_label.text = "Choose a GLB first."
		return
	_apply_loaded_config_result(ConfigUtils.load_sidecar(_current_asset_path, "glb"))

func _apply_loaded_config_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		_status_label.text = String(result.get("message", "Load failed"))
		return
	if not result.get("has_config", false):
		_status_label.text = "No sibling .config.yaml sidecar found for this GLB."
		return
	var transform: Dictionary = result.get("config", {}).get("transform", {})
	_set_line_edits(_position_edits, _vector3_from_variant(transform.get("position", DEFAULT_POSITION), DEFAULT_POSITION))
	_set_line_edits(_scale_edits, _vector3_from_variant(transform.get("scale", DEFAULT_SCALE), DEFAULT_SCALE))
	_set_line_edits(_rotation_edits, _vector3_from_variant(transform.get("rotation_degrees", DEFAULT_ROTATION_DEGREES), DEFAULT_ROTATION_DEGREES))
	_apply_transform_from_ui()
	_status_label.text = "Loaded sibling .config.yaml sidecar for the GLB asset."

func _reset_transform_ui_to_defaults() -> void:
	_set_line_edits(_position_edits, DEFAULT_POSITION)
	_set_line_edits(_rotation_edits, DEFAULT_ROTATION_DEGREES)
	_set_line_edits(_scale_edits, DEFAULT_SCALE)
	if _rotation_gizmo != null:
		_rotation_gizmo.set_gizmo_rotation_degrees(DEFAULT_ROTATION_DEGREES)

func _unload_current_glb() -> void:
	if not _current_load_result.is_empty():
		_gltf_loader.unload_result(_current_load_result)
		_current_load_result = {}
	_loaded_instance = null

func _get_transform_target() -> Node3D:
	return _loaded_instance

func _sync_transform_ui_from_target() -> void:
	var target := _get_transform_target()
	if target == null:
		return
	_set_line_edits(_position_edits, target.position)
	_set_line_edits(_rotation_edits, target.rotation_degrees)
	_set_line_edits(_scale_edits, target.scale)
	if _rotation_gizmo != null:
		_rotation_gizmo.set_gizmo_rotation_degrees(target.rotation_degrees)

func _apply_transform_dictionary(target: Node3D, transform: Dictionary) -> void:
	target.position = _vector3_from_variant(transform.get("position", DEFAULT_POSITION), DEFAULT_POSITION)
	target.rotation_degrees = _vector3_from_variant(transform.get("rotation_degrees", DEFAULT_ROTATION_DEGREES), DEFAULT_ROTATION_DEGREES)
	target.scale = _sanitize_scale(_vector3_from_variant(transform.get("scale", DEFAULT_SCALE), DEFAULT_SCALE))

func _apply_live_transform_delta(move_input: Vector3, scale_input: float, delta: float, fast_mode: bool) -> bool:
	var target := _get_transform_target()
	if target == null:
		return false
	var changed := false
	if move_input != Vector3.ZERO:
		var move_speed := LIVE_MOVE_SPEED * (LIVE_FAST_MULTIPLIER if fast_mode else 1.0)
		target.position += move_input.normalized() * move_speed * delta
		changed = true
	if not is_zero_approx(scale_input):
		var scale_step := LIVE_SCALE_RATE * (LIVE_FAST_MULTIPLIER if fast_mode else 1.0) * scale_input * delta
		target.scale = _sanitize_scale(target.scale + Vector3.ONE * scale_step)
		changed = true
	if changed:
		_sync_transform_ui_from_target()
	return changed

func _read_live_move_input() -> Vector3:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		move.y += 1.0
	if Input.is_key_pressed(KEY_E):
		move.y -= 1.0
	return move

func _read_live_scale_input() -> float:
	var scale_input := 0.0
	if Input.is_key_pressed(KEY_UP):
		scale_input += 1.0
	if Input.is_key_pressed(KEY_DOWN):
		scale_input -= 1.0
	return scale_input

func _is_live_transform_input_allowed() -> bool:
	if _get_transform_target() == null:
		return false
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return false
	if _file_dialog != null and _file_dialog.visible:
		return false
	if _rotation_gizmo != null and _rotation_gizmo.is_dragging():
		return false
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner == null or not (focus_owner is LineEdit)

func _on_rotation_gizmo_changed(rotation_degrees: Vector3) -> void:
	var target := _get_transform_target()
	_set_line_edits(_rotation_edits, rotation_degrees)
	if target == null:
		return
	target.rotation_degrees = rotation_degrees
	_sync_transform_ui_from_target()

func _sanitize_scale(value: Vector3) -> Vector3:
	return Vector3(
		maxf(value.x, LIVE_MIN_SCALE),
		maxf(value.y, LIVE_MIN_SCALE),
		maxf(value.z, LIVE_MIN_SCALE)
	)

func _vector3_from_edits(edits: Array[LineEdit]) -> Vector3:
	return Vector3(float(edits[0].text), float(edits[1].text), float(edits[2].text))

func _set_line_edits(edits: Array[LineEdit], value: Vector3) -> void:
	edits[0].text = str(value.x)
	edits[1].text = str(value.y)
	edits[2].text = str(value.z)

func _vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _vector3_from_variant(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)), float(value.get("z", fallback.z)))
	return fallback
