extends Control

const Paths := preload("res://scripts/testbed_paths.gd")

var _path_label: Label
var _status_label: Label
var _fit_selector: OptionButton
var _file_dialog: FileDialog
var _video_player: VideoStreamPlayer
var _texture_rect: TextureRect

func _ready() -> void:
	_build_ui()
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
	_fit_selector.add_item("contain")
	_fit_selector.add_item("cover")
	_fit_selector.item_selected.connect(_apply_fit_mode)
	panel.add_child(_fit_selector)

	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.text = "No video selected."
	panel.add_child(_path_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Contain/cover is driven through a mirrored TextureRect when the backend exposes a video texture."
	panel.add_child(_status_label)

	var preview_holder := PanelContainer.new()
	preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(preview_holder)

	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_holder.add_child(_texture_rect)

	_video_player = VideoStreamPlayer.new()
	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_player.visible = false
	preview_holder.add_child(_video_player)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.root_subfolder = Paths.default_global_dir("videos")
	_file_dialog.current_dir = Paths.default_global_dir("videos")
	_file_dialog.filters = PackedStringArray(["*.ogv,*.webm,*.mp4 ; Video files"])
	_file_dialog.file_selected.connect(_load_video)
	add_child(_file_dialog)

func _process(_delta: float) -> void:
	if _video_player != null and _video_player.has_method("get_video_texture"):
		var texture = _video_player.call("get_video_texture")
		if texture != null:
			_texture_rect.texture = texture
			_video_player.visible = false
		else:
			_video_player.visible = true

func _open_file_dialog() -> void:
	_file_dialog.popup_centered_ratio(0.8)

func _apply_fit_mode(index: int) -> void:
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if index == 0 else TextureRect.STRETCH_KEEP_ASPECT_COVERED

func _load_video(path: String) -> void:
	var local_path := Paths.localize_if_possible(path)
	var stream = ResourceLoader.load(local_path)
	if stream == null and local_path != path:
		stream = ResourceLoader.load(path)
	if stream == null:
		_path_label.text = "Failed to load video resource: %s" % path
		return
	_video_player.stream = stream
	_video_player.autoplay = true
	_video_player.play()
	_path_label.text = path
	_status_label.text = "Loaded video. Right now contain/cover mirrors the video texture when available; otherwise the built-in player is shown as a fallback."
