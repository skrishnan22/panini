"""Tests for model storage service."""

import pytest
from pathlib import Path

from panini.model_storage import ModelStorage, ModelStatus


class TestModelStorage:
    @pytest.fixture
    def storage(self, tmp_path: Path) -> ModelStorage:
        return ModelStorage(models_dir=tmp_path)

    def test_status_not_downloaded(self, storage: ModelStorage):
        result = storage.status("gemma-4-e4b")
        assert result == ModelStatus.NOT_DOWNLOADED

    def test_status_ready_when_directory_exists(self, storage: ModelStorage, tmp_path: Path):
        (tmp_path / "gemma-4-e4b").mkdir()
        (tmp_path / "gemma-4-e4b" / "config.json").write_text("{}")
        result = storage.status("gemma-4-e4b")
        assert result == ModelStatus.READY

    def test_status_not_downloaded_for_empty_dir(self, storage: ModelStorage, tmp_path: Path):
        (tmp_path / "gemma-4-e4b").mkdir()
        result = storage.status("gemma-4-e4b")
        assert result == ModelStatus.NOT_DOWNLOADED

    def test_disk_usage_bytes_no_models(self, storage: ModelStorage):
        assert storage.disk_usage_bytes() == 0

    def test_disk_usage_bytes_with_model(self, storage: ModelStorage, tmp_path: Path):
        model_dir = tmp_path / "gemma-4-e4b"
        model_dir.mkdir()
        (model_dir / "weights.bin").write_bytes(b"x" * 1024)
        assert storage.disk_usage_bytes() == 1024

    def test_delete_model(self, storage: ModelStorage, tmp_path: Path):
        model_dir = tmp_path / "gemma-4-e4b"
        model_dir.mkdir()
        (model_dir / "config.json").write_text("{}")
        storage.delete("gemma-4-e4b")
        assert not model_dir.exists()

    def test_delete_nonexistent_is_noop(self, storage: ModelStorage):
        storage.delete("nonexistent")  # should not raise

    def test_model_path(self, storage: ModelStorage, tmp_path: Path):
        assert storage.model_path("gemma-4-e4b") == tmp_path / "gemma-4-e4b"
