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
var _center_edits: Array[LineEdit] = []
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
	_status_label.text = "WASD / arrows move. Right-click captures mouse. Esc releases."
	vbox.add_child(_status_label)

	vbox.add_child(_make_vector3_editor("Center", _center_edits, Vector3.ZERO))
	vbox.add_child(_make_vector3_editor("Scale", _scale_edits, Vector3.ONE))
	vbox.add_child(_make_vector3_editor("Rotation", _rotation_edits, Vector3.ZERO))

	var apply_button := Button.new()
	apply_button.text = "Apply transform"
	apply_button.pressed.connect(_apply_transform_from_ui)
	vbox.add_child(apply_button)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)

	var save_button := Button.new()
	save_button.text = "Save JSON beside asset"
	save_button.pressed.connect(_save_config)
	buttons.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Load JSON beside asset"
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
	_apply_transform_from_ui()
	_status_label.text = "Loaded GLB. Save/load writes JSON beside the asset."

func _apply_transform_from_ui() -> void:
	if _loaded_instance == null:
		return
	var config := ConfigUtils.parse_config({
		"center": _line_edits_to_array(_center_edits),
		"scale": _line_edits_to_array(_scale_edits),
		"rotation": _line_edits_to_array(_rotation_edits)
	})
	_loaded_instance.position = config["center"]
	_loaded_instance.scale = config["scale"]
	_loaded_instance.rotation_degrees = config["rotation"]

func _save_config() -> void:
	if _current_asset_path.is_empty():
		_status_label.text = "Choose a GLB first."
		return
	_apply_transform_from_ui()
	var config_path := Paths.sidecar_path_for(_current_asset_path)
	var payload := ConfigUtils.build_config(_loaded_instance.position, _loaded_instance.scale, _loaded_instance.rotation_degrees)
	var result := ConfigUtils.save_json(config_path, payload)
	_status_label.text = "Saved %s" % result.get("path", config_path) if result.get("ok", false) else result.get("message", "Save failed")

func _load_config() -> void:
	if _current_asset_path.is_empty():
		_status_label.text = "Choose a GLB first."
		return
	var result := ConfigUtils.load_json(Paths.sidecar_path_for(_current_asset_path))
	if not result.get("ok", false):
		_status_label.text = result.get("message", "Load failed")
		return
	var config: Dictionary = result["config"]
	_set_line_edits(_center_edits, config["center"])
	_set_line_edits(_scale_edits, config["scale"])
	_set_line_edits(_rotation_edits, config["rotation"])
	_apply_transform_from_ui()
	_status_label.text = "Loaded JSON beside the GLB asset."

func _line_edits_to_array(edits: Array[LineEdit]) -> Array:
	return [float(edits[0].text), float(edits[1].text), float(edits[2].text)]

func _set_line_edits(edits: Array[LineEdit], value: Vector3) -> void:
	edits[0].text = str(value.x)
	edits[1].text = str(value.y)
	edits[2].text = str(value.z)
