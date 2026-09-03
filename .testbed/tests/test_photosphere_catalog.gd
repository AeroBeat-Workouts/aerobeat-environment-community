extends GutTest

const EXPECTED_IDS := [
	"luminious-ice-cave-photosphere",
	"icebergs-on-sea-shore-photosphere",
	"snow-mountain-with-lake-photosphere",
	"iceland-waterfall-photosphere",
	"igloo-toon-photosphere",
	"salt-lake-photosphere",
	"salt-lake-2-photosphere",
	"alpine-river-valley-photosphere",
]

func test_catalog_has_exact_ordered_eight_entries_and_bounded_configs() -> void:
	var catalog := _read_json("res://assets/images/photosphere-catalog.json")
	assert_eq(catalog.get("schema"), "aerobeat.photosphere-catalog/v1")
	assert_eq(catalog.get("entryCount"), 8.0)
	var entries: Array = catalog.get("entries", [])
	assert_eq(entries.size(), 8)
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var asset_id: String = EXPECTED_IDS[index]
		assert_eq(entry.get("id"), asset_id)
		var config := _read_json("res://assets/images/%s/%s.config.json" % [asset_id, asset_id])
		assert_eq(config.keys().size(), 5, "%s config stays bounded" % asset_id)
		assert_eq(config.get("schema"), "aerobeat/environment_asset_config")
		assert_eq(config.get("version"), 1.0)
		assert_eq(config.get("id"), asset_id)
		assert_eq(config.get("projection"), "equirectangular")
		assert_eq(config.get("transform"), {"position": {"x": 0.0, "y": 0.0, "z": 0.0}, "rotationDegrees": {"xPitch": 0.0, "yYaw": 0.0, "zRoll": 0.0}, "scale": 1.0})
		assert_eq(entry.get("centerForward"), [0.0, 0.0, -1.0])
		assert_eq(entry.get("worldUp"), [0.0, 1.0, 0.0])
		assert_true(FileAccess.file_exists(entry["image"]["path"].replace(".testbed/", "res://")), "%s JPEG exists" % asset_id)

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "Expected JSON file: %s" % path)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, "Expected JSON object: %s" % path)
	return parsed if parsed is Dictionary else {}
