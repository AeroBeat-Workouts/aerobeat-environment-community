extends Node3D

const SplatManagerScript := preload("res://addons/aerobeat-tool-gaussian-splat-loader/src/AeroGaussianSplatManager.gd")
const GaussianSplatNodeScript := preload("res://addons/gdgs/runtime/nodes/gaussian_splat_node.gd")
const StandardPlyDecoder := preload("res://addons/gdgs/importers/decoders/standard_ply_decoder.gd")
const CompressedPlyDecoder := preload("res://addons/gdgs/importers/decoders/compressed_ply_decoder.gd")
const SplatDecoder := preload("res://addons/gdgs/importers/decoders/splat_decoder.gd")
const SogDecoder := preload("res://addons/gdgs/importers/decoders/sog_decoder.gd")
const GaussianResourceBuilder := preload("res://addons/gdgs/importers/builders/gaussian_resource_builder.gd")

var _mode := "wrapper"
var _asset_path := ""
var _out_dir := ""
var _manager
var _display_root: Node3D
var _world_environment: WorldEnvironment
var _camera: Camera3D
var _splat_node: Node3D
var _done := false
var _skip_capture := false

func _ready() -> void:
	_parse_args()
	if _asset_path.is_empty() or _out_dir.is_empty():
		printerr("[oc-c3u] missing required --asset or --out_dir user args")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_setup_scene()
	if _mode == "raw":
		_run_raw()
	elif _mode == "raw_file":
		_run_raw_file()
	else:
		_run_wrapper()

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--asset="):
			_asset_path = arg.trim_prefix("--asset=")
		elif arg.begins_with("--out_dir="):
			_out_dir = arg.trim_prefix("--out_dir=")
		elif arg == "--skip_capture":
			_skip_capture = true

func _setup_scene() -> void:
	_display_root = Node3D.new()
	add_child(_display_root)

	_camera = Camera3D.new()
	_camera.look_at_from_position(Vector3(0.0, 0.0, 4.0), Vector3.ZERO)
	add_child(_camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 25.0, 0.0)
	add_child(light)

	_world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.04, 0.06)
	_world_environment.environment = environment
	add_child(_world_environment)

func _run_wrapper() -> void:
	_manager = SplatManagerScript.new()
	add_child(_manager)
	_manager.background_load_finished.connect(_on_wrapper_finished)
	_manager.configure_world_environment(_world_environment)
	var result: Dictionary = _manager.begin_create_splat_node_from_path(_asset_path)
	print("[oc-c3u] wrapper begin result: ", JSON.stringify(result))
	if not result.get("ok", false):
		printerr("[oc-c3u] wrapper begin failed: %s" % result.get("message", "unknown"))
		get_tree().quit(3)

func _ensure_manager_with_compositor() -> void:
	if _manager == null:
		_manager = SplatManagerScript.new()
		add_child(_manager)
		_manager.configure_world_environment(_world_environment)

func _run_raw() -> void:
	_ensure_manager_with_compositor()
	var resource := load(_asset_path) as Resource
	if resource == null:
		printerr("[oc-c3u] raw load failed for %s" % _asset_path)
		get_tree().quit(4)
		return
	print("[oc-c3u] raw resource class: ", resource.get_class())
	var node = GaussianSplatNodeScript.new()
	node.gaussian = resource
	_splat_node = node
	_display_root.add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture_and_quit("raw")

func _run_raw_file() -> void:
	_ensure_manager_with_compositor()
	var decode_result := _decode_file(_asset_path)
	var decode_summary := decode_result.duplicate(true)
	if decode_summary.has("canonical"):
		var canonical: Dictionary = decode_summary["canonical"]
		decode_summary["canonical"] = {
			"count": int(canonical.get("count", -1)),
			"positions_size": canonical.get("positions", PackedVector3Array()).size(),
			"opacities_size": canonical.get("opacities", PackedFloat32Array()).size(),
			"sh_coeffs_size": canonical.get("sh_coeffs", PackedFloat32Array()).size()
		}
	print("[oc-c3u] raw_file decode result: ", JSON.stringify(decode_summary))
	if not decode_result.get("ok", false):
		printerr("[oc-c3u] raw_file decode failed: %s" % decode_result.get("message", "unknown"))
		get_tree().quit(6)
		return
	var build_result: Dictionary = GaussianResourceBuilder.build(decode_result["canonical"])
	var build_summary := build_result.duplicate(true)
	if build_summary.has("resource"):
		build_summary["resource"] = str(build_summary["resource"])
	print("[oc-c3u] raw_file build result: ", JSON.stringify(build_summary))
	if not build_result.get("ok", false):
		printerr("[oc-c3u] raw_file build failed: %s" % build_result.get("message", "unknown"))
		get_tree().quit(7)
		return
	var node = GaussianSplatNodeScript.new()
	node.gaussian = build_result["resource"]
	_splat_node = node
	_display_root.add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture_and_quit("raw_file")

func _on_wrapper_finished(result: Dictionary) -> void:
	print("[oc-c3u] wrapper finished result: ", JSON.stringify(result))
	if not result.get("ok", false):
		printerr("[oc-c3u] wrapper finish failed: %s" % result.get("message", "unknown"))
		get_tree().quit(5)
		return
	_splat_node = result.get("node")
	_display_root.add_child(_splat_node)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture_and_quit("wrapper")

func _decode_file(path: String) -> Dictionary:
	var lower := path.to_lower()
	if lower.ends_with(".compressed.ply"):
		return CompressedPlyDecoder.decode(path)
	if lower.ends_with(".ply"):
		return StandardPlyDecoder.decode(path)
	if lower.ends_with(".splat"):
		return SplatDecoder.decode(path)
	if lower.ends_with(".sog"):
		return SogDecoder.decode(path)
	return {"ok": false, "message": "unsupported extension"}

func _capture_and_quit(label: String) -> void:
	if _done:
		return
	_done = true
	var meta := {
		"mode": label,
		"asset_path": _asset_path,
		"renderer_name": RenderingServer.get_current_rendering_method(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"node_class": _splat_node.get_class() if _splat_node != null else "",
		"node_aabb": str(_splat_node.get_aabb()) if _splat_node != null and _splat_node.has_method("get_aabb") else "",
		"resource_class": _splat_node.gaussian.get_class() if _splat_node != null and _splat_node.get("gaussian") != null else "",
		"point_count": int(_splat_node.gaussian.point_count) if _splat_node != null and _splat_node.get("gaussian") != null else -1,
		"resource_aabb": str(_splat_node.gaussian.aabb) if _splat_node != null and _splat_node.get("gaussian") != null else "",
		"compositor_effect_count": _world_environment.compositor.compositor_effects.size() if _world_environment.compositor != null else 0
	}
	var meta_path := _out_dir.path_join("meta_%s.json" % label)
	var meta_file := FileAccess.open(meta_path, FileAccess.WRITE)
	meta_file.store_string(JSON.stringify(meta, "  "))
	meta_file.close()
	await RenderingServer.frame_post_draw
	if _skip_capture:
		print("[oc-c3u] skip_capture after frame_post_draw")
		get_tree().quit(0)
		return
	var image := get_viewport().get_texture().get_image()
	var png_path := _out_dir.path_join("capture_%s.png" % label)
	var err := image.save_png(png_path)
	print("[oc-c3u] saved capture: %s err=%d" % [png_path, err])
	get_tree().quit(0)
