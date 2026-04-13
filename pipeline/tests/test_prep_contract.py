import pandas as pd

from pipeline.prep import build_analysis_base, build_assortativity, build_edge_table


def test_build_edge_table_splits_pipe_lists() -> None:
    base = pd.DataFrame({"usuario_id": [1.0, 2.0], "friend": ["3|4", ""]})
    result = build_edge_table(base, "friend")
    assert result.to_dict("records") == [
        {"usuario_id": 1.0, "friend_id": 3.0, "friend": 1},
        {"usuario_id": 1.0, "friend_id": 4.0, "friend": 2},
    ]


def test_analysis_base_and_assortativity_keep_match_positions() -> None:
    base = pd.DataFrame(
        {
            "usuario_id": [1.0, 2.0, 3.0],
            "country": [1.0, 1.0, 1.0],
            "friend": ["2", "", ""],
        }
    )
    matches = pd.DataFrame(
        {
            "usuario_id": [1.0, 2.0, 3.0],
            "match1": [2.0, 1.0, None],
            "match2": [2.0, 1.0, None],
        }
    )
    analysis_base, long = build_analysis_base(base, matches)
    assert analysis_base.loc[analysis_base["usuario_id"] == 1.0, "degree_match"].iloc[0] == 1.0
    assert analysis_base.loc[analysis_base["usuario_id"] == 1.0, "count_match1"].iloc[0] == 2.0

    edges = build_edge_table(base, "friend")
    assort = build_assortativity(long, edges, "friend")
    row = assort.loc[(assort["usuario_id"] == 1.0) & (assort["match_id"] == 2.0)].iloc[0]
    assert row["assort_friend_dir1"] == 1.0
    assert row["assort_friend_union"] == 1.0
    unmatched = assort.loc[assort["usuario_id"] == 3.0].iloc[0]
    assert pd.isna(unmatched["assort_friend_dir1"])
