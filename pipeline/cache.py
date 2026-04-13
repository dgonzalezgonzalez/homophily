from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Iterable

from .config import PipelineConfig


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def combined_hash(parts: Iterable[str]) -> str:
    digest = hashlib.sha256()
    for part in parts:
        digest.update(part.encode("utf-8"))
    return digest.hexdigest()


class StageCache:
    def __init__(self, config: PipelineConfig) -> None:
        self.config = config

    def meta_path(self, stage: str) -> Path:
        return self.config.cache_meta_dir / f"{stage}.json"

    def data_path(self, name: str) -> Path:
        return self.config.cache_data_dir / name

    def load(self, stage: str) -> dict | None:
        path = self.meta_path(stage)
        if not path.exists():
            return None
        return json.loads(path.read_text())

    def save(self, stage: str, payload: dict) -> None:
        path = self.meta_path(stage)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2, sort_keys=True))

    def valid(self, stage: str, fingerprint: str, outputs: Iterable[Path]) -> bool:
        meta = self.load(stage)
        if not meta or meta.get("fingerprint") != fingerprint:
            return False
        return all(Path(path).exists() for path in outputs)

    def fingerprint(
        self,
        *,
        stage: str,
        inputs: Iterable[Path],
        code_paths: Iterable[Path],
        extra: Iterable[str] = (),
    ) -> str:
        parts = [stage]
        parts.extend(sha256_file(path) for path in inputs)
        parts.extend(sha256_file(path) for path in code_paths)
        parts.extend(extra)
        return combined_hash(parts)
