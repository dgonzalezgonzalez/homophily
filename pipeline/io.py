from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat


def read_stata(path: str | Path) -> pd.DataFrame:
    df, _ = pyreadstat.read_dta(path, apply_value_formats=False)
    return df


def _normalize_for_stata(df: pd.DataFrame) -> pd.DataFrame:
    normalized = df.copy()
    for column in normalized.columns:
        series = normalized[column]
        if not (pd.api.types.is_object_dtype(series) or pd.api.types.is_string_dtype(series)):
            continue
        nonnull = series.dropna()
        if nonnull.empty:
            normalized[column] = pd.Series(np.nan, index=series.index, dtype="float64")
            continue
        if nonnull.map(lambda value: isinstance(value, (int, float, np.integer, np.floating, bool))).all():
            normalized[column] = pd.to_numeric(series, errors="coerce")
            continue
        normalized[column] = series.map(lambda value: None if pd.isna(value) else str(value))
    return normalized


def write_stata(df: pd.DataFrame, path: str | Path) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    _normalize_for_stata(df).to_stata(target, write_index=False, version=118)
