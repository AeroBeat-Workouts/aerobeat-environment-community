#!/usr/bin/env python3
"""Finalize the bounded eight-entry AeroBeat photosphere catalog and review evidence."""

from __future__ import annotations

import hashlib
import json
import re
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

IDS = (
    "luminious-ice-cave",
    "icebergs-on-sea-shore",
    "snow-mountain-with-lake",
    "iceland-waterfall",
    "igloo-toon",
    "salt-lake",
    "salt-lake-2",
    "alpine-river-valley",
)
LABELS = {
    "luminious-ice-cave": "Luminious Ice Cave",
    "icebergs-on-sea-shore": "Icebergs on Sea Shore",
    "snow-mountain-with-lake": "Snow Mountain with Lake",
    "iceland-waterfall": "Iceland Waterfall",
    "igloo-toon": "Igloo Toon",
    "salt-lake": "Salt Lake",
    "salt-lake-2": "Salt Lake 2",
    "alpine-river-valley": "Alpine River Valley",
}
SOURCE_HASHES = {
    "luminious-ice-cave": (55619663, "a5732239888a0c6967d85693b504248733dbd48e7981cf39a348c32badc3c56a"),
    "icebergs-on-sea-shore": (55619663, "24dfaf4654c9bcc951d66b7ea0d730a6fede101f433efb7064d912e3cd4fceaa"),
    "snow-mountain-with-lake": (55619663, "c9353c30cbff071bad0c51ed7aa8f61bb5405cc98d7792a26e621dd50d59cc53"),
    "iceland-waterfall": (55619664, "b83ffe8ee100731a7adbd35a71a68b30ceb4d2247c94b48f5054f9573a3b93e5"),
    "igloo-toon": (55619664, "88dca765c2cf56f76786140d592f82cd2b3059cfa1966d025147776926f1abbf"),
    "salt-lake": (55619664, "beb9dab250ad146cbe24199c7405d1745f817a5757e7538e81bb0fbe538aec6a"),
    "salt-lake-2": (55619663, "4e623aab0b1dfca463b3d201b4c5cbefe6375ffb2ac2af58f4d6294694c09b3a"),
    "alpine-river-valley": (55619664, "eae63f0baf671e085d2d4b374d4b43cacbb02979c293e1ed194f9fb5813449d5"),
}
# These notes describe the fixed-view conversion, not source quality or runtime suitability.
NOTES = {
    "luminious-ice-cave": ("strong", "Dense crystalline cave coverage surrounds the fixed viewpoint; the existing selected conversion remains the visual baseline."),
    "icebergs-on-sea-shore": ("strong-comparison", "Complete realistic icy-shore coverage; near-nadir ice and shoreline stretch visibly under equirectangular projection."),
    "snow-mountain-with-lake": ("comparison-with-artifacts", "Complete mountain-and-lake coverage retained with conspicuous soft gray source artifacts over the water/ice near one horizon sector."),
    "iceland-waterfall": ("strong-comparison", "Complete waterfall, mossy ridge, sky, and gravel coverage; the detailed nadir produces the measured bottom-row variation."),
    "igloo-toon": ("comparison-with-artifacts", "Bright complete stylized ice world retained with two conspicuous dark soft source artifacts at the horizon."),
    "salt-lake": ("strong-comparison", "Complete open salt-lake coverage with broad low-detail horizons and a detailed salt/water nadir retained from the common viewpoint."),
    "salt-lake-2": ("strong-comparison", "Complete alternate salt-lake coverage with distant low-detail terrain and normal equirectangular nadir stretching."),
    "alpine-river-valley": ("strong-comparison", "Complete alpine meadow, river, mountain, and sky coverage; detailed grass at the nadir produces the measured bottom-row variation."),
}
CONFIG_SCHEMA = "aerobeat/environment_asset_config"
CONFIG_YAW_DEGREES = {
    "luminious-ice-cave": 0,
    "icebergs-on-sea-shore": 0,
    "snow-mountain-with-lake": 0,
    "iceland-waterfall": 0,
    "igloo-toon": 0,
    "salt-lake": 0,
    "salt-lake-2": 0,
    "alpine-river-valley": 180,
}
CONFIG_TRANSFORMS = {
    source_id: {
        "position": {"x": 0, "y": 0, "z": 0},
        "rotationDegrees": {"xPitch": 0, "yYaw": CONFIG_YAW_DEGREES[source_id], "zRoll": 0},
        "scale": 1,
    }
    for source_id in IDS
}
CATALOG_SCHEMA = "aerobeat.photosphere-catalog/v1"
MANIFEST_SCHEMA = "aerobeat.photosphere-derivative/v1"
RIGHTS = {
    "authority": "Derrick Barra direct project instruction on 2026-09-03",
    "statement": "The listed splats were generated and then purchased by AeroBeat and may be used commercially without attribution.",
    "attributionRequired": False,
    "scopeLimit": "Applies only to the listed purchased splats and their photosphere derivatives; it does not apply to the rejected third-party alien-moon GLB and does not assert public sublicensing rights.",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_aabb(value: str) -> dict[str, list[float]]:
    match = re.fullmatch(r"\[P: \(([^)]+)\), S: \(([^)]+)\)\]", value)
    if not match:
        raise ValueError(f"unexpected AABB: {value}")
    return {
        "position": [float(item.strip()) for item in match.group(1).split(",")],
        "size": [float(item.strip()) for item in match.group(2).split(",")],
    }


def continuity(path: Path) -> dict[str, float]:
    with Image.open(path) as image:
        pixels = np.asarray(image.convert("RGB"), dtype=np.uint8)
    seam = np.abs(pixels[:, 0].astype(float) - pixels[:, -1].astype(float)).mean(axis=1)
    return {
        "seamMeanRgbDelta": float(seam.mean()),
        "seamP95RgbDelta": float(np.percentile(seam, 95)),
        "poleTopChannelSpread": float(pixels[0].astype(float).std(axis=0).mean()),
        "poleBottomChannelSpread": float(pixels[-1].astype(float).std(axis=0).mean()),
    }


def file_record(path: Path) -> dict[str, object]:
    with Image.open(path) as image:
        image.load()
        return {"path": path.name, "sha256": sha256(path), "bytes": path.stat().st_size, "dimensions": list(image.size), "mode": image.mode}


def main() -> int:
    root = Path(__file__).resolve().parents[3]
    image_root = root / ".testbed/assets/images"
    review_root = root / ".plans/review/2026-09-03-owned-photosphere-catalog"
    review_root.mkdir(parents=True, exist_ok=True)
    old_review = root / ".plans/review/2026-09-03-luminious-ice-cave-photosphere"

    # Preserve the original selected package and review bytes; add only its JSON successor and copied aggregate evidence.
    luminous_review = review_root / "luminious-ice-cave"
    luminous_review.mkdir(parents=True, exist_ok=True)
    for name in ("cubemap-cross.png", "panorama-preview.jpg", "stitch-report.json"):
        shutil.copyfile(old_review / name, luminous_review / name)

    configs: dict[str, dict[str, object]] = {}
    entries: list[dict[str, object]] = []
    metrics: dict[str, dict[str, float]] = {}
    for source_id in IDS:
        asset_id = f"{source_id}-photosphere"
        asset_dir = image_root / asset_id
        image_path = asset_dir / f"{asset_id}.jpg"
        review_dir = review_root / source_id
        report = json.loads((review_dir / "stitch-report.json").read_text(encoding="utf-8"))
        capture = report["input"]["capture_metadata"]
        source_path = root / f".testbed/assets/splats/{source_id}/{source_id}.compressed.ply"
        expected_bytes, expected_hash = SOURCE_HASHES[source_id]
        if source_path.stat().st_size != expected_bytes or sha256(source_path) != expected_hash:
            raise ValueError(f"source identity mismatch: {source_id}")
        config = {
            "schema": CONFIG_SCHEMA,
            "version": 1,
            "id": asset_id,
            "projection": "equirectangular",
            "transform": CONFIG_TRANSFORMS[source_id],
        }
        config_path = asset_dir / f"{asset_id}.config.json"
        config_path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
        configs[source_id] = config
        metrics[source_id] = continuity(image_path)
        quality, note = NOTES[source_id]
        if source_id != "luminious-ice-cave":
            manifest = {
                "schema": MANIFEST_SCHEMA,
                "id": asset_id,
                "source": {"path": f".testbed/assets/splats/{source_id}/{source_id}.compressed.ply", "sha256": expected_hash, "bytes": expected_bytes, "pointCount": 2200000, "aabb": parse_aabb(capture["aabb"])},
                "capture": {"tool": ".testbed/tools/photosphere/capture_cubemap.gd", "scene": ".testbed/tools/photosphere/capture_cubemap.tscn", "viewpoint": [0, 0, 4], "centerForward": [0, 0, -1], "worldUp": [0, 1, 0], "faceSize": 1920, "faceOrder": ["pos_x", "neg_x", "pos_y", "neg_y", "pos_z", "neg_z"], "loadCount": 1, "requiredExecution": "visible Vulkan Forward+", "versions": {"godot": capture["godot_version"], "gdgsUpstream": "2.2.0", "aerobeatVendorGdgsCommit": "f5d5e1b6d580ba1342022d1ceac8ac982f9597fb", "gpu": capture["rendering_device"], "gpuDriver": "580.173.02", "vulkanReportedByGodot": "1.4.312", "renderingMethod": capture["rendering_method"], "renderingDriver": capture["rendering_driver"], "displayServer": capture["display_server"]}},
                "stitch": {"tool": ".testbed/tools/photosphere/cube_to_equirect.py", "mapping": "longitude wraps horizontally; -Z center, +Y/-Y poles", "sampling": "bilinear RGB, half-texel pixel centers, face-edge clamp", "versions": {"python": "3.14.2", "pillow": "12.1.0", "numpy": "2.4.2"}},
                "output": {"path": f".testbed/assets/images/{asset_id}/{asset_id}.jpg", "dimensions": [4096, 2048], "mode": "RGB", "encoding": "JPEG", "colorSpace": "sRGB", "jpeg": {"quality": 92, "subsampling": 0, "optimize": False, "progressive": False}, "sha256": sha256(image_path), "bytes": image_path.stat().st_size},
                "config": {"path": f".testbed/assets/images/{asset_id}/{asset_id}.config.json", "schema": CONFIG_SCHEMA, "version": 1, "sha256": sha256(config_path), "bytes": config_path.stat().st_size, "parityIntent": "One-to-one future photosphere/splat transform parity; no runtime splat integration in this package."},
                "rights": RIGHTS,
                "continuity": {"metrics": metrics[source_id], "thresholds": {"seamMeanRgbDelta": 5, "seamP95RgbDelta": 16, "poleTopChannelSpread": 16, "poleBottomChannelSpread": 16}},
                "conversionAssessment": {"classification": quality, "note": note},
                "review": {"folder": f".plans/review/2026-09-03-owned-photosphere-catalog/{source_id}", "report": "stitch-report.json", "fullResolutionFacesRetained": False},
                "reproducibilityLimit": "Offline stitching is deterministic only for fixed face bytes and pinned versions. Full-resolution GPU faces are omitted; a fresh GDGS/GPU capture may differ due to device rendering, splat sorting, and driver behavior.",
            }
            (asset_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        manifest_path = asset_dir / "manifest.json"
        review_files = {
            name: {"path": f".plans/review/2026-09-03-owned-photosphere-catalog/{source_id}/{name}", "sha256": sha256(review_dir / name), "bytes": (review_dir / name).stat().st_size}
            for name in ("cubemap-cross.png", "panorama-preview.jpg", "stitch-report.json")
        }
        entries.append({
            "id": asset_id,
            "label": LABELS[source_id],
            "projection": "equirectangular",
            "centerForward": [0, 0, -1],
            "worldUp": [0, 1, 0],
            "image": {"path": f".testbed/assets/images/{asset_id}/{asset_id}.jpg", "sha256": sha256(image_path), "bytes": image_path.stat().st_size},
            "config": {"path": f".testbed/assets/images/{asset_id}/{asset_id}.config.json", "sha256": sha256(config_path), "bytes": config_path.stat().st_size},
            "manifest": {"path": f".testbed/assets/images/{asset_id}/manifest.json", "sha256": sha256(manifest_path), "bytes": manifest_path.stat().st_size},
            "source": {"path": f".testbed/assets/splats/{source_id}/{source_id}.compressed.ply", "sha256": expected_hash},
            "review": review_files,
            "conversionAssessment": {"classification": quality, "note": note},
        })

    catalog = {
        "schema": CATALOG_SCHEMA,
        "id": "aerobeat-owned-photospheres",
        "sourceRepository": "aerobeat-environment-community",
        "sourceCommitLineage": {"candidateInventory": "d46ad5b254df4f718fa935490be3b51dc3dffeae", "firstPhotosphere": "2a3072ff21236ee3d47c3ff3eb813d85eb1ef6c2", "protectedBaseline": "543686003c36eb0ddface684925b373260d8f1d9"},
        "entryCount": 8,
        "rights": RIGHTS,
        "entries": entries,
    }
    catalog_path = image_root / "photosphere-catalog.json"
    catalog_path.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")

    tile_w, tile_h = 480, 240
    sheet = Image.new("RGB", (tile_w * 4, tile_h * 2), (10, 12, 18))
    draw = ImageDraw.Draw(sheet)
    for index, source_id in enumerate(IDS):
        preview = review_root / source_id / "panorama-preview.jpg"
        with Image.open(preview) as image:
            tile = image.convert("RGB").resize((tile_w, tile_h), Image.Resampling.LANCZOS)
        x, y = (index % 4) * tile_w, (index // 4) * tile_h
        sheet.paste(tile, (x, y))
        draw.rectangle((x, y, x + tile_w, y + 28), fill=(0, 0, 0))
        draw.text((x + 8, y + 7), f"{index + 1}. {LABELS[source_id]} [{NOTES[source_id][0]}]", fill=(255, 255, 255))
    sheet_path = review_root / "eight-panorama-contact-sheet.jpg"
    sheet.save(sheet_path, format="JPEG", quality=92, subsampling=0, optimize=False, progressive=False)
    metrics_path = review_root / "metrics.json"
    metrics_path.write_text(json.dumps({"schema": "aerobeat.photosphere-continuity-metrics/v1", "thresholds": {"seamMeanRgbDelta": 5, "seamP95RgbDelta": 16, "poleTopChannelSpread": 16, "poleBottomChannelSpread": 16}, "entries": metrics}, indent=2) + "\n", encoding="utf-8")
    review_entries = {
        source_id: {
            name: {"sha256": sha256(review_root / source_id / name), "bytes": (review_root / source_id / name).stat().st_size}
            for name in ("cubemap-cross.png", "panorama-preview.jpg", "stitch-report.json")
        }
        for source_id in IDS
    }
    review_manifest = {
        "schema": "aerobeat.photosphere-catalog-review/v1",
        "entryCount": 8,
        "inventoryPerEntry": ["cubemap-cross.png", "panorama-preview.jpg", "stitch-report.json"],
        "entries": review_entries,
        "contactSheet": file_record(sheet_path),
        "metrics": {"path": metrics_path.name, "sha256": sha256(metrics_path), "bytes": metrics_path.stat().st_size},
        "catalog": {"path": ".testbed/assets/images/photosphere-catalog.json", "sha256": sha256(catalog_path), "bytes": catalog_path.stat().st_size},
        "note": "Review artifacts are bounded derivatives only. No full-resolution cubemap faces, PLY bytes, rejected GLB bytes, or absolute paths are included.",
    }
    (review_root / "review-manifest.json").write_text(json.dumps(review_manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"catalog": str(catalog_path.relative_to(root)), "entries": entries, "metrics": metrics}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
