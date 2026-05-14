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
	assert_true(text.contains('"aerobeat-tool-gaussian-splat"'), "Manifest should depend on the AeroBeat splat tool")
	assert_true(text.contains('"gdgs"'), "Manifest should pin gdgs through the vendor repo")
