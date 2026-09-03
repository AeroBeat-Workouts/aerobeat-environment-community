#!/usr/bin/env python3
"""Deterministically stitch AeroBeat's six-face cubemap convention.

The equirectangular center points along world -Z. Image right advances toward +X;
image top advances toward +Y. Input image rows run from camera +up to -up.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

FACE_ORDER = ("pos_x", "neg_x", "pos_y", "neg_y", "pos_z", "neg_z")
# forward, camera-right, camera-up; right = forward cross up.
FACE_AXES = {
    "pos_x": ((1, 0, 0), (0, 0, 1), (0, 1, 0)),
    "neg_x": ((-1, 0, 0), (0, 0, -1), (0, 1, 0)),
    "pos_y": ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
    "neg_y": ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
    "pos_z": ((0, 0, 1), (-1, 0, 0), (0, 1, 0)),
    "neg_z": ((0, 0, -1), (1, 0, 0), (0, 1, 0)),
}
JPEG_OPTIONS = {
    "quality": 92,
    "subsampling": 0,  # 4:4:4
    "optimize": False,
    "progressive": False,
}
PREVIEW_JPEG_OPTIONS = {
    "quality": 90,
    "subsampling": 0,
    "optimize": False,
    "progressive": False,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_faces(face_dir: Path) -> tuple[dict[str, np.ndarray], int]:
    faces: dict[str, np.ndarray] = {}
    size = 0
    for name in FACE_ORDER:
        path = face_dir / f"{name}.png"
        with Image.open(path) as image:
            rgb = image.convert("RGB")
            if rgb.width != rgb.height:
                raise ValueError(f"{path} is not square: {rgb.size}")
            if size and rgb.width != size:
                raise ValueError(f"face size mismatch: {path} is {rgb.size}, expected {size} square")
            size = rgb.width
            faces[name] = np.asarray(rgb, dtype=np.uint8).copy()
    return faces, size


def bilinear(face: np.ndarray, source_x: np.ndarray, source_y: np.ndarray) -> np.ndarray:
    size = face.shape[0]
    x = np.clip(source_x, 0.0, size - 1.0)
    y = np.clip(source_y, 0.0, size - 1.0)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    x1 = np.minimum(x0 + 1, size - 1)
    y1 = np.minimum(y0 + 1, size - 1)
    wx = (x - x0)[..., None]
    wy = (y - y0)[..., None]
    top = face[y0, x0].astype(np.float64) * (1.0 - wx) + face[y0, x1].astype(np.float64) * wx
    bottom = face[y1, x0].astype(np.float64) * (1.0 - wx) + face[y1, x1].astype(np.float64) * wx
    return np.clip(np.rint(top * (1.0 - wy) + bottom * wy), 0, 255).astype(np.uint8)


def stitch(faces: dict[str, np.ndarray], width: int, height: int) -> Image.Image:
    if width != height * 2:
        raise ValueError("equirectangular output must have exact 2:1 dimensions")
    size = next(iter(faces.values())).shape[0]
    output = np.empty((height, width, 3), dtype=np.uint8)
    x = np.arange(width, dtype=np.float64)
    longitude = ((x + 0.5) / width - 0.5) * (2.0 * np.pi)
    # Explicit wrap makes the horizontal seam convention independent of caller input.
    longitude = ((longitude + np.pi) % (2.0 * np.pi)) - np.pi
    sin_lon = np.sin(longitude)
    cos_lon = np.cos(longitude)

    for row_start in range(0, height, 128):
        row_end = min(row_start + 128, height)
        y = np.arange(row_start, row_end, dtype=np.float64)[:, None]
        latitude = (0.5 - (y + 0.5) / height) * np.pi
        cos_lat = np.cos(latitude)
        directions = np.empty((row_end - row_start, width, 3), dtype=np.float64)
        directions[..., 0] = cos_lat * sin_lon[None, :]
        directions[..., 1] = np.sin(latitude)
        directions[..., 2] = -cos_lat * cos_lon[None, :]
        major_axis = np.argmax(np.abs(directions), axis=2)
        sign_positive = np.take_along_axis(directions, major_axis[..., None], axis=2)[..., 0] >= 0.0
        face_index = major_axis * 2 + (~sign_positive).astype(np.int8)
        # axis index/sign order maps to +X,-X,+Y,-Y,+Z,-Z.
        chunk = np.empty((row_end - row_start, width, 3), dtype=np.uint8)
        for index, name in enumerate(FACE_ORDER):
            mask = face_index == index
            if not np.any(mask):
                continue
            forward, right, up = (np.asarray(axis, dtype=np.float64) for axis in FACE_AXES[name])
            selected = directions[mask]
            denominator = selected @ forward
            sx = (selected @ right) / denominator
            sy = (selected @ up) / denominator
            source_x = ((sx + 1.0) * 0.5 * size) - 0.5
            source_y = ((1.0 - sy) * 0.5 * size) - 0.5
            chunk[mask] = bilinear(faces[name], source_x, source_y)
        output[row_start:row_end] = chunk
    return Image.fromarray(output, mode="RGB")


def save_cross(faces: dict[str, np.ndarray], output: Path, tile_size: int = 512) -> None:
    positions = {
        "pos_y": (1, 0),
        "neg_x": (0, 1),
        "neg_z": (1, 1),
        "pos_x": (2, 1),
        "pos_z": (3, 1),
        "neg_y": (1, 2),
    }
    canvas = Image.new("RGB", (tile_size * 4, tile_size * 3), (10, 12, 18))
    draw = ImageDraw.Draw(canvas)
    for name, (column, row) in positions.items():
        tile = Image.fromarray(faces[name], mode="RGB").resize((tile_size, tile_size), Image.Resampling.LANCZOS)
        canvas.paste(tile, (column * tile_size, row * tile_size))
        label = f" {name}  F={FACE_AXES[name][0]} U={FACE_AXES[name][2]} "
        draw.rectangle((column * tile_size + 8, row * tile_size + 8, column * tile_size + 8 + len(label) * 7, row * tile_size + 28), fill=(0, 0, 0))
        draw.text((column * tile_size + 10, row * tile_size + 10), label, fill=(255, 255, 255))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, format="PNG", optimize=False, compress_level=9)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--faces", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--review-dir", type=Path, required=True)
    parser.add_argument("--width", type=int, default=4096)
    parser.add_argument("--height", type=int, default=2048)
    args = parser.parse_args()

    faces, face_size = load_faces(args.faces)
    panorama = stitch(faces, args.width, args.height)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    panorama.save(args.output, format="JPEG", **JPEG_OPTIONS)

    args.review_dir.mkdir(parents=True, exist_ok=True)
    cross_path = args.review_dir / "cubemap-cross.png"
    preview_path = args.review_dir / "panorama-preview.jpg"
    save_cross(faces, cross_path)
    panorama.resize((1024, 512), Image.Resampling.LANCZOS).save(
        preview_path, format="JPEG", **PREVIEW_JPEG_OPTIONS
    )

    capture_metadata = json.loads((args.faces / "capture.json").read_text(encoding="utf-8"))
    report = {
        "convention": {
            "equirect_center_forward": [0, 0, -1],
            "equirect_right_at_center": [1, 0, 0],
            "equirect_top": [0, 1, 0],
            "face_axes_forward_right_up": FACE_AXES,
        },
        "input": {
            "face_size": face_size,
            "inventory": [f"{name}.png" for name in FACE_ORDER] + ["capture.json"],
            "face_sha256": {name: sha256(args.faces / f"{name}.png") for name in FACE_ORDER},
            "face_bytes": {name: (args.faces / f"{name}.png").stat().st_size for name in FACE_ORDER},
            "capture_metadata_sha256": sha256(args.faces / "capture.json"),
            "capture_metadata": capture_metadata,
            "note": "Full-resolution GPU face PNGs are transient build products and are not retained in Git.",
        },
        "output": {
            "path": args.output.name,
            "dimensions": [args.width, args.height],
            "mode": "RGB",
            "jpeg": JPEG_OPTIONS,
            "sha256": sha256(args.output),
            "bytes": args.output.stat().st_size,
        },
        "review": {
            cross_path.name: {"sha256": sha256(cross_path), "bytes": cross_path.stat().st_size, "dimensions": [2048, 1536], "mode": "RGB"},
            preview_path.name: {"sha256": sha256(preview_path), "bytes": preview_path.stat().st_size, "dimensions": [1024, 512], "mode": "RGB", "jpeg": PREVIEW_JPEG_OPTIONS},
        },
        "versions": {"pillow": Image.__version__, "numpy": np.__version__},
    }
    (args.review_dir / "stitch-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
