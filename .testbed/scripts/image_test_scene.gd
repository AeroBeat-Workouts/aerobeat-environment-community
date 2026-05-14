extends Control

const Paths := preload("res://scripts/testbed_paths.gd")

var _texture_rect: TextureRect
var _path_label: Label
var _fit_selector: OptionButton
var _file_dialog: FileDialog

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
	_fit_selector.add_item("contain")
	_fit_selector.add_item("cover")
	_fit_selector.item_selected.connect(_on_fit_mode_changed)
	panel.add_child(_fit_selector)

	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_path_label.text = "No image selected."
	panel.add_child(_path_label)

	var preview_holder := PanelContainer.new()
	preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(preview_holder)

	_texture_rect = TextureRect.new()
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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

func _open_file_dialog() -> void:
	_file_dialog.popup_centered_ratio(0.8)

func _on_fit_mode_changed(index: int) -> void:
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if index == 0 else TextureRect.STRETCH_KEEP_ASPECT_COVERED

func _load_image(path: String) -> void:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		_path_label.text = "Failed to load image: %s" % path
		return
	_texture_rect.texture = ImageTexture.create_from_image(image)
	_path_label.text = path
