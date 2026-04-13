from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from .cache import StageCache
from .config import PipelineConfig
from .prep import export_prepared_artifacts
from .stata_runner import run_stata_do
from .validate import snapshot_current_contract, validate_against_baseline


def ensure_matches(config: PipelineConfig, cache: StageCache, rebuild: bool = False) -> Path:
    stage = "match"
    outputs = [config.temp_dir / "matches.dta", cache.data_path("matches.dta")]
    fingerprint = cache.fingerprint(
        stage=stage,
        inputs=[config.raw_dta],
        code_paths=[config.code_dir / "matches.do"],
        extra=["stata-matches-stage-v1"],
    )
    if not rebuild and cache.valid(stage, fingerprint, outputs):
        if not (config.temp_dir / "matches.dta").exists():
            shutil.copy2(cache.data_path("matches.dta"), config.temp_dir / "matches.dta")
        return config.temp_dir / "matches.dta"

    temp_matches = config.temp_dir / "matches.dta"
    if temp_matches.exists() and not rebuild:
        shutil.copy2(temp_matches, cache.data_path("matches.dta"))
    else:
        run_stata_do(config, config.code_dir / "matches.do")
        shutil.copy2(temp_matches, cache.data_path("matches.dta"))
    cache.save(
        stage,
        {
            "fingerprint": fingerprint,
            "outputs": [str(path) for path in outputs],
        },
    )
    return temp_matches


def run_prep(config: PipelineConfig, cache: StageCache, matches_path: Path, force: bool = False) -> None:
    stage = "prep"
    outputs = [
        config.temp_dir / "analysis_base.dta",
        config.temp_dir / "friend.dta",
        config.temp_dir / "friend2.dta",
        config.temp_dir / "enemy.dta",
        config.temp_dir / "enemy2.dta",
        config.temp_dir / "assort_friend.dta",
        config.temp_dir / "assort_friend2.dta",
        config.temp_dir / "assort_enemy.dta",
        config.temp_dir / "assort_enemy2.dta",
    ]
    fingerprint = cache.fingerprint(
        stage=stage,
        inputs=[config.raw_dta, matches_path],
        code_paths=[config.code_dir / "desc.do", Path(__file__).with_name("prep.py")],
        extra=["python-prep-v1"],
    )
    if not force and cache.valid(stage, fingerprint, outputs):
        return
    export_prepared_artifacts(config, matches_path)
    cache.save(stage, {"fingerprint": fingerprint, "outputs": [str(path) for path in outputs]})


def run_analysis(config: PipelineConfig) -> None:
    run_stata_do(config, config.code_dir / "desc.do")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Cached pipeline for homophily analysis.")
    parser.add_argument("stage", choices=["full", "match", "prep", "analysis", "validate", "snapshot-baseline"])
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--raw-dta")
    parser.add_argument("--stata-bin")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--rebuild-matches", action="store_true")
    return parser


def main() -> None:
    args = build_parser().parse_args()
    config = PipelineConfig.from_repo(args.repo_root, raw_dta=args.raw_dta, stata_bin=args.stata_bin)
    config.ensure_dirs()
    cache = StageCache(config)

    if args.stage == "snapshot-baseline":
        snapshot_current_contract(config)
        return

    matches_path = None
    if args.stage in {"full", "match", "prep"}:
        matches_path = ensure_matches(config, cache, rebuild=args.rebuild_matches)

    if args.stage in {"full", "prep"}:
        assert matches_path is not None
        run_prep(config, cache, matches_path, force=args.force)

    if args.stage in {"full", "analysis"}:
        run_analysis(config)

    if args.stage == "match":
        return

    if args.stage == "validate":
        errors = validate_against_baseline(config)
        if errors:
            raise SystemExit("\n".join(errors))
        return


if __name__ == "__main__":
    main()

