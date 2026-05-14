extends GutTest

const README_PATH := "../README.md"
const PLUGIN_CFG_PATH := "../plugin.cfg"
const PROJECT_GODOT_PATH := "project.godot"

func _read_repo_file(relative_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path("res://%s" % relative_path)
	assert_true(FileAccess.file_exists(absolute_path), "Expected repo file to exist: %s" % absolute_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	assert_true(file != null, "Expected repo file to open: %s" % absolute_path)
	return file.get_as_text()

func test_readme_documents_testbed_scope() -> void:
	var readme_text := _read_repo_file(README_PATH)
	assert_true(readme_text.contains("image, video, GLB, and Gaussian splat"), "README should describe the four test surfaces")
	assert_true(readme_text.contains("center"), "README should document shared config fields")
	assert_true(readme_text.contains("arbitrary local filesystem loading outside `res://`"), "README should mention arbitrary local splat loading")

func test_plugin_cfg_matches_environment_community_repo_role() -> void:
	var config := ConfigFile.new()
	var error := config.load(ProjectSettings.globalize_path("res://%s" % PLUGIN_CFG_PATH))
	assert_eq(error, OK, "plugin.cfg should parse cleanly")
	assert_eq(config.get_value("plugin", "name", ""), "AeroBeat Environment - Community")
	assert_true(
		String(config.get_value("plugin", "description", "")).contains("Gaussian splat"),
		"plugin description should mention Gaussian splat validation"
	)

func test_hidden_testbed_name_matches_repo_scope() -> void:
	var config := ConfigFile.new()
	var error := config.load(ProjectSettings.globalize_path("res://%s" % PROJECT_GODOT_PATH))
	assert_eq(error, OK, "project.godot should parse cleanly")
	assert_eq(config.get_value("application", "config/name", ""), "AeroBeat Environment Community Testbed")
