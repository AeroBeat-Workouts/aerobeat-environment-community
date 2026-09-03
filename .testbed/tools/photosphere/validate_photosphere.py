#!/usr/bin/env python3
"""Focused validation for the luminious ice cave photosphere package."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from cube_to_equirect import FACE_ORDER, stitch

ASSET_INVENTORY = {
    "luminious-ice-cave-photosphere.jpg",
    "luminious-ice-cave-photosphere.config.yaml",
    "manifest.json",
}
REVIEW_INVENTORY = {"cubemap-cross.png", "panorama-preview.jpg", "stitch-report.json"}
FORBIDDEN_METADATA = (
    "/home/",
    "\\home\\",
    "luis vidal",
    "sketchfab",
    "bfc9a041814f4112b016904edfaad0c5",
    "alien-moon-icescape",
)
FACE_COLORS = {
    "pos_x": (255, 0, 0),
    "neg_x": (0, 255, 0),
    "pos_y": (0, 0, 255),
    "neg_y": (255, 255, 0),
    "pos_z": (255, 0, 255),
    "neg_z": (0, 255, 255),
}


def fail(message: str) -> None:
    raise AssertionError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def assert_inventory(folder: Path, expected: set[str]) -> None:
    # Godot may materialize ignored *.import cache sidecars after an import check;
    # they are generated state, not preserved package inventory.
    actual = {path.name for path in folder.iterdir() if path.is_file() and path.suffix != ".import"}
    if actual != expected:
        fail(f"preserved inventory mismatch in {folder}: expected {sorted(expected)}, got {sorted(actual)}")
    if any(path.is_dir() for path in folder.iterdir()):
        fail(f"unexpected nested directory in {folder}")


def assert_image(path: Path, size: tuple[int, int], mode: str) -> np.ndarray:
    with Image.open(path) as image:
        image.load()
        if image.size != size:
            fail(f"{path.name} dimensions {image.size}, expected {size}")
        if image.mode != mode:
            fail(f"{path.name} mode {image.mode}, expected {mode}")
        if image.getexif():
            fail(f"{path.name} contains EXIF metadata")
        if "icc_profile" in image.info or "comment" in image.info:
            fail(f"{path.name} contains nonessential embedded metadata")
        array = np.asarray(image, dtype=np.uint8).copy()
    if float(array.std()) < 10.0 or float(array.mean()) < 5.0:
        fail(f"{path.name} appears blank or nearly constant")
    return array


def validate_orientation_self_test() -> None:
    faces = {
        name: np.full((32, 32, 3), FACE_COLORS[name], dtype=np.uint8)
        for name in FACE_ORDER
    }
    panorama = np.asarray(stitch(faces, 256, 128))
    probes = {
        "neg_z": panorama[64, 128],
        "pos_x": panorama[64, 192],
        "neg_x": panorama[64, 64],
        "pos_z": panorama[64, 0],
        "pos_y": panorama[0, 128],
        "neg_y": panorama[-1, 128],
    }
    for name, pixel in probes.items():
        if np.max(np.abs(pixel.astype(int) - np.asarray(FACE_COLORS[name]))) > 1:
            fail(f"synthetic orientation marker failed for {name}: {pixel.tolist()}")


def mean_patch(array: np.ndarray, x: int, y: int, radius: int = 4) -> np.ndarray:
    return array[max(0, y - radius): y + radius + 1, max(0, x - radius): x + radius + 1].mean(axis=(0, 1))


def validate_cross_consistency(cross: np.ndarray, preview: np.ndarray) -> dict[str, float]:
    tile = 512
    positions = {
        "pos_y": (1, 0), "neg_x": (0, 1), "neg_z": (1, 1),
        "pos_x": (2, 1), "pos_z": (3, 1), "neg_y": (1, 2),
    }
    panorama_points = {
        "neg_z": (512, 256), "pos_x": (768, 256), "neg_x": (256, 256),
        "pos_z": (0, 256), "pos_y": (512, 0), "neg_y": (512, 511),
    }
    interiors: dict[str, np.ndarray] = {}
    errors: dict[str, float] = {}
    for name, (column, row) in positions.items():
        x0, y0 = column * tile, row * tile
        interior = cross[y0 + 48:y0 + tile - 24, x0 + 24:x0 + tile - 24]
        interiors[name] = interior
        if float(interior.std()) < 10.0:
            fail(f"cubemap cross face {name} appears blank")
        cross_center = mean_patch(cross, x0 + tile // 2, y0 + tile // 2, 10)
        px, py = panorama_points[name]
        panorama_center = mean_patch(preview, px, py, 5)
        error = float(np.mean(np.abs(cross_center - panorama_center)))
        errors[name] = error
        if error > 35.0:
            fail(f"cubemap/panorama feature consistency failed for {name}: mean RGB error {error:.3f}")
    for left_index, left in enumerate(FACE_ORDER):
        for right in FACE_ORDER[left_index + 1:]:
            # Resize-free central samples reject accidental repeated/stale faces.
            left_sample = interiors[left][::16, ::16].astype(float)
            right_sample = interiors[right][::16, ::16].astype(float)
            height = min(left_sample.shape[0], right_sample.shape[0])
            width = min(left_sample.shape[1], right_sample.shape[1])
            difference = float(np.mean(np.abs(left_sample[:height, :width] - right_sample[:height, :width])))
            if difference < 1.0:
                fail(f"cubemap faces {left} and {right} appear duplicated")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    root = args.repo_root.resolve()
    asset_dir = root / ".testbed/assets/images/luminious-ice-cave-photosphere"
    review_dir = root / ".plans/review/2026-09-03-luminious-ice-cave-photosphere"
    source = root / ".testbed/assets/splats/luminious-ice-cave/luminious-ice-cave.compressed.ply"

    assert_inventory(asset_dir, ASSET_INVENTORY)
    assert_inventory(review_dir, REVIEW_INVENTORY)
    manifest = json.loads((asset_dir / "manifest.json").read_text(encoding="utf-8"))
    report = json.loads((review_dir / "stitch-report.json").read_text(encoding="utf-8"))
    serialized_metadata = "\n".join(
        path.read_text(encoding="utf-8", errors="strict")
        for path in (*sorted(asset_dir.glob("*.json")), *sorted(asset_dir.glob("*.yaml")), *sorted(review_dir.glob("*.json")))
    ).lower()
    for forbidden in FORBIDDEN_METADATA:
        if forbidden in serialized_metadata:
            fail(f"forbidden absolute/third-party metadata found: {forbidden}")
    if any(asset_dir.glob("*.glb")) or any(review_dir.glob("*.glb")):
        fail("rejected GLB content is forbidden from asset and review folders")

    source_expected = manifest["source"]
    if source.stat().st_size != source_expected["bytes"] or sha256(source) != source_expected["sha256"]:
        fail("selected PLY source identity mismatch")
    if source_expected["point_count"] != 2_200_000:
        fail("selected PLY point count is not pinned")
    expected_aabb = {"position": [-13.19479, -6.108843, -20.97153], "size": [42.97656, 9.789062, 77.45679]}
    if source_expected["aabb"] != expected_aabb:
        fail("selected PLY AABB is not exactly pinned")
    capture_metadata = report["input"]["capture_metadata"]
    if capture_metadata["point_count"] != source_expected["point_count"]:
        fail("GPU capture point count disagrees with source manifest")
    if capture_metadata["aabb"] != "[P: (-13.19479, -6.108843, -20.97153), S: (42.97656, 9.789062, 77.45679)]":
        fail("GPU capture AABB disagrees with source manifest")
    if capture_metadata["load_count"] != 1 or capture_metadata["face_size"] != 1920:
        fail("GPU capture did not preserve one-load square-face contract")

    panorama_path = asset_dir / "luminious-ice-cave-photosphere.jpg"
    panorama = assert_image(panorama_path, (4096, 2048), "RGB")
    output = manifest["output"]
    if panorama_path.stat().st_size != output["bytes"] or sha256(panorama_path) != output["sha256"]:
        fail("canonical panorama byte/hash identity mismatch")
    if output["jpeg"] != {"quality": 92, "subsampling": 0, "optimize": False, "progressive": False}:
        fail("canonical JPEG options are not exactly pinned")
    if report["output"]["sha256"] != output["sha256"]:
        fail("stitch derivative report disagrees with asset manifest")

    cross = assert_image(review_dir / "cubemap-cross.png", (2048, 1536), "RGB")
    preview = assert_image(review_dir / "panorama-preview.jpg", (1024, 512), "RGB")
    for filename in ("cubemap-cross.png", "panorama-preview.jpg"):
        recorded = report["review"][filename]
        path = review_dir / filename
        if path.stat().st_size != recorded["bytes"] or sha256(path) != recorded["sha256"]:
            fail(f"review artifact identity mismatch: {filename}")

    validate_orientation_self_test()
    consistency = validate_cross_consistency(cross, preview)

    seam_delta = np.abs(panorama[:, 0].astype(float) - panorama[:, -1].astype(float)).mean(axis=1)
    top_spread = panorama[0].astype(float).std(axis=0).mean()
    bottom_spread = panorama[-1].astype(float).std(axis=0).mean()
    metrics = {
        "seam_mean_rgb_delta": float(seam_delta.mean()),
        "seam_p95_rgb_delta": float(np.percentile(seam_delta, 95)),
        "pole_top_channel_spread": float(top_spread),
        "pole_bottom_channel_spread": float(bottom_spread),
    }
    thresholds = manifest["validation"]["continuity_thresholds"]
    for key, value in metrics.items():
        if value > float(thresholds[key]):
            fail(f"continuity threshold exceeded: {key}={value:.4f} > {thresholds[key]}")

    if not re.fullmatch(r"[0-9a-f]{64}", output["sha256"]):
        fail("output SHA-256 is malformed")
    print(json.dumps({"ok": True, "metrics": metrics, "cross_feature_mean_rgb_errors": consistency}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, FileNotFoundError, KeyError, ValueError, json.JSONDecodeError) as error:
        print(f"photosphere validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
