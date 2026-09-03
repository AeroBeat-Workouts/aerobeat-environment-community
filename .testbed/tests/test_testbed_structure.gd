extends GutTest

const REQUIRED_DIRS := [
	"res://assets/images",
	"res://assets/videos",
	"res://assets/models",
	"res://assets/splats",
	"res://scenes",
	"res://scripts"
]

const REQUIRED_SCENES := [
	"res://scenes/image_test.tscn",
	"res://scenes/video_test.tscn",
	"res://scenes/glb_test.tscn",
	"res://scenes/splat_test.tscn"
]

func test_required_testbed_directories_exist() -> void:
	for path in REQUIRED_DIRS:
		assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)), "Expected directory: %s" % path)

func test_required_scenes_exist() -> void:
	for path in REQUIRED_SCENES:
		assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(path)), "Expected scene: %s" % path)

func test_manifest_mentions_tool_and_vendor_dependencies() -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path("res://addons.jsonc"), FileAccess.READ)
	assert_true(file != null, "addons manifest should exist")
	var text := file.get_as_text()
	assert_true(text.contains('"aerobeat-tool-gaussian-splat-loader"'), "Manifest should depend on the AeroBeat splat tool loader")
	assert_true(text.contains('"aerobeat-tool-core"'), "Manifest should pin the shared playback contract dependency")
	assert_true(text.contains('"aerobeat-tool-video-player"'), "Manifest should pin the shared playback facade")
	assert_true(text.contains('"aerobeat-vendor-godot-video"'), "Manifest should pin the Godot video backend")
	assert_true(text.contains('"aerobeat-vendor-gdgs"'), "Manifest should pin GDGS through the explicit vendor repo addon identity")

func test_media_buckets_use_per_asset_folders() -> void:
	_assert_bucket_has_only_directories("res://assets/images", [".gitkeep", "photosphere-catalog.json"])
	_assert_bucket_has_only_directories("res://assets/videos", [".gitkeep"])
	_assert_bucket_has_only_directories("res://assets/models", [".gitkeep"])
	_assert_bucket_has_only_directories("res://assets/splats")

func test_normalized_asset_examples_exist() -> void:
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/videos/calm_blue_sea_1/calm_blue_sea_1.ogv")), "canonical video sample should live inside its per-asset folder")
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/models/alien-planet/alien-planet.glb")), "canonical GLB sample should live inside its per-asset folder")
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/splats/alpine-river-valley/alpine-river-valley.compressed.ply")), "normalized splat sample should live inside its per-asset folder")
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://assets/splats/MultiTabber Worlds")), "legacy MultiTabber Worlds bucket should be removed after normalization")

func _assert_bucket_has_only_directories(res_path: String, allowed_files: Array[String] = []) -> void:
	var dir := DirAccess.open(ProjectSettings.globalize_path(res_path))
	assert_true(dir != null, "Expected to open bucket: %s" % res_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name in [".", ".."]:
			continue
		var child_path := "%s/%s" % [res_path, name]
		if dir.current_is_dir():
			continue
		assert_true(name in allowed_files, "Unexpected top-level file in normalized bucket: %s" % child_path)
	dir.list_dir_end()
