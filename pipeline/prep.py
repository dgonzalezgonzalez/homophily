from __future__ import annotations

import re
from pathlib import Path

import numpy as np
import pandas as pd

from .config import PipelineConfig
from .io import read_stata, write_stata


NETWORKS = ("friend", "friend2", "enemy", "enemy2")


def load_base_sample(config: PipelineConfig) -> pd.DataFrame:
    df = read_stata(config.raw_dta)
    return df.loc[df["country"] == 1].copy()


def build_edge_table(base: pd.DataFrame, network: str) -> pd.DataFrame:
    edges = base[["usuario_id", network]].copy()
    edges[network] = edges[network].fillna("")
    edges[network] = edges[network].astype(str).str.split("|")
    edges = edges.explode(network)
    edges[network] = edges[network].str.strip()
    edges = edges.loc[edges[network] != ""].copy()
    edges[f"{network}_id"] = pd.to_numeric(edges[network], errors="coerce")
    edges = edges.loc[edges[f"{network}_id"].notna()].copy()
    edges[network] = edges.groupby("usuario_id").cumcount() + 1
    edges = edges[["usuario_id", f"{network}_id", network]].reset_index(drop=True)
    return edges


def build_match_long(matches: pd.DataFrame) -> pd.DataFrame:
    match_cols = [col for col in matches.columns if re.fullmatch(r"match\d+", col)]
    long = matches.melt(
        id_vars=["usuario_id"],
        value_vars=match_cols,
        var_name="match_var",
        value_name="match_id",
    )
    long["match_n"] = long["match_var"].str.extract(r"(\d+)").astype(int)
    long = long.drop(columns=["match_var"])
    long = long.sort_values(["usuario_id", "match_n"]).reset_index(drop=True)
    total_slots = len(match_cols)
    observed_count = long.groupby("usuario_id")["match_id"].transform(lambda s: s.notna().sum())
    unique_nonmissing = long.groupby("usuario_id")["match_id"].transform(lambda s: s.nunique(dropna=True))
    partial_missing = (observed_count > 0) & (observed_count < total_slots)

    long["match_group"] = long["match_id"].astype(object)
    long.loc[partial_missing & long["match_id"].isna(), "match_group"] = "__MISSING__"

    long["count_match"] = long.groupby(["usuario_id", "match_group"], dropna=False)["usuario_id"].transform("size")
    long.loc[observed_count == 0, "count_match"] = np.nan

    long["degree_match"] = unique_nonmissing + partial_missing.astype(int)
    long.loc[observed_count == 0, "degree_match"] = np.nan

    long["freq"] = long["count_match"] / total_slots
    weight_sum = long.groupby("usuario_id")["freq"].transform(lambda s: np.square(s.dropna()).sum())
    long["wdegree_match"] = 100.0 / weight_sum
    long.loc[observed_count == 0, "wdegree_match"] = np.nan
    return long.drop(columns=["match_group"])


def build_analysis_base(base: pd.DataFrame, matches: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    long = build_match_long(matches)
    degree = long[["usuario_id", "degree_match", "wdegree_match"]].drop_duplicates()
    wide_match = long.pivot(index="usuario_id", columns="match_n", values="match_id")
    wide_count = long.pivot(index="usuario_id", columns="match_n", values="count_match")
    wide_match.columns = [f"match_id{idx}" for idx in wide_match.columns]
    wide_count.columns = [f"count_match{idx}" for idx in wide_count.columns]
    exported = matches[["usuario_id"]].merge(wide_match, on="usuario_id", how="left")
    exported = exported.merge(wide_count, on="usuario_id", how="left")
    exported = exported.merge(degree, on="usuario_id", how="left")
    analysis_base = base.merge(exported, on="usuario_id", how="left")
    return analysis_base, long


def build_assortativity(long: pd.DataFrame, edge_table: pd.DataFrame, network: str) -> pd.DataFrame:
    max_count = long["count_match"].max()
    unique_pairs = long[["usuario_id", "match_id", "count_match"]].drop_duplicates()

    dir1 = edge_table[["usuario_id", f"{network}_id"]].rename(columns={f"{network}_id": "match_id"})
    dir1 = dir1.drop_duplicates().assign(**{f"assort_{network}_dir1": 1.0})

    dir2 = edge_table[["usuario_id", f"{network}_id"]].rename(
        columns={"usuario_id": "match_id", f"{network}_id": "usuario_id"}
    )
    dir2 = dir2.drop_duplicates().assign(**{f"assort_{network}_dir2": 1.0})

    assort = unique_pairs.merge(dir1, on=["usuario_id", "match_id"], how="left")
    assort = assort.merge(dir2, on=["usuario_id", "match_id"], how="left")
    assort[f"assort_{network}_dir1"] = assort[f"assort_{network}_dir1"].fillna(0.0)
    assort[f"assort_{network}_dir2"] = assort[f"assort_{network}_dir2"].fillna(0.0)
    assort[f"assort_{network}_union"] = (
        (assort[f"assort_{network}_dir1"] == 1.0) | (assort[f"assort_{network}_dir2"] == 1.0)
    ).astype(float)
    assort[f"assort_{network}_inter"] = (
        (assort[f"assort_{network}_dir1"] == 1.0) & (assort[f"assort_{network}_dir2"] == 1.0)
    ).astype(float)

    missing_match = assort["match_id"].isna()
    for col in (
        f"assort_{network}_dir1",
        f"assort_{network}_dir2",
        f"assort_{network}_union",
        f"assort_{network}_inter",
    ):
        assort.loc[missing_match, col] = np.nan
        assort[f"w{col}"] = assort[col] * (assort["count_match"] / max_count)

    return assort


def export_prepared_artifacts(config: PipelineConfig, matches_path: Path) -> None:
    base = load_base_sample(config)
    matches = read_stata(matches_path)
    analysis_base, long = build_analysis_base(base, matches)
    write_stata(analysis_base, config.temp_dir / "analysis_base.dta")

    for network in NETWORKS:
        edge_table = build_edge_table(base, network)
        write_stata(edge_table, config.temp_dir / f"{network}.dta")
        assort = build_assortativity(long, edge_table, network)
        write_stata(assort, config.temp_dir / f"assort_{network}.dta")
