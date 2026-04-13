from pathlib import Path

from pipeline.cache import StageCache
from pipeline.config import PipelineConfig


def make_config(tmp_path: Path) -> PipelineConfig:
    root = tmp_path / "repo"
    (root / "code").mkdir(parents=True)
    (root / "temp").mkdir()
    (root / "output").mkdir()
    raw = root / "raw.dta"
    raw.write_text("raw")
    (root / "code" / "main.do").write_text('global raw_dta "raw.dta"\n')
    return PipelineConfig.from_repo(root, raw_dta=raw, stata_bin="/bin/echo")


def test_fingerprint_changes_when_input_changes(tmp_path: Path) -> None:
    config = make_config(tmp_path)
    code_path = config.code_dir / "prep.py"
    code_path.write_text("alpha")
    cache = StageCache(config)
    first = cache.fingerprint(stage="prep", inputs=[config.raw_dta], code_paths=[code_path], extra=["v1"])
    config.raw_dta.write_text("beta")
    second = cache.fingerprint(stage="prep", inputs=[config.raw_dta], code_paths=[code_path], extra=["v1"])
    assert first != second


def test_valid_requires_matching_fingerprint_and_outputs(tmp_path: Path) -> None:
    config = make_config(tmp_path)
    cache = StageCache(config)
    output = config.temp_dir / "artifact.txt"
    output.write_text("x")
    cache.save("prep", {"fingerprint": "abc"})
    assert cache.valid("prep", "abc", [output])
    output.unlink()
    assert not cache.valid("prep", "abc", [output])
    assert not cache.valid("prep", "def", [])

