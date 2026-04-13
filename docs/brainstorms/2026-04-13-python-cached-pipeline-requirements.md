---
date: 2026-04-13
topic: python-cached-pipeline
---

# Python-Cached Pipeline for Fast Repeated Reruns

## Problem Frame

Current project spends too much time in data construction before analysis. Biggest pain is repeated reruns while iterating on analysis and figures. User wants optimization beyond Stata-only preprocessing. Only hard constraints are: final analysis must remain in Stata, and project must keep a master script that can run full workflow or selected parts. User is open to replacing preprocessing and matching with another language if faster.

## Requirements

**Workflow and Scope**
- R1. Replace current pure-Stata preprocessing pipeline with a new default pipeline that is allowed to use Python outside analysis.
- R2. Keep analytical stage in Stata. `code/desc.do` or successor Stata do-file remains source of final analysis and figure generation.
- R3. Provide a master script that can run full workflow and selected stages.
- R4. New pipeline becomes default path. Legacy pure-Stata prep/matching path does not need to remain runnable through master script.

**Performance and Rerun Behavior**
- R5. Optimize for fastest repeated reruns during paper iteration, not only fastest single clean run.
- R6. Use content-hash-based cache invalidation so expensive preprocessing stages rerun only when inputs or relevant transformation logic change.
- R7. Heavy matching, network construction, and assortativity preparation should be eligible for caching and reuse across runs.

**Output Compatibility**
- R8. Preserve analytical values used by final analysis.
- R9. Preserve output filenames and output inventory expected by current project.
- R10. Visual appearance of figures may change where explicitly requested, especially scatter-plot scaling and diagonal reference line.
- R11. Exact byte-for-byte equivalence of intermediate `.dta` files and rendered figures is not required, as long as analytical values and expected filenames are preserved.

**Matching and Data Preparation**
- R12. New non-Stata pipeline may replace current matching stage as well as downstream network and assortativity preparation if doing so improves performance.
- R13. New pipeline must produce Stata-readable inputs needed by final analysis.

## Success Criteria
- Full workflow can run from one master entrypoint.
- Analysis-only rerun skips expensive preprocessing when cached inputs remain valid.
- Changes to analysis code can be rerun without rebuilding matching/network caches.
- Final analytical values match current workflow for agreed validation targets.
- Existing output filenames remain available after pipeline run.
- New default workflow is materially faster on repeated reruns than current baseline.

## Scope Boundaries
- Do not keep pure-Stata preprocessing as equal-status fallback in master script.
- Do not require byte-identical intermediate files.
- Do not require byte-identical figure rendering.
- Do not change substantive analysis definitions merely to gain speed.

## Key Decisions
- Python-first direction chosen over R-first: broader orchestration flexibility and likely strongest path for cached preprocessing.
- Hybrid cached architecture chosen over simple one-shot rewrite: repeated rerun speed is primary goal.
- Content-hash invalidation chosen over timestamps or manual flags: reproducibility and cache correctness matter.
- Matching stage is in scope for replacement, not only downstream prep: user wants fastest feasible pipeline.
- Compatibility target is analytical equivalence plus stable filenames, not file-level or pixel-level identity: lowers unnecessary migration cost while preserving research outputs.

## Dependencies / Assumptions
- Python environment and required dependencies may be introduced into repo.
- Stata remains available for final analysis stage.
- Existing raw input data remains accessible in current project workflow.
- Planning should define what counts as relevant transformation logic for cache invalidation.

## Outstanding Questions

### Resolve Before Planning
- None.

### Deferred to Planning
- [Affects R3][Technical] What master-script form best fits repo: Python CLI, shell wrapper, or thin Stata launcher calling Python?
- [Affects R6][Technical] Which artifacts should be hashed independently: raw input, matching outputs, network edge tables, assortativity tables, analysis-ready export, or all of them?
- [Affects R8][Needs research] Which exact validation targets should define analytical equivalence: final regressions, class-level aggregates, assortativity summaries, figure source tables, or a combination?
- [Affects R12][Needs research] Should matching be reimplemented to numerically mirror current Stata behavior exactly, or should planning preserve current `matches.dta` semantics via a compatibility layer if exact reimplementation proves fragile?
- [Affects R13][Technical] Which final Stata-readable artifacts should remain persisted on disk versus generated only as transient exports from cache?

## Next Steps
-> /ce:plan for structured implementation planning
