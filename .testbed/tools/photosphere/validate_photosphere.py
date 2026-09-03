#!/usr/bin/env python3
"""Strict validation for the bounded eight-entry AeroBeat photosphere catalog."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, JpegImagePlugin

from cube_to_equirect import FACE_ORDER, stitch

IDS = (
    "luminious-ice-cave", "icebergs-on-sea-shore", "snow-mountain-with-lake",
    "iceland-waterfall", "igloo-toon", "salt-lake", "salt-lake-2", "alpine-river-valley",
)
CONFIG_KEYS = {"schema", "version", "id", "projection", "transform"}
THRESHOLDS = {"seamMeanRgbDelta": 5.0, "seamP95RgbDelta": 16.0, "poleTopChannelSpread": 16.0, "poleBottomChannelSpread": 16.0}
FORBIDDEN_METADATA = ("/home/", "\\home\\", "luis vidal", "sketchfab", "bfc9a041814f4112b016904edfaad0c5", "alien-moon-icescape")
REJECTED_HASHES = {
    "40e38a7bdce9eab4266d8bb19510a95bb4e0410534f3f14a500f36fac2b65077",
    "1e50a9416dc2e506284919947088df812da54e537df69be5ec002c4cc167e788",
    "7654e9450ddc16ed613bf7c5bbd442c0466d89cad8ea4a59a3d1ff12ef8f513c",
}
PROTECTED = {
    ".testbed/assets/images/luminious-ice-cave-photosphere/luminious-ice-cave-photosphere.jpg": "ff142b3ce3d3509ab3cfafcfc6a8cc2d3b0ff737852072d3a7aea8075478eed5",
    ".testbed/assets/images/luminious-ice-cave-photosphere/luminious-ice-cave-photosphere.config.yaml": "d415e7de8cdc9c78cfc2d3261b9f50a0d9cb626fe8e368bec43de2c8e686fb42",
    ".testbed/assets/images/luminious-ice-cave-photosphere/manifest.json": "524c7a5623dfbafb65590a9b3b78dc894d4341165d564ac267d470f03acf7e80",
    ".plans/review/2026-09-03-luminious-ice-cave-photosphere/cubemap-cross.png": "4a547299a6fde2e0a22e7334849fa882e755f3f7310cc434fef2865fdfdc74c2",
    ".plans/review/2026-09-03-luminious-ice-cave-photosphere/panorama-preview.jpg": "8fd0292c40dc93bc44846ef59eb98a7b921c1dd927eca2156ba98d9d9f3e1823",
    ".plans/review/2026-09-03-luminious-ice-cave-photosphere/stitch-report.json": "bab767d0618ee4744cb9ee1763b0ac302cdc9cd6e6a07fa6bc2d179677870228",
}
FACE_COLORS = {"pos_x": (255, 0, 0), "neg_x": (0, 255, 0), "pos_y": (0, 0, 255), "neg_y": (255, 255, 0), "pos_z": (255, 0, 255), "neg_z": (0, 255, 255)}


def fail(message: str) -> None:
    raise AssertionError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inventory(folder: Path) -> set[str]:
    return {path.name for path in folder.iterdir() if path.is_file() and path.suffix != ".import"}


def expected_quality_92_tables() -> dict[int, list[int]]:
    stream = io.BytesIO()
    Image.new("RGB", (8, 8), (0, 0, 0)).save(stream, format="JPEG", quality=92, subsampling=0, optimize=False, progressive=False)
    stream.seek(0)
    with Image.open(stream) as reference:
        reference.load()
        return reference.quantization


def assert_image(path: Path, size: tuple[int, int], require_quality_92: bool = False) -> np.ndarray:
    with Image.open(path) as image:
        image.load()
        if image.size != size or image.mode != "RGB":
            fail(f"{path} must be RGB {size}, got {image.mode} {image.size}")
        if path.suffix.lower() in {".jpg", ".jpeg"} and (image.format != "JPEG" or JpegImagePlugin.get_sampling(image) != 0):
            fail(f"{path} must be JPEG with 4:4:4 subsampling=0")
        if require_quality_92 and (image.quantization != expected_quality_92_tables() or image.info.get("progressive", False)):
            fail(f"{path} does not use the pinned Pillow quality=92 non-progressive quantization")
        if image.getexif() or "icc_profile" in image.info or "comment" in image.info:
            fail(f"{path} contains nonessential metadata")
        pixels = np.asarray(image, dtype=np.uint8).copy()
    if float(pixels.std()) < 10 or float(pixels.mean()) < 5:
        fail(f"{path} appears blank")
    return pixels


def continuity(pixels: np.ndarray) -> dict[str, float]:
    seam = np.abs(pixels[:, 0].astype(float) - pixels[:, -1].astype(float)).mean(axis=1)
    return {"seamMeanRgbDelta": float(seam.mean()), "seamP95RgbDelta": float(np.percentile(seam, 95)), "poleTopChannelSpread": float(pixels[0].astype(float).std(axis=0).mean()), "poleBottomChannelSpread": float(pixels[-1].astype(float).std(axis=0).mean())}


def orientation_self_test() -> None:
    faces = {name: np.full((32, 32, 3), FACE_COLORS[name], dtype=np.uint8) for name in FACE_ORDER}
    panorama = np.asarray(stitch(faces, 256, 128))
    probes = {"neg_z": panorama[64, 128], "pos_x": panorama[64, 192], "neg_x": panorama[64, 64], "pos_z": panorama[64, 0], "pos_y": panorama[0, 128], "neg_y": panorama[-1, 128]}
    for name, pixel in probes.items():
        if np.max(np.abs(pixel.astype(int) - np.asarray(FACE_COLORS[name]))) > 1:
            fail(f"orientation self-test failed for {name}")


def mean_patch(array: np.ndarray, x: int, y: int, radius: int) -> np.ndarray:
    return array[max(0, y - radius): y + radius + 1, max(0, x - radius): x + radius + 1].mean(axis=(0, 1))


def validate_cross_consistency(cross: np.ndarray, preview: np.ndarray) -> dict[str, float]:
    tile = 512
    positions = {"pos_y": (1, 0), "neg_x": (0, 1), "neg_z": (1, 1), "pos_x": (2, 1), "pos_z": (3, 1), "neg_y": (1, 2)}
    panorama_points = {"neg_z": (512, 256), "pos_x": (768, 256), "neg_x": (256, 256), "pos_z": (0, 256), "pos_y": (512, 0), "neg_y": (512, 511)}
    interiors = {}
    errors = {}
    for name, (column, row) in positions.items():
        x0, y0 = column * tile, row * tile
        interior = cross[y0 + 48:y0 + tile - 24, x0 + 24:x0 + tile - 24]
        if float(interior.std()) < 10:
            fail(f"cubemap face appears blank: {name}")
        interiors[name] = interior
        px, py = panorama_points[name]
        error = float(np.mean(np.abs(mean_patch(cross, x0 + tile // 2, y0 + tile // 2, 10) - mean_patch(preview, px, py, 5))))
        errors[name] = error
        if error > 35:
            fail(f"cubemap/panorama feature consistency failed: {name}={error:.3f}")
    for index, left in enumerate(FACE_ORDER):
        for right in FACE_ORDER[index + 1:]:
            left_sample = interiors[left][::16, ::16].astype(float)
            right_sample = interiors[right][::16, ::16].astype(float)
            height, width = min(left_sample.shape[0], right_sample.shape[0]), min(left_sample.shape[1], right_sample.shape[1])
            if float(np.mean(np.abs(left_sample[:height, :width] - right_sample[:height, :width]))) < 1:
                fail(f"cubemap faces appear duplicated: {left}/{right}")
    return errors


def walk_strings(value: object):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from walk_strings(key)
            yield from walk_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_strings(child)


def assert_no_absolute_paths(documents: list[object]) -> None:
    for document in documents:
        for value in walk_strings(document):
            if value.startswith(("/", "\\\\")) or re.match(r"^[A-Za-z]:[\\/]", value):
                fail(f"absolute path found in metadata: {value}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    root = args.repo_root.resolve()
    image_root = root / ".testbed/assets/images"
    review_root = root / ".plans/review/2026-09-03-owned-photosphere-catalog"
    catalog_path = image_root / "photosphere-catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    if catalog.get("schema") != "aerobeat.photosphere-catalog/v1" or catalog.get("entryCount") != 8:
        fail("catalog schema/count mismatch")
    entries = catalog.get("entries", [])
    if len(entries) != 8 or [entry["id"] for entry in entries] != [f"{item}-photosphere" for item in IDS]:
        fail("catalog must contain the exact ordered eight entries")
    if set(review_root.iterdir()) != {*(review_root / item for item in IDS), review_root / "eight-panorama-contact-sheet.jpg", review_root / "metrics.json", review_root / "review-manifest.json"}:
        fail("aggregate review inventory mismatch")
    if inventory(review_root) != {"eight-panorama-contact-sheet.jpg", "metrics.json", "review-manifest.json"}:
        fail("aggregate review root files mismatch")
    assert_image(review_root / "eight-panorama-contact-sheet.jpg", (1920, 480))
    metrics_doc = json.loads((review_root / "metrics.json").read_text(encoding="utf-8"))
    review_manifest = json.loads((review_root / "review-manifest.json").read_text(encoding="utf-8"))
    if metrics_doc.get("thresholds") != {key: int(value) for key, value in THRESHOLDS.items()} or set(metrics_doc.get("entries", {})) != set(IDS):
        fail("metrics schema/inventory mismatch")
    if review_manifest.get("entryCount") != 8 or review_manifest["catalog"]["sha256"] != sha256(catalog_path):
        fail("review manifest/catalog mismatch")

    serialized = []
    documents: list[object] = [catalog, metrics_doc, review_manifest]
    results = {}
    for path_string, expected_hash in PROTECTED.items():
        if sha256(root / path_string) != expected_hash:
            fail(f"protected prior file changed: {path_string}")
    for source_id, entry in zip(IDS, entries, strict=True):
        asset_id = f"{source_id}-photosphere"
        asset_dir = image_root / asset_id
        expected_asset_inventory = {f"{asset_id}.jpg", f"{asset_id}.config.json", "manifest.json"}
        if source_id == "luminious-ice-cave":
            expected_asset_inventory.add(f"{asset_id}.config.yaml")
        if inventory(asset_dir) != expected_asset_inventory or any(path.is_dir() for path in asset_dir.iterdir()):
            fail(f"asset inventory mismatch: {source_id}")
        config_path = asset_dir / f"{asset_id}.config.json"
        image_path = asset_dir / f"{asset_id}.jpg"
        config = json.loads(config_path.read_text(encoding="utf-8"))
        expected_config = {"schema": "aerobeat/environment_asset_config", "version": 1, "id": asset_id, "projection": "equirectangular", "transform": {"position": {"x": 0, "y": 0, "z": 0}, "rotationDegrees": {"xPitch": 0, "yYaw": 0, "zRoll": 0}, "scale": 1}}
        if set(config) != CONFIG_KEYS or config != expected_config:
            fail(f"bounded config contract mismatch: {source_id}")
        if entry.get("projection") != "equirectangular" or entry.get("centerForward") != [0, 0, -1] or entry.get("worldUp") != [0, 1, 0]:
            fail(f"catalog orientation contract mismatch: {source_id}")
        if entry["image"]["sha256"] != sha256(image_path) or entry["image"]["bytes"] != image_path.stat().st_size:
            fail(f"catalog image identity mismatch: {source_id}")
        if entry["config"]["sha256"] != sha256(config_path) or entry["config"]["bytes"] != config_path.stat().st_size:
            fail(f"catalog config identity mismatch: {source_id}")
        source_value = entry["source"]["path"]
        if Path(source_value).is_absolute() or ".." in Path(source_value).parts:
            fail(f"source path must stay repository-relative: {source_id}")
        source_path = root / source_value
        if sha256(source_path) != entry["source"]["sha256"]:
            fail(f"source identity mismatch: {source_id}")
        pixels = assert_image(image_path, (4096, 2048), require_quality_92=True)
        measured = continuity(pixels)
        recorded = metrics_doc["entries"][source_id]
        for key, value in measured.items():
            if abs(value - float(recorded[key])) > 1e-9 or value > THRESHOLDS[key]:
                fail(f"continuity mismatch/threshold: {source_id} {key}={value}")
        results[source_id] = measured
        review_dir = review_root / source_id
        if inventory(review_dir) != {"cubemap-cross.png", "panorama-preview.jpg", "stitch-report.json"} or any(path.is_dir() for path in review_dir.iterdir()):
            fail(f"per-entry review inventory mismatch: {source_id}")
        cross = assert_image(review_dir / "cubemap-cross.png", (2048, 1536))
        preview = assert_image(review_dir / "panorama-preview.jpg", (1024, 512))
        validate_cross_consistency(cross, preview)
        report = json.loads((review_dir / "stitch-report.json").read_text(encoding="utf-8"))
        if report["output"]["sha256"] != sha256(image_path) or report["output"]["dimensions"] != [4096, 2048] or report["output"]["mode"] != "RGB":
            fail(f"stitch report output mismatch: {source_id}")
        if report["output"]["jpeg"] != {"quality": 92, "subsampling": 0, "optimize": False, "progressive": False}:
            fail(f"stitch report JPEG settings mismatch: {source_id}")
        capture = report["input"]["capture_metadata"]
        expected_res_path = f"res://assets/splats/{source_id}/{source_id}.compressed.ply"
        if capture["viewpoint"] != [0.0, 0.0, 4.0] or report["input"]["face_size"] != 1920 or capture["face_size"] != 1920:
            fail(f"capture viewpoint/face size mismatch: {source_id}")
        if capture["asset"] != expected_res_path or capture["point_count"] != 2_200_000 or capture["load_count"] != 1:
            fail(f"capture source/point/load mismatch: {source_id}")
        if capture["rendering_method"] != "forward_plus" or capture["rendering_driver"] != "vulkan" or capture["display_server"] != "X11":
            fail(f"capture backend mismatch: {source_id}")
        if report["input"]["inventory"] != [f"{name}.png" for name in FACE_ORDER] + ["capture.json"]:
            fail(f"face inventory mismatch: {source_id}")
        face_hashes = report["input"]["face_sha256"]
        face_bytes = report["input"]["face_bytes"]
        if set(face_hashes) != set(FACE_ORDER) or len(set(face_hashes.values())) != 6 or any(not re.fullmatch(r"[0-9a-f]{64}", value) for value in face_hashes.values()):
            fail(f"face hash identity mismatch/duplication: {source_id}")
        if set(face_bytes) != set(FACE_ORDER) or any(not isinstance(value, int) or value <= 0 for value in face_bytes.values()):
            fail(f"face byte record mismatch: {source_id}")
        for name in ("cubemap-cross.png", "panorama-preview.jpg"):
            record = report["review"][name]
            path = review_dir / name
            if record["sha256"] != sha256(path) or record["bytes"] != path.stat().st_size:
                fail(f"review identity mismatch: {source_id}/{name}")
        manifest_path = asset_dir / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if entry["manifest"]["sha256"] != sha256(manifest_path) or entry["manifest"]["bytes"] != manifest_path.stat().st_size:
            fail(f"catalog manifest identity mismatch: {source_id}")
        for name in ("cubemap-cross.png", "panorama-preview.jpg", "stitch-report.json"):
            path = review_dir / name
            if entry["review"][name]["sha256"] != sha256(path) or entry["review"][name]["bytes"] != path.stat().st_size:
                fail(f"catalog review identity mismatch: {source_id}/{name}")
            aggregate_record = review_manifest["entries"][source_id][name]
            if aggregate_record["sha256"] != sha256(path) or aggregate_record["bytes"] != path.stat().st_size:
                fail(f"aggregate review identity mismatch: {source_id}/{name}")
        if source_id != "luminious-ice-cave":
            if manifest.get("schema") != "aerobeat.photosphere-derivative/v1" or manifest["output"]["sha256"] != sha256(image_path) or manifest["config"]["sha256"] != sha256(config_path):
                fail(f"derivative manifest mismatch: {source_id}")
            if manifest["source"]["sha256"] != entry["source"]["sha256"] or manifest["source"]["bytes"] != source_path.stat().st_size or manifest["source"]["pointCount"] != capture["point_count"]:
                fail(f"derivative source identity mismatch: {source_id}")
            expected_aabb = f"[P: ({', '.join(str(value) for value in manifest['source']['aabb']['position'])}), S: ({', '.join(str(value) for value in manifest['source']['aabb']['size'])})]"
            if capture["aabb"] != expected_aabb:
                fail(f"capture/manifest AABB mismatch: {source_id}")
            if manifest["continuity"]["metrics"] != recorded or "deterministic only for fixed face bytes" not in manifest["reproducibilityLimit"]:
                fail(f"continuity/reproducibility record mismatch: {source_id}")
        documents.extend([config, manifest, report])
        serialized.extend([config_path.read_text(encoding="utf-8"), manifest_path.read_text(encoding="utf-8"), (review_dir / "stitch-report.json").read_text(encoding="utf-8")])

    serialized.extend([catalog_path.read_text(encoding="utf-8"), (review_root / "metrics.json").read_text(encoding="utf-8"), (review_root / "review-manifest.json").read_text(encoding="utf-8")])
    metadata = "\n".join(serialized).lower()
    assert_no_absolute_paths(documents)
    for forbidden in (*FORBIDDEN_METADATA, *REJECTED_HASHES):
        if forbidden in metadata:
            fail(f"forbidden absolute/third-party metadata found: {forbidden}")
    delivered_files = [path for source_id in IDS for path in (image_root / f"{source_id}-photosphere").iterdir() if path.is_file() and path.suffix != ".import"] + [path for path in review_root.rglob("*") if path.is_file()] + [catalog_path]
    if any(path.suffix.lower() in {".glb", ".ply"} for path in delivered_files):
        fail("GLB/PLY bytes are forbidden from photosphere asset/review inventories")
    for path in delivered_files:
        if sha256(path) in REJECTED_HASHES:
            fail(f"rejected third-party byte identity found: {path}")
    orientation_self_test()
    print(json.dumps({"ok": True, "entryCount": 8, "metrics": results}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, FileNotFoundError, KeyError, ValueError, json.JSONDecodeError) as error:
        print(f"photosphere validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
