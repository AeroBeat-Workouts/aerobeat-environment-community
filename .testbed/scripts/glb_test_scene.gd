extends Node3D

const Paths := preload("res://scripts/testbed_paths.gd")
const ConfigUtils := preload("res://scripts/transform_config.gd")
const FreeLookCameraScript := preload("res://scripts/free_look_camera.gd")

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

func _ready() -> void:
	_setup_3d()
	_setup_ui()

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
	panel.offset_bottom = 520
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
	_status_label.text = "WASD / arrows move. Right-click captures mouse. Esc releases. Selecting a GLB auto-loads any sibling .config.yaml transform sidecar."
	vbox.add_child(_status_label)

	vbox.add_child(_make_vector3_editor("Position", _position_edits, Vector3.ZERO))
	vbox.add_child(_make_vector3_editor("Scale", _scale_edits, Vector3.ONE))
	vbox.add_child(_make_vector3_editor("Rotation Degrees", _rotation_edits, Vector3.ZERO))

	var apply_button := Button.new()
	apply_button.text = "Apply transform"
	apply_button.pressed.connect(_apply_transform_from_ui)
	vbox.add_child(apply_button)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var save_button := Button.new()
	save_button.text = "Save YAML beside asset"
	save_button.pressed.connect(_save_config)
	buttons.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Load YAML beside asset"
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
	if _loaded_instance == null:
		return ConfigUtils.build_transform_config(_vector3_from_edits(_position_edits), _vector3_from_edits(_rotation_edits), _vector3_from_edits(_scale_edits))
	return ConfigUtils.build_transform_config(_loaded_instance.position, _loaded_instance.rotation_degrees, _loaded_instance.scale)

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
	if _loaded_instance != null:
		_loaded_instance.queue_free()
		_loaded_instance = null
	var local_path := Paths.localize_if_possible(path)
	var resource = ResourceLoader.load(local_path)
	if resource == null:
		_status_label.text = "Failed to load GLB resource: %s" % path
		return
	if resource is PackedScene:
		var instance = resource.instantiate()
		if instance is Node3D:
			_loaded_instance = instance
		else:
			var wrapper := Node3D.new()
			wrapper.add_child(instance)
			_loaded_instance = wrapper
	else:
		_status_label.text = "Loaded resource is not a PackedScene: %s" % local_path
		return
	_display_root.add_child(_loaded_instance)
	var config_result := ConfigUtils.load_sidecar(_current_asset_path, "glb")
	if config_result.get("has_config", false):
		_apply_loaded_config_result(config_result)
	else:
		_apply_transform_from_ui()
		_status_label.text = "Loaded GLB with no sibling .config.yaml sidecar."

func _apply_transform_from_ui() -> void:
	if _loaded_instance == null:
		return
	var config := ConfigUtils.normalize_transform_config({
		"transform": {
			"position": _vector3_to_array(_vector3_from_edits(_position_edits)),
			"rotation_degrees": _vector3_to_array(_vector3_from_edits(_rotation_edits)),
			"scale": _vector3_to_array(_vector3_from_edits(_scale_edits))
		}
	})
	var transform: Dictionary = config.get("transform", {})
	_loaded_instance.position = _vector3_from_variant(transform.get("position", Vector3.ZERO), Vector3.ZERO)
	_loaded_instance.rotation_degrees = _vector3_from_variant(transform.get("rotation_degrees", Vector3.ZERO), Vector3.ZERO)
	_loaded_instance.scale = _vector3_from_variant(transform.get("scale", Vector3.ONE), Vector3.ONE)

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
	_set_line_edits(_position_edits, _vector3_from_variant(transform.get("position", Vector3.ZERO), Vector3.ZERO))
	_set_line_edits(_scale_edits, _vector3_from_variant(transform.get("scale", Vector3.ONE), Vector3.ONE))
	_set_line_edits(_rotation_edits, _vector3_from_variant(transform.get("rotation_degrees", Vector3.ZERO), Vector3.ZERO))
	_apply_transform_from_ui()
	_status_label.text = "Loaded sibling .config.yaml sidecar for the GLB asset."

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
