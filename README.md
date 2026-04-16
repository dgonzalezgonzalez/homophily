# Homophily and Assortativity in School Social Networks

This repository contains a cached Python + Stata pipeline for my PhD economics paper on homophily and assortativity in social networks. Python handles matching orchestration, network preparation, and Stata exports; `code/desc.do` remains the analysis layer.

## Repository Layout
- `code/`: Stata scripts.
  - `main.do`: legacy Stata entrypoint.
  - `matches.do`: bootstrap nearest-neighbor matching assignment.
  - `dataprep.do`: legacy preprocessing reference.
  - `desc.do`: descriptive analysis and figure generation.
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

Matching notes:
- The pipeline caches `temp/matches.dta`.
- If `temp/matches.dta` is already present, the first Python run imports it into cache and avoids recomputing matching.
- Use `.venv/bin/python -m pipeline.main match --rebuild-matches` to force Stata to regenerate matching.

## Main Outputs
- Scatter plots: `output/scatter/scatter_*.png`
- Alternative classroom-tie normalization scatters: `output/scatter/scatter_altnorm_*.png`
- Assortativity densities: `output/distribution/dens_assort*.png`, `output/distribution/dens_wassort*.png`

## Notes
- `temp/` and `output/` are reproducible artifacts and can be regenerated from source code.
- Matching regeneration still uses Stata 16+ features (`frame`, `frlink`, `frget`) in `matches.do`.
- Repeated reruns are faster because unchanged stages hit `.cache/pipeline/` rather than rebuilding network tables.
