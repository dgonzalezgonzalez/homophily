# Homophily and Assortativity in School Social Networks

This repository contains reproducible Stata code for my PhD economics paper on homophily and assortativity in social networks. The pipeline builds matching-based peer links, computes assortativity metrics, and exports descriptive figures.

## Repository Layout
- `code/`: core Stata scripts.
  - `main.do`: orchestration entrypoint.
  - `matches.do`: optional bootstrap nearest-neighbor matching assignment.
  - `dataprep.do`: network/match reshaping and intermediate datasets.
  - `desc.do`: descriptive analysis and figure generation.
- `temp/`: generated intermediate `.dta` files.
- `output/`: generated figures (`.png`).

## Reproducibility
1. Open `code/main.do`.
2. Set:
   - `global cd` to this repository path.
   - `global raw_dta` to input dataset path (e.g., `data_schools.dta`).
3. Run full pipeline:
   - `stata-mp -b do code/main.do`

Optional: enable `do "$cd/code/matches.do"` in `main.do` to regenerate `temp/matches.dta` (computationally heavier).

## Main Outputs
- Scatter plots: `output/scatter_*.png`
- Assortativity densities: `output/dens_assort*.png`, `output/dens_wassort*.png`

## Notes
- `temp/` and `output/` are reproducible artifacts and can be regenerated from source code.
- Scripts use Stata 16+ features (`frame`, `frlink`, `frget`) in `matches.do`.
