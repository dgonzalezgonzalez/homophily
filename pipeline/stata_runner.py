from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

from .config import PipelineConfig


def run_stata_do(config: PipelineConfig, do_file: Path, *args: str) -> None:
    command_args = " ".join(f'"{arg}"' for arg in args)
    script = "\n".join(
        [
            f'global cd "{config.repo_root}"',
            f'global raw_dta "{config.raw_dta}"',
            f'do "{do_file}" {command_args}'.strip(),
            "exit, clear",
            "",
        ]
    )
    with tempfile.NamedTemporaryFile("w", suffix=".do", delete=False) as handle:
        handle.write(script)
        wrapper = Path(handle.name)
    try:
        subprocess.run([config.stata_bin, "-q", "do", str(wrapper)], check=True)
    finally:
        wrapper.unlink(missing_ok=True)

