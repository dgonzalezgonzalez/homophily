# Repository Guidelines

## Project Structure & Module Organization
- `code/`: analysis scripts (`main.do`, `matches.do`, `dataprep.do`, `desc.do`).
- `temp/`: generated intermediate `.dta` files.
- `output/`: generated figures (`.png`).

Put analysis logic in `code/`. Treat `temp/` and `output/` as reproducible artifacts.

## Build, Test, and Development Commands
- Run full pipeline (Stata batch):
  - `stata-mp -b do code/main.do`
  - Runs data preparation and descriptive outputs.
- Run optional matching stage (`teffects nnmatch`):
  - Enable `do "$cd/code/matches.do"` in `code/main.do`, then rerun.
- Run stages individually:
  - `stata-mp -b do code/dataprep.do`
  - `stata-mp -b do code/desc.do`

Before execution, set `global cd` and `global raw_dta` in `code/main.do` to valid local paths.

## Coding Style & Naming Conventions
- Use standard Stata `.do` style, one command per line, consistent indentation.
- Use lowercase snake_case for variables/files (`degree_match`, `assort_friend.dta`).
- Keep network tags consistent: `friend`, `friend2`, `enemy`, `enemy2`.
- Keep output naming deterministic: `output/scatter_<metric>.png`, `output/dens_<type>.png`.

## Testing Guidelines
- No formal unit-test framework configured.
- Validate by rerunning changed scripts and checking:
  - Stata finishes without errors.
  - Expected files regenerate in `temp/` and `output/`.
  - Basic sanity stats remain plausible (`sum`, `tab`, `duplicates report`).

## Commit & Pull Request Guidelines
- Use short, imperative commit messages with optional scope prefixes:
  - `data: fix reshape key in dataprep.do`
  - `analysis: update assortativity graph labels`
- PRs should include:
  - Change summary and rationale.
  - `.do` files executed.
  - Input-path assumptions (`raw_dta` location).
  - Updated artifacts, or reason they were not regenerated.

## Agent-Specific Instructions
- Default interaction mode for this repository: `$caveman wenyan-ultra`.
- Exception: when summarizing completed work for the user and/or requesting user action, switch to `$caveman`.
