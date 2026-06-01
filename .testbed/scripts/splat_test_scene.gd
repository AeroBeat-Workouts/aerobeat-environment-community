extends Node3D

const Paths := preload("res://scripts/testbed_paths.gd")
const ConfigUtils := preload("res://scripts/transform_config.gd")
const FreeLookCameraScript := preload("res://scripts/free_look_camera.gd")
const SplatManagerScript := preload("res://addons/aerobeat-tool-gaussian-splat-loader/src/AeroGaussianSplatManager.gd")

const DEFAULT_POSITION := Vector3.ZERO
const DEFAULT_ROTATION_DEGREES := Vector3.ZERO
const DEFAULT_SCALE := Vector3.ONE

var _manager
var _display_root: Node3D
var _splat_node: Node3D
var _current_asset_path: String = ""
var _status_label: Label
var _path_label: Label
var _loading_state_label: Label
var _loading_bar: ProgressBar
var _debug_label: RichTextLabel
var _renderer_warning_label: Label
var _rooted_dialog: FileDialog
var _any_dialog: FileDialog
var _pick_button: Button
var _any_button: Button
var _position_edits: Array[LineEdit] = []
var _scale_edits: Array[LineEdit] = []
var _rotation_edits: Array[LineEdit] = []
var _renderer_support_status: Dictionary = {}

func _ready() -> void:
	_manager = SplatManagerScript.new()
	add_child(_manager)
	_manager.background_load_started.connect(_on_background_load_started)
	_manager.background_load_progressed.connect(_on_background_load_progressed)
	_manager.background_load_finished.connect(_on_background_load_finished)
	_renderer_support_status = _manager.get_renderer_support_status()
	_setup_3d()
	_setup_ui()
	_apply_renderer_support_ui()
	_set_loading_ui({
		"pending": false,
		"progress": 0.0,
		"phase": "idle",
		"status": "Idle"
	})

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
	panel.offset_bottom = 720
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Gaussian splat test scene"
	vbox.add_child(title)

	_renderer_warning_label = Label.new()
	_renderer_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_renderer_warning_label)

	_pick_button = Button.new()
	_pick_button.text = "Choose recommended .compressed.ply from assets/splats"
	_pick_button.pressed.connect(_open_rooted_dialog)
	vbox.add_child(_pick_button)

	_any_button = Button.new()
	_any_button.text = "Choose arbitrary local splat file (compat formats also supported)"
	_any_button.pressed.connect(_open_any_dialog)
	vbox.add_child(_any_button)

	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.text = "No splat selected."
	vbox.add_child(_path_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "WASD / arrows move. Right-click captures mouse. Esc releases. Selecting a splat auto-loads any sibling .config.yaml transform sidecar."
	vbox.add_child(_status_label)

	_loading_state_label = Label.new()
	_loading_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loading_state_label.text = "Idle"
	vbox.add_child(_loading_state_label)

	_loading_bar = ProgressBar.new()
	_loading_bar.min_value = 0.0
	_loading_bar.max_value = 100.0
	_loading_bar.value = 0.0
	_loading_bar.show_percentage = true
	_loading_bar.visible = false
	vbox.add_child(_loading_bar)

	vbox.add_child(_make_vector3_editor("Position", _position_edits, DEFAULT_POSITION))
	vbox.add_child(_make_vector3_editor("Scale", _scale_edits, DEFAULT_SCALE))
	vbox.add_child(_make_vector3_editor("Rotation Degrees", _rotation_edits, DEFAULT_ROTATION_DEGREES))

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
	_rooted_dialog.filters = PackedStringArray(["*.compressed.ply ; Recommended AeroBeat splat format", "*.ply,*.splat,*.sog ; GDGS compatibility formats"])
	_rooted_dialog.file_selected.connect(_load_splat)
	layer.add_child(_rooted_dialog)

	_any_dialog = FileDialog.new()
	_any_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_any_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_any_dialog.current_dir = Paths.default_global_dir("splats")
	_any_dialog.filters = PackedStringArray(["*.compressed.ply ; Recommended AeroBeat splat format", "*.ply,*.splat,*.sog ; GDGS compatibility formats"])
	_any_dialog.file_selected.connect(_load_splat)
	layer.add_child(_any_dialog)

func get_current_sidecar_path() -> String:
	return Paths.sidecar_path_for(_current_asset_path)

func get_current_config_payload() -> Dictionary:
	if _splat_node == null:
		return ConfigUtils.build_transform_config(_vector3_from_edits(_position_edits), _vector3_from_edits(_rotation_edits), _vector3_from_edits(_scale_edits))
	return ConfigUtils.build_transform_config(_splat_node.position, _splat_node.rotation_degrees, _splat_node.scale)

func save_current_config() -> Dictionary:
	var result := ConfigUtils.save_sidecar(_current_asset_path, "splat", get_current_config_payload())
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

func _apply_renderer_support_ui() -> void:
	var renderer_name := String(_renderer_support_status.get("renderer_name", "unknown"))
	var support_level := String(_renderer_support_status.get("support_level", "unknown"))
	var message := String(_renderer_support_status.get("message", "Renderer status unavailable."))
	_renderer_warning_label.text = "Renderer: %s\nSupport: %s\n%s" % [renderer_name, support_level, message]
	var can_attempt_render := bool(_renderer_support_status.get("can_attempt_render", false))
	_pick_button.disabled = not can_attempt_render
	_any_button.disabled = not can_attempt_render
	if not can_attempt_render:
		_status_label.text = "Visible splat rendering is disabled on this renderer path."
		_loading_state_label.text = "Renderer path unsupported"
	else:
		_status_label.text = "WASD / arrows move. Right-click captures mouse. Esc releases. Selecting a splat auto-loads any sibling .config.yaml transform sidecar."

func _open_rooted_dialog() -> void:
	if not _can_attempt_render():
		return
	_rooted_dialog.popup_centered_ratio(0.8)

func _open_any_dialog() -> void:
	if not _can_attempt_render():
		return
	_any_dialog.popup_centered_ratio(0.8)

func _can_attempt_render() -> bool:
	return bool(_renderer_support_status.get("can_attempt_render", false))

func _load_splat(path: String) -> void:
	if not _can_attempt_render():
		_status_label.text = String(_renderer_support_status.get("message", "Visible splat rendering is unavailable on this renderer path."))
		_debug_label.text = _renderer_warning_label.text
		return
	_current_asset_path = path
	_path_label.text = path
	_reset_transform_ui_to_defaults()
	_clear_current_splat()
	_status_label.text = "Starting async load..."
	_debug_label.text = ""
	var result: Dictionary = _manager.begin_create_splat_node_from_path(path)
	if result.get("ok", false):
		_set_loading_ui(result)
		return
	if int(result.get("error", OK)) == ERR_UNAVAILABLE:
		_status_label.text = "Async loading is only available for .ply and .compressed.ply. Falling back to synchronous compatibility load."
		_set_loading_ui({
			"pending": false,
			"progress": 0.0,
			"phase": "idle",
			"status": "Compatibility format uses synchronous load"
		})
		var sync_result: Dictionary = _manager.create_splat_node_from_path(path)
		if sync_result.get("ok", false):
			_install_loaded_splat(sync_result, "Loaded via synchronous compatibility path.")
		else:
			_status_label.text = String(sync_result.get("message", "Failed to load splat"))
			_debug_label.text = _status_label.text
		return
	_status_label.text = String(result.get("message", "Failed to start async load"))
	_debug_label.text = _status_label.text
	_set_loading_ui({
		"pending": false,
		"progress": 0.0,
		"phase": "idle",
		"status": "Load failed to start"
	})

func _apply_transform_from_ui() -> void:
	if _splat_node == null:
		return
	var config := ConfigUtils.normalize_transform_config({
		"transform": {
			"position": _vector3_to_array(_vector3_from_edits(_position_edits)),
			"rotation_degrees": _vector3_to_array(_vector3_from_edits(_rotation_edits)),
			"scale": _vector3_to_array(_vector3_from_edits(_scale_edits))
		}
	})
	var transform: Dictionary = config.get("transform", {})
	_splat_node.position = _vector3_from_variant(transform.get("position", DEFAULT_POSITION), DEFAULT_POSITION)
	_splat_node.scale = _vector3_from_variant(transform.get("scale", DEFAULT_SCALE), DEFAULT_SCALE)
	_splat_node.rotation_degrees = _vector3_from_variant(transform.get("rotation_degrees", DEFAULT_ROTATION_DEGREES), DEFAULT_ROTATION_DEGREES)

func _save_config() -> void:
	if _current_asset_path.is_empty() or _splat_node == null:
		_status_label.text = "Choose a splat first."
		return
	_apply_transform_from_ui()
	save_current_config()

func _load_config() -> void:
	if _current_asset_path.is_empty():
		_status_label.text = "Choose a splat first."
		return
	_apply_loaded_config_result(ConfigUtils.load_sidecar(_current_asset_path, "splat"))

func _apply_loaded_config_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		_status_label.text = String(result.get("message", "Load failed"))
		return
	if not result.get("has_config", false):
		_status_label.text = "No sibling .config.yaml sidecar found for this splat."
		return
	var transform: Dictionary = result.get("config", {}).get("transform", {})
	_set_line_edits(_position_edits, _vector3_from_variant(transform.get("position", DEFAULT_POSITION), DEFAULT_POSITION))
	_set_line_edits(_scale_edits, _vector3_from_variant(transform.get("scale", DEFAULT_SCALE), DEFAULT_SCALE))
	_set_line_edits(_rotation_edits, _vector3_from_variant(transform.get("rotation_degrees", DEFAULT_ROTATION_DEGREES), DEFAULT_ROTATION_DEGREES))
	_apply_transform_from_ui()
	_status_label.text = "Loaded sibling .config.yaml sidecar for the splat asset."

func _reset_transform_ui_to_defaults() -> void:
	_set_line_edits(_position_edits, DEFAULT_POSITION)
	_set_line_edits(_rotation_edits, DEFAULT_ROTATION_DEGREES)
	_set_line_edits(_scale_edits, DEFAULT_SCALE)

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

func _on_background_load_started(result: Dictionary) -> void:
	_set_loading_ui(result)
	_status_label.text = "Async load started."

func _on_background_load_progressed(result: Dictionary) -> void:
	_set_loading_ui(result)
	_status_label.text = "Async load in progress."

func _on_background_load_finished(result: Dictionary) -> void:
	_set_loading_ui(result)
	if not result.get("ok", false):
		_status_label.text = String(result.get("message", "Failed to load splat"))
		_debug_label.text = _status_label.text
		return
	_install_loaded_splat(result, "Loaded via async AeroBeat wrapper API.")

func _install_loaded_splat(result: Dictionary, success_text: String) -> void:
	if _splat_node != null:
		_splat_node.queue_free()
		_splat_node = null
	_splat_node = result["node"]
	_display_root.add_child(_splat_node)
	var config_result := ConfigUtils.load_sidecar(_current_asset_path, "splat")
	if config_result.get("has_config", false):
		_apply_loaded_config_result(config_result)
	else:
		_apply_transform_from_ui()
		_status_label.text = "%s No sibling .config.yaml sidecar was found." % success_text
	_debug_label.text = "Path: %s\nFormat: %s\nPoints: %s\nAABB: %s\nPhase: %s\nProgress: %s%%\nRenderer: %s\nSupport: %s" % [
		result.get("path", _current_asset_path),
		result.get("format", "unknown"),
		str(result.get("point_count", 0)),
		str(result.get("aabb", AABB())),
		result.get("phase", "ready"),
		str(roundf(clampf(float(result.get("progress", 1.0)), 0.0, 1.0) * 100.0)),
		_renderer_support_status.get("renderer_name", "unknown"),
		_renderer_support_status.get("support_level", "unknown")
	]

func _set_loading_ui(result: Dictionary) -> void:
	var pending := bool(result.get("pending", false))
	var progress := clampf(float(result.get("progress", 0.0)), 0.0, 1.0)
	_loading_bar.visible = pending
	_loading_bar.value = progress * 100.0
	_loading_state_label.text = "%s (%d%%)" % [
		result.get("status", "Idle"),
		int(round(progress * 100.0))
	] if pending else String(result.get("status", "Idle"))

func _clear_current_splat() -> void:
	if _splat_node != null:
		_splat_node.queue_free()
		_splat_node = null
