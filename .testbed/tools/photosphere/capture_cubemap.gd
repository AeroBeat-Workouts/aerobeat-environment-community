extends Node3D

## Visible Forward+ cubemap capture for GDGS Gaussian splats.
## Loads one splat node, then rotates one 90 degree camera through all six faces.

const SplatManagerScript := preload("res://addons/aerobeat-tool-gaussian-splat-loader/src/AeroGaussianSplatManager.gd")

const DEFAULT_ASSET := "res://assets/splats/luminious-ice-cave/luminious-ice-cave.compressed.ply"
const DEFAULT_FACE_SIZE := 1920
const VIEWPOINT := Vector3(0.0, 0.0, 4.0)
const FACE_ORDER := ["pos_x", "neg_x", "pos_y", "neg_y", "pos_z", "neg_z"]
const FACE_FORWARD := {
	"pos_x": Vector3(1.0, 0.0, 0.0),
	"neg_x": Vector3(-1.0, 0.0, 0.0),
	"pos_y": Vector3(0.0, 1.0, 0.0),
	"neg_y": Vector3(0.0, -1.0, 0.0),
	"pos_z": Vector3(0.0, 0.0, 1.0),
	"neg_z": Vector3(0.0, 0.0, -1.0),
}
# Camera local +Y. Horizontal faces preserve world +Y. Polar choices make
# camera-right +X and put the -Z meridian at the bottom/top of +Y/-Y.
const FACE_UP := {
	"pos_x": Vector3(0.0, 1.0, 0.0),
	"neg_x": Vector3(0.0, 1.0, 0.0),
	"pos_y": Vector3(0.0, 0.0, 1.0),
	"neg_y": Vector3(0.0, 0.0, -1.0),
	"pos_z": Vector3(0.0, 1.0, 0.0),
	"neg_z": Vector3(0.0, 1.0, 0.0),
}

var _asset_path := DEFAULT_ASSET
var _out_dir := ""
var _face_size := DEFAULT_FACE_SIZE
var _timeout_seconds := 240.0
var _started_msec := 0
var _finished := false
var _manager
var _display_root: Node3D
var _world_environment: WorldEnvironment
var _camera: Camera3D
var _splat_node: Node3D

func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	_parse_args()
	if _out_dir.is_empty():
		_fail(2, "missing required --out-dir=<absolute-or-res-path>")
		return
	if _face_size < 64:
		_fail(2, "--face-size must be at least 64")
		return
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail(2, "visible display required: headless GDGS draw completion is unsupported")
		return
	var absolute_out := _globalize_if_needed(_out_dir)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_out)
	if mkdir_error != OK:
		_fail(2, "cannot create output directory: %s" % absolute_out)
		return
	_out_dir = absolute_out
	get_window().size = Vector2i(_face_size, _face_size)
	_setup_scene()
	_load_splat_once()

func _process(_delta: float) -> void:
	if not _finished and Time.get_ticks_msec() - _started_msec > int(_timeout_seconds * 1000.0):
		_fail(9, "capture watchdog exceeded %.1f seconds" % _timeout_seconds)

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="):
			_asset_path = arg.trim_prefix("--asset=")
		elif arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=")
		elif arg.begins_with("--face-size="):
			_face_size = int(arg.trim_prefix("--face-size="))
		elif arg.begins_with("--timeout-seconds="):
			_timeout_seconds = float(arg.trim_prefix("--timeout-seconds="))

func _globalize_if_needed(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path

func _setup_scene() -> void:
	_display_root = Node3D.new()
	_display_root.name = "CapturedSplat"
	add_child(_display_root)
	_camera = Camera3D.new()
	_camera.name = "CubemapCamera"
	_camera.fov = 90.0
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.near = 0.01
	_camera.far = 1000.0
	_camera.current = true
	add_child(_camera)
	_world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.04, 0.06, 1.0)
	_world_environment.environment = environment
	add_child(_world_environment)

func _load_splat_once() -> void:
	_manager = SplatManagerScript.new()
	add_child(_manager)
	_manager.background_load_finished.connect(_on_splat_loaded, CONNECT_ONE_SHOT)
	_manager.configure_world_environment(_world_environment)
	var result: Dictionary = _manager.begin_create_splat_node_from_path(_asset_path)
	print("[photosphere-capture] load begin: ", JSON.stringify(result))
	if not result.get("ok", false):
		_fail(3, "splat load begin failed: %s" % result.get("message", "unknown"))

func _on_splat_loaded(result: Dictionary) -> void:
	print("[photosphere-capture] load complete: ", JSON.stringify(result))
	if not result.get("ok", false):
		_fail(4, "splat load failed: %s" % result.get("message", "unknown"))
		return
	_splat_node = result.get("node")
	if _splat_node == null:
		_fail(4, "splat loader returned no node")
		return
	_display_root.add_child(_splat_node)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture_faces()

func _capture_faces() -> void:
	var face_records: Array[Dictionary] = []
	for face_name in FACE_ORDER:
		var forward: Vector3 = FACE_FORWARD[face_name]
		var up: Vector3 = FACE_UP[face_name]
		_camera.look_at_from_position(VIEWPOINT, VIEWPOINT + forward, up)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image.get_width() != _face_size or image.get_height() != _face_size:
			_fail(5, "unexpected viewport capture size %dx%d" % [image.get_width(), image.get_height()])
			return
		var path := _out_dir.path_join("%s.png" % face_name)
		var save_error := image.save_png(path)
		if save_error != OK:
			_fail(6, "failed saving %s: error %d" % [path, save_error])
			return
		face_records.append({
			"name": face_name,
			"forward": [forward.x, forward.y, forward.z],
			"up": [up.x, up.y, up.z],
			"bytes": FileAccess.get_file_as_bytes(path).size(),
			"sha256": FileAccess.get_sha256(path),
		})
		print("[photosphere-capture] saved ", path)
	var gaussian = _splat_node.get("gaussian")
	var metadata := {
		"asset": _asset_path,
		"viewpoint": [VIEWPOINT.x, VIEWPOINT.y, VIEWPOINT.z],
		"vertical_fov_degrees": 90.0,
		"face_size": _face_size,
		"face_order": FACE_ORDER,
		"faces": face_records,
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_device": RenderingServer.get_video_adapter_name(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"display_server": DisplayServer.get_name(),
		"point_count": int(gaussian.point_count) if gaussian != null else -1,
		"aabb": str(gaussian.aabb) if gaussian != null else "",
		"load_count": 1,
	}
	var metadata_file := FileAccess.open(_out_dir.path_join("capture.json"), FileAccess.WRITE)
	if metadata_file == null:
		_fail(7, "failed opening capture.json")
		return
	metadata_file.store_string(JSON.stringify(metadata, "  ") + "\n")
	metadata_file.close()
	_finished = true
	print("[photosphere-capture] complete; quitting cleanly")
	get_tree().quit(0)

func _fail(code: int, message: String) -> void:
	if _finished:
		return
	_finished = true
	printerr("[photosphere-capture] ERROR: ", message)
	get_tree().quit(code)
