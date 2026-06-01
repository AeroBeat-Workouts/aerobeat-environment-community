extends Control

const Paths := preload("res://scripts/testbed_paths.gd")
const ConfigUtils := preload("res://scripts/transform_config.gd")

var _texture_rect: TextureRect
var _path_label: Label
var _status_label: Label
var _fit_selector: OptionButton
var _file_dialog: FileDialog
var _current_asset_path: String = ""

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var split := HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(split)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(280.0, 0.0)
	split.add_child(panel)

	var title := Label.new()
	title.text = "Image test scene"
	panel.add_child(title)

	var button := Button.new()
	button.text = "Choose image from assets/images"
	button.pressed.connect(_open_file_dialog)
	panel.add_child(button)

	_fit_selector = OptionButton.new()
	_fit_selector.add_item("stretch")
	_fit_selector.add_item("contain")
	_fit_selector.add_item("cover")
	_fit_selector.item_selected.connect(_on_fit_mode_changed)
	_fit_selector.select(2)
	panel.add_child(_fit_selector)

	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.text = "No image selected."
	panel.add_child(_path_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Select an image to preview it and auto-load any sibling .config.yaml fit-mode sidecar."
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

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.root_subfolder = Paths.default_global_dir("images")
	_file_dialog.current_dir = Paths.default_global_dir("images")
	_file_dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg,*.jpeg ; JPEG", "*.webp ; WebP"])
	_file_dialog.file_selected.connect(_load_image)
	add_child(_file_dialog)

func get_current_sidecar_path() -> String:
	return Paths.sidecar_path_for(_current_asset_path)

func get_current_config_payload() -> Dictionary:
	return ConfigUtils.build_media_config(_current_fit_mode())

func save_current_config() -> Dictionary:
	var result := ConfigUtils.save_sidecar(_current_asset_path, "image", get_current_config_payload())
	if result.get("ok", false):
		_status_label.text = "Saved %s" % String(result.get("path", get_current_sidecar_path()))
	else:
		_status_label.text = String(result.get("message", "Save failed"))
	return result

func _open_file_dialog() -> void:
	_file_dialog.popup_centered_ratio(0.8)

func _on_fit_mode_changed(index: int) -> void:
	match index:
		0:
			_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		1:
			_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_:
			_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func _load_image(path: String) -> void:
	_current_asset_path = path
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		_path_label.text = "Failed to load image: %s" % path
		_status_label.text = "Image load failed before any sidecar config could be applied."
		return
	_texture_rect.texture = ImageTexture.create_from_image(image)
	_path_label.text = path
	_apply_loaded_config_result(ConfigUtils.load_sidecar(_current_asset_path, "image"))

func _apply_loaded_config_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		_status_label.text = String(result.get("message", "Config load failed"))
		return
	if not result.get("has_config", false):
		_status_label.text = "Loaded image with no sibling .config.yaml sidecar."
		return
	var config: Dictionary = result.get("config", {})
	var media: Dictionary = config.get("media", {})
	_set_fit_mode(String(media.get("fit_mode", ConfigUtils.DEFAULT_FIT_MODE)))
	_status_label.text = "Loaded image and applied sibling .config.yaml fit-mode sidecar."

func _set_fit_mode(fit_mode: String) -> void:
	var normalized := String(fit_mode).strip_edges().to_lower()
	match normalized:
		"stretch":
			_fit_selector.select(0)
		"contain":
			_fit_selector.select(1)
		_:
			_fit_selector.select(2)
	_on_fit_mode_changed(_fit_selector.selected)

func _current_fit_mode() -> String:
	match _fit_selector.selected:
		0:
			return "stretch"
		1:
			return "contain"
		_:
			return "cover"
