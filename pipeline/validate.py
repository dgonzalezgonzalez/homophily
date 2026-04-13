from __future__ import annotations

import math
import shutil

import pandas as pd

from .config import PipelineConfig
from .io import read_stata
from .prep import NETWORKS


CONTRACT_FILES = ["analysis_base.dta"] + [f"assort_{network}.dta" for network in NETWORKS]
ANALYSIS_BASE_COLUMNS = {
    "usuario_id",
    "class_id",
    "class_size",
    "school",
    "grade",
    "group2",
    "degree_match",
    "wdegree_match",
    "indegreef",
    "indegreebf",
    "indegreee",
    "indegreewe",
    "degreef",
    "degreebf",
    "degreee",
    "degreewe",
    "outdegreef",
    "outdegreebf",
    "outdegreee",
    "outdegreewe",
}


def _contract_columns(name: str, baseline: pd.DataFrame) -> list[str]:
    if name != "analysis_base.dta":
        return list(baseline.columns)
    return [
        column
        for column in baseline.columns
        if column in ANALYSIS_BASE_COLUMNS
        or column.startswith("match_id")
        or column.startswith("count_match")
    ]


def snapshot_current_contract(config: PipelineConfig) -> None:
    config.baseline_dir.mkdir(parents=True, exist_ok=True)
    for name in CONTRACT_FILES:
        source = config.temp_dir / name
        if source.exists():
            shutil.copy2(source, config.baseline_dir / name)


def _compare_series(left: pd.Series, right: pd.Series, tol: float) -> bool:
    if left.dtype.kind in "if" or right.dtype.kind in "if":
        numeric_equal = ((left.fillna(math.nan) - right.fillna(math.nan)).abs() <= tol) | (
            left.isna() & right.isna()
        )
        return bool(numeric_equal.all())
    return bool((left.fillna("__NA__") == right.fillna("__NA__")).all())


def _sort_for_compare(name: str, df: pd.DataFrame) -> pd.DataFrame:
    if name == "analysis_base.dta":
        return df.sort_values(["usuario_id"]).reset_index(drop=True)
    return df.sort_values(["usuario_id", "match_id", "count_match"], na_position="first").reset_index(drop=True)


def validate_against_baseline(config: PipelineConfig, tol: float = 1e-5) -> list[str]:
    errors: list[str] = []
    for name in CONTRACT_FILES:
        current_path = config.temp_dir / name
        baseline_path = config.baseline_dir / name
        if not current_path.exists():
            errors.append(f"missing current file: {name}")
            continue
        if not baseline_path.exists():
            errors.append(f"missing baseline file: {name}")
            continue
        current = read_stata(current_path)
        baseline = read_stata(baseline_path)
        contract_columns = _contract_columns(name, baseline)
        missing_columns = [column for column in contract_columns if column not in current.columns]
        if missing_columns:
            errors.append(f"column mismatch: {name} missing {missing_columns[:5]}")
            continue
        current = current[contract_columns]
        baseline = baseline[contract_columns]
        current = _sort_for_compare(name, current)
        baseline = _sort_for_compare(name, baseline)
        if current.shape != baseline.shape:
            errors.append(f"shape mismatch: {name} {current.shape} != {baseline.shape}")
            continue
        for column in current.columns:
            if not _compare_series(current[column], baseline[column], tol):
                errors.append(f"value mismatch: {name}:{column}")
                break
    return errors
