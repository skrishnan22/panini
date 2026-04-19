# Settings Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the read-only SettingsView with a fully configurable settings window — model management with downloads, backend toggle, preset picker, hotkey configuration, cloud API key, and dictionary management.

**Architecture:** Native macOS Settings scene with 5 tabs (General, Models, Cloud, Hotkeys, Dictionary). UserDefaults for preferences, Keychain for API key. Server gets new model management endpoints. Server restarts on backend/model changes.

**Tech Stack:** SwiftUI, UserDefaults (`@AppStorage`), Security framework (Keychain), FastAPI, huggingface_hub (model downloads)

**Spec:** `docs/superpowers/specs/2026-04-11-settings-page-design.md`

---

## File Structure

### Server (Python)

| File | Action | Responsibility |
|------|--------|----------------|
| `shared/models.json` | Modify | Add `download_size_gb` field per model |
| `server/src/panini/types.py` | Modify | Add `download_size_gb` to `ModelInfo` |
| `server/src/panini/model_storage.py` | Create | Model file management — check downloaded, get size, delete |
| `server/src/panini/model_downloader.py` | Create | Background download with progress tracking |
| `server/src/panini/app.py` | Modify | Add model management endpoints |
| `server/tests/test_model_storage.py` | Create | Tests for ModelStorage |
| `server/tests/test_model_downloader.py` | Create | Tests for ModelDownloader |
| `server/tests/test_app.py` | Modify | Add model endpoint integration tests |

### macOS Client (Swift)

| File | Action | Responsibility |
|------|--------|----------------|
| `macos/Panini/Infrastructure/Config/UserSettings.swift` | Create | UserDefaults wrapper for all preferences |
| `macos/Panini/Infrastructure/Config/KeychainService.swift` | Create | Keychain CRUD for API key |
| `macos/Panini/Infrastructure/API/ModelManagementService.swift` | Create | HTTP client for model endpoints |
| `macos/Panini/UI/Settings/SettingsTheme.swift` | Create | Colors, fonts, spacing constants for settings UI |
| `macos/Panini/UI/Settings/SettingsView.swift` | Rewrite | Tabbed container with 5 tabs |
| `macos/Panini/UI/Settings/SettingsViewModel.swift` | Rewrite | Full observable view model |
| `macos/Panini/UI/Settings/GeneralTabView.swift` | Create | Backend toggle, preset picker, behavior, status |
| `macos/Panini/UI/Settings/ModelsTabView.swift` | Create | Model list with download/delete/progress |
| `macos/Panini/UI/Settings/CloudTabView.swift` | Create | API key field, connection test |
| `macos/Panini/UI/Settings/HotkeysTabView.swift` | Create | Predefined hotkey pickers |
| `macos/Panini/UI/Settings/DictionaryTabView.swift` | Create | Word list management |
| `macos/Panini/App/DIContainer.swift` | Modify | Wire new services |
| `macos/Panini/App/AppDelegate.swift` | Modify | Use settings for hotkeys, server restart |
| `macos/Panini/App/PaniniApp.swift` | Modify | Update Settings scene frame |
| `macos/Panini/Infrastructure/Server/ServerProcessManager.swift` | Modify | Accept dynamic config for restart |
| `macos/PaniniTests/UserSettingsTests.swift` | Create | Tests for UserSettings |
| `macos/PaniniTests/KeychainServiceTests.swift` | Create | Tests for KeychainService |
| `macos/PaniniTests/ModelManagementServiceTests.swift` | Create | Tests for model API client |
| `macos/PaniniTests/SettingsViewModelTests.swift` | Create | Tests for new SettingsViewModel |

---

### Task 1: Extend Model Registry with Download Sizes

**Files:**
- Modify: `shared/models.json`
- Modify: `server/src/panini/types.py:92-104`
- Test: `server/tests/test_app.py` (existing — verify no breakage)

- [ ] **Step 1: Add `download_size_gb` to `shared/models.json`**

```json
{
  "models": [
    {
      "id": "gemma-4-e2b",
      "name": "Gemma 4 E2B",
      "params": "2B",
      "backends": ["webgpu", "mlx"],
      "ram_required_gb": 2,
      "download_size_gb": 1.6,
      "quantization": "Q4",
      "capabilities": ["spelling", "grammar", "clarity"],
      "default_for": "webgpu",
      "mlx_repo": "mlx-community/gemma-4-e2b-it-4bit",
      "prompt_format": "gemma"
    },
    {
      "id": "gemma-4-e4b",
      "name": "Gemma 4 E4B",
      "params": "4B",
      "backends": ["webgpu", "mlx"],
      "ram_required_gb": 4,
      "download_size_gb": 3.1,
      "quantization": "Q4",
      "capabilities": ["spelling", "grammar", "clarity", "tone", "style"],
      "default_for": "mlx",
      "mlx_repo": "mlx-community/gemma-4-e4b-it-4bit",
      "prompt_format": "gemma"
    },
    {
      "id": "qwen-2.5-3b",
      "name": "Qwen 2.5 3B",
      "params": "3B",
      "backends": ["webgpu", "mlx"],
      "ram_required_gb": 3,
      "download_size_gb": 2.0,
      "quantization": "Q4",
      "capabilities": ["spelling", "grammar", "clarity", "style"],
      "mlx_repo": "mlx-community/Qwen2.5-3B-Instruct-4bit",
      "prompt_format": "chatml"
    }
  ]
}
```

- [ ] **Step 2: Add `download_size_gb` to Python `ModelInfo`**

In `server/src/panini/types.py`, add the field to the `ModelInfo` class:

```python
class ModelInfo(BaseModel):
    """Model registry entry loaded from shared/models.json."""

    id: str
    name: str
    params: str
    backends: list[str]
    ram_required_gb: int
    download_size_gb: float
    quantization: str
    capabilities: list[str]
    default_for: str | None = None
    mlx_repo: str | None = None
    prompt_format: str
```

- [ ] **Step 3: Run existing tests to verify nothing breaks**

Run: `cd /Users/skrishnan/development/panini/server && python -m pytest tests/ -v`
Expected: All existing tests pass.

- [ ] **Step 4: Commit**

```bash
git add shared/models.json server/src/panini/types.py
git commit -m "feat: add download_size_gb to model registry"
```

---

### Task 2: Server Model Storage Service

**Files:**
- Create: `server/src/panini/model_storage.py`
- Create: `server/tests/test_model_storage.py`

- [ ] **Step 1: Write failing tests for ModelStorage**

Create `server/tests/test_model_storage.py`:

```python
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/skrishnan/development/panini/server && python -m pytest tests/test_model_storage.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'panini.model_storage'`

- [ ] **Step 3: Implement ModelStorage**

Create `server/src/panini/model_storage.py`:

```python
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/skrishnan/development/panini/server && python -m pytest tests/test_model_storage.py -v`
Expected: All 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add server/src/panini/model_storage.py server/tests/test_model_storage.py
git commit -m "feat: add ModelStorage service for model file management"
```

---

### Task 3: Server Model Download Manager

**Files:**
- Create: `server/src/panini/model_downloader.py`
- Create: `server/tests/test_model_downloader.py`

- [ ] **Step 1: Write failing tests for ModelDownloader**

Create `server/tests/test_model_downloader.py`:

```python
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
            # download runs in a thread — give it a moment
            import time
            time.sleep(0.1)
            # After completion, progress should be cleared
            # (or still active if slow)

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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/skrishnan/development/panini/server && python -m pytest tests/test_model_downloader.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'panini.model_downloader'`

- [ ] **Step 3: Implement ModelDownloader**

Create `server/src/panini/model_downloader.py`:

```python
"""Background model download manager with progress tracking."""

from __future__ import annotations

import threading
from dataclasses import dataclass, field
from pathlib import Path

from huggingface_hub import snapshot_download

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/skrishnan/development/panini/server && python -m pytest tests/test_model_downloader.py -v`
Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add server/src/panini/model_downloader.py server/tests/test_model_downloader.py
git commit -m "feat: add ModelDownloader with background download and progress tracking"
```

---

### Task 4: Server Model Management Endpoints

**Files:**
- Modify: `server/src/panini/app.py`
- Modify: `server/tests/test_app.py`

- [ ] **Step 1: Write failing integration tests**

Add to `server/tests/test_app.py`:

```python
class TestModelStatusEndpoint:
    @pytest.mark.asyncio
    async def test_model_status_not_downloaded(self, app_client):
        async with await app_client() as client:
            response = await client.get("/models/gemma-4-e4b/status")
            assert response.status_code == 200
            data = response.json()
            assert data["model_id"] == "gemma-4-e4b"
            assert data["status"] == "not_downloaded"

    @pytest.mark.asyncio
    async def test_model_status_unknown_model(self, app_client):
        async with await app_client() as client:
            response = await client.get("/models/nonexistent/status")
            assert response.status_code == 404


class TestModelDeleteEndpoint:
    @pytest.mark.asyncio
    async def test_delete_downloaded_model(self, app_client, tmp_path):
        # Create a fake downloaded model
        model_dir = tmp_path / "models" / "gemma-4-e4b"
        model_dir.mkdir(parents=True)
        (model_dir / "config.json").write_text("{}")

        async with await app_client() as client:
            response = await client.delete("/models/gemma-4-e4b")
            assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_delete_unknown_model_returns_404(self, app_client):
        async with await app_client() as client:
            response = await client.delete("/models/nonexistent")
            assert response.status_code == 404
```

Update the `app_client` fixture in `server/tests/conftest.py` to pass a models directory:

```python
@pytest.fixture
def app_client(mock_backend: MockBackend, tmp_path: Path, shared_dir: Path):
    from panini.app import create_app
    from panini.backends import clear_backends, register_backend

    clear_backends()
    register_backend(mock_backend)

    models_dir = tmp_path / "models"
    models_dir.mkdir()

    app = create_app(
        default_backend="mock",
        default_model_id="gemma-4-e4b",
        dictionary_path=tmp_path / "dict.json",
        shared_dir=shared_dir,
        models_dir=models_dir,
    )

    transport = ASGITransport(app=app)

    async def _make_client() -> AsyncClient:
        return AsyncClient(transport=transport, base_url="http://test")

    return _make_client
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/skrishnan/development/panini/server && python -m pytest tests/test_app.py::TestModelStatusEndpoint -v`
Expected: FAIL — endpoints don't exist yet.

- [ ] **Step 3: Add model management endpoints to `app.py`**

Add to the `create_app` function in `server/src/panini/app.py`:

Import at top of file:
```python
from panini.model_storage import ModelStorage, ModelStatus
from panini.model_downloader import ModelDownloader
```

Update `create_app` signature to accept `models_dir`:
```python
def create_app(
    default_backend: str = "mlx",
    default_model_id: str = "gemma-4-e4b",
    dictionary_path: Path | None = None,
    shared_dir: Path | None = None,
    models_dir: Path | None = None,
) -> FastAPI:
```

Add after dictionary initialization:
```python
    model_storage = ModelStorage(models_dir=models_dir)
    model_downloader = ModelDownloader(storage=model_storage)

    @app.get("/models/{model_id}/status")
    async def model_status(model_id: str) -> dict[str, object]:
        if model_id not in models:
            raise HTTPException(status_code=404, detail=f"Unknown model '{model_id}'.")

        status = model_storage.status(model_id)
        if model_downloader.is_downloading(model_id):
            status = ModelStatus.DOWNLOADING

        result: dict[str, object] = {
            "model_id": model_id,
            "status": status.value,
        }

        if status == ModelStatus.DOWNLOADING:
            progress = model_downloader.get_progress(model_id)
            if progress:
                result["bytes_downloaded"] = progress.bytes_downloaded
                result["bytes_total"] = progress.bytes_total

        return result

    @app.post("/models/{model_id}/download")
    async def download_model(model_id: str) -> dict[str, str]:
        model_info = models.get(model_id)
        if model_info is None:
            raise HTTPException(status_code=404, detail=f"Unknown model '{model_id}'.")

        if model_storage.status(model_id) == ModelStatus.READY:
            return {"status": "already_downloaded", "model_id": model_id}

        if model_downloader.is_downloading(model_id):
            return {"status": "already_downloading", "model_id": model_id}

        repo_id = model_info.mlx_repo or model_info.id
        model_downloader.start_download(model_id, repo_id)
        return {"status": "started", "model_id": model_id}

    @app.get("/models/{model_id}/download/progress")
    async def download_progress(model_id: str) -> dict[str, object]:
        if model_id not in models:
            raise HTTPException(status_code=404, detail=f"Unknown model '{model_id}'.")

        progress = model_downloader.get_progress(model_id)
        if progress is None:
            status = model_storage.status(model_id)
            return {"model_id": model_id, "status": status.value}

        return {
            "model_id": model_id,
            "status": progress.status,
            "bytes_downloaded": progress.bytes_downloaded,
            "bytes_total": progress.bytes_total,
            "error": progress.error,
        }

    @app.post("/models/{model_id}/download/cancel")
    async def cancel_download(model_id: str) -> dict[str, str]:
        model_downloader.cancel(model_id)
        return {"status": "cancelled", "model_id": model_id}

    @app.delete("/models/{model_id}")
    async def delete_model(model_id: str) -> dict[str, str]:
        if model_id not in models:
            raise HTTPException(status_code=404, detail=f"Unknown model '{model_id}'.")

        if model_storage.status(model_id) == ModelStatus.NOT_DOWNLOADED:
            raise HTTPException(status_code=404, detail=f"Model '{model_id}' is not downloaded.")

        model_storage.delete(model_id)
        return {"status": "deleted", "model_id": model_id}
```

- [ ] **Step 4: Run all server tests**

Run: `cd /Users/skrishnan/development/panini/server && python -m pytest tests/ -v`
Expected: All tests pass (existing + new).

- [ ] **Step 5: Commit**

```bash
git add server/src/panini/app.py server/tests/test_app.py server/tests/conftest.py
git commit -m "feat: add model management endpoints (status, download, delete, progress)"
```

---

### Task 5: Swift UserSettings

**Files:**
- Create: `macos/Panini/Infrastructure/Config/UserSettings.swift`
- Create: `macos/PaniniTests/UserSettingsTests.swift`

- [ ] **Step 1: Write failing tests**

Create `macos/PaniniTests/UserSettingsTests.swift`:

```swift
import XCTest
@testable import GrammarAI

final class UserSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: UserSettings!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "UserSettingsTests")!
        defaults.removePersistentDomain(forName: "UserSettingsTests")
        settings = UserSettings(defaults: defaults)
    }

    func testDefaultPresetIsFix() {
        XCTAssertEqual(settings.defaultPreset, "fix")
    }

    func testSetDefaultPreset() {
        settings.defaultPreset = "improve"
        XCTAssertEqual(settings.defaultPreset, "improve")
        XCTAssertEqual(defaults.string(forKey: "defaultPreset"), "improve")
    }

    func testDefaultBackendIsLocal() {
        XCTAssertEqual(settings.backendChoice, .local)
    }

    func testSetBackendChoice() {
        settings.backendChoice = .cloud
        XCTAssertEqual(settings.backendChoice, .cloud)
    }

    func testDefaultModelID() {
        XCTAssertEqual(settings.selectedModelID, "gemma-4-e4b")
    }

    func testSetSelectedModelID() {
        settings.selectedModelID = "qwen-2.5-3b"
        XCTAssertEqual(settings.selectedModelID, "qwen-2.5-3b")
    }

    func testDefaultLaunchAtLogin() {
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testHotkeyDefaults() {
        XCTAssertEqual(settings.paletteHotkey, "cmd+shift+g")
        XCTAssertEqual(settings.fixHotkey, "cmd+shift+option+g")
        XCTAssertEqual(settings.paraphraseHotkey, "cmd+shift+option+p")
        XCTAssertEqual(settings.professionalHotkey, "cmd+shift+option+m")
    }

    func testSetHotkey() {
        settings.paletteHotkey = "cmd+shift+r"
        XCTAssertEqual(settings.paletteHotkey, "cmd+shift+r")
    }
}
```

- [ ] **Step 2: Implement UserSettings**

Create `macos/Panini/Infrastructure/Config/UserSettings.swift`:

```swift
import Foundation

enum BackendChoice: String {
    case local
    case cloud
}

final class UserSettings: ObservableObject {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            "defaultPreset": "fix",
            "backendChoice": BackendChoice.local.rawValue,
            "selectedModelID": "gemma-4-e4b",
            "launchAtLogin": false,
            "paletteHotkey": "cmd+shift+g",
            "fixHotkey": "cmd+shift+option+g",
            "paraphraseHotkey": "cmd+shift+option+p",
            "professionalHotkey": "cmd+shift+option+m",
        ])
    }

    var defaultPreset: String {
        get { defaults.string(forKey: "defaultPreset") ?? "fix" }
        set { defaults.set(newValue, forKey: "defaultPreset"); objectWillChange.send() }
    }

    var backendChoice: BackendChoice {
        get { BackendChoice(rawValue: defaults.string(forKey: "backendChoice") ?? "local") ?? .local }
        set { defaults.set(newValue.rawValue, forKey: "backendChoice"); objectWillChange.send() }
    }

    var selectedModelID: String {
        get { defaults.string(forKey: "selectedModelID") ?? "gemma-4-e4b" }
        set { defaults.set(newValue, forKey: "selectedModelID"); objectWillChange.send() }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: "launchAtLogin") }
        set { defaults.set(newValue, forKey: "launchAtLogin"); objectWillChange.send() }
    }

    var paletteHotkey: String {
        get { defaults.string(forKey: "paletteHotkey") ?? "cmd+shift+g" }
        set { defaults.set(newValue, forKey: "paletteHotkey"); objectWillChange.send() }
    }

    var fixHotkey: String {
        get { defaults.string(forKey: "fixHotkey") ?? "cmd+shift+option+g" }
        set { defaults.set(newValue, forKey: "fixHotkey"); objectWillChange.send() }
    }

    var paraphraseHotkey: String {
        get { defaults.string(forKey: "paraphraseHotkey") ?? "cmd+shift+option+p" }
        set { defaults.set(newValue, forKey: "paraphraseHotkey"); objectWillChange.send() }
    }

    var professionalHotkey: String {
        get { defaults.string(forKey: "professionalHotkey") ?? "cmd+shift+option+m" }
        set { defaults.set(newValue, forKey: "professionalHotkey"); objectWillChange.send() }
    }
}
```

- [ ] **Step 3: Run tests**

Run: `cd /Users/skrishnan/development/panini/macos && swift test --filter UserSettingsTests`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add macos/Panini/Infrastructure/Config/UserSettings.swift macos/PaniniTests/UserSettingsTests.swift
git commit -m "feat: add UserSettings for persistent preferences via UserDefaults"
```

---

### Task 6: Swift Keychain Service

**Files:**
- Create: `macos/Panini/Infrastructure/Config/KeychainService.swift`
- Create: `macos/PaniniTests/KeychainServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Create `macos/PaniniTests/KeychainServiceTests.swift`:

```swift
import XCTest
@testable import GrammarAI

final class KeychainServiceTests: XCTestCase {
    private let testService = "com.panini.test.keychain"

    override func tearDown() {
        super.tearDown()
        KeychainService.delete(service: testService, account: "api-key")
    }

    func testSaveAndRetrieve() throws {
        try KeychainService.save(service: testService, account: "api-key", data: "sk-test-key-123")
        let retrieved = KeychainService.retrieve(service: testService, account: "api-key")
        XCTAssertEqual(retrieved, "sk-test-key-123")
    }

    func testRetrieveNonexistent() {
        let result = KeychainService.retrieve(service: testService, account: "nonexistent")
        XCTAssertNil(result)
    }

    func testUpdateExistingKey() throws {
        try KeychainService.save(service: testService, account: "api-key", data: "old-key")
        try KeychainService.save(service: testService, account: "api-key", data: "new-key")
        let retrieved = KeychainService.retrieve(service: testService, account: "api-key")
        XCTAssertEqual(retrieved, "new-key")
    }

    func testDelete() throws {
        try KeychainService.save(service: testService, account: "api-key", data: "to-delete")
        KeychainService.delete(service: testService, account: "api-key")
        let result = KeychainService.retrieve(service: testService, account: "api-key")
        XCTAssertNil(result)
    }
}
```

- [ ] **Step 2: Implement KeychainService**

Create `macos/Panini/Infrastructure/Config/KeychainService.swift`:

```swift
import Foundation
import Security

enum KeychainService {
    static let defaultService = "com.panini.credentials"
    static let apiKeyAccount = "vercel-ai-gateway-key"

    static func save(service: String = defaultService, account: String, data: String) throws {
        guard let data = data.data(using: .utf8) else { return }

        delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PaniniError.keychainError(status)
        }
    }

    static func retrieve(service: String = defaultService, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String = defaultService, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

Also add the new error case to `macos/Panini/Domain/Errors.swift`. Read it first to see the existing enum, then add:

```swift
case keychainError(OSStatus)
```

- [ ] **Step 3: Run tests**

Run: `cd /Users/skrishnan/development/panini/macos && swift test --filter KeychainServiceTests`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add macos/Panini/Infrastructure/Config/KeychainService.swift macos/PaniniTests/KeychainServiceTests.swift macos/Panini/Domain/Errors.swift
git commit -m "feat: add KeychainService for secure API key storage"
```

---

### Task 7: Swift ModelManagementService

**Files:**
- Create: `macos/Panini/Infrastructure/API/ModelManagementService.swift`
- Create: `macos/PaniniTests/ModelManagementServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Create `macos/PaniniTests/ModelManagementServiceTests.swift`:

```swift
import XCTest
@testable import GrammarAI

final class ModelManagementServiceTests: XCTestCase {
    private var session: URLSession!
    private var service: ModelManagementService!

    override func setUp() {
        super.setUp()
        session = makeMockSession()
        service = ModelManagementService(
            baseURL: URL(string: "http://test")!,
            session: session
        )
    }

    func testFetchModelStatus() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertTrue(request.url!.path.hasSuffix("/models/gemma-4-e4b/status"))
            let body = #"{"model_id":"gemma-4-e4b","status":"ready"}"#
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                body.data(using: .utf8)!
            )
        }

        let status = try await service.fetchModelStatus(modelID: "gemma-4-e4b")
        XCTAssertEqual(status.modelID, "gemma-4-e4b")
        XCTAssertEqual(status.status, .ready)
    }

    func testStartDownload() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url!.path.hasSuffix("/models/gemma-4-e4b/download"))
            let body = #"{"status":"started","model_id":"gemma-4-e4b"}"#
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                body.data(using: .utf8)!
            )
        }

        try await service.startDownload(modelID: "gemma-4-e4b")
    }

    func testFetchDownloadProgress() async throws {
        MockURLProtocol.handler = { request in
            let body = #"{"model_id":"gemma-4-e4b","status":"downloading","bytes_downloaded":500,"bytes_total":1000,"error":null}"#
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                body.data(using: .utf8)!
            )
        }

        let progress = try await service.fetchDownloadProgress(modelID: "gemma-4-e4b")
        XCTAssertEqual(progress.bytesDownloaded, 500)
        XCTAssertEqual(progress.bytesTotal, 1000)
    }

    func testDeleteModel() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            let body = #"{"status":"deleted","model_id":"gemma-4-e4b"}"#
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                body.data(using: .utf8)!
            )
        }

        try await service.deleteModel(modelID: "gemma-4-e4b")
    }
}
```

- [ ] **Step 2: Implement ModelManagementService**

Create `macos/Panini/Infrastructure/API/ModelManagementService.swift`:

```swift
import Foundation

enum ModelDownloadStatus: String, Codable {
    case notDownloaded = "not_downloaded"
    case downloading
    case ready
}

struct ModelStatusResponse: Codable {
    let modelID: String
    let status: ModelDownloadStatus

    enum CodingKeys: String, CodingKey {
        case modelID = "model_id"
        case status
    }
}

struct DownloadProgressResponse: Codable {
    let modelID: String
    let status: String
    let bytesDownloaded: Int?
    let bytesTotal: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case modelID = "model_id"
        case status
        case bytesDownloaded = "bytes_downloaded"
        case bytesTotal = "bytes_total"
        case error
    }
}

struct ModelManagementService {
    let baseURL: URL
    let timeout: TimeInterval
    let session: URLSession

    init(baseURL: URL, timeout: TimeInterval = 30, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.session = session
    }

    func fetchModelStatus(modelID: String) async throws -> ModelStatusResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("models/\(modelID)/status"))
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PaniniError.backendRequestFailed("Failed to fetch model status.")
        }
        return try JSONDecoder().decode(ModelStatusResponse.self, from: data)
    }

    func startDownload(modelID: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("models/\(modelID)/download"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        let (_, response) = try await session.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(statusCode) else {
            throw PaniniError.backendRequestFailed("Failed to start model download.")
        }
    }

    func fetchDownloadProgress(modelID: String) async throws -> DownloadProgressResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("models/\(modelID)/download/progress"))
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PaniniError.backendRequestFailed("Failed to fetch download progress.")
        }
        return try JSONDecoder().decode(DownloadProgressResponse.self, from: data)
    }

    func cancelDownload(modelID: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("models/\(modelID)/download/cancel"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        let (_, response) = try await session.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(statusCode) else {
            throw PaniniError.backendRequestFailed("Failed to cancel download.")
        }
    }

    func deleteModel(modelID: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("models/\(modelID)"))
        request.httpMethod = "DELETE"
        request.timeoutInterval = timeout
        let (_, response) = try await session.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(statusCode) else {
            throw PaniniError.backendRequestFailed("Failed to delete model.")
        }
    }
}
```

- [ ] **Step 3: Run tests**

Run: `cd /Users/skrishnan/development/panini/macos && swift test --filter ModelManagementServiceTests`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add macos/Panini/Infrastructure/API/ModelManagementService.swift macos/PaniniTests/ModelManagementServiceTests.swift
git commit -m "feat: add ModelManagementService for model download API"
```

---

### Task 8: Rewrite SettingsViewModel

**Files:**
- Rewrite: `macos/Panini/UI/Settings/SettingsViewModel.swift`
- Create: `macos/PaniniTests/SettingsViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

Create `macos/PaniniTests/SettingsViewModelTests.swift`:

```swift
import XCTest
@testable import GrammarAI

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: UserSettings!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsViewModelTests")!
        defaults.removePersistentDomain(forName: "SettingsViewModelTests")
        settings = UserSettings(defaults: defaults)
        session = makeMockSession()
    }

    private func makeViewModel() -> SettingsViewModel {
        let config = AppConfig()
        let healthClient = ServerHealthClient(baseURL: URL(string: "http://test")!, session: session)
        let permissionService = AccessibilityPermissionService()
        let dictionaryService = DictionaryService(baseURL: URL(string: "http://test")!, session: session)
        let modelService = ModelManagementService(baseURL: URL(string: "http://test")!, session: session)

        return SettingsViewModel(
            config: config,
            userSettings: settings,
            healthClient: healthClient,
            permissionService: permissionService,
            dictionaryService: dictionaryService,
            modelService: modelService
        )
    }

    func testDefaultPresetFromSettings() {
        settings.defaultPreset = "improve"
        let vm = makeViewModel()
        XCTAssertEqual(vm.selectedPreset, "improve")
    }

    func testSetPresetUpdatesSettings() {
        let vm = makeViewModel()
        vm.selectedPreset = "professional"
        XCTAssertEqual(settings.defaultPreset, "professional")
    }

    func testBackendChoiceFromSettings() {
        settings.backendChoice = .cloud
        let vm = makeViewModel()
        XCTAssertEqual(vm.backendChoice, .cloud)
    }

    func testAvailablePresetsMatchesSelectionActions() {
        let vm = makeViewModel()
        let presetIDs = vm.availablePresets.map(\.id)
        XCTAssertEqual(presetIDs, ["fix", "improve", "professional", "casual", "paraphrase"])
    }

    func testHotkeyConflictDetection() {
        let vm = makeViewModel()
        settings.paletteHotkey = "cmd+shift+g"
        settings.fixHotkey = "cmd+shift+g"
        XCTAssertTrue(vm.hasHotkeyConflict)
    }

    func testNoHotkeyConflictWithDefaults() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.hasHotkeyConflict)
    }
}
```

- [ ] **Step 2: Rewrite SettingsViewModel**

Replace the contents of `macos/Panini/UI/Settings/SettingsViewModel.swift`:

```swift
import Combine
import Foundation

struct PresetOption: Identifiable {
    let id: String
    let name: String
    let description: String
}

struct ModelEntry: Identifiable {
    let id: String
    let name: String
    let params: String
    let ramGB: Int
    let downloadSizeGB: Double
    let isDefault: Bool
    var downloadStatus: ModelDownloadStatus
    var downloadProgress: Double?
    var bytesDownloaded: Int?
    var bytesTotal: Int?
}

@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - General

    @Published var selectedPreset: String {
        didSet { userSettings.defaultPreset = selectedPreset }
    }

    @Published var backendChoice: BackendChoice {
        didSet {
            userSettings.backendChoice = backendChoice
            onBackendOrModelChanged?()
        }
    }

    @Published var launchAtLogin: Bool {
        didSet { userSettings.launchAtLogin = launchAtLogin }
    }

    @Published var selectedModelID: String {
        didSet {
            userSettings.selectedModelID = selectedModelID
            onBackendOrModelChanged?()
        }
    }

    // MARK: - Status

    @Published var serverStatus: String = "Starting"
    @Published var accessibilityGranted: Bool = false

    // MARK: - Models

    @Published var models: [ModelEntry] = []
    @Published var totalDiskUsageLabel: String = "0 GB used by models"

    // MARK: - Cloud

    @Published var apiKey: String = "" {
        didSet { saveAPIKey() }
    }
    @Published var connectionTestStatus: ConnectionTestStatus = .untested

    enum ConnectionTestStatus: Equatable {
        case untested
        case testing
        case connected
        case failed(String)
    }

    // MARK: - Hotkeys

    @Published var paletteHotkey: String {
        didSet { userSettings.paletteHotkey = paletteHotkey; onHotkeysChanged?() }
    }

    @Published var fixHotkey: String {
        didSet { userSettings.fixHotkey = fixHotkey; onHotkeysChanged?() }
    }

    @Published var paraphraseHotkey: String {
        didSet { userSettings.paraphraseHotkey = paraphraseHotkey; onHotkeysChanged?() }
    }

    @Published var professionalHotkey: String {
        didSet { userSettings.professionalHotkey = professionalHotkey; onHotkeysChanged?() }
    }

    var hasHotkeyConflict: Bool {
        let all = [paletteHotkey, fixHotkey, paraphraseHotkey, professionalHotkey]
        return Set(all).count != all.count
    }

    // MARK: - Dictionary

    @Published var dictionaryWords: [String] = []
    @Published var newDictionaryWord: String = ""
    @Published var lastError: String?

    // MARK: - Callbacks

    var onBackendOrModelChanged: (() -> Void)?
    var onHotkeysChanged: (() -> Void)?

    // MARK: - Dependencies

    private let config: AppConfig
    private let userSettings: UserSettings
    private let healthClient: ServerHealthChecking
    private let permissionService: AccessibilityPermissionService
    private let dictionaryService: DictionaryService
    private let modelService: ModelManagementService

    private var downloadPollTimer: Timer?

    let availablePresets: [PresetOption] = [
        PresetOption(id: "fix", name: "Fix", description: "Correct grammar and spelling"),
        PresetOption(id: "improve", name: "Improve", description: "Polish clarity and flow"),
        PresetOption(id: "professional", name: "Professional", description: "Rewrite in a professional tone"),
        PresetOption(id: "casual", name: "Casual", description: "Make the tone more casual"),
        PresetOption(id: "paraphrase", name: "Paraphrase", description: "Generate rewrite variants"),
    ]

    let hotkeyOptions: [String] = [
        "cmd+shift+g", "cmd+shift+r", "ctrl+shift+g", "cmd+shift+;",
        "cmd+shift+option+g", "cmd+shift+option+r", "ctrl+shift+option+g",
        "cmd+shift+option+f", "ctrl+shift+f",
        "cmd+shift+option+p", "cmd+shift+option+h", "ctrl+shift+p",
        "cmd+shift+option+m", "cmd+shift+option+j", "ctrl+shift+m",
    ]

    init(
        config: AppConfig,
        userSettings: UserSettings,
        healthClient: ServerHealthChecking,
        permissionService: AccessibilityPermissionService,
        dictionaryService: DictionaryService,
        modelService: ModelManagementService
    ) {
        self.config = config
        self.userSettings = userSettings
        self.healthClient = healthClient
        self.permissionService = permissionService
        self.dictionaryService = dictionaryService
        self.modelService = modelService

        self.selectedPreset = userSettings.defaultPreset
        self.backendChoice = userSettings.backendChoice
        self.launchAtLogin = userSettings.launchAtLogin
        self.selectedModelID = userSettings.selectedModelID
        self.paletteHotkey = userSettings.paletteHotkey
        self.fixHotkey = userSettings.fixHotkey
        self.paraphraseHotkey = userSettings.paraphraseHotkey
        self.professionalHotkey = userSettings.professionalHotkey
        self.accessibilityGranted = permissionService.isGranted()

        loadAPIKey()
    }

    // MARK: - Status

    func refreshServerHealth() async {
        let healthy = await healthClient.isHealthy()
        serverStatus = healthy ? "Healthy" : "Error"
    }

    func refreshPermission() {
        accessibilityGranted = permissionService.isGranted()
    }

    func requestAccessibilityPermission() {
        permissionService.requestIfNeeded()
        refreshPermission()
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }

    // MARK: - Models

    func loadModels() async {
        do {
            let response = try await modelService.fetchModelList()
            var entries: [ModelEntry] = []
            for model in response {
                let statusResponse = try await modelService.fetchModelStatus(modelID: model.id)
                entries.append(ModelEntry(
                    id: model.id,
                    name: model.name,
                    params: model.params,
                    ramGB: model.ramRequiredGB,
                    downloadSizeGB: model.downloadSizeGB,
                    isDefault: model.defaultFor == "mlx",
                    downloadStatus: statusResponse.status,
                    downloadProgress: nil,
                    bytesDownloaded: nil,
                    bytesTotal: nil
                ))
            }
            models = entries
        } catch {
            lastError = error.localizedDescription
        }
    }

    func downloadModel(_ modelID: String) async {
        do {
            try await modelService.startDownload(modelID: modelID)
            if let index = models.firstIndex(where: { $0.id == modelID }) {
                models[index].downloadStatus = .downloading
            }
            startPollingProgress(modelID: modelID)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func cancelDownload(_ modelID: String) async {
        do {
            try await modelService.cancelDownload(modelID: modelID)
            if let index = models.firstIndex(where: { $0.id == modelID }) {
                models[index].downloadStatus = .notDownloaded
                models[index].downloadProgress = nil
            }
            stopPollingProgress()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteModel(_ modelID: String) async {
        do {
            try await modelService.deleteModel(modelID: modelID)
            if let index = models.firstIndex(where: { $0.id == modelID }) {
                models[index].downloadStatus = .notDownloaded
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func startPollingProgress(modelID: String) {
        stopPollingProgress()
        downloadPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollProgress(modelID: modelID)
            }
        }
    }

    private func stopPollingProgress() {
        downloadPollTimer?.invalidate()
        downloadPollTimer = nil
    }

    private func pollProgress(modelID: String) async {
        do {
            let progress = try await modelService.fetchDownloadProgress(modelID: modelID)
            guard let index = models.firstIndex(where: { $0.id == modelID }) else { return }

            if progress.status == "ready" || progress.status == "not_downloaded" {
                models[index].downloadStatus = ModelDownloadStatus(rawValue: progress.status) ?? .notDownloaded
                models[index].downloadProgress = nil
                stopPollingProgress()
            } else if progress.status == "downloading" {
                models[index].downloadStatus = .downloading
                models[index].bytesDownloaded = progress.bytesDownloaded
                models[index].bytesTotal = progress.bytesTotal
                if let downloaded = progress.bytesDownloaded, let total = progress.bytesTotal, total > 0 {
                    models[index].downloadProgress = Double(downloaded) / Double(total)
                }
            } else if progress.status == "failed" {
                models[index].downloadStatus = .notDownloaded
                models[index].downloadProgress = nil
                lastError = progress.error ?? "Download failed."
                stopPollingProgress()
            }
        } catch {
            stopPollingProgress()
        }
    }

    var hasAnyModelDownloaded: Bool {
        models.contains { $0.downloadStatus == .ready }
    }

    // MARK: - Cloud

    func testConnection() async {
        connectionTestStatus = .testing
        let healthy = await healthClient.isHealthy()
        connectionTestStatus = healthy ? .connected : .failed("Could not connect to backend.")
    }

    private func loadAPIKey() {
        apiKey = KeychainService.retrieve(account: KeychainService.apiKeyAccount) ?? ""
    }

    private func saveAPIKey() {
        if apiKey.isEmpty {
            KeychainService.delete(account: KeychainService.apiKeyAccount)
        } else {
            try? KeychainService.save(account: KeychainService.apiKeyAccount, data: apiKey)
        }
    }

    // MARK: - Dictionary

    func loadDictionary() async {
        do {
            dictionaryWords = try await dictionaryService.listWords()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addDictionaryWord() async {
        let word = newDictionaryWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        do {
            try await dictionaryService.addWord(word)
            newDictionaryWord = ""
            await loadDictionary()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func removeDictionaryWord(_ word: String) async {
        do {
            try await dictionaryService.removeWord(word)
            await loadDictionary()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Hotkeys

    func resetHotkeysToDefaults() {
        paletteHotkey = "cmd+shift+g"
        fixHotkey = "cmd+shift+option+g"
        paraphraseHotkey = "cmd+shift+option+p"
        professionalHotkey = "cmd+shift+option+m"
    }
}
```

Note: This requires adding a `fetchModelList` method to `ModelManagementService`. Add to `ModelManagementService.swift`:

```swift
struct ModelListEntry: Codable {
    let id: String
    let name: String
    let params: String
    let ramRequiredGB: Int
    let downloadSizeGB: Double
    let defaultFor: String?

    enum CodingKeys: String, CodingKey {
        case id, name, params
        case ramRequiredGB = "ram_required_gb"
        case downloadSizeGB = "download_size_gb"
        case defaultFor = "default_for"
    }
}

// Add to ModelManagementService struct:
func fetchModelList() async throws -> [ModelListEntry] {
    var request = URLRequest(url: baseURL.appendingPathComponent("models"))
    request.timeoutInterval = timeout
    let (data, response) = try await session.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw PaniniError.backendRequestFailed("Failed to fetch model list.")
    }
    struct ModelsResponse: Codable {
        let models: [ModelListEntry]
    }
    return try JSONDecoder().decode(ModelsResponse.self, from: data).models
}
```

- [ ] **Step 3: Run tests**

Run: `cd /Users/skrishnan/development/panini/macos && swift test --filter SettingsViewModelTests`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add macos/Panini/UI/Settings/SettingsViewModel.swift macos/PaniniTests/SettingsViewModelTests.swift macos/Panini/Infrastructure/API/ModelManagementService.swift
git commit -m "feat: rewrite SettingsViewModel with full settings management"
```

---

### Task 9: Settings Theme and Shared Components

**Files:**
- Create: `macos/Panini/UI/Settings/SettingsTheme.swift`

- [ ] **Step 1: Create SettingsTheme**

Create `macos/Panini/UI/Settings/SettingsTheme.swift`:

```swift
import SwiftUI

struct SettingsTheme {
    // Section headers
    static let sectionHeaderFont = Font.custom("Georgia", size: 11)
    static let sectionHeaderColor = Color(red: 0.541, green: 0.518, blue: 0.471)
    static let sectionHeaderSpacing: CGFloat = 0.5

    // Cards
    static let cardBackground = Color.white
    static let cardBorder = Color(white: 0.867)
    static let cardCornerRadius: CGFloat = 10

    // Accent
    static let accentGreen = Color(red: 0.298, green: 0.561, blue: 0.322)
    static let accentGreenLight = Color(red: 0.91, green: 0.96, blue: 0.914)
    static let accentGreenBorder = Color(red: 0.298, green: 0.561, blue: 0.322).opacity(0.24)

    // Status
    static let healthyColor = Color(red: 0.298, green: 0.561, blue: 0.322)
    static let errorColor = Color.red
    static let warningColor = Color(red: 0.541, green: 0.427, blue: 0.169)

    // Badges
    static let badgeCornerRadius: CGFloat = 4
    static let badgeFont = Font.system(size: 9, weight: .semibold)

    // Progress bar
    static let progressHeight: CGFloat = 4
    static let progressBackground = Color(white: 0.933)
    static let progressFill = LinearGradient(
        colors: [Color(red: 0.545, green: 0.765, blue: 0.29), Color(red: 0.298, green: 0.686, blue: 0.314)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Preset pills
    static let pillCornerRadius: CGFloat = 20
    static let pillFont = Font.system(size: 12, weight: .semibold)

    // Content
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let destructiveText = Color(red: 0.8, green: 0.267, blue: 0.267)

    // Dark mode adaptations
    static func cardBackgroundColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.15) : .white
    }

    static func cardBorderColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color(white: 0.867)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(SettingsTheme.sectionHeaderFont)
            .foregroundColor(SettingsTheme.sectionHeaderColor)
            .tracking(SettingsTheme.sectionHeaderSpacing)
            .fontWeight(.semibold)
    }
}

struct SettingsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: SettingsTheme.cardCornerRadius, style: .continuous)
                    .fill(SettingsTheme.cardBackgroundColor(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsTheme.cardCornerRadius, style: .continuous)
                    .stroke(SettingsTheme.cardBorderColor(for: colorScheme), lineWidth: 1)
            )
    }
}

struct PresetPill: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(SettingsTheme.pillFont)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundColor(isSelected ? Color(red: 0.165, green: 0.329, blue: 0.188) : .secondary)
                .background(
                    Capsule()
                        .fill(isSelected ? SettingsTheme.accentGreenLight : Color.secondary.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? SettingsTheme.accentGreenBorder : Color.secondary.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct StatusDot: View {
    let healthy: Bool

    var body: some View {
        Circle()
            .fill(healthy ? SettingsTheme.healthyColor : SettingsTheme.errorColor)
            .frame(width: 7, height: 7)
    }
}

struct ModelBadge: View {
    let text: String
    let style: BadgeStyle

    enum BadgeStyle {
        case recommended
        case defaultModel
        case ready
        case downloading
    }

    var body: some View {
        Text(text.uppercased())
            .font(SettingsTheme.badgeFont)
            .tracking(0.3)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundColor(foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: SettingsTheme.badgeCornerRadius)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsTheme.badgeCornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var foregroundColor: Color {
        switch style {
        case .recommended: return Color(red: 0.165, green: 0.329, blue: 0.188)
        case .defaultModel: return .white
        case .ready: return Color(red: 0.165, green: 0.329, blue: 0.188)
        case .downloading: return Color(red: 0.541, green: 0.427, blue: 0.169)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .recommended: return SettingsTheme.accentGreenLight
        case .defaultModel: return SettingsTheme.accentGreen
        case .ready: return SettingsTheme.accentGreenLight
        case .downloading: return Color(red: 1.0, green: 0.953, blue: 0.878)
        }
    }

    private var borderColor: Color {
        switch style {
        case .recommended: return SettingsTheme.accentGreenBorder
        case .defaultModel: return .clear
        case .ready: return SettingsTheme.accentGreenBorder
        case .downloading: return Color(red: 0.784, green: 0.588, blue: 0.196).opacity(0.2)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add macos/Panini/UI/Settings/SettingsTheme.swift
git commit -m "feat: add SettingsTheme and shared UI components"
```

---

### Task 10: Settings Tab Views and Main Container

**Files:**
- Create: `macos/Panini/UI/Settings/GeneralTabView.swift`
- Create: `macos/Panini/UI/Settings/ModelsTabView.swift`
- Create: `macos/Panini/UI/Settings/CloudTabView.swift`
- Create: `macos/Panini/UI/Settings/HotkeysTabView.swift`
- Create: `macos/Panini/UI/Settings/DictionaryTabView.swift`
- Rewrite: `macos/Panini/UI/Settings/SettingsView.swift`

- [ ] **Step 1: Create GeneralTabView**

Create `macos/Panini/UI/Settings/GeneralTabView.swift`:

```swift
import SwiftUI

struct GeneralTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var statusExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                backendSection
                presetSection
                behaviorSection
                statusSection
            }
            .padding(20)
        }
    }

    private var backendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Backend")
            SettingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $viewModel.backendChoice) {
                        Text("Local (MLX)").tag(BackendChoice.local)
                        Text("Cloud (Vercel AI Gateway)").tag(BackendChoice.cloud)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(viewModel.backendChoice == .local
                        ? "Running on-device with downloaded models. No data leaves your machine."
                        : "Using Vercel AI Gateway. Text is sent to cloud for processing.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Default Preset")
            SettingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    FlowLayout(spacing: 6) {
                        ForEach(viewModel.availablePresets) { preset in
                            PresetPill(
                                name: preset.name,
                                isSelected: viewModel.selectedPreset == preset.id
                            ) {
                                viewModel.selectedPreset = preset.id
                            }
                        }
                    }
                    Text("The preset used when you trigger a correction via the review hotkey.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Behavior")
            SettingsCard {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Launch at login")
                            .font(.system(size: 13))
                        Text("Start Panini automatically when you log in")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(12)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    statusExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(statusExpanded ? 90 : 0))
                    SectionHeader(title: "Status")
                }
            }
            .buttonStyle(.plain)

            if statusExpanded {
                SettingsCard {
                    VStack(spacing: 0) {
                        statusRow(label: "Server", value: viewModel.serverStatus, healthy: viewModel.serverStatus == "Healthy")
                        Divider()
                        statusRow(label: "Accessibility", value: viewModel.accessibilityGranted ? "Granted" : "Not Granted", healthy: viewModel.accessibilityGranted)
                        if !viewModel.accessibilityGranted {
                            Divider()
                            HStack {
                                Spacer()
                                Button("Open System Settings") {
                                    viewModel.openSystemSettings()
                                }
                                .font(.system(size: 12))
                            }
                            .padding(12)
                        }
                        Divider()
                        HStack {
                            Text("Active Model")
                                .font(.system(size: 13))
                            Spacer()
                            Text(viewModel.selectedModelID)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                    }
                }
            }
        }
    }

    private func statusRow(label: String, value: String, healthy: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            HStack(spacing: 6) {
                StatusDot(healthy: healthy)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(healthy ? SettingsTheme.healthyColor : SettingsTheme.errorColor)
            }
        }
        .padding(12)
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
```

- [ ] **Step 2: Create ModelsTabView**

Create `macos/Panini/UI/Settings/ModelsTabView.swift`:

```swift
import SwiftUI

struct ModelsTabView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !viewModel.hasAnyModelDownloaded {
                    nudgeBanner
                }
                modelList
                storageFooter
            }
            .padding(20)
        }
        .task { await viewModel.loadModels() }
    }

    private var nudgeBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 18))
                .foregroundColor(SettingsTheme.accentGreen)
                .frame(width: 36, height: 36)
                .background(SettingsTheme.accentGreenLight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Download a model to get started")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.165, green: 0.329, blue: 0.188))
                Text("We recommend **Gemma 4 E4B** for the best balance of speed and quality.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.29, green: 0.478, blue: 0.31))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [SettingsTheme.accentGreenLight, Color(red: 0.945, green: 0.973, blue: 0.914)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(SettingsTheme.accentGreenBorder, lineWidth: 1)
        )
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Available Models")
            SettingsCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.models.enumerated()), id: \.element.id) { index, model in
                        if index > 0 { Divider() }
                        modelRow(model)
                    }
                }
            }
        }
    }

    private func modelRow(_ model: ModelEntry) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.system(size: 13, weight: .semibold))

                        if model.isDefault && model.downloadStatus == .ready {
                            ModelBadge(text: "Default", style: .defaultModel)
                        }

                        if model.downloadStatus == .ready {
                            ModelBadge(text: "Ready", style: .ready)
                        } else if model.downloadStatus == .downloading {
                            ModelBadge(text: "Downloading", style: .downloading)
                        }
                    }

                    Text("\(model.params) parameters · \(String(format: "%.1f", model.downloadSizeGB)) GB · Requires \(model.ramGB) GB RAM")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                modelActionButton(model)
            }
            .padding(14)
            .background(model.downloadStatus == .ready ? SettingsTheme.accentGreenLight.opacity(0.3) : .clear)

            if model.downloadStatus == .downloading {
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(SettingsTheme.progressBackground)
                                .frame(height: SettingsTheme.progressHeight)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(SettingsTheme.progressFill)
                                .frame(width: geometry.size.width * (model.downloadProgress ?? 0), height: SettingsTheme.progressHeight)
                        }
                    }
                    .frame(height: SettingsTheme.progressHeight)

                    if let downloaded = model.bytesDownloaded, let total = model.bytesTotal, total > 0 {
                        HStack {
                            Spacer()
                            Text("\(formatBytes(downloaded)) / \(formatBytes(total)) · \(Int((model.downloadProgress ?? 0) * 100))%")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
    }

    @ViewBuilder
    private func modelActionButton(_ model: ModelEntry) -> some View {
        switch model.downloadStatus {
        case .notDownloaded:
            Button("Download") {
                Task { await viewModel.downloadModel(model.id) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .downloading:
            Button("Cancel") {
                Task { await viewModel.cancelDownload(model.id) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(.secondary)

        case .ready:
            Button("Delete") {
                Task { await viewModel.deleteModel(model.id) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(SettingsTheme.destructiveText)
            .disabled(model.id == viewModel.selectedModelID)
        }
    }

    private var storageFooter: some View {
        HStack {
            Spacer()
            Text(viewModel.totalDiskUsageLabel)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}
```

- [ ] **Step 3: Create CloudTabView**

Create `macos/Panini/UI/Settings/CloudTabView.swift`:

```swift
import SwiftUI

struct CloudTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showAPIKey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.backendChoice == .local {
                    disabledMessage
                } else {
                    apiKeySection
                    connectionSection
                }
            }
            .padding(20)
        }
    }

    private var disabledMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Switch to Cloud backend in General to configure.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Vercel AI Gateway")
            SettingsCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.system(size: 13, weight: .medium))

                    HStack {
                        if showAPIKey {
                            TextField("Enter API key", text: $viewModel.apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Enter API key", text: $viewModel.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Stored securely in macOS Keychain.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Connection")
            SettingsCard {
                HStack {
                    Button("Test Connection") {
                        Task { await viewModel.testConnection() }
                    }
                    .disabled(viewModel.apiKey.isEmpty)

                    Spacer()

                    connectionStatusView
                }
                .padding(14)
            }
        }
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch viewModel.connectionTestStatus {
        case .untested:
            HStack(spacing: 6) {
                Circle().fill(Color.secondary.opacity(0.3)).frame(width: 7, height: 7)
                Text("Untested").font(.system(size: 12)).foregroundColor(.secondary)
            }
        case .testing:
            ProgressView().controlSize(.small)
        case .connected:
            HStack(spacing: 6) {
                StatusDot(healthy: true)
                Text("Connected").font(.system(size: 12, weight: .medium)).foregroundColor(SettingsTheme.healthyColor)
            }
        case .failed(let message):
            HStack(spacing: 6) {
                StatusDot(healthy: false)
                Text(message).font(.system(size: 12)).foregroundColor(SettingsTheme.errorColor)
            }
        }
    }
}
```

- [ ] **Step 4: Create HotkeysTabView**

Create `macos/Panini/UI/Settings/HotkeysTabView.swift`:

```swift
import SwiftUI

struct HotkeysTabView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hotkeyList

                if viewModel.hasHotkeyConflict {
                    conflictWarning
                }

                resetButton
            }
            .padding(20)
        }
    }

    private var hotkeyList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Keyboard Shortcuts")
            SettingsCard {
                VStack(spacing: 0) {
                    hotkeyRow(label: "Command Palette", binding: $viewModel.paletteHotkey)
                    Divider()
                    hotkeyRow(label: "Fix (direct)", binding: $viewModel.fixHotkey)
                    Divider()
                    hotkeyRow(label: "Paraphrase (direct)", binding: $viewModel.paraphraseHotkey)
                    Divider()
                    hotkeyRow(label: "Professional (direct)", binding: $viewModel.professionalHotkey)
                }
            }
        }
    }

    private func hotkeyRow(label: String, binding: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Picker("", selection: binding) {
                ForEach(viewModel.hotkeyOptions, id: \.self) { option in
                    Text(formatHotkey(option)).tag(option)
                }
            }
            .frame(width: 200)
            .labelsHidden()
        }
        .padding(12)
    }

    private var conflictWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(SettingsTheme.warningColor)
            Text("Two or more actions share the same keyboard shortcut.")
                .font(.system(size: 12))
                .foregroundColor(SettingsTheme.warningColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 1.0, green: 0.953, blue: 0.878))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(red: 0.784, green: 0.588, blue: 0.196).opacity(0.3), lineWidth: 1)
        )
    }

    private var resetButton: some View {
        HStack {
            Spacer()
            Button("Reset to Defaults") {
                viewModel.resetHotkeysToDefaults()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func formatHotkey(_ key: String) -> String {
        key.replacingOccurrences(of: "cmd", with: "⌘")
            .replacingOccurrences(of: "shift", with: "⇧")
            .replacingOccurrences(of: "option", with: "⌥")
            .replacingOccurrences(of: "ctrl", with: "⌃")
            .replacingOccurrences(of: "+", with: "")
            .uppercased()
    }
}
```

- [ ] **Step 5: Create DictionaryTabView**

Create `macos/Panini/UI/Settings/DictionaryTabView.swift`:

```swift
import SwiftUI

struct DictionaryTabView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Personal Dictionary")
                SettingsCard {
                    VStack(spacing: 0) {
                        HStack {
                            TextField("Add a word", text: $viewModel.newDictionaryWord)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    Task { await viewModel.addDictionaryWord() }
                                }
                            Button("Add") {
                                Task { await viewModel.addDictionaryWord() }
                            }
                            .disabled(viewModel.newDictionaryWord.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(12)

                        Divider()

                        if viewModel.dictionaryWords.isEmpty {
                            Text("No words added yet. Words you add here will be ignored during corrections.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(viewModel.dictionaryWords, id: \.self) { word in
                                        HStack {
                                            Text(word)
                                                .font(.system(size: 13))
                                            Spacer()
                                            Button {
                                                Task { await viewModel.removeDictionaryWord(word) }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.secondary.opacity(0.5))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .frame(minHeight: 120, maxHeight: 240)
                        }
                    }
                }
            }

            if let error = viewModel.lastError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(SettingsTheme.errorColor)
            }
        }
        .padding(20)
        .task { await viewModel.loadDictionary() }
    }
}
```

- [ ] **Step 6: Rewrite SettingsView as tabbed container**

Replace `macos/Panini/UI/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            GeneralTabView(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gearshape") }

            ModelsTabView(viewModel: viewModel)
                .tabItem { Label("Models", systemImage: "arrow.down.circle") }

            CloudTabView(viewModel: viewModel)
                .tabItem { Label("Cloud", systemImage: "cloud") }

            HotkeysTabView(viewModel: viewModel)
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }

            DictionaryTabView(viewModel: viewModel)
                .tabItem { Label("Dictionary", systemImage: "book") }
        }
        .task {
            viewModel.refreshPermission()
            await viewModel.refreshServerHealth()
        }
    }
}
```

- [ ] **Step 7: Update PaniniApp to increase window size**

In `macos/Panini/App/PaniniApp.swift`, update the Settings scene frame:

```swift
Settings {
    SettingsView(viewModel: DIContainer.shared.settingsViewModel)
        .frame(width: 560, height: 480)
}
```

- [ ] **Step 8: Commit**

```bash
git add macos/Panini/UI/Settings/ macos/Panini/App/PaniniApp.swift
git commit -m "feat: implement tabbed settings UI with all five tabs"
```

---

### Task 11: Integration Wiring

**Files:**
- Modify: `macos/Panini/App/DIContainer.swift`
- Modify: `macos/Panini/App/AppDelegate.swift`
- Modify: `macos/Panini/Infrastructure/Server/ServerProcessManager.swift`

- [ ] **Step 1: Update ServerProcessManager to support restart with dynamic config**

Add a `restart` method to `ServerProcessManager`:

```swift
func restart(backend: String, modelID: String, cloudURL: String?, cloudKey: String?) throws {
    stop()

    let process = makeProcess()
    process.executableURL = URL(fileURLWithPath: config.pythonExecutablePath)

    var args = [
        "-m", config.serverModule,
        "--host", config.serverHost,
        "--port", "\(config.serverPort)",
        "--backend", backend,
        "--model", modelID,
    ]

    if backend == "cloud", let cloudURL, let cloudKey {
        args.append(contentsOf: ["--cloud-url", cloudURL, "--cloud-key", cloudKey])
    }

    process.arguments = args
    process.currentDirectoryURL = config.serverEntryWorkingDirectory

    var env = ProcessInfo.processInfo.environment
    env["PYTHONUNBUFFERED"] = "1"
    process.environment = env

    AppLogger.server.info(
        "Restarting server: backend=\(backend, privacy: .public) model=\(modelID, privacy: .public)"
    )

    try process.run()
    self.process = process
}
```

- [ ] **Step 2: Update DIContainer to wire new services**

Replace `DIContainer.swift`:

```swift
import Foundation

@MainActor
final class DIContainer {
    static let shared = DIContainer()

    let config: AppConfig
    let userSettings: UserSettings
    let serverProcessManager: ServerProcessManager
    let serverHealthClient: ServerHealthClient
    let correctionAPIClient: CorrectionAPIClient
    let accessibilityPermissionService: AccessibilityPermissionService
    let focusedTextReader: FocusedTextReader
    let focusedTextWriter: FocusedTextWriter
    let clipboardInserter: ClipboardSwapInserter
    let undoBuffer: UndoBuffer
    let reviewPanelController: ReviewPanelController
    let toastController: ToastController
    let dictionaryService: DictionaryService
    let modelManagementService: ModelManagementService
    let coordinator: CorrectionCoordinator
    let settingsViewModel: SettingsViewModel

    private init() {
        let config = AppConfig()
        self.config = config

        let userSettings = UserSettings()
        self.userSettings = userSettings

        let processManager = ServerProcessManager(config: config)
        self.serverProcessManager = processManager

        let healthClient = ServerHealthClient(baseURL: config.serverBaseURL, timeout: config.serverHealthTimeout)
        self.serverHealthClient = healthClient

        let apiClient = CorrectionAPIClient(baseURL: config.serverBaseURL, timeout: config.requestTimeout)
        self.correctionAPIClient = apiClient

        let permissionService = AccessibilityPermissionService()
        self.accessibilityPermissionService = permissionService

        let frontmostApplicationProvider = DefaultFrontmostApplicationProvider()
        let applicationActivator = DefaultApplicationActivator()

        let reader = FocusedTextReader(provider: DefaultFocusedElementProvider.shared)
        self.focusedTextReader = reader

        let writer = FocusedTextWriter(provider: DefaultWritableFocusedElementProvider.shared)
        self.focusedTextWriter = writer

        let clipboardInserter = ClipboardSwapInserter()
        self.clipboardInserter = clipboardInserter

        let undo = UndoBuffer(ttlSeconds: config.undoWindowSeconds)
        self.undoBuffer = undo

        let reviewPanel = ReviewPanelController()
        self.reviewPanelController = reviewPanel

        let toast = ToastController()
        self.toastController = toast

        let dictionaryService = DictionaryService(baseURL: config.serverBaseURL, timeout: config.requestTimeout)
        self.dictionaryService = dictionaryService

        let modelService = ModelManagementService(baseURL: config.serverBaseURL)
        self.modelManagementService = modelService

        let coordinator = CorrectionCoordinator(
            config: config,
            serverManager: processManager,
            healthClient: healthClient,
            apiClient: apiClient,
            frontmostApplicationProvider: frontmostApplicationProvider,
            applicationActivator: applicationActivator,
            textReader: reader,
            textWriter: writer,
            clipboardInserter: clipboardInserter,
            undoBuffer: undo,
            reviewPresenter: reviewPanel,
            toastPresenter: toast
        )
        self.coordinator = coordinator

        reviewPanel.applyHandler = { [weak coordinator] in
            Task { await coordinator?.applyReviewSelection() }
        }
        reviewPanel.cancelHandler = { [weak coordinator] in
            coordinator?.cancelReview()
        }
        reviewPanel.retryHandler = { [weak coordinator] in
            coordinator?.retryReview()
        }

        let settingsViewModel = SettingsViewModel(
            config: config,
            userSettings: userSettings,
            healthClient: healthClient,
            permissionService: permissionService,
            dictionaryService: dictionaryService,
            modelService: modelService
        )
        self.settingsViewModel = settingsViewModel

        // Wire settings change callbacks
        settingsViewModel.onBackendOrModelChanged = { [weak processManager, weak settingsViewModel] in
            guard let processManager, let settingsViewModel else { return }
            let backend = settingsViewModel.backendChoice == .cloud ? "cloud" : "mlx"
            let modelID = settingsViewModel.selectedModelID
            let cloudKey = settingsViewModel.backendChoice == .cloud ? settingsViewModel.apiKey : nil
            // Vercel AI Gateway URL would come from a config or the key implies the endpoint
            try? processManager.restart(
                backend: backend,
                modelID: modelID,
                cloudURL: cloudKey != nil ? "https://api.vercel.ai" : nil,
                cloudKey: cloudKey
            )
        }

        settingsViewModel.onHotkeysChanged = {}  // Wired in AppDelegate
    }
}
```

- [ ] **Step 3: Update AppDelegate to use settings for hotkeys**

Replace `AppDelegate.swift`:

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let container = DIContainer.shared
    private let hotkeyManager = GlobalHotkeyManager()
    private let commandPaletteController = CommandPaletteController()
    private let commandPaletteActions: [SelectionAction] = [.fix, .paraphrase, .professional, .improve, .casual]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerHotkeys()

        container.settingsViewModel.onHotkeysChanged = { [weak self] in
            self?.registerHotkeys()
        }

        Task {
            AppLogger.server.info(
                "App launch config host=\(self.container.config.serverHost, privacy: .public) port=\(self.container.config.serverPort) python=\(self.container.config.pythonExecutablePath, privacy: .public) cwd=\(self.container.config.serverEntryWorkingDirectory.path, privacy: .public)"
            )

            if !(await self.container.serverHealthClient.isHealthy()) {
                try? self.container.serverProcessManager.startIfNeeded()
            }
            await self.container.settingsViewModel.refreshServerHealth()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        container.serverProcessManager.stop()
    }

    func openCommandPalette() {
        commandPaletteController.present(actions: commandPaletteActions) { [weak self] action in
            self?.runAction(action)
        }
    }

    func runQuickFix() {
        runAction(.fix)
    }

    func runQuickParaphrase() {
        runAction(.paraphrase)
    }

    func runQuickProfessional() {
        runAction(.professional)
    }

    func undoLastApply() {
        Task { await self.container.coordinator.undoLastAutofix() }
    }

    func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func terminateApp() {
        NSApp.terminate(nil)
    }

    private func registerHotkeys() {
        let settings = container.userSettings
        let bindings = HotkeyParser.parseBindings(
            palette: settings.paletteHotkey,
            fix: settings.fixHotkey,
            paraphrase: settings.paraphraseHotkey,
            professional: settings.professionalHotkey
        )
        hotkeyManager.register(bindings: bindings) { [weak self] action in
            guard let self else { return }
            switch action {
            case .palette:
                self.openCommandPalette()
            case .fix:
                self.runQuickFix()
            case .paraphrase:
                self.runQuickParaphrase()
            case .professional:
                self.runQuickProfessional()
            }
        }
    }

    private func runAction(_ action: SelectionAction) {
        commandPaletteController.dismiss()
        Task { await container.coordinator.runAction(action) }
    }
}
```

- [ ] **Step 4: Create HotkeyParser utility**

Create `macos/Panini/Infrastructure/Hotkey/HotkeyParser.swift`:

```swift
import Carbon
import Foundation

enum HotkeyParser {
    static func parseBindings(
        palette: String,
        fix: String,
        paraphrase: String,
        professional: String
    ) -> [HotkeyBinding] {
        var bindings: [HotkeyBinding] = []
        if let b = parse(palette, action: .palette) { bindings.append(b) }
        if let b = parse(fix, action: .fix) { bindings.append(b) }
        if let b = parse(paraphrase, action: .paraphrase) { bindings.append(b) }
        if let b = parse(professional, action: .professional) { bindings.append(b) }
        return bindings
    }

    private static func parse(_ combo: String, action: GlobalHotkeyAction) -> HotkeyBinding? {
        let parts = combo.lowercased().split(separator: "+").map(String.init)
        var modifiers: UInt32 = 0
        var keyChar: String?

        for part in parts {
            switch part {
            case "cmd": modifiers |= UInt32(cmdKey)
            case "shift": modifiers |= UInt32(shiftKey)
            case "option": modifiers |= UInt32(optionKey)
            case "ctrl": modifiers |= UInt32(controlKey)
            default: keyChar = part
            }
        }

        guard let char = keyChar, let keyCode = keyCodeForCharacter(char) else { return nil }
        return HotkeyBinding(action: action, keyCode: keyCode, modifiers: modifiers)
    }

    private static func keyCodeForCharacter(_ char: String) -> UInt32? {
        let map: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            ";": kVK_ANSI_Semicolon,
        ]
        guard let code = map[char.lowercased()] else { return nil }
        return UInt32(code)
    }
}
```

- [ ] **Step 5: Run all Swift tests**

Run: `cd /Users/skrishnan/development/panini/macos && swift test`
Expected: All tests pass.

- [ ] **Step 6: Run all server tests**

Run: `cd /Users/skrishnan/development/panini/server && python -m pytest tests/ -v`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add macos/Panini/App/ macos/Panini/Infrastructure/Server/ServerProcessManager.swift macos/Panini/Infrastructure/Hotkey/HotkeyParser.swift
git commit -m "feat: wire settings into DIContainer, AppDelegate, and ServerProcessManager"
```

---

### Task 12: Final Verification

- [ ] **Step 1: Run full server test suite**

Run: `cd /Users/skrishnan/development/panini/server && python -m pytest tests/ -v`
Expected: All tests pass.

- [ ] **Step 2: Run full Swift test suite**

Run: `cd /Users/skrishnan/development/panini/macos && swift test`
Expected: All tests pass.

- [ ] **Step 3: Build the macOS app**

Run: `cd /Users/skrishnan/development/panini/macos && swift build`
Expected: Build succeeds with no errors.

- [ ] **Step 4: Commit any remaining fixes**

```bash
git add -A
git commit -m "fix: address build issues from settings integration"
```
