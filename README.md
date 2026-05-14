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

The image and video scenes expose web-style fit modes as closely as practical:

- `contain`
- `cover`

## GodotEnv development flow

```bash
cd .testbed
godotenv addons install
godot --headless --path . --import
godot --headless --path . --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
