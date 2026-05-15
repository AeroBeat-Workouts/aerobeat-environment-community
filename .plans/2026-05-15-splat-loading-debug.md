# AeroBeat Environment Community — Splat Loading Debug

**Date:** 2026-05-15  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Investigate why newly added test splats in `.testbed/assets/splats/` cause a long editor/runtime stall on load and then appear black / not visibly rendered even though the UI reports them as loaded.

---

## Overview

Derrick added a batch of splats to `aerobeat-environment-community` for testing and observed two likely-related symptoms in the testbed: selecting a splat from the file picker hangs the engine for a while, and once control returns the left panel says the splat loaded but the scene appears black where the splat should be. There was also uncertainty about whether dynamically created nodes should show up in the hierarchy and whether expected logs were missing from the console.

New context tightens the likely diagnosis path:
- the repo must be synced to the latest before reproduction so the new splats are available locally
- `Alpine River Valley.compressed.ply` successfully loads in `3dgsviewer.com`, including background-threaded loading, which strongly suggests the asset itself is valid and shifts suspicion toward our implementation/runtime path rather than the file

This debug pass should therefore begin with a latest-sync pull, then reproduce the issue inside the repo’s current testbed, identifying whether the stall is import/decode/build/render related and checking whether the loaded node is actually instantiated, transformed, and assigned a valid Gaussian resource. The investigation should pay special attention to likely implementation gaps versus the external viewer behavior, including synchronous main-thread loading, compositor/render integration, camera framing, and any wrapper/vendor misuse. Reproduction already isolated two separate lanes: a compositor-attachment bug in the AeroBeat wrapper layer and a deeper downstream GDGS/Godot renderer-path problem after the wrapper fix. The current execution order is now:
- send a researcher to inspect the original upstream GDGS GitHub repo for existing issues/notes around compositor crashes, device loss, black renders, and background-thread loading so we do not retread solved or known-broken paths
- in parallel, follow the normal coder → QA → auditor loop for the background-thread loading work in `aerobeat-tool-gaussian-splat`, since that slice is likely easier and lower-risk than the deeper renderer-path investigation

The work should stay narrow and evidence-driven before any broader refactor.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Current splat testbed scene logic | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/splat_test_scene.gd` |
| `REF-02` | Current environment-community README / testbed expectations | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/README.md` |
| `REF-03` | AeroBeat Gaussian splat wrapper manager | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/aerobeat-tool-gaussian-splat/src/AeroGaussianSplatManager.gd` |
| `REF-04` | GDGS import/decoder surface in the testbed vendor payload | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/gdgs/` |

---

## Tasks

### Task 1: Reproduce the stall + black render and capture concrete evidence

**Bead ID:** `aerobeat-environment-community-56q`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-01`, `REF-03`, `REF-04`  
**Prompt:** Reproduce the splat-loading issue in `aerobeat-environment-community` using the newly added assets in `.testbed/assets/splats/`. Claim the bead on start, determine whether the stall happens during import/decode/resource build/render, inspect whether the runtime-created splat node exists and has a valid resource, capture relevant console evidence, and report the most likely failure mode(s). If a narrow fix is obvious and safe, implement it with validation; otherwise stop with a precise diagnosis and recommended next slice.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.plans/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/`

**Files Created/Deleted/Modified:**
- Investigation-dependent; likely `.testbed/scripts/*`, tests, or vendor-wrapper instrumentation if a narrow fix is needed.

**Status:** ✅ Complete

**Results:** Completed as a diagnosis pass. Reproduction established that the long stall is caused by synchronous main-thread load/decode/build behavior, while the black render is most likely caused by `AeroGaussianSplatManager.configure_world_environment()` failing to actually persist the compositor effect onto `world_environment.compositor.compositor_effects`. The runtime-created splat node exists, has valid Gaussian data, and should be visible from the current framing, but with the compositor effect count stuck at `0` nothing is composited to screen. Temporary diagnostic patching confirmed that reassigning the compositor effects array makes the compositor callback start firing and produces render textures. The next slice is to land that fix in the owning addon repo and retest against the newly synced MultiTabber Worlds assets, including `Alpine River Valley.compressed.ply`.

---

### Task 1B: Land the compositor attachment fix in the owning addon repo and retest in environment-community

**Bead ID:** `aerobeat-tool-gaussian-splat-6jy`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-03`, `REF-04`  
**Prompt:** Patch the owning addon repo so `AeroGaussianSplatManager.configure_world_environment()` actually persists the compositor effect, validate the addon repo, restore/reinstall the addon into `aerobeat-environment-community`, and retest against the real MultiTabber Worlds `.compressed.ply` assets—especially `Alpine River Valley.compressed.ply`. Claim the bead on start, keep the fix narrow, and report whether the black render is resolved and how much synchronous load time remains.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat/src/AeroGaussianSplatManager.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat/.testbed/tests/test_AeroToolManager.gd`

**Status:** ⚠️ Partial

**Results:** The compositor attachment bug was fixed in the owning addon repo and pushed as commit `0047981` (`Fix compositor effect persistence`). The addon repo validation passed and the restored addon in environment-community now reports the compositor effect count correctly and reaches the GDGS compositor callback for the real `Alpine River Valley.compressed.ply` asset. However, the downstream retest still exposes a deeper GDGS/Godot renderer-path issue: Vulkan paths hit device-loss / compositor-resource errors and GL Compatibility remains background-only. The visible black-render symptom is therefore not fully resolved yet at the end-user level, even though this wrapper-layer bug is fixed. The large-file synchronous stall also remains at roughly `22.3s–22.8s` for `Alpine River Valley.compressed.ply`.

---

### Task 2: QA the reproduced bug / fix path

**Bead ID:** `aerobeat-environment-community-qo4`  
**SubAgent:** `primary` (for `qa` workflow role)  
**Role:** `qa`  
**References:** `REF-01`, `REF-03`, `REF-04`  
**Prompt:** Verify the reproduction findings and, if a fix lands, confirm the selected splats load without the prior black/no-visible-result failure. Claim the bead on start, rerun the highest-fidelity repo-local validation available, and report any remaining gaps clearly.

**Folders Created/Deleted/Modified:**
- Validation only unless QA finds required fixes.

**Files Created/Deleted/Modified:**
- Validation only unless QA finds required fixes.

**Status:** ⏸️ Deferred

**Results:** Deferred for now because the compositor-attachment fix exposed a deeper GDGS/Godot renderer-path problem that still blocks a truthful end-to-end visual-pass result for the black-render issue. This QA bead should be resumed later for the renderer-path follow-up, not for the background-thread loading slice.

---

### Task 3: Independent audit of the diagnosis/fix

**Bead ID:** `aerobeat-environment-community-aat`  
**SubAgent:** `primary` (for `auditor` workflow role)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-03`, `REF-04`  
**Prompt:** Independently audit the reproduction evidence and any landed fix. Claim the bead on start only after coder and QA evidence are available. Confirm the root-cause explanation is truthful, the patch stayed narrow, and validation supports the conclusion.

**Folders Created/Deleted/Modified:**
- Validation only unless audit finds required fixes.

**Files Created/Deleted/Modified:**
- Validation only unless audit finds required fixes.

**Status:** ⏸️ Deferred

**Results:** Deferred with Task 2 for the later renderer-path follow-up. The compositor-layer fix was real and landed, but this bead should wait until the deeper GDGS/Godot renderer issue has a proper coder → QA handoff to audit.

---

### Task 4: Research upstream GDGS issues so we do not retread old paths

**Bead ID:** `aerobeat-environment-community-3ld`  
**SubAgent:** `primary` (for `research` workflow role)  
**Role:** `research`  
**References:** `REF-04`  
**Prompt:** Inspect the original upstream GDGS GitHub repo—not our vendor clone—for issues, discussions, commits, or notes related to compositor/device-loss crashes, Vulkan texture-usage or uniform-set failures, black render outcomes, and background-threaded loading. Claim the bead on start, use the GitHub CLI skill and web/docs as needed, and report concrete upstream references so we do not retread old paths.

**Folders Created/Deleted/Modified:**
- Research only.

**Files Created/Deleted/Modified:**
- Research only.

**Status:** ✅ Complete

**Results:** Completed. Upstream research against `ReconWorldLab/godot-gaussian-splatting` found meaningful prior art for render-path fragility (Mac blank renders, compositor/Vulkan projection-sign fixes, subgroup-size/compute hardening, VRAM pressure issues, and view/projection-path differences), but no clear upstream prior art for background-threaded or asynchronous loading. This supports treating the remaining runtime display bug as a genuine GDGS/render-path investigation while keeping the async loader work as an AeroBeat-owned slice.

---

### Task 5: Implement background-threaded splat loading in the owning addon repo

**Bead ID:** `aerobeat-tool-gaussian-splat-8my`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-03`, `REF-04`  
**Prompt:** Modify `aerobeat-tool-gaussian-splat` so large splat loads do not block the main thread. Claim the bead on start, keep the change narrow, validate in the addon repo, restore/reinstall into environment-community, and retest with MultiTabber Worlds assets. Report the before/after stall behavior and any API/UX implications.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/`

**Files Created/Deleted/Modified:**
- `src/AeroGaussianSplatManager.gd`
- `src/AeroToolManager.gd`
- `src/AeroGaussianSplatBackgroundLoader.gd`
- `src/AeroGaussianSplatBackgroundReadWorker.gd`
- `.testbed/tests/test_AeroToolManager.gd`
- `README.md`

**Status:** ✅ Complete

**Results:** Completed. The addon now exposes a real non-blocking load path via `begin_load_gaussian_resource_from_path(...)` / `begin_create_splat_node_from_path(...)`, plus background load signals/state. The implementation uses a background thread for PLY/container read and cooperative frame-yielded decode/build on the main thread. On `Alpine River Valley.compressed.ply`, the old sync path froze the main thread for ~21.6s, while the new async path took ~27.5s total but avoided the giant freeze and kept frame updates advancing.

---

### Task 6: QA background-threaded splat loading

**Bead ID:** `aerobeat-tool-gaussian-splat-jhx`  
**SubAgent:** `primary` (for `qa` workflow role)  
**Role:** `qa`  
**References:** `REF-03`, `REF-04`  
**Prompt:** Verify the background-threaded splat loading implementation and downstream retest in environment-community. Claim the bead on start, run the highest-fidelity repo-local validation available, and confirm the main-thread stall improvement plus any remaining caveats.

**Folders Created/Deleted/Modified:**
- Validation only unless QA finds required fixes.

**Files Created/Deleted/Modified:**
- Validation only unless QA finds required fixes.

**Status:** ✅ Complete

**Results:** Completed. QA confirmed that the async path behaves truthfully, synchronous APIs still work, and callers can avoid the giant freeze by using the new async entrypoints. On `Alpine River Valley.compressed.ply`, the sync path still froze for ~21.6s, while the async path returned immediately, completed successfully later, and reduced the maximum observed frame gap to ~170ms instead of a single multi-second stall.

---

### Task 7: Independent audit of background-threaded splat loading

**Bead ID:** `aerobeat-tool-gaussian-splat-gti`  
**SubAgent:** `primary` (for `auditor` workflow role)  
**Role:** `auditor`  
**References:** `REF-03`, `REF-04`  
**Prompt:** Independently audit the background-threaded splat loading implementation, QA evidence, and downstream retest. Claim the bead on start only after coder and QA evidence are available. Confirm the patch stayed narrow and that validation supports the conclusion.

**Folders Created/Deleted/Modified:**
- Validation only unless audit finds required fixes.

**Files Created/Deleted/Modified:**
- Validation only unless audit finds required fixes.

**Status:** ✅ Complete

**Results:** Completed. Audit confirmed the background-loading patch stayed reasonably narrow, the async API honestly avoids the hard freeze rather than faking completion, sync APIs and compatibility paths remain intact, and docs now truthfully state that async loading currently supports `.ply` / `.compressed.ply` while `.splat` / `.sog` remain synchronous. The deeper GDGS/Godot renderer-path bug remains correctly scoped as a separate issue.

---

### Task 8: Add async progress/callback support and wire the test scene UI

**Bead ID:** `aerobeat-tool-gaussian-splat-bkl`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-01`, `REF-03`, `REF-04`  
**Prompt:** Extend the async splat-loading path with truthful progress/state reporting (percentage + phase/status text) suitable for user-facing UI. Then wire the environment-community test scene to demonstrate the async path with a visible loading bar and loading state text. Keep the change narrow, validate in the addon repo, restore/reinstall into environment-community, and retest against MultiTabber Worlds assets.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/`

**Files Created/Deleted/Modified:**
- `src/AeroGaussianSplatManager.gd`
- `src/AeroToolManager.gd`
- `.testbed/tests/test_AeroToolManager.gd`
- `README.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/splat_test_scene.gd`

**Status:** ✅ Complete

**Results:** Completed. The async path now exposes truthful status/progress reporting through `background_load_started`, `background_load_progressed`, `background_load_finished`, and `get_background_load_status()`. Status payloads include `progress`, `phase`, `status`, and `pending`, with progress staying below `1.0` until the resource/node is actually ready. The environment-community test scene now uses the async path for supported formats, shows a loading bar and state text, and falls back to the synchronous compatibility path for `.splat` / `.sog`.

---

### Task 9: QA async progress/callback support and test-scene UI

**Bead ID:** `aerobeat-tool-gaussian-splat-wfh`  
**SubAgent:** `primary` (for `qa` workflow role)  
**Role:** `qa`  
**References:** `REF-01`, `REF-03`, `REF-04`  
**Prompt:** Verify the new async progress/state reporting and the environment-community loading bar/state UI. Claim the bead on start, run the highest-fidelity repo-local validation available, and confirm the UI stays truthful about progress/load readiness.

**Folders Created/Deleted/Modified:**
- Validation only unless QA finds required fixes.

**Files Created/Deleted/Modified:**
- Validation only unless QA finds required fixes.

**Status:** ✅ Complete

**Results:** Superseded by the corrected QA pass on bead `aerobeat-tool-gaussian-splat-i3t`. The first QA attempt correctly failed the slice because progress could still hit `1.0` while pending and the environment test scene was not yet running from a clean restored remote addon version. That failure directly informed the follow-up fix in bead `aerobeat-tool-gaussian-splat-2nq`.

---

### Task 10: Independent audit of async progress/callback support and test-scene UI

**Bead ID:** `aerobeat-tool-gaussian-splat-fuq`  
**SubAgent:** `primary` (for `auditor` workflow role)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-03`, `REF-04`  
**Prompt:** Independently audit the async progress/state reporting implementation and the environment-community loading UI after coder and QA evidence are available. Confirm the patch stayed narrow and the UI/progress semantics are truthful.

**Folders Created/Deleted/Modified:**
- Validation only unless audit finds required fixes.

**Files Created/Deleted/Modified:**
- Validation only unless audit finds required fixes.

**Status:** ✅ Complete

**Results:** Superseded by the corrected audit pass on bead `aerobeat-tool-gaussian-splat-k3v`. The initial audit attempt correctly blocked closure because progress semantics were not yet truthful and the environment scene wiring had not yet been validated from a normal restored remote addon copy. Those blockers were fixed in the follow-up slice.

---

### Queued next slice after Task 10 completes

Derrick confirmed the next priorities once the current progress/UI loop finishes:

1. **Plan the runtime display bug separately** and continue that investigation in parallel with the now-landed async loader/progress UI work.
   - Do **not** build the pure GDGS happy-path control scene yet.
   - Keep that as a fallback diagnostic option only if the normal runtime-display debugging stops converging.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** We completed the splat loading/stall slice. The main-thread freeze was diagnosed and then mitigated through a real async loader path in `aerobeat-tool-gaussian-splat`, truthful progress/state reporting was added, and the environment-community test scene was wired to show a loading bar/state while using the async path for `.ply` / `.compressed.ply` with sync fallback for `.splat` / `.sog`. The wrapper-layer compositor attachment bug was also fixed and pushed separately, but the deeper runtime display/render-path issue remains open.

**Reference Check:** `REF-01` now reflects the async test-scene UX and compatibility fallback behavior. `REF-03` yielded both the compositor attachment fix and the async/progress loader work. `REF-04` remains the key source surface for the still-open GDGS/Godot renderer-path bug, while the upstream research already confirmed that this area has prior render-path fragility but no obvious async-loading prior art.

**Commits:**
- `0047981` - `Fix compositor effect persistence`
- `18f4824` - `Fix async splat progress semantics`
- `Pending env-community wrap-up commit for async test-scene wiring + active plan update`

**Lessons Learned:** A real wrapper-layer bug can mask deeper vendor/render-path issues; once the first bug is fixed, split the newly exposed problems into separate tracks instead of overloading a single debug bead. Also, for restored addon workflows, validate against the real pushed repo version rather than local overlay hacks so QA/audit evidence matches the runnable repo truth.

**Next Step:** Start the remaining runtime display bug as its own follow-up slice, using the now-landed async loader/progress UI as the stable baseline. Keep the pure GDGS happy-path control scene in reserve only if the normal renderer-path debugging stops converging.

---

*Completed on 2026-05-15*
