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
- free-fly camera controls (`WASD`, arrows, mouse look, `Esc` to release mouse)
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
godot --headless --path . --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
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
