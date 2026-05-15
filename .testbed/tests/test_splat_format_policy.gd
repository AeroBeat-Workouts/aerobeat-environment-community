extends GutTest

const README_PATH := "../README.md"
const SPLAT_SCENE_SCRIPT := "res://scripts/splat_test_scene.gd"

func _read_repo_file(relative_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path("res://%s" % relative_path)
	assert_true(FileAccess.file_exists(absolute_path), "Expected repo file to exist: %s" % absolute_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	assert_true(file != null, "Expected repo file to open: %s" % absolute_path)
	return file.get_as_text()

func test_readme_documents_recommended_and_compat_splat_formats() -> void:
	var readme_text := _read_repo_file(README_PATH)
	assert_true(readme_text.contains("`.compressed.ply` is the official recommended splat format"), "README should name .compressed.ply as the recommended AeroBeat format")
	assert_true(readme_text.contains("`.ply`, `.splat`, and `.sog` remain compatibility-supported through GDGS"), "README should preserve GDGS compatibility wording")
	assert_false(readme_text.contains(".spz"), "README should not imply .spz support")

func test_splat_scene_prioritizes_recommended_format_without_overclaiming() -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(SPLAT_SCENE_SCRIPT), FileAccess.READ)
	assert_true(file != null, "splat scene script should exist")
	var text := file.get_as_text()
	assert_true(text.contains("Choose recommended .compressed.ply from assets/splats"), "UI should steer toward the recommended format")
	assert_true(text.contains("Recommended AeroBeat splat format"), "file picker should label the recommended format clearly")
	assert_true(text.contains("GDGS compatibility formats"), "file picker should preserve compatibility wording")
	assert_false(text.contains(".spz"), "splat scene should not imply .spz support")
