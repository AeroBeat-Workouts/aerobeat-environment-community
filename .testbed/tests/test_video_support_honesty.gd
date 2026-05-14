extends GutTest

const VIDEO_SCENE_SCRIPT := "res://scripts/video_test_scene.gd"
const README_PATH := "../README.md"

func test_video_scene_is_truth_locked_to_ogv() -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(VIDEO_SCENE_SCRIPT), FileAccess.READ)
	assert_true(file != null, "video scene script should exist")
	var text := file.get_as_text()
	assert_true(text.contains("*.ogv ; Ogg Theora video"), "video chooser should only advertise canonical .ogv support")
	assert_false(text.contains("*.webm"), "video chooser should not overclaim .webm support")
	assert_false(text.contains("*.mp4"), "video chooser should not overclaim .mp4 support")
	assert_true(text.contains("VideoStreamTheora"), "video loader should enforce Theora-backed streams")

func test_canonical_video_asset_is_ogv_only() -> void:
	var ogv_path := ProjectSettings.globalize_path("res://assets/videos/calm_blue_sea_1.ogv")
	var mp4_path := ProjectSettings.globalize_path("res://assets/videos/calm_blue_sea_1.mp4")
	assert_true(FileAccess.file_exists(ogv_path), "canonical .ogv asset should exist")
	assert_false(FileAccess.file_exists(mp4_path), "source .mp4 should not remain in the canonical assets folder")
	var stream = ResourceLoader.load("res://assets/videos/calm_blue_sea_1.ogv")
	assert_true(stream is VideoStreamTheora, "canonical asset should load as a Theora-backed Godot video stream")

func test_readme_documents_delete_first_restore_flow() -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path("res://%s" % README_PATH), FileAccess.READ)
	assert_true(file != null, "README should exist")
	var text := file.get_as_text()
	assert_true(text.contains("truth-locked to canonical `.ogv`"), "README should document honest .ogv-only support")
	assert_true(text.contains("./scripts/restore-testbed-addons.sh"), "README should document the canonical restore helper")
	assert_true(text.contains("without relying on manual deletion tribal knowledge"), "README should describe why the restore helper exists")
