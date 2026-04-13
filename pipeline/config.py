from __future__ import annotations

from dataclasses import dataclass
import os
import re
import shutil
from pathlib import Path


DEFAULT_STATA_CANDIDATES = (
    "/Applications/StataNow/StataSE.app/Contents/MacOS/stata-se",
    "/Applications/Stata/StataSE.app/Contents/MacOS/stata-se",
    "stata-mp",
    "stata-se",
    "stata",
)


def _extract_main_do_global(main_do: Path, key: str) -> str | None:
    pattern = re.compile(rf'^\s*global\s+{re.escape(key)}\s+"([^"]+)"', re.MULTILINE)
    match = pattern.search(main_do.read_text())
    return match.group(1) if match else None


def detect_stata_binary(explicit: str | None = None) -> str:
    candidates = []
    if explicit:
        candidates.append(explicit)
    env_bin = os.environ.get("STATA_BIN")
    if env_bin:
        candidates.append(env_bin)
    candidates.extend(DEFAULT_STATA_CANDIDATES)
    for candidate in candidates:
        if Path(candidate).exists():
            return candidate
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    raise FileNotFoundError("Could not find a Stata executable. Set STATA_BIN.")


@dataclass(frozen=True)
class PipelineConfig:
    repo_root: Path
    raw_dta: Path
    stata_bin: str
    code_dir: Path
    temp_dir: Path
    output_dir: Path
    cache_dir: Path
    cache_meta_dir: Path
    cache_data_dir: Path
    baseline_dir: Path

    @classmethod
    def from_repo(
        cls,
        repo_root: str | Path,
        raw_dta: str | Path | None = None,
        stata_bin: str | None = None,
    ) -> "PipelineConfig":
        root = Path(repo_root).resolve()
        main_do = root / "code" / "main.do"
        inferred_raw = raw_dta or _extract_main_do_global(main_do, "raw_dta")
        if not inferred_raw:
            raise FileNotFoundError("Could not infer raw_dta. Pass --raw-dta.")
        cache_dir = root / ".cache" / "pipeline"
        return cls(
            repo_root=root,
            raw_dta=Path(inferred_raw).expanduser().resolve(),
            stata_bin=detect_stata_binary(stata_bin),
            code_dir=root / "code",
            temp_dir=root / "temp",
            output_dir=root / "output",
            cache_dir=cache_dir,
            cache_meta_dir=cache_dir / "meta",
            cache_data_dir=cache_dir / "data",
            baseline_dir=cache_dir / "baseline",
        )

    def ensure_dirs(self) -> None:
        for path in (
            self.temp_dir,
            self.output_dir,
            self.cache_dir,
            self.cache_meta_dir,
            self.cache_data_dir,
            self.baseline_dir,
        ):
            path.mkdir(parents=True, exist_ok=True)

