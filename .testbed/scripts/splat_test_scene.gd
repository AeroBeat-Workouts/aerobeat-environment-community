extends Node3D

const Paths := preload("res://scripts/testbed_paths.gd")
const ConfigUtils := preload("res://scripts/transform_config.gd")
const FreeLookCameraScript := preload("res://scripts/free_look_camera.gd")
const SplatManagerScript := preload("res://addons/aerobeat-tool-gaussian-splat/src/AeroGaussianSplatManager.gd")

var _manager
var _display_root: Node3D
var _splat_node: Node3D
var _current_asset_path: String = ""
var _status_label: Label
var _path_label: Label
var _debug_label: RichTextLabel
var _rooted_dialog: FileDialog
var _any_dialog: FileDialog
var _center_edits: Array[LineEdit] = []
var _scale_edits: Array[LineEdit] = []
var _rotation_edits: Array[LineEdit] = []

func _ready() -> void:
	_manager = SplatManagerScript.new()
	add_child(_manager)
	_setup_3d()
	_setup_ui()

func _setup_3d() -> void:
	_display_root = Node3D.new()
	add_child(_display_root)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 4.0)
	camera.script = FreeLookCameraScript
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 25.0, 0.0)
	add_child(light)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.04, 0.06)
	world_environment.environment = environment
	add_child(world_environment)
	_manager.configure_world_environment(world_environment)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 400
	panel.offset_bottom = 680
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Gaussian splat test scene"
	vbox.add_child(title)

	var pick_button := Button.new()
	pick_button.text = "Choose splat from assets/splats"
	pick_button.pressed.connect(_open_rooted_dialog)
	vbox.add_child(pick_button)

	var any_button := Button.new()
	any_button.text = "Choose arbitrary local splat file"
	any_button.pressed.connect(_open_any_dialog)
	vbox.add_child(any_button)

	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.text = "No splat selected."
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

	var debug_title := Label.new()
	debug_title.text = "Debug / info"
	vbox.add_child(debug_title)

	_debug_label = RichTextLabel.new()
	_debug_label.fit_content = true
	_debug_label.custom_minimum_size = Vector2(0.0, 220.0)
	vbox.add_child(_debug_label)

	_rooted_dialog = FileDialog.new()
	_rooted_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_rooted_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_rooted_dialog.root_subfolder = Paths.default_global_dir("splats")
	_rooted_dialog.current_dir = Paths.default_global_dir("splats")
	_rooted_dialog.filters = PackedStringArray(["*.ply,*.splat,*.sog ; Splat assets", "*.compressed.ply ; Compressed PLY"])
	_rooted_dialog.file_selected.connect(_load_splat)
	layer.add_child(_rooted_dialog)

	_any_dialog = FileDialog.new()
	_any_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_any_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_any_dialog.current_dir = Paths.default_global_dir("splats")
	_any_dialog.filters = PackedStringArray(["*.ply,*.splat,*.sog ; Splat assets", "*.compressed.ply ; Compressed PLY"])
	_any_dialog.file_selected.connect(_load_splat)
	layer.add_child(_any_dialog)

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

func _open_rooted_dialog() -> void:
	_rooted_dialog.popup_centered_ratio(0.8)

func _open_any_dialog() -> void:
	_any_dialog.popup_centered_ratio(0.8)

func _load_splat(path: String) -> void:
	_current_asset_path = path
	_path_label.text = path
	if _splat_node != null:
		_splat_node.queue_free()
		_splat_node = null
	var result: Dictionary = _manager.create_splat_node_from_path(path)
	if not result.get("ok", false):
		_status_label.text = result.get("message", "Failed to load splat")
		_debug_label.text = _status_label.text
		return
	_splat_node = result["node"]
	_display_root.add_child(_splat_node)
	_apply_transform_from_ui()
	_status_label.text = "Loaded splat via AeroBeat wrapper API."
	_debug_label.text = "Path: %s
Format: %s
Points: %s
AABB: %s" % [
		result.get("path", path),
		result.get("format", "unknown"),
		str(result.get("point_count", 0)),
		str(result.get("aabb", AABB()))
	]

func _apply_transform_from_ui() -> void:
	if _splat_node == null:
		return
	var config := ConfigUtils.parse_config({
		"center": _line_edits_to_array(_center_edits),
		"scale": _line_edits_to_array(_scale_edits),
		"rotation": _line_edits_to_array(_rotation_edits)
	})
	_splat_node.position = config["center"]
	_splat_node.scale = config["scale"]
	_splat_node.rotation_degrees = config["rotation"]

func _save_config() -> void:
	if _current_asset_path.is_empty() or _splat_node == null:
		_status_label.text = "Choose a splat first."
		return
	_apply_transform_from_ui()
	var config_path := Paths.sidecar_path_for(_current_asset_path)
	var payload := ConfigUtils.build_config(_splat_node.position, _splat_node.scale, _splat_node.rotation_degrees)
	var result := ConfigUtils.save_json(config_path, payload)
	_status_label.text = "Saved %s" % result.get("path", config_path) if result.get("ok", false) else result.get("message", "Save failed")

func _load_config() -> void:
	if _current_asset_path.is_empty():
		_status_label.text = "Choose a splat first."
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
	_status_label.text = "Loaded JSON beside the splat asset."

func _line_edits_to_array(edits: Array[LineEdit]) -> Array:
	return [float(edits[0].text), float(edits[1].text), float(edits[2].text)]

func _set_line_edits(edits: Array[LineEdit], value: Vector3) -> void:
	edits[0].text = str(value.x)
	edits[1].text = str(value.y)
	edits[2].text = str(value.z)
