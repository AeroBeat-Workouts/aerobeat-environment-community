# AeroBeat Cross-Repo — Splat Format Policy Alignment

**Date:** 2026-05-15  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Align the AeroBeat environment, docs, and content-core repos with the new Gaussian splat policy: `.compressed.ply` is the official recommended AeroBeat splat format, while `.ply`, `.splat`, and `.sog` remain supported compatibility formats through GDGS.

---

## Overview

Derrick is adding a batch of `.compressed.ply` assets into `aerobeat-environment-community` for testing. Before and alongside that asset pass, the user-facing and contributor-facing guidance across the owning repos should clearly state which splat format is officially recommended so contributors and future agents do not treat all supported formats as equal.

This is now a cross-repo alignment pass. The first slice is `aerobeat-environment-community`, where the testbed and repo README need to present `.compressed.ply` as the official recommendation without implying that the other GDGS-supported formats were removed. The second slice is `aerobeat-docs`, where the broader product/documentation truth should reflect the same recommendation and support matrix. The third slice is `aerobeat-content-core`, where any content contract or asset guidance touching Gaussian splats should match the same policy. The work should remain narrow: clarify recommendation vs compatibility, avoid implying `.spz` support, and avoid changing actual loader/runtime behavior.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Current environment-community repo README and testbed behavior | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/README.md` |
| `REF-02` | Current splat testbed picker/UI wording | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/splat_test_scene.gd` |
| `REF-03` | Current GDGS/AeroBeat wrapper supported format surface | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/aerobeat-tool-gaussian-splat/README.md` |
| `REF-04` | AeroBeat docs repo current splat/environment documentation | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/` |
| `REF-05` | AeroBeat content-core repo current asset/content guidance | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-content-core/` |

---

## Tasks

### Task 1: Lock environment-community wording to the new splat recommendation

**Bead ID:** `aerobeat-environment-community-ujv`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`  
**Prompt:** Update `aerobeat-environment-community` so it explicitly recommends `.compressed.ply` as the official AeroBeat splat format while preserving compatibility notes for `.ply`, `.splat`, and `.sog`. Claim the bead on start, keep the change narrow, update README/testbed wording/tests as needed, run repo-local validation, and close the bead with the validation summary.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.plans/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/README.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/scripts/splat_test_scene.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/tests/test_splat_format_policy.gd`

**Status:** ✅ Complete

**Results:** Completed. Repo wording now explicitly recommends `.compressed.ply` as the official AeroBeat splat format while preserving `.ply`, `.splat`, and `.sog` as GDGS compatibility-supported formats. The testbed UI/file filters were updated to reinforce that recommendation, and `test_splat_format_policy.gd` was added to lock the wording/support matrix and ensure `.spz` is not implied. Repo-local validation passed via restore, headless import, and GUT (`12/12` tests, `48` asserts).

---

### Task 2: Align the docs repo to the same recommendation/support matrix

**Bead ID:** `aerobeat-docs-lg8z`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-04`, `REF-03`  
**Prompt:** Inspect `aerobeat-docs` for Gaussian splat, environment asset, and content format documentation. Update the relevant docs so `.compressed.ply` is the official recommended AeroBeat splat format while `.ply`, `.splat`, and `.sog` remain compatibility formats via GDGS. Claim the bead on start, keep the patch narrowly scoped to the new policy, run relevant repo-local validation if available, and close the bead with the file list and validation summary.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/.plans/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/architecture/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/guides/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/architecture/workout-creation-tools-import-format-matrix.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/architecture/content-model.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/architecture/workout-package-storage-and-discovery.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/guides/environment_creation.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/guides/demo_workout_package.md`

**Status:** ✅ Complete

**Results:** Completed. The docs repo now consistently presents `.compressed.ply` as the official recommended AeroBeat splat payload while documenting `.ply`, `.splat`, and `.sog` as GDGS compatibility-supported formats and avoiding any `.spz` implication. Validation passed with `python3 scripts/create_placeholders.py` and `./venv/bin/mkdocs build --strict`.

---

### Task 3: Align content-core guidance to the same recommendation/support matrix

**Bead ID:** `oc-xsa`  
**SubAgent:** `primary` (for `coder` workflow role)  
**Role:** `coder`  
**References:** `REF-05`, `REF-03`  
**Prompt:** Inspect `aerobeat-content-core` for any Gaussian splat, environment asset, or content guidance that should reflect the new AeroBeat recommendation. Update the relevant docs/contracts so `.compressed.ply` is recommended and `.ply`, `.splat`, and `.sog` remain compatibility formats through GDGS. Claim the bead on start, keep the scope narrow, run relevant repo-local validation if available, and close the bead with the file list and validation summary.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-content-core/.plans/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-content-core/fixtures/package_yaml_valid_splat/environments/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-content-core/fixtures/package_yaml_missing_environment_ref/environments/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-content-core/data_types/environment.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-content-core/tests/test_environment_contract.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-content-core/README.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-content-core/fixtures/package_yaml_valid_splat/environments/ab-environment-splat-demo.yaml`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-content-core/fixtures/package_yaml_missing_environment_ref/environments/ab-environment-splat-demo.yaml`

**Status:** ✅ Complete

**Results:** Completed. `aerobeat-content-core` now treats `.compressed.ply` as the recommended splat authored path while keeping `.ply`, `.splat`, and `.sog` valid compatibility formats and explicitly rejecting `.spz`. Contract validation passed, including explicit coverage for valid `.compressed.ply`, `.ply`, `.splat`, `.sog`, and rejected `.spz`.

---

### Task 4: Decide whether the Gaussian splat wrapper docs also need policy wording alignment

**Bead ID:** `aerobeat-environment-community-qtq`  
**SubAgent:** `primary` (for `research` / `coder` workflow role)  
**Role:** `research`  
**References:** `REF-03`  
**Prompt:** Inspect the current AeroBeat Gaussian splat wrapper docs and decide whether they should merely document supported formats or also mention `.compressed.ply` as the recommended AeroBeat format. Claim the bead on start, keep the recommendation scoped correctly, and report whether a follow-up docs patch is warranted.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.plans/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/addons/aerobeat-tool-gaussian-splat/README.md` (only if warranted)

**Status:** ✅ Complete

**Results:** Completed. Scope review concluded that the AeroBeat Gaussian splat wrapper README should remain a runtime/support-surface document that lists supported formats, rather than becoming the product-policy source for the recommended authoring format. No wrapper README patch was required for this slice.

---

### Task 5: QA the recommendation path across the touched repos

**Bead ID:** `aerobeat-environment-community-1qz`  
**SubAgent:** `primary` (for `qa` workflow role)  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Verify that the final wording across the touched repos matches the actual supported runtime formats and that `.compressed.ply` is presented as recommended rather than incorrectly as the only supported format. Claim the bead on start, run the highest-fidelity repo-local validation available for each touched repo, and leave a precise QA result.

**Folders Created/Deleted/Modified:**
- Validation only unless QA finds required fixes.

**Files Created/Deleted/Modified:**
- Validation only unless QA finds required fixes.

**Status:** ✅ Complete

**Results:** Completed. QA verified that all three touched repos present `.compressed.ply` as recommended while preserving `.ply`, `.splat`, and `.sog` as compatibility-supported formats and avoiding any `.spz` implication. Validation passed across all repos: environment-community import + GUT (`12/12` tests, `48` asserts), content-core contract suite (including explicit `.spz` rejection), docs placeholder generation + strict MkDocs build, and `git diff --check` clean in all three repos.

---

### Task 6: Independent audit of the policy change before handoff

**Bead ID:** `aerobeat-environment-community-n6s`  
**SubAgent:** `primary` (for `auditor` workflow role)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Independently audit the touched repos after coder and QA complete. Confirm that the recommendation/support matrix is truthful, `.spz` is not implied as supported, and the docs/UX changes remain narrow. Claim the bead on start and close the bead only if the work is genuinely complete.

**Folders Created/Deleted/Modified:**
- Validation only unless audit finds required fixes.

**Files Created/Deleted/Modified:**
- Validation only unless audit finds required fixes.

**Status:** ✅ Complete

**Results:** Completed. Independent audit verified the QA handoff, confirmed the recommendation/support matrix is truthful across all touched repos, confirmed `.spz` is not implied as supported, and confirmed the wrapper README non-change is sensible because it remains a runtime support-surface doc. Validation re-runs passed across environment-community, docs, and content-core, and `git diff --check` was clean.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Cross-repo policy alignment for AeroBeat Gaussian splats. `aerobeat-environment-community`, `aerobeat-docs`, and `aerobeat-content-core` now consistently present `.compressed.ply` as the official recommended AeroBeat splat format while preserving `.ply`, `.splat`, and `.sog` as GDGS compatibility-supported formats. `.spz` is not implied as supported, and content-core explicitly rejects it.

**Reference Check:** `REF-01` / `REF-02` updated to show the recommendation in the environment repo and testbed UX; `REF-03` intentionally remained a support-surface-only wrapper doc; `REF-04` and `REF-05` now match the same policy/support matrix.

**Commits:**
- Pending wrap-up commit/push.

**Lessons Learned:** Keep product-policy recommendation wording in product/content/docs surfaces and keep lower-level runtime wrapper docs focused on the actual support surface. Also ensure QA closure evidence is reflected in the coordinating plan before the auditor handoff.

---

*Completed on 2026-05-15*
