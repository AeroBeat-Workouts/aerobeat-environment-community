# AeroBeat Environment Community

**Date:** 2026-06-01  
**Status:** Complete  
**Last Updated:** 2026-06-01 11:59 EDT  
**Blocked Reason:** None  
**Agent:** `cookie`

---

## Goal

Fix the hidden `.testbed` GLB proving scene so `AeroGLTFLoader` successfully resolves its vendor runtime backend instead of reporting `Vendor GLTF runtime loader is unavailable.`, and add the requested GLB/splat manipulation controls for live movement, scale stepping, and rotation gizmo support without breaking the tool-facade architecture.

---

## Overview

The screenshot points at a backend-discovery failure, not an asset-path failure. The GLB test scene is correctly entering through `AeroGLTFLoader`, but the loader’s backend resolution paths do not match the actual installed layout of `aerobeat-vendor-godot-gltf` inside this testbed.

Derrick also clarified an architectural rule that applies here: testbed scenes should use the Aero-wrapped tool singleton/facade surfaces only, and should not directly interact with vendor loader/backend classes. That means the fix should preserve or improve the scene’s use of `AeroGLTFLoader` rather than teaching the scene about vendor runtime files directly.

Current installed vendor layout is flat at `res://addons/aerobeat-vendor-godot-gltf/` with files such as `aero_godot_gltf_runtime_loader.gd` and `aero_godot_gltf_contract.gd` at the addon root. But the tool loader still looks for backend/runtime scripts under `.../src/...` and `.../loaders/...` paths that do not exist in this testbed install. That mismatch explains the exact UI message shown in the screenshot.

You also added a second slice to this follow-up: the GLB and splat proving scenes should become much faster to tune interactively. The requested controls are scene-level manipulation UX, not vendor-level loader behavior: keyboard movement for the loaded object (`WASD`, `Q`, `E`, with `Shift` for faster motion), `Up`/`Down` arrow scale stepping with `Shift` for faster steps, and a rotation gizmo in the left inspector panel that behaves like Godot’s rotation control by rotating the object around its parent transform. Those controls should sit on top of the existing tool-facing load path and sidecar config workflow rather than bypassing it.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | GLB test scene entering through `AeroGLTFLoader` | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/glb_test_scene.gd` |
| `REF-02` | Tool GLTF loader backend resolution paths | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/aerobeat-tool-gltf-loader/src/AeroGLTFLoader.gd` |
| `REF-03` | Vendor backend adapter runtime-loader resolution paths | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/aerobeat-tool-gltf-loader/src/AeroVendorGodotGLTFBackendAdapter.gd` |
| `REF-04` | Actual installed vendor GLTF addon layout | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/aerobeat-vendor-godot-gltf/` |
| `REF-05` | Screenshot showing `Vendor GLTF runtime loader is unavailable.` | `/home/derrick/.openclaw/workspace/.temp/nerve-uploads/2026/06/01/image-ddf954a6.png` |
| `REF-06` | Derrick requirement that testbed scenes use Aero-wrapped tool singleton/facade loaders, not vendor equivalents directly | Current session request |
| `REF-07` | Derrick requirement for GLB/splat manipulation controls: keyboard movement, scale stepping, and rotation gizmo | Current session request |

---

## Tasks

### Task 1: Fix GLTF backend/runtime path resolution against the real vendor addon layout

**Bead ID:** `aerobeat-environment-community-cib`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Update the GLTF tool-facing loader seam so the hidden `.testbed` resolves the installed `aerobeat-vendor-godot-gltf` backend/runtime scripts from their real addon-root paths instead of nonexistent `src/` or `loaders/` subpaths. Claim the bead on start. Preserve the architectural rule that testbed scenes must use only Aero-wrapped tool singleton/facade surfaces and must not directly interact with vendor loader/backend classes. Make the minimal durable fix in the owning source repo(s), refresh generated addon state if needed, then verify the GLB proving scene no longer shows `Vendor GLTF runtime loader is unavailable.` and that relevant repo-local tests still pass. Commit and push by default unless blocked.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gltf-loader/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-godot-gltf/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/aerobeat-tool-gltf-loader/src/AeroGLTFLoader.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/aerobeat-tool-gltf-loader/src/AeroVendorGodotGLTFBackendAdapter.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/aerobeat-vendor-godot-gltf/**`

**Status:** ✅ Complete

**Results:** The backend path-resolution seam was fixed in the owning addon sources rather than by teaching the testbed scene about vendor classes directly. `aerobeat-tool-gltf-loader` now probes flattened installed-path locations for the vendor runtime loader, and `aerobeat-vendor-godot-gltf` now probes flattened installed-path locations for its contract script. Narrow regression coverage was added in those addon repos so the flattened installed paths remain protected. After refreshing the consumer `.testbed` addon install state, the root hidden testbed moved past `Vendor GLTF runtime loader is unavailable.` and successfully resolved the runtime/contract seam. Validation proved the failure mode changed from backend-unavailable to actual GLTF file loading behavior. Commits: `7d83a18` and `7df5df1`.

---

### Task 2: Add GLB/splat live manipulation controls on top of the existing tool-facing scenes

**Bead ID:** `aerobeat-environment-community-6z1`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-06`, `REF-07`  
**Prompt:** Add the requested live manipulation controls to the hidden `.testbed` GLB and splat proving scenes without breaking the tool-facade architecture. Claim the bead on start. Keep loading routed through `AeroGLTFLoader` and `AeroGaussianSplatManager`, then add scene-level controls for: (a) moving the loaded GLB/splat with `WASD`, `Q`, `E`, with `Shift` for faster speed; (b) scale stepping with `Up` / `Down`, with `Shift` for faster speed; and (c) a left-panel rotation gizmo that behaves like Godot’s rotation control by allowing click-drag rotation around the object’s parent transform. Ensure the live controls update the visible transform state and remain compatible with the existing `.config.yaml` save/load flow. Add or update regression coverage and verify the scenes still behave truthfully. Commit and push by default unless blocked.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/tests/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/glb_test_scene.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/splat_test_scene.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/rotation_gizmo.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/free_look_camera.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/tests/test_glb_splat_transform_ui.gd`

**Status:** ✅ Complete

**Results:** The full manipulation slice landed on retry. Both GLB and splat scenes now support object movement with `WASD`, `Q`, `E`, `Shift`-accelerated movement, `Up` / `Down` scale stepping with `Shift` acceleration, and a left-panel click-drag rotation gizmo layered on top of the existing tool-facing load paths. The scenes keep using only `AeroGLTFLoader` and `AeroGaussianSplatManager`, update the visible transform UI live as controls are used, and stay compatible with `.config.yaml` save/load for position, rotation, and scale. `free_look_camera.gd` was intentionally adjusted so camera movement requires mouse capture, preventing camera hotkeys from stealing the same keys needed for object manipulation. Regression coverage was expanded, the full testbed GUT suite passed 33/33 tests, and push succeeded. Commits: `bebf995` and `2b212c8`.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Fixed the GLTF tool-facade backend discovery seam so the hidden `.testbed` can resolve the installed `aerobeat-vendor-godot-gltf` runtime/contract layout without teaching the scene about vendor classes directly, then added the requested GLB/splat live manipulation controls on top of the existing tool-facing scenes. Both GLB and splat scenes now support `WASD`/`Q`/`E` object movement, `Shift` acceleration, `Up`/`Down` scale stepping with `Shift` acceleration, and a left-panel click-drag rotation gizmo, while keeping the visible transform UI and `.config.yaml` sidecar flow in sync.

**Reference Check:** The backend fix addressed the exact code/layout mismatch between `REF-02` / `REF-03` and `REF-04`, and the manipulation slice satisfied `REF-07` while preserving the facade-only rule in `REF-06`.

**Commits:**
- `7d83a18` - Probe flattened vendor runtime loader path
- `7df5df1` - Probe flattened installed contract path
- `bebf995` - Add live GLB and splat transform controls
- `2b212c8` - Fix rotation gizmo wrap regression expectation

**Lessons Learned:** The scene architecture was already correct; the real seam was backend path drift inside the tool/vendor handshake. Once that was repaired, the interaction UX could be layered cleanly at the scene level without breaking the facade boundary.

---

*Completed on 2026-06-01*