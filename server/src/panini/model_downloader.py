"""Background model download manager with progress tracking."""

from __future__ import annotations

import threading
from dataclasses import dataclass
from pathlib import Path

try:
    from huggingface_hub import snapshot_download
except ImportError:
    snapshot_download = None  # type: ignore[assignment]

from panini.model_storage import ModelStorage


@dataclass
class DownloadProgress:
    model_id: str
    bytes_downloaded: int
    bytes_total: int
    status: str  # "downloading", "complete", "failed", "cancelled"
    error: str | None = None


class ModelDownloader:
    """Manages background model downloads with progress tracking."""

    def __init__(self, storage: ModelStorage) -> None:
        self._storage = storage
        self._active_downloads: dict[str, DownloadProgress] = {}
        self._cancel_flags: dict[str, threading.Event] = {}
        self._lock = threading.Lock()

    def start_download(self, model_id: str, repo_id: str) -> bool:
        """Start downloading a model in the background. Returns False if already downloading."""
        if snapshot_download is None:
            raise RuntimeError(
                "huggingface_hub is not installed. Install with: pip install huggingface-hub"
            )

        with self._lock:
            if model_id in self._active_downloads:
                return False

            self._active_downloads[model_id] = DownloadProgress(
                model_id=model_id,
                bytes_downloaded=0,
                bytes_total=0,
                status="downloading",
            )
            cancel_event = threading.Event()
            self._cancel_flags[model_id] = cancel_event

        thread = threading.Thread(
            target=self._download_worker,
            args=(model_id, repo_id, cancel_event),
            daemon=True,
        )
        thread.start()
        return True

    def get_progress(self, model_id: str) -> DownloadProgress | None:
        with self._lock:
            return self._active_downloads.get(model_id)

    def is_downloading(self, model_id: str) -> bool:
        with self._lock:
            progress = self._active_downloads.get(model_id)
            return progress is not None and progress.status == "downloading"

    def cancel(self, model_id: str) -> None:
        with self._lock:
            cancel_event = self._cancel_flags.pop(model_id, None)
            if cancel_event:
                cancel_event.set()
            self._active_downloads.pop(model_id, None)

    def _download_worker(
        self, model_id: str, repo_id: str, cancel_event: threading.Event
    ) -> None:
        try:
            dest = self._storage.model_path(model_id)
            dest.mkdir(parents=True, exist_ok=True)

            snapshot_download(
                repo_id=repo_id,
                local_dir=str(dest),
                local_dir_use_symlinks=False,
            )

            if cancel_event.is_set():
                return

            with self._lock:
                self._active_downloads.pop(model_id, None)
                self._cancel_flags.pop(model_id, None)

        except Exception as exc:
            with self._lock:
                progress = self._active_downloads.get(model_id)
                if progress and not cancel_event.is_set():
                    progress.status = "failed"
                    progress.error = str(exc)
                self._cancel_flags.pop(model_id, None)
