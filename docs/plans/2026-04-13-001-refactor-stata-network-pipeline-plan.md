---
title: Refactor Stata Network Pipeline for Equivalent Faster Execution
type: refactor
status: active
date: 2026-04-13
---

# Refactor Stata Network Pipeline for Equivalent Faster Execution

## Overview

The current Stata pipeline spends significant time materializing intermediate network datasets, repeatedly loading and saving `.dta` files, and merging the same structures multiple times before generating descriptive outputs. This plan refactors the pipeline to preserve identical analytical results and identical output filenames while reducing I/O churn and repeated reshaping. The analytical stage remains in Stata (`code/desc.do`), and the project retains a master entrypoint that can run the full workflow or selected stages.

## Problem Frame

The current workflow builds four network edge tables (`friend`, `friend2`, `enemy`, `enemy2`), reshapes match assignments, then repeatedly preserves, restores, merges, and saves assortativity datasets. This is likely the dominant runtime cost, especially because the same match-level keys are reconstructed several times. The user requires that:

- analytical results remain exactly the same;
- figure names and produced outputs remain exactly the same;
- the analysis layer stays in a Stata do-file;
- a master script can run the full process or only selected stages;
- scatter plots use the same scale on both axes, use a data-driven upper bound instead of always `0` to `1`, and include a slope-1 diagonal.

## Requirements Trace

- R1. Preserve all analytical results produced by the current pipeline.
- R2. Preserve output artifact names and locations, including all files in `output/` and `temp/` that are part of the current workflow.
- R3. Keep the analysis stage implemented in Stata, with `code/desc.do` or its successor remaining a Stata do-file.
- R4. Retain a master script that can run the whole process or selected parts.
- R5. Reduce runtime by eliminating unnecessary reshapes, merges, disk writes, and repeated dataset materialization.
- R6. Update scatter plots so both axes share the same data-driven range and include a 45-degree reference line, while keeping the existing output filenames.
- R7. Validate equivalence before the optimized branch is considered complete.

## Scope Boundaries

- No change to the substantive econometric or descriptive definitions.
- No change to output filenames under `output/`.
- No change to the matching algorithm's statistical logic unless a characterization pass proves the optimized implementation is numerically identical.
- No requirement to preserve byte-for-byte graph pixels if Stata redraws the same statistics differently after axis scaling changes; the planned invariant is same underlying analytical content plus the requested scatter-plot presentation update.

## Context & Research

### Relevant Code and Patterns

- `code/main.do` is the current master entrypoint and already encodes staged execution via commented `do` calls.
- `code/dataprep.do` creates edge lists and assortativity datasets through repeated `use`, `save`, `merge`, `preserve`, and `restore` cycles.
- `code/desc.do` performs the class-level scatter plots and the micro-level assortativity density plots, and currently depends on datasets left in memory by `code/dataprep.do` plus `cd "$cd/temp"` side effects from `code/dataprep.do`.
- `code/matches.do` already uses frames for temporary lookup work, which is the main local pattern supporting a broader move away from repeated disk-backed joins.

### Institutional Learnings

- No `docs/solutions/` repository knowledge base is present in this repo.

### External References

- Not used. The repository is small, the stack is pure Stata, and the current local code provides enough pattern context to plan responsibly without external documentation.

## Key Technical Decisions

- Use characterization-first validation for any optimization that changes data flow. This reduces the risk of silently changing results while chasing speed.
- Decouple stage boundaries explicitly in the master script. `code/desc.do` should load the exact datasets it needs instead of depending on whatever dataset `code/dataprep.do` leaves in memory.
- Replace repeated disk round-trips with in-memory frames or tempfiles where possible, while preserving stable on-disk artifacts expected by downstream analysis.
- Build a single canonical match-long structure once, then derive assortativity metrics from it, rather than reconstructing the same keys repeatedly for each network.
- Keep output filenames unchanged, but parameterize scatter-axis scaling from the observed maxima of each x/y pair so both axes share the same upper bound and the slope-1 line is visible.

## Open Questions

### Resolved During Planning

- Should the optimized workflow still center around a single master script? Yes. `code/main.do` remains the orchestration entrypoint, but will be made parameterizable so it can run full or partial stages without manual commenting.
- Should the figure names change when the scatter plots are reformatted? No. Output paths remain unchanged.
- Should the requested diagonal line be interpreted as a 45-degree reference where `y = x`? Yes.

### Deferred to Implementation

- Whether the fastest safe refactor uses frames end-to-end, tempfiles plus merge keys, or a hybrid approach inside `code/dataprep.do`. This depends on how Stata behaves on the actual machine and should be decided during coding while preserving characterized outputs.
- Whether the matching stage should be left untouched or only lightly cleaned. The current user concern focuses on the network-database buildup and descriptive analysis, so matching optimization is lower priority unless profiling shows it remains dominant after the refactor.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
raw_dta
  -> filtered base sample (country == 1)
  -> match-wide dataset
  -> canonical match-long dataset with count weights
  -> per-network edge lookup structures (friend/friend2/enemy/enemy2)
  -> per-network assortativity flags + weighted flags
  -> stable temp/*.dta artifacts required by analysis
  -> code/desc.do loads only the required artifact(s)
  -> class-level scatters and micro-level densities exported with existing names
```

## Implementation Units

- [ ] **Unit 1: Characterize current outputs and stage contracts**

**Goal:** Establish a reproducibility baseline for datasets and figures before changing data flow.

**Requirements:** R1, R2, R4, R7

**Dependencies:** None

**Files:**
- Modify: `code/main.do`
- Create: `code/validate_equivalence.do`
- Test: `code/validate_equivalence.do`

**Approach:**
- Make stage selection explicit in the master script so baseline and optimized runs can be invoked consistently.
- Add a validation do-file that compares expected intermediate and final artifacts across baseline and refactored runs using dataset-level summaries, key uniqueness checks, and output existence checks.
- Capture the hidden contract that `code/desc.do` currently relies on a dataset already loaded into memory and on `cd` being moved to `temp/` by `code/dataprep.do`.

**Execution note:** Add characterization coverage before modifying the legacy data-preparation flow.

**Patterns to follow:**
- `code/main.do` for orchestration.
- Current sanity-check idioms already used in the repo, such as `sum`, `duplicates drop`, and merge-key logic.

**Test scenarios:**
- Happy path: Running the baseline full pipeline produces the same set of expected `temp/*.dta` and `output/*.png` files currently present in the repo.
- Happy path: Running only the analysis stage through the master script succeeds when prerequisite temp artifacts already exist.
- Edge case: Validation detects a missing expected temp artifact and fails clearly rather than silently passing.
- Integration: Validation compares the baseline and optimized versions of the key analytical variables used in `code/desc.do` and confirms equality within exact or explicitly documented tolerance rules.

**Verification:**
- An implementer can describe the current pipeline inputs, in-memory assumptions, and expected artifacts without relying on manual comments or remembered execution order.

- [ ] **Unit 2: Refactor data preparation around canonical long-form match and edge lookups**

**Goal:** Remove redundant reshapes and repeated merge cycles in `code/dataprep.do` while preserving the same temp outputs.

**Requirements:** R1, R2, R5, R7

**Dependencies:** Unit 1

**Files:**
- Modify: `code/dataprep.do`
- Test: `code/validate_equivalence.do`

**Approach:**
- Load the filtered base sample once and reuse it.
- Build edge lists for all four networks with a consistent helper pattern rather than four independent full reloads of the raw dataset.
- Build the match-long dataset once, compute `degree_match`, `wdegree_match`, and match weights once, then reuse that structure to derive all assortativity outputs.
- Replace repeated save/reload cycles for `_temp_dir1.dta` and `_temp_dir2.dta` with in-memory frames or tempfiles scoped to a single network iteration.
- Preserve the on-disk artifacts `temp/friend.dta`, `temp/friend2.dta`, `temp/enemy.dta`, `temp/enemy2.dta`, and `temp/assort_*.dta` because downstream analysis expects them.

**Execution note:** Characterization-first. Do not change formulas; change only data movement and reuse.

**Technical design:** *(directional guidance)* Use a canonical `(usuario_id, match_id, count_match)` long table as the single source for per-network assortativity joins instead of rebuilding that shape inside each network-specific branch.

**Patterns to follow:**
- Frame-based lookup pattern in `code/matches.do`.
- Existing naming conventions for network tags and temp output files.

**Test scenarios:**
- Happy path: Each optimized network edge artifact contains the same observations and key variables as the current version for `friend`, `friend2`, `enemy`, and `enemy2`.
- Happy path: Each optimized `temp/assort_<network>.dta` reproduces the same assortativity indicator and weighted-indicator columns as the baseline.
- Edge case: Classes or users with missing matches still propagate missing values exactly as before in assortativity variables.
- Edge case: Duplicate `(usuario_id, match_id)` combinations remain de-duplicated exactly once, not dropped too early or counted twice.
- Error path: If a required temp input such as `temp/matches.dta` is absent, the stage stops with a clear message rather than leaving partial outputs behind.
- Integration: `code/desc.do` can consume the optimized temp artifacts without any change in analytical content.

**Verification:**
- Runtime decreases materially because the number of raw-data reloads, disk writes, and repeated merges is reduced, and equivalence checks for all retained temp outputs pass.

- [ ] **Unit 3: Make analysis independent, deterministic, and graph-compatible**

**Goal:** Keep analysis in Stata while making `code/desc.do` self-contained and preserving the same output filenames.

**Requirements:** R1, R2, R3, R4, R7

**Dependencies:** Unit 2

**Files:**
- Modify: `code/desc.do`
- Modify: `code/main.do`
- Test: `code/validate_equivalence.do`

**Approach:**
- Ensure `code/desc.do` explicitly loads the prepared dataset(s) it needs instead of assuming `code/dataprep.do` left a specific dataset in memory.
- Remove reliance on implicit working-directory state from `code/dataprep.do` by using explicit paths for `assort_*.dta` inputs.
- Preserve all exported filenames exactly, including `output/scatter_*.png`, `output/dens_assort*.png`, and `output/dens_wassort*.png`.
- Keep regression calls and density construction unchanged unless required for path independence.

**Patterns to follow:**
- Existing output naming scheme in `code/desc.do`.
- Existing staged orchestration pattern in `code/main.do`.

**Test scenarios:**
- Happy path: Running only the analysis stage after temp artifacts exist produces the complete current set of output figures with unchanged filenames.
- Edge case: Analysis exits cleanly with a clear prerequisite error if the expected temp artifacts are missing.
- Integration: The optimized `code/main.do` can run `dataprep` followed by `desc` in one invocation and also run `desc` alone without editing source comments.

**Verification:**
- Analysis no longer depends on implicit in-memory state or a prior `cd`, and the current output inventory is reproduced with the same names.

- [ ] **Unit 4: Update scatter-plot presentation without changing analytical content**

**Goal:** Implement the requested visual changes to scatter plots while preserving file names and the underlying statistics.

**Requirements:** R2, R6, R7

**Dependencies:** Unit 3

**Files:**
- Modify: `code/desc.do`
- Test: `code/validate_equivalence.do`

**Approach:**
- For each scatter pair, compute a shared upper bound from the observed maxima of the x and y variables, then apply the same bound to both axes so the 45-degree line is interpretable.
- Replace the fixed `0` to `1` axis range with a data-driven range starting at `0` and ending at a rounded upper bound that fits the data well.
- Add a reference line representing `y = x` to each scatter panel while keeping the existing regression fit and confidence interval overlays.
- Keep annotation, labels, and output paths stable except for the requested axis formatting change.

**Patterns to follow:**
- Current graph-export loop in `code/desc.do`.
- Existing local-macro labeling pattern for network-degree titles.

**Test scenarios:**
- Happy path: Every exported scatter figure keeps its current filename and now shows equal x/y axis scales plus a visible slope-1 diagonal.
- Edge case: If the y-variable maximum exceeds the x-variable maximum, the shared upper bound still accommodates both variables without clipping.
- Edge case: If the observed maxima are very small, axis rounding still produces a readable plot rather than collapsing to a degenerate scale.
- Integration: The graph changes do not alter the regression coefficients, density outputs, or any non-scatter artifacts.

**Verification:**
- Scatter plots are visually easier to compare, preserve analytical interpretation, and satisfy the requested equal-axis plus diagonal-line presentation constraint.

## System-Wide Impact

- **Interaction graph:** `code/main.do` orchestrates `code/matches.do`, `code/dataprep.do`, `code/desc.do`, and the new `code/validate_equivalence.do`; `code/desc.do` consumes temp artifacts produced by `code/dataprep.do`.
- **Error propagation:** Missing prerequisite temp files should cause early, explicit failure in analysis and validation stages rather than silent partial graphs.
- **State lifecycle risks:** The current pipeline relies on mutable in-memory and working-directory state. The refactor should make dataset loading and file paths explicit to avoid stage-order bugs.
- **API surface parity:** The master-script entrypoint and artifact filenames are external contracts for this repo and must remain stable.
- **Integration coverage:** Equality checks are needed across both intermediate temp datasets and final output inventory because runtime optimizations affect data movement across stages.
- **Unchanged invariants:** Variable definitions, network semantics (`friend`, `friend2`, `enemy`, `enemy2`), match formulas, and output filenames remain unchanged.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Optimization changes analytical results through subtle duplicate-handling differences | Characterization-first validation of key datasets and analytical variables before accepting the refactor |
| `code/desc.do` currently depends on hidden state not captured in the code | Make all required dataset loads and paths explicit before further optimization |
| Scatter-plot presentation changes could be mistaken for analytical changes | Limit graph edits to scaling and the diagonal reference line; keep filenames and fitted overlays unchanged |
| Matching stage remains the actual runtime bottleneck after refactoring dataprep | Reassess after the first equivalence-validated refactor and optimize `code/matches.do` only if profiling still justifies it |

## Documentation / Operational Notes

- The master script should document how to run full pipeline versus stage-specific pipeline without editing comments.
- Validation guidance should state which artifacts are expected before an analysis-only run.
- The implementation should land on a non-`main` Git branch, and equivalence should be checked before committing that branch.

## Sources & References

- Related code: `code/main.do`
- Related code: `code/dataprep.do`
- Related code: `code/desc.do`
- Related code: `code/matches.do`
- User constraints from request on 2026-04-13
- User constraints from request on 2026-04-13
