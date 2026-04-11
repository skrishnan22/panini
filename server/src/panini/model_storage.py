"""Model file storage management."""

from __future__ import annotations

import shutil
from enum import Enum
from pathlib import Path


class ModelStatus(str, Enum):
    NOT_DOWNLOADED = "not_downloaded"
    DOWNLOADING = "downloading"
    READY = "ready"


class ModelStorage:
    """Manages local model files on disk."""

    def __init__(self, models_dir: Path | None = None) -> None:
        self._models_dir = (
            models_dir
            or Path.home()
            / "Library"
            / "Application Support"
            / "Panini"
            / "models"
        )

    @property
    def models_dir(self) -> Path:
        return self._models_dir

    def model_path(self, model_id: str) -> Path:
        return self._models_dir / model_id

    def status(self, model_id: str) -> ModelStatus:
        model_dir = self.model_path(model_id)
        if not model_dir.exists():
            return ModelStatus.NOT_DOWNLOADED
        if not any(model_dir.iterdir()):
            return ModelStatus.NOT_DOWNLOADED
        return ModelStatus.READY

    def disk_usage_bytes(self) -> int:
        if not self._models_dir.exists():
            return 0
        total = 0
        for path in self._models_dir.rglob("*"):
            if path.is_file():
                total += path.stat().st_size
        return total

    def delete(self, model_id: str) -> None:
        model_dir = self.model_path(model_id)
        if model_dir.exists():
            shutil.rmtree(model_dir)
