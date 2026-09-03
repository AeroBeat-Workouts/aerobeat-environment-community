# Photosphere config GUT number-type mismatch

## Exact observed failure

Godot import and parse completed, but `test_photosphere_catalog.gd` failed because `JSON.parse_string()` returned numeric arrays/dictionaries containing floats while the test expected integers, for example `[0.0, 0.0, -1.0] != [0, 0, -1]`. The other 33 tests passed.

## Expected behavior

The GUT check should accept the exact identity transform and axis values produced by Godot's JSON parser without confusing JSON numeric representation with a semantic transform mismatch.

## Execution path

The test opens each generated config, passes its text through `JSON.parse_string()`, reads `centerForward`, `worldUp`, and `transform`, then compares them using GUT's type-strict `assert_eq` against integer literals.

## Most likely root cause

Godot JSON parsing materializes JSON numbers as floats. The test's expected arrays used integer literals, and GUT's deep equality is type-strict. Evidence is the repeated float/int warning and otherwise numerically identical actual/expected values for all eight configs.

## Alternative hypotheses

1. Config generation wrote unintended decimals: contradicted by the tracked JSON text and strict Python validator, which both show the intended numeric values.
2. A catalog/config was malformed or missing: contradicted by successful JSON reads and the failures occurring only at numeric equality assertions.
3. Godot import altered source JSON: contradicted by source hashes and the parser behavior occurring consistently for all eight files.

## Why previous fixes failed

No fix had been attempted. The first run exposed a test-only type expectation error rather than an asset or schema defect.

## Unknowns

None material. The parser's float behavior and GUT's strict comparison are directly observed.

## Minimal reproduction

Parse `{"axis":[0,0,-1]}` with `JSON.parse_string()` and compare the resulting array to `[0,0,-1]` using `assert_eq`; GUT reports float/int inequality.

## Proposed verification

Change only the GUT expected literals to floats and rerun the full GUT suite. Python validation must continue to assert the exact serialized bounded config contract.

## Recommended fix

Use float literals in the GUT expectations (`[0.0, 0.0, -1.0]`, etc.). This aligns the test with Godot JSON semantics without weakening keys, values, entry count, ordering, paths, or the independent byte/schema validator.

```text
Problem: GUT config test rejected semantically identical JSON numbers.
Observed symptom: 33/34 tests passed; all eight config comparisons reported float/int mismatch.
Root cause: Godot JSON numbers parse as floats while expected literals were ints and GUT equality is type-strict.
Evidence: Repeated `[0.0, ...] != [0, ...]` output; all paths/configs parsed successfully.
Failed approaches: None.
Corrective action: Use float literals in GUT expected values.
Verification test: Rerun full GUT suite plus strict Python photosphere validator.
Related files/components: `.testbed/tests/test_photosphere_catalog.gd`, Godot `JSON.parse_string()`.
Remaining uncertainty: None material.
```
