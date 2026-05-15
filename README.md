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

The GLB and splat scenes expose:

- a file picker rooted to the matching asset folder
- free-fly camera controls (`WASD`, arrows, mouse look, `Esc` to release mouse)
- left-panel JSON config save/load beside the selected asset
- shared baseline config fields: `center`, `scale`, `rotation`

The splat scene also exposes:

- a left-side debug/info panel
- arbitrary local filesystem loading outside `res://`
- explicit AeroBeat format guidance: `.compressed.ply` is the official recommended splat format, while `.ply`, `.splat`, and `.sog` remain compatibility-supported through GDGS

The image and video scenes expose web-style fit modes as closely as practical:

- `contain`
- `cover`

Video validation is intentionally **truth-locked to canonical `.ogv` (Theora)** input.
The current testbed does not claim `.webm` or `.mp4` playback support.
Use `.testbed/assets/videos/calm_blue_sea_1.ogv` as the baseline sample clip.

## GodotEnv development flow

```bash
./scripts/restore-testbed-addons.sh
cd .testbed
godot --headless --path . --import
godot --headless --path . --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## Clean restore flow for GodotEnv-managed addons

When Godot imports mark files inside `.testbed/addons/` or `.testbed/.addons/` as dirty,
rerun the canonical delete-first restore flow from the repo root:

```bash
./scripts/restore-testbed-addons.sh
```

That script safely clears the generated GodotEnv install targets first:

- `.testbed/addons/*` except `.editorconfig`
- `.testbed/.addons/`

Then it reruns `godotenv addons install` so the testbed comes back in a clean state
without relying on manual deletion tribal knowledge.
