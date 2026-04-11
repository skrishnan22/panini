"""Integration tests for the FastAPI server."""

import pytest

from panini.app import _resolve_model_for_backend
from panini.config import load_models


class TestHealthEndpoint:
    @pytest.mark.asyncio
    async def test_health_returns_ok(self, app_client):
        async with await app_client() as client:
            response = await client.get("/health")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "ok"
            assert isinstance(data["backends"], list)
            assert data["backends"][0]["name"] == "mock"


class TestCorrectEndpoint:
    @pytest.mark.asyncio
    async def test_correct_returns_result(self, app_client, mock_backend):
        mock_backend._response = "I am here."

        async with await app_client() as client:
            response = await client.post(
                "/correct",
                json={"text": "i am here.", "preset": "fix"},
            )
            assert response.status_code == 200
            data = response.json()
            assert data["kind"] == "single"
            assert data["original"] == "i am here."
            assert data["corrected"] == "I am here."
            assert data["backend_used"] == "mock"
            assert isinstance(data["changes"], list)

    @pytest.mark.asyncio
    async def test_correct_with_custom_prompt(self, app_client, mock_backend):
        mock_backend._response = "Formal text."

        async with await app_client() as client:
            response = await client.post(
                "/correct",
                json={"text": "hey whats up", "custom_prompt": "Make it formal."},
            )
            assert response.status_code == 200
            data = response.json()
            assert data["kind"] == "single"
            assert data["corrected"] == "Formal text."

    @pytest.mark.asyncio
    async def test_correct_empty_text_returns_400(self, app_client):
        async with await app_client() as client:
            response = await client.post("/correct", json={"text": ""})
            assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_correct_unknown_model_returns_400(self, app_client):
        async with await app_client() as client:
            response = await client.post(
                "/correct",
                json={"text": "hello", "model_id": "does-not-exist"},
            )
            assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_correct_no_changes(self, app_client, mock_backend):
        mock_backend._response = "Already correct."

        async with await app_client() as client:
            response = await client.post(
                "/correct",
                json={"text": "Already correct."},
            )
            assert response.status_code == 200
            data = response.json()
            assert data["kind"] == "single"
            assert data["changes"] == []

    @pytest.mark.asyncio
    async def test_paraphrase_returns_variant_payload(self, app_client, mock_backend):
        mock_backend._response = """
        [[option:recommended]]
        Could you send me the file when you get a chance?
        [[/option]]
        [[option:alternative]]
        When you have a moment, please send me the file.
        [[/option]]
        """

        async with await app_client() as client:
            response = await client.post(
                "/correct",
                json={"text": "send me the file", "preset": "paraphrase"},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["kind"] == "variants"
        assert len(data["variants"]) == 2

    @pytest.mark.asyncio
    async def test_avoid_outputs_are_forwarded_to_prompt(
        self,
        app_client,
        mock_backend,
    ):
        async with await app_client() as client:
            await client.post(
                "/correct",
                json={
                    "text": "hey checking in",
                    "preset": "professional",
                    "avoid_outputs": ["Hello, I am following up."],
                },
            )

        assert "Do not repeat or lightly rephrase these previous options" in (
            mock_backend.last_messages[1]["content"]
        )


class TestModelsEndpoint:
    @pytest.mark.asyncio
    async def test_models_returns_list(self, app_client):
        async with await app_client() as client:
            response = await client.get("/models")
            assert response.status_code == 200
            data = response.json()
            assert isinstance(data["models"], list)
            assert len(data["models"]) > 0


class TestDictionaryEndpoints:
    @pytest.mark.asyncio
    async def test_add_and_list_words(self, app_client):
        async with await app_client() as client:
            response = await client.post("/dictionary", json={"word": "MLX"})
            assert response.status_code == 200

            response = await client.get("/dictionary")
            assert response.status_code == 200
            assert "mlx" in response.json()["words"]

    @pytest.mark.asyncio
    async def test_delete_word_case_insensitive(self, app_client):
        async with await app_client() as client:
            await client.post("/dictionary", json={"word": "mlx"})
            response = await client.delete("/dictionary/MLX")
            assert response.status_code == 200

            response = await client.get("/dictionary")
            assert "mlx" not in response.json()["words"]


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


class TestModelResolution:
    def test_mlx_model_resolution_uses_repo(self, shared_dir):
        models = load_models(shared_dir=shared_dir)
        model_ref, prompt_format = _resolve_model_for_backend(
            models=models,
            backend_name="mlx",
            requested_model_id="gemma-4-e4b",
        )
        assert model_ref == "mlx-community/gemma-4-e4b-it-4bit"
        assert prompt_format == "gemma"
