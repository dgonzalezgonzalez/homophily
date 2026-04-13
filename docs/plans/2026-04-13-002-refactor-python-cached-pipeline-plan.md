---
title: Refactor Pipeline to Python-Cached Preprocessing with Stata Analysis
type: refactor
status: active
date: 2026-04-13
origin: docs/brainstorms/2026-04-13-python-cached-pipeline-requirements.md
---

# Refactor Pipeline to Python-Cached Preprocessing with Stata Analysis

## Overview

Replace current pure-Stata preprocessing and matching workflow with a Python-first cached pipeline optimized for repeated reruns, while preserving Stata as the final analysis layer. The new default entrypoint should orchestrate cache-aware matching, network construction, assortativity preparation, Stata-ready exports, and final Stata analysis. Compatibility target is analytical equivalence plus stable output filenames, not byte-identical intermediates.

## Problem Frame

Current runtime cost sits in matching, network expansion, and repeated reshape/join work rather than in the final Stata analysis itself. The user wants a faster default workflow with aggressive rerun reuse. The origin requirements document fixes the product direction: Python-first preprocessing, content-hash invalidation, Stata-only final analysis, no legacy pure-Stata fallback in the master script, and preservation of analytical values plus output filenames (see origin: `docs/brainstorms/2026-04-13-python-cached-pipeline-requirements.md`).

## Requirements Trace

- R1. Replace current pure-Stata preprocessing with a Python-based default pipeline.
- R2. Keep final analysis in Stata.
- R3. Provide a master script that runs the full workflow and selected stages.
- R4. Make the new pipeline the default path.
- R5. Optimize for fastest repeated reruns.
- R6. Use content-hash cache invalidation.
- R7. Cache matching, network construction, and assortativity preparation.
- R8. Preserve analytical values used by final analysis.
- R9. Preserve output filenames and output inventory.
- R10. Allow requested figure-presentation changes where intentional.
- R11. Do not require byte-identical intermediates.
- R12. Matching replacement is in scope.
- R13. Produce Stata-readable inputs for analysis.

## Scope Boundaries

- No requirement to preserve or expose legacy pure-Stata preprocessing through the new master script.
- No requirement to preserve exact intermediate `.dta` schema beyond what `code/desc.do` needs.
- No requirement to preserve pixel-identical figures.
- No requirement to optimize paper-writing or document-generation workflow outside this repo's data pipeline.

## Context & Research

### Relevant Code and Patterns

- `code/desc.do` is already the stable analysis contract. It requires `temp/analysis_base.dta` plus `temp/assort_friend.dta`, `temp/assort_friend2.dta`, `temp/assort_enemy.dta`, and `temp/assort_enemy2.dta`.
- `code/main.do` currently acts as entrypoint and already encodes stage-based execution semantics worth preserving conceptually.
- `code/validate_equivalence.do` provides a local pattern for validating analytical equivalence against a baseline snapshot.
- `temp/matches.dta`, `temp/friend*.dta`, `temp/enemy*.dta`, `temp/assort_*.dta`, and `temp/analysis_base.dta` show the current artifact surface, though planning should reduce persisted artifacts to what the Stata analysis contract actually needs.

### Institutional Learnings

- No `docs/solutions/` knowledge base is present in this repo.

### External References

- Not needed at planning time. This is an internal pipeline refactor grounded primarily in repo behavior and the user-defined architecture choice.

## Key Technical Decisions

- Use a Python CLI as the master entrypoint rather than a shell wrapper or thin Stata launcher. Rationale: the cache, hashing, stage orchestration, and validation logic all live more naturally in one Python control plane.
- Treat `code/desc.do` as the downstream contract boundary and generate only the Stata-readable artifacts it truly consumes. Rationale: this minimizes compatibility surface while honoring the Stata-analysis restriction.
- Hash both data inputs and logic fingerprints by stage. Rationale: content-only hashing of raw files is insufficient if transformation code changes while inputs stay constant.
- Keep stage caches in fast internal artifacts and export `.dta` only at the final boundary into Stata analysis. Rationale: fastest repeated reruns come from avoiding repeated `.dta` serialization until necessary.
- Define analytical equivalence using analysis-relevant targets rather than whole-repo binary identity. Rationale: the origin document explicitly chose analytical-value compatibility over byte-identical artifacts.
- Plan for exact-match compatibility first on downstream prep and only then on matching replacement. Rationale: replacing matching has more numerical risk and should be isolated behind characterization checks.

## Open Questions

### Resolved During Planning

- What should the master script be? A Python CLI, because hashing, caching, orchestration, and validation all belong in one control surface.
- Which artifacts should remain stable for Stata? `temp/analysis_base.dta` and the four `temp/assort_*.dta` files consumed by `code/desc.do`.
- What should define compatibility? Final analytical values and output filenames, with validation built around analysis-relevant datasets and regressions rather than byte-identical files.

### Deferred to Implementation

- Whether the Python implementation should use one engine end-to-end or a small hybrid internally. This is a coding-time choice as long as the contract and cache behavior hold.
- Whether `temp/friend*.dta` and `temp/enemy*.dta` should remain persisted for debugging or become optional debug artifacts. Planning can state the preference, but implementation should settle it based on actual validation and operational usefulness.
- How closely the Python matching code can numerically mirror current Stata matching behavior without preserving Stata internals. This requires execution-time validation on real data.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
raw input + pipeline code fingerprints
  -> stage hash resolver
  -> cached matching output
  -> cached network edge tables
  -> cached assortativity source tables
  -> Stata export boundary (`analysis_base.dta` + `assort_*.dta`)
  -> `code/desc.do`
  -> `output/*.png`

master CLI stages:
  full | match | prep | export | analysis | validate
```

## Implementation Units

- [ ] **Unit 1: Define Python control plane and cache contract**

**Goal:** Establish the new default orchestration path, stage model, cache layout, and invalidation rules before reimplementing data logic.

**Requirements:** R1, R3, R4, R5, R6, R7

**Dependencies:** None

**Files:**
- Create: `pipeline/main.py`
- Create: `pipeline/config.py`
- Create: `pipeline/cache.py`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Test: `pipeline/tests/test_cache_contract.py`

**Approach:**
- Introduce a Python master CLI with stage-level commands that mirror current user needs: full run, selected-stage run, analysis-only run, and validation.
- Define stage fingerprints that combine raw input content hash, stage-specific code hash, and relevant upstream artifact hashes.
- Separate internal cache artifacts from exported Stata-facing artifacts so reruns can skip redundant conversion work.
- Make this Python entrypoint the default workflow documented in the repo.

**Patterns to follow:**
- Existing stage-oriented semantics in `code/main.do`.
- Repo artifact conventions in `temp/` and `output/`.

**Test scenarios:**
- Happy path: Unchanged inputs and unchanged stage logic produce a cache hit and skip expensive rebuild work on rerun.
- Edge case: Modifying only analysis code invalidates analysis stage without rebuilding matching or network caches.
- Edge case: Modifying matching-stage logic invalidates downstream stages that depend on matching outputs.
- Error path: Missing raw input path causes an explicit, early failure with no partial cache state marked valid.
- Integration: Running the Python CLI in analysis-only mode invokes Stata against exported `.dta` artifacts without touching upstream cached stages.

**Verification:**
- An implementer can rerun the pipeline selectively and understand exactly why a stage was or was not rebuilt.

- [ ] **Unit 2: Reimplement matching and preprocessing as cached Python stages**

**Goal:** Move matching, network expansion, and assortativity preparation into Python while preserving analysis-relevant semantics.

**Requirements:** R1, R5, R6, R7, R8, R12

**Dependencies:** Unit 1

**Files:**
- Create: `pipeline/matching.py`
- Create: `pipeline/networks.py`
- Create: `pipeline/assortativity.py`
- Create: `pipeline/io.py`
- Test: `pipeline/tests/test_matching_equivalence.py`
- Test: `pipeline/tests/test_network_prep_equivalence.py`

**Approach:**
- Characterize current Stata outputs first, then replace stage logic one slice at a time: matching, then edge-table generation, then assortativity preparation.
- Use internal cached tables as the canonical data model for repeated reruns; avoid `.dta` writes until export stage.
- Preserve semantics that affect `degree_match`, `wdegree_match`, match multiplicities, and assortativity flags.
- Isolate matching replacement behind explicit equivalence checks because it is numerically riskier than downstream prep.

**Execution note:** Characterization-first. Replace downstream prep only after baseline behavior is captured; replace matching only after downstream exports are already validated.

**Technical design:** *(directional guidance)* Treat matching output as the canonical upstream event that fans out into network and assortativity derivations; every downstream stage should declare its dependency on the matching-stage hash rather than recomputing matching-related work implicitly.

**Patterns to follow:**
- Semantic targets encoded in `code/dataprep.do` and `code/matches.do`.
- Baseline comparison pattern in `code/validate_equivalence.do`.

**Test scenarios:**
- Happy path: Python preprocessing reproduces the same analysis-relevant match multiplicities and derived degree measures as the baseline.
- Happy path: Assortativity exports derived from Python stages produce the same averages and weighted averages used later in `code/desc.do`.
- Edge case: Missing matches propagate missing analytical values consistently with current workflow.
- Edge case: Duplicate user-match combinations are handled once and do not inflate counts.
- Error path: Corrupt or partially missing cache artifacts are detected and rebuilt rather than silently reused.
- Integration: Replacing Stata matching with Python matching still allows exported Stata analysis to pass analytical validation targets.

**Verification:**
- Python stages become the dominant data engine, and analysis-relevant values remain within agreed equivalence bounds against the baseline.

- [ ] **Unit 3: Define Stata export boundary and keep analysis stable**

**Goal:** Reduce the Stata-facing contract to a small exported dataset surface while keeping `code/desc.do` as the analysis engine.

**Requirements:** R2, R8, R9, R10, R11, R13

**Dependencies:** Unit 2

**Files:**
- Modify: `code/desc.do`
- Create: `pipeline/export_stata.py`
- Test: `pipeline/tests/test_stata_export_contract.py`
- Test: `pipeline/tests/test_analysis_contract.py`

**Approach:**
- Make the Python export stage responsible for writing `temp/analysis_base.dta` and required `temp/assort_*.dta` artifacts with the variable names and types `code/desc.do` expects.
- Keep `code/desc.do` focused on analysis and graph production, not on any remaining preprocessing logic.
- Preserve current output filenames and keep intentional scatter-plot formatting changes.
- If additional debug exports are retained, mark them as non-contract artifacts so planning and maintenance stay focused on the true boundary.

**Patterns to follow:**
- Current input expectations in `code/desc.do`.
- Existing output naming conventions in `output/`.

**Test scenarios:**
- Happy path: Exported `.dta` files can be consumed by `code/desc.do` with no manual intervention.
- Happy path: Final output inventory contains the expected scatter and density filenames.
- Edge case: Export stage regenerates missing Stata-facing artifacts from valid caches without rebuilding unaffected upstream stages.
- Error path: Export fails clearly when a required upstream cached table is missing or incompatible.
- Integration: Analysis-only run after a cache hit rebuilds figures without rerunning matching or network construction.

**Verification:**
- Stata analysis remains intact while the upstream contract shrinks to a clearly defined exported dataset surface.

- [ ] **Unit 4: Build analytical validation and migration checks**

**Goal:** Prove that the new default pipeline preserves analytical values and remains safe to use as the repo's main workflow.

**Requirements:** R3, R8, R9, R11, R12

**Dependencies:** Unit 3

**Files:**
- Modify: `code/validate_equivalence.do`
- Create: `pipeline/validate.py`
- Modify: `README.md`
- Test: `pipeline/tests/test_validation_workflow.py`

**Approach:**
- Expand validation from dataset equality toward analytical-equivalence targets: class-level aggregates, regression coefficients used in `code/desc.do`, assortativity summaries, and expected output inventory.
- Keep a migration-mode comparison path so the new Python pipeline can be validated against the current baseline during rollout.
- Document what is and is not considered equivalent, matching the origin requirements.
- Make validation a first-class CLI stage so future reruns can be trusted after code changes.

**Execution note:** Start with a failing validation target list derived from current baseline behavior before marking migration complete.

**Patterns to follow:**
- Baseline comparison intent in `code/validate_equivalence.do`.
- Output inventory already established in `output/`.

**Test scenarios:**
- Happy path: Validation passes when analytical targets match the agreed baseline.
- Edge case: A benign figure-rendering difference does not fail validation if analytical targets still match and filenames exist.
- Error path: A change in regression coefficients, class-level aggregates, or assortativity summaries fails validation with a targeted explanation of which metric drifted.
- Integration: Full pipeline run followed by validation provides a single trustable migration check before branch merge.

**Verification:**
- The repo has an explicit, repeatable proof that the Python-first pipeline preserves research results while allowing non-identical intermediates.

## System-Wide Impact

- **Interaction graph:** Python CLI becomes top-level orchestrator; exported Stata datasets feed `code/desc.do`; validation spans both Python stages and Stata outputs.
- **Error propagation:** Cache corruption, export mismatch, or Stata invocation failures must stop downstream stages and surface which contract failed.
- **State lifecycle risks:** Cached artifacts can become stale if code fingerprints or upstream data dependencies are defined too narrowly; invalidation design is therefore a core architectural risk.
- **API surface parity:** The current user-facing capability of running full or stage-specific workflows must survive the migration even though the control plane changes from Stata entrypoint to Python CLI.
- **Integration coverage:** Validation must cross language boundaries: Python-generated `.dta` artifacts into Stata analysis.
- **Unchanged invariants:** Final analysis remains in Stata, output filenames stay stable, and substantive analytical definitions must not drift.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Python matching cannot reproduce current Stata behavior closely enough | Stage rollout so downstream prep migrates first; isolate matching replacement behind dedicated equivalence checks |
| Cache invalidation misses logic changes and reuses stale artifacts | Fingerprint stage code and explicit upstream dependency graph, not just raw input files |
| Exported `.dta` artifacts differ in types or naming expected by Stata | Define a small explicit export contract and cover it with tests before full migration |
| Performance gains are offset by expensive export-to-Stata steps | Keep cache artifacts in internal fast format and export only final Stata-facing datasets on demand |
| Repo usability drops if new workflow is under-documented | Update `README.md` and `AGENTS.md` with new default commands and stage semantics |

## Documentation / Operational Notes

- Repo docs should describe new default entrypoint, cache behavior, and when validation should be run.
- Planning assumes Python dependencies will be pinned and documented.
- Migration should land on a feature branch and be validated before any decision to replace current default workflow on `main`.

## Sources & References

- **Origin document:** `docs/brainstorms/2026-04-13-python-cached-pipeline-requirements.md`
- Related code: `code/main.do`
- Related code: `code/desc.do`
- Related code: `code/dataprep.do`
- Related code: `code/matches.do`
- Related code: `code/validate_equivalence.do`
