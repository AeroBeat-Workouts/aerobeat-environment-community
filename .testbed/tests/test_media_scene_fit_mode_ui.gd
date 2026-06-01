extends GutTest

const ConfigUtils := preload("res://scripts/transform_config.gd")
const ImageSceneScript := preload("res://scripts/image_test_scene.gd")
const VideoSceneScript := preload("res://scripts/video_test_scene.gd")

const IMAGE_SCENE_PATH := "res://scripts/image_test_scene.gd"
const VIDEO_SCENE_PATH := "res://scripts/video_test_scene.gd"
const TEMP_DIR := "user://media_scene_fit_mode_tests"

func after_each() -> void:
	_cleanup_temp_dir()

func test_image_scene_routes_loading_through_aero_image_loader_contract() -> void:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(IMAGE_SCENE_PATH))
	assert_true(text.contains("AeroImageLoaderScript"), "Image scene should preload the public AeroImageLoader contract")
	assert_true(text.contains("load_image({"), "Image scene should load through the public loader API")
	assert_false(text.contains("Image.load("), "Image scene should not call the built-in Image.load path directly anymore")
	assert_true(text.contains("Save Config"), "Image scene should expose Save Config beside the live fit mode controls")

func test_video_scene_uses_live_fit_mode_ui_without_backend_child_poking() -> void:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(VIDEO_SCENE_PATH))
	assert_true(text.contains("Save Config"), "Video scene should expose Save Config beside the live fit mode controls")
	assert_true(text.contains("attach_slot_surface(VIDEO_SLOT, _video_surface)"), "Video scene should attach the shared manager directly to the preview surface")
	assert_false(text.contains("get_video_texture"), "Video scene should not scrape textures from backend-owned children anymore")
	assert_false(text.contains("_get_backend_player"), "Video scene should not reach through the manager boundary for child nodes anymore")

func test_image_scene_defaults_to_cover_and_roundtrips_sidecar_fit_mode() -> void:
	var scene = ImageSceneScript.new()
	scene._ready()
	scene._current_asset_path = _temp_asset_path("images", "cover-check.png")

	assert_eq(scene.get_current_config_payload().get("media", {}).get("fit_mode", ""), "cover")

	scene._set_fit_mode("stretch")
	var save_result := scene.save_current_config()
	assert_true(save_result.get("ok", false), "Expected image sidecar save to succeed")
	assert_true(FileAccess.get_file_as_string(save_result.get("path", "")).contains("fit_mode: stretch"), "Image sidecar should persist the canonical fit_mode field")

	var load_result := ConfigUtils.load_sidecar(scene._current_asset_path, "image")
	assert_eq(load_result.get("config", {}).get("media", {}).get("fit_mode", ""), "stretch")

	scene._set_fit_mode("cover")
	scene._apply_loaded_config_result(load_result)
	assert_eq(scene.get_current_config_payload().get("media", {}).get("fit_mode", ""), "stretch")
	_free_scene(scene)

func test_video_scene_defaults_to_cover_and_roundtrips_sidecar_fit_mode() -> void:
	var scene = VideoSceneScript.new()
	scene._ready()
	scene._current_asset_path = _temp_asset_path("videos", "cover-check.ogv")

	assert_eq(scene.get_current_config_payload().get("media", {}).get("fit_mode", ""), "cover")

	scene._set_fit_mode("contain")
	var save_result := scene.save_current_config()
	assert_true(save_result.get("ok", false), "Expected video sidecar save to succeed")
	assert_true(FileAccess.get_file_as_string(save_result.get("path", "")).contains("fit_mode: contain"), "Video sidecar should persist the canonical fit_mode field")

	var load_result := ConfigUtils.load_sidecar(scene._current_asset_path, "video")
	assert_eq(load_result.get("config", {}).get("media", {}).get("fit_mode", ""), "contain")

	scene._set_fit_mode("cover")
	scene._apply_loaded_config_result(load_result)
	assert_eq(scene.get_current_config_payload().get("media", {}).get("fit_mode", ""), "contain")
	_free_scene(scene)

func _free_scene(scene: Node) -> void:
	if scene != null and is_instance_valid(scene):
		scene.free()

func _temp_asset_path(bucket: String, file_name: String) -> String:
	var dir_path := ProjectSettings.globalize_path(TEMP_DIR.path_join(bucket))
	DirAccess.make_dir_recursive_absolute(dir_path)
	return dir_path.path_join(file_name)

func _cleanup_temp_dir() -> void:
	var root_path := ProjectSettings.globalize_path(TEMP_DIR)
	if not DirAccess.dir_exists_absolute(root_path):
		return
	_cleanup_dir(root_path)

func _cleanup_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry in [".", ".."]:
			continue
		var child_path := path.path_join(entry)
		if dir.current_is_dir():
			_cleanup_dir(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
