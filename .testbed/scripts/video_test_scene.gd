extends Control

const Paths := preload("res://scripts/testbed_paths.gd")
const ConfigUtils := preload("res://scripts/transform_config.gd")
const VideoPlayerManagerScript := preload("res://addons/aerobeat-tool-video-player/src/AeroVideoPlayerManager.gd")
const GodotVideoBackendScript := preload("res://addons/aerobeat-vendor-godot-video/src/AeroGodotVideoBackend.gd")

var _path_label: Label
var _status_label: Label
var _fit_selector: OptionButton
var _file_dialog: FileDialog
var _video_manager: Node
var _video_surface: Control
var _texture_rect: TextureRect
var _current_asset_path: String = ""

func _ready() -> void:
	_build_ui()
	_video_manager = _build_video_manager()
	add_child(_video_manager)
	set_process(true)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var split := HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(split)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	split.add_child(panel)

	var title := Label.new()
	title.text = "Video test scene"
	panel.add_child(title)

	var button := Button.new()
	button.text = "Choose video from assets/videos"
	button.pressed.connect(_open_file_dialog)
	panel.add_child(button)

	_fit_selector = OptionButton.new()
	_fit_selector.add_item("stretch")
	_fit_selector.add_item("contain")
	_fit_selector.add_item("cover")
	_fit_selector.item_selected.connect(_apply_fit_mode)
	_fit_selector.select(2)
	panel.add_child(_fit_selector)

	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.text = "No video selected."
	panel.add_child(_path_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Canonical video support here is truth-locked to .ogv (Theora). Playback routes through the shared AeroVideoPlayerManager facade. Selecting a video auto-loads any sibling .config.yaml fit-mode sidecar."
	panel.add_child(_status_label)

	var preview_holder := PanelContainer.new()
	preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(preview_holder)

	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_holder.add_child(_texture_rect)

	_video_surface = Control.new()
	_video_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_holder.add_child(_video_surface)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.root_subfolder = Paths.default_global_dir("videos")
	_file_dialog.current_dir = Paths.default_global_dir("videos")
	_file_dialog.filters = PackedStringArray(["*.ogv ; Ogg Theora video"])
	_file_dialog.file_selected.connect(_load_video)
	add_child(_file_dialog)

func get_current_sidecar_path() -> String:
	return Paths.sidecar_path_for(_current_asset_path)

func get_current_config_payload() -> Dictionary:
	return ConfigUtils.build_media_config(_current_fit_mode())

func save_current_config() -> Dictionary:
	var result := ConfigUtils.save_sidecar(_current_asset_path, "video", get_current_config_payload())
	if result.get("ok", false):
		_status_label.text = "Saved %s" % String(result.get("path", get_current_sidecar_path()))
	else:
		_status_label.text = String(result.get("message", "Save failed"))
	return result

func _process(_delta: float) -> void:
	var backend_player := _get_backend_player()
	if backend_player == null:
		_texture_rect.texture = null
		return
	if backend_player is Control:
		(backend_player as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if backend_player.has_method("get_video_texture"):
		var texture: Variant = backend_player.call("get_video_texture")
		if texture != null:
			_texture_rect.texture = texture
			if backend_player is CanvasItem:
				(backend_player as CanvasItem).visible = false
				return
	_texture_rect.texture = null
	if backend_player is CanvasItem:
		(backend_player as CanvasItem).visible = true

func _build_video_manager() -> Node:
	var manager := VideoPlayerManagerScript.new()
	manager.set_backend(GodotVideoBackendScript.new())
	return manager

func _get_backend_player() -> Node:
	if _video_surface == null or _video_surface.get_child_count() == 0:
		return null
	return _video_surface.get_child(0)

func _get_manager_error() -> Dictionary:
	if _video_manager == null or not _video_manager.has_method("get_last_error"):
		return {}
	var last_error: Variant = _video_manager.get_last_error()
	if last_error is Dictionary:
		return Dictionary(last_error).duplicate(true)
	return {}

func _get_manager_state() -> Dictionary:
	if _video_manager == null or not _video_manager.has_method("get_state"):
		return {}
	var state: Variant = _video_manager.get_state()
	if state is Dictionary:
		return Dictionary(state).duplicate(true)
	return {}

func _open_file_dialog() -> void:
	_file_dialog.popup_centered_ratio(0.8)

func _apply_fit_mode(index: int) -> void:
	match index:
		0:
			_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		1:
			_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_:
			_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if _video_manager != null and _video_manager.has_method("set_fit_mode"):
		_video_manager.set_fit_mode(_current_fit_mode())

func _load_video(path: String) -> void:
	_current_asset_path = path
	if path.get_extension().to_lower() != "ogv":
		_path_label.text = "Unsupported video extension: %s" % path
		_status_label.text = "Video validation is truth-locked to canonical .ogv input."
		return
	var local_path := Paths.localize_if_possible(path)
	_texture_rect.texture = null
	if _video_manager.has_method("unload"):
		_video_manager.unload()
	_video_manager.attach_surface(_video_surface)
	var attach_error := _get_manager_error()
	if not attach_error.is_empty():
		_path_label.text = "Failed to attach playback surface: %s" % path
		_status_label.text = String(attach_error.get("message", "Shared video backend rejected the playback surface."))
		return
	_video_manager.load({
		"path": local_path,
		"kind": "file",
		"autoplay": false,
		"metadata": {
			"scene": "environment_community_video_test",
			"selected_path": path,
		},
	})
	var load_error := _get_manager_error()
	if not load_error.is_empty():
		_path_label.text = "Failed to load video resource: %s" % path
		_status_label.text = "%s Shared playback here still only proves canonical .ogv files." % String(load_error.get("message", "Video stream could not be loaded."))
		return
	_video_manager.play()
	var play_error := _get_manager_error()
	if not play_error.is_empty():
		_path_label.text = "Failed to start playback: %s" % path
		_status_label.text = String(play_error.get("message", "Video playback could not be started."))
		return
	_path_label.text = path
	_apply_loaded_config_result(ConfigUtils.load_sidecar(_current_asset_path, "video"))
	var state := _get_manager_state()
	if not _status_label.text.contains(".config.yaml"):
		_status_label.text = "Loaded canonical .ogv video through shared backend %s. Contain/cover mirrors the backend texture when available; otherwise the backend-owned player node is shown as a fallback." % String(state.get("backend", "unknown"))

func _apply_loaded_config_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		_status_label.text = String(result.get("message", "Config load failed"))
		return
	if not result.get("has_config", false):
		_status_label.text = "Loaded canonical .ogv video with no sibling .config.yaml sidecar."
		return
	var config: Dictionary = result.get("config", {})
	var media: Dictionary = config.get("media", {})
	_set_fit_mode(String(media.get("fit_mode", ConfigUtils.DEFAULT_FIT_MODE)))
	_status_label.text = "Loaded canonical .ogv video and applied sibling .config.yaml fit-mode sidecar."

func _set_fit_mode(fit_mode: String) -> void:
	var normalized := String(fit_mode).strip_edges().to_lower()
	match normalized:
		"stretch":
			_fit_selector.select(0)
		"contain":
			_fit_selector.select(1)
		_:
			_fit_selector.select(2)
	_apply_fit_mode(_fit_selector.selected)

func _current_fit_mode() -> String:
	match _fit_selector.selected:
		0:
			return "stretch"
		1:
			return "contain"
		_:
			return "cover"
