# AeroBeat Environment - Community

`aerobeat-environment-community` is the curated default-environment source-of-truth repo
for community-distributed AeroBeat environments.

## Role

- Stores curated environment payloads and sidecar config data.
- Mirrors its folder structure cleanly to AWS S3 for authoring/distribution and backup.
- Uses `.testbed/` as the canonical direct-validation surface for image, video, GLB, and Gaussian splat previews.
- Keeps shipped workouts self-contained by treating this repo as an authoring/catalog source, not a runtime network dependency.

## `.testbed` structure

- `assets/images/`
- `assets/videos/`
- `assets/models/`
- `assets/splats/`
- `scenes/`
- `scripts/`

Within each media bucket, every shipped asset now lives in its own lowercase folder named after the asset stem. Whitespace is normalized to `-`, and Gaussian splat folders drop the `.compressed` portion while the actual `.compressed.ply` filename stays truthful.

The GLB and splat scenes expose:

- a file picker rooted to the matching asset folder
- scene-level live transform controls for the loaded object: `WASD` move on X/Z, `Q` up, `E` down, `Shift` boosts movement, and `Up`/`Down` adjust uniform scale with the same boost modifier
- a right-click free-look camera (`mouse look`, `Esc` to release mouse) that stays out of the way until explicitly captured
- a left-panel rotation gizmo below the transform inspector that supports click-drag local-axis rotation like Godot's inspector
- left-panel YAML sidecar save/load beside the selected asset
- auto-load of sibling `<asset-stem>.config.yaml` files when an asset is selected
- shared transform contract fields: `transform.position`, `transform.rotation_degrees`, `transform.scale`

The splat scene also exposes:

- a left-side debug/info panel
- arbitrary local filesystem loading outside `res://`
- explicit AeroBeat format guidance: `.compressed.ply` is the official recommended splat format, while `.ply`, `.splat`, and `.sog` remain compatibility-supported through GDGS
- renderer-path support truth from the wrapper so the scene can disable unsupported renderer paths instead of pretending splats should visibly render everywhere
- current validation warning text that keeps Forward+ / Vulkan render output in the experimental bucket until the GDGS compositor path is proven stable on the active backend/hardware

The image and video scenes expose the shared `media.fit_mode` contract, default the live value to `cover`, and include a `Save Config` action beside the live fit-mode control. They currently support these preview modes:

- `stretch`
- `contain`
- `cover`

For every media type in `.testbed/`, the shared sidecar seam now resolves the selected asset's sibling `<asset-stem>.config.yaml` file and normalizes payloads to one of:

- image / video: `media.fit_mode`
- GLB / splat: `transform.position`, `transform.rotation_degrees`, `transform.scale`

Video validation is intentionally **truth-locked to canonical `.ogv` (Theora)** input.
The current testbed does not claim `.webm` or `.mp4` playback support.
Use `.testbed/assets/videos/calm_blue_sea_1/calm_blue_sea_1.ogv` as the baseline sample clip.
The proving scene now depends on the stable `AeroVideoPlayerManager` facade from `aerobeat-tool-video-player`, with the real `AeroGodotVideoBackend` injected underneath for truthful backend-path validation.

Renderer-path truth note:

- Renderer paths without a `RenderingDevice` backend are currently treated as unsupported for visible splat rendering in the testbed, so the load buttons stay disabled there instead of yielding a blank/background-only result.
- Renderer paths with a `RenderingDevice` backend remain visible-render **experimental** in the current slice. The current validation repros have shown Forward+ / Vulkan can still crash in the GDGS compositor after a successful load, so the testbed now warns instead of implying stable support.

## GodotEnv development flow

```bash
cd .testbed
godotenv addons install
godot --headless --path . --import
godot --headless --path . --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## Clean restore flow for GodotEnv-managed addons

When Godot imports mark files inside `.testbed/addons/` or `.testbed/.addons/` as dirty,
rerun the canonical delete-first restore helper from the repo root:

```bash
./scripts/restore-testbed-addons.sh
```

That helper safely clears the generated GodotEnv install targets first:

- `.testbed/addons/*` except `.editorconfig`
- `.testbed/.addons/`
- `.testbed/.godot/`

Then it reruns `godotenv addons install` so the testbed comes back in a clean state
without relying on manual deletion tribal knowledge.

## Luminious ice cave photosphere source

The AeroBeat-controlled runtime photosphere source and its sidecar/manifest live in
`.testbed/assets/images/luminious-ice-cave-photosphere/`. Reusable capture and stitch
utilities live in `.testbed/tools/photosphere/`; review-only downscales and the exact
intermediate/output hash record live in
`.plans/review/2026-09-03-luminious-ice-cave-photosphere/`.

Capture requires a visible Vulkan Forward+ session because headless GDGS capture does
not reliably complete a draw. The scene loads the selected splat once, captures six
square 90-degree faces without UI, and quits after the sixth face:

```bash
cd .testbed
godot --path . --resolution 1920x1920 res://tools/photosphere/capture_cubemap.tscn -- \
  --asset=res://assets/splats/luminious-ice-cave/luminious-ice-cave.compressed.ply \
  --out-dir=/tmp/aerobeat-luminious-cubemap --face-size=1920 --timeout-seconds=360
```

Stitch and validate from the repository root with Python 3.14.2, Pillow 12.1.0,
and NumPy 2.4.2:

```bash
python3 .testbed/tools/photosphere/cube_to_equirect.py \
  --faces /tmp/aerobeat-luminious-cubemap \
  --output .testbed/assets/images/luminious-ice-cave-photosphere/luminious-ice-cave-photosphere.jpg \
  --review-dir .plans/review/2026-09-03-luminious-ice-cave-photosphere \
  --width 4096 --height 2048
python3 .testbed/tools/photosphere/validate_photosphere.py --repo-root .
```

The six full-resolution face PNGs are transient and intentionally not committed. Their
hashes and sizes are retained in the review stitch report, but a GPU recapture is not
promised byte-identical across GDGS/device/driver changes; the offline stitch is
deterministic only for fixed face bytes and the pinned tool versions.

## Owned photosphere catalog

`.testbed/assets/images/photosphere-catalog.json` pins exactly eight generated-and-
purchased splat derivatives. Each `<id>-photosphere/` folder contains a `4096 × 2048`
RGB JPEG, a bounded `aerobeat/environment_asset_config` v1 JSON identity/transform contract,
and a derivative manifest. The pre-existing luminous JPEG, YAML, manifest, and review
bytes remain protected; its JSON config is an additive successor for catalog parity.

The seven additional captures use the same visible Vulkan Forward+ scene, fixed
`[0, 0, 4]` viewpoint, center-forward `-Z`, and `1920`-pixel faces. For each ID, run:

```bash
cd .testbed
godot --path . --resolution 1920x1920 res://tools/photosphere/capture_cubemap.tscn -- \
  --asset=res://assets/splats/<id>/<id>.compressed.ply \
  --out-dir=/tmp/aerobeat-<id>-cubemap --face-size=1920 --timeout-seconds=360
cd ..
python3 .testbed/tools/photosphere/cube_to_equirect.py \
  --faces /tmp/aerobeat-<id>-cubemap \
  --output .testbed/assets/images/<id>-photosphere/<id>-photosphere.jpg \
  --review-dir .plans/review/2026-09-03-owned-photosphere-catalog/<id> \
  --width 4096 --height 2048
```

After all seven stitches, `python3 .testbed/tools/photosphere/finalize_catalog.py`
regenerates additive JSON configs, seven manifests, the exact eight-entry catalog,
continuity metrics, copied bounded luminous review evidence, and the labeled panorama
contact sheet. Validate everything with:

```bash
python3 .testbed/tools/photosphere/validate_photosphere.py --repo-root .
```

Coverage weaknesses from the common viewpoint are retained and labeled in the catalog;
they are not hidden by moving the camera. No runtime splat integration is included.
