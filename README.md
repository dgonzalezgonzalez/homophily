# Homophily and Assortativity in School Social Networks

This repository contains a cached Python + Stata pipeline for my PhD economics paper on homophily and assortativity in social networks. Python handles matching orchestration, network preparation, and Stata exports; `code/desc.do` remains the analysis layer.

## Repository Layout
- `code/`: Stata scripts.
  - `main.do`: legacy Stata entrypoint.
  - `matches.do`: bootstrap nearest-neighbor matching assignment.
  - `dataprep.do`: legacy preprocessing reference.
  - `desc.do`: descriptive analysis and figure generation.
  - `main_synth.do`: synthetic-twin entrypoint (parallel flow, does not overwrite legacy flow).
  - `matches_synth.do`: class-by-class synthetic twin assignment using observable covariates.
  - `dataprep_synth.do`: preprocessing for the synthetic twin network.
  - `desc_synth.do`: descriptive analysis and figures for the synthetic twin network.
- `pipeline/`: Python master pipeline, cache contract, preprocessing, and validation.
- `temp/`: generated intermediate `.dta` files.
- `output/`: generated figures (`.png`).

## Reproducibility
1. Create a Python environment and install the lightweight dependencies used here:
   - `.venv/bin/pip install pandas pyreadstat pytest`
2. Set the raw data path either:
   - in `code/main.do` via `global raw_dta`, or
   - at runtime with `--raw-dta /path/to/data_schools.dta`
3. Run the default cached pipeline:
   - `.venv/bin/python -m pipeline.main full`

Useful stage runs:
- `.venv/bin/python -m pipeline.main prep`
- `.venv/bin/python -m pipeline.main analysis`
- `.venv/bin/python -m pipeline.main snapshot-baseline`
- `.venv/bin/python -m pipeline.main validate`

## Synthetic Twin Network (Alternative Method)
This repository now includes an alternative twin-network construction based on synthetic-control-style donor weights at the individual level, run class by class with the same observable covariates used in the bootstrap matching flow.

The synthetic flow is separate and non-destructive:
- It writes synthetic artifacts with `_synth` suffixes and synthetic output folders.
- It does not replace `matches.dta`, `analysis_base.dta`, or legacy output figures.

Run synthetic flow in Stata:
- `do code/main_synth.do all`
- `do code/main_synth.do matches`
- `do code/main_synth.do dataprep`
- `do code/main_synth.do analysis`

Key synthetic artifacts:
- `temp/matches_synth_long.dta`
- `temp/matches_synth.dta`
- `temp/analysis_base_synth.dta`
- `temp/assort_synth_*.dta`
- `temp/synth_panel_base.dta` (duplicated panel with `te=1/2`, used as synthetic-control-style setup artifact)

Synthetic figures:
- `output/scatter_synth/scatter_*.png`
- `output/scatter_synth/scatter_altnorm_*.png`
- `output/distribution_synth/dens_assort*.png`
- `output/distribution_synth/dens_wassort*.png`

Weighting note:
- In the synthetic network, donor weights for each individual are normalized to sum to 1.
- Scatter weighting uses a bootstrap-comparable scaling via `wdegree_match = 1 / sum(w_i^2)` (effective number of donors), so magnitudes are comparable to the legacy weighted-degree interpretation.

Matching notes:
- The pipeline caches `temp/matches.dta`.
- If `temp/matches.dta` is already present, the first Python run imports it into cache and avoids recomputing matching.
- Use `.venv/bin/python -m pipeline.main match --rebuild-matches` to force Stata to regenerate matching.

## Main Outputs
- Scatter plots: `output/scatter/scatter_*.png`
- Alternative classroom-tie normalization scatters: `output/scatter/scatter_altnorm_*.png`
- Assortativity densities: `output/distribution/dens_assort*.png`, `output/distribution/dens_wassort*.png`
  - Current density style (regular and synth): in-degree assortativity with match overlaid against `P(not in relation & not matched)` in the same figure.

## Notes
- `temp/` and `output/` are reproducible artifacts and can be regenerated from source code.
- Matching regeneration still uses Stata 16+ features (`frame`, `frlink`, `frget`) in `matches.do`.
- Repeated reruns are faster because unchanged stages hit `.cache/pipeline/` rather than rebuilding network tables.
- For PNG export reliability, use StataNow/Stata 19+ when possible. Some Stata 15 installations may miss the `Graph2png` translator in batch mode.
