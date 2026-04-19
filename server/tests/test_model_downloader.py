"""Tests for model download manager."""

import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock

from panini.model_downloader import ModelDownloader, DownloadProgress
from panini.model_storage import ModelStorage


class TestModelDownloader:
    @pytest.fixture
    def storage(self, tmp_path: Path) -> ModelStorage:
        return ModelStorage(models_dir=tmp_path)

    @pytest.fixture
    def downloader(self, storage: ModelStorage) -> ModelDownloader:
        return ModelDownloader(storage=storage)

    def test_no_active_download_initially(self, downloader: ModelDownloader):
        progress = downloader.get_progress("gemma-4-e4b")
        assert progress is None

    def test_start_download_creates_progress(self, downloader: ModelDownloader):
        with patch("panini.model_downloader.snapshot_download") as mock_dl:
            mock_dl.return_value = "/tmp/fake"
            downloader.start_download("gemma-4-e4b", "mlx-community/gemma-4-e4b-it-4bit")
            import time
            time.sleep(0.1)

    def test_cancel_removes_progress(self, downloader: ModelDownloader):
        downloader._active_downloads["test-model"] = DownloadProgress(
            model_id="test-model",
            bytes_downloaded=0,
            bytes_total=1000,
            status="downloading",
        )
        downloader.cancel("test-model")
        assert downloader.get_progress("test-model") is None

    def test_is_downloading(self, downloader: ModelDownloader):
        assert not downloader.is_downloading("test-model")
        downloader._active_downloads["test-model"] = DownloadProgress(
            model_id="test-model",
            bytes_downloaded=500,
            bytes_total=1000,
            status="downloading",
        )
        assert downloader.is_downloading("test-model")
