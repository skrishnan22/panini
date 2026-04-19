"""Shared test fixtures."""

import sys
from pathlib import Path

import pytest
from httpx import ASGITransport, AsyncClient

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))


class MockBackend:
    """Test backend that returns a predetermined correction."""

    def __init__(
        self,
        response: str = "I have corrected text.",
        name: str = "mock",
    ) -> None:
        self._response = response
        self._name = name
        self.last_messages: list[dict[str, str]] = []
        self.last_model_id: str = ""
        self.last_temperature: float = 0.0

    @property
    def name(self) -> str:
        return self._name

    async def correct(
        self,
        messages: list[dict[str, str]],
        model_id: str,
        temperature: float,
    ) -> str:
        self.last_messages = messages
        self.last_model_id = model_id
        self.last_temperature = temperature
        return self._response

    async def health(self) -> bool:
        return True


@pytest.fixture
def shared_dir() -> Path:
    return Path(__file__).resolve().parents[2] / "shared"


@pytest.fixture
def mock_backend() -> MockBackend:
    return MockBackend()


@pytest.fixture
def app_client(mock_backend: MockBackend, tmp_path: Path, shared_dir: Path):
    from panini.app import create_app
    from panini.backends import clear_backends, register_backend

    clear_backends()
    register_backend(mock_backend)

    models_dir = tmp_path / "models"
    models_dir.mkdir(parents=True, exist_ok=True)

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
