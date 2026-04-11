"""FastAPI application for Panini inference server."""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from panini import backends
from panini.config import get_default_model, load_models, load_presets
from panini.dictionary import UserDictionary
from panini.model_downloader import ModelDownloader
from panini.model_storage import ModelStatus, ModelStorage
from panini.parser import compute_changes
from panini.prompt import PromptEngine
from panini.types import (
    CorrectionRequest,
    CorrectionResponse,
    ModelInfo,
    PresetInfo,
    ResponseMode,
    RewriteVariant,
    SingleCorrectionResult,
    VariantCorrectionResult,
)
from panini.variant_parser import parse_variants


class DictionaryWordRequest(BaseModel):
    word: str


def _default_dictionary_path() -> Path:
    return (
        Path.home()
        / "Library"
        / "Application Support"
        / "Panini"
        / "dictionary.json"
    )


def _resolve_model_for_backend(
    *,
    models: dict[str, ModelInfo],
    backend_name: str,
    requested_model_id: str,
) -> tuple[str, str]:
    """Return (model_ref_for_backend, prompt_format)."""
    model_info = models.get(requested_model_id)

    if backend_name == "cloud":
        prompt_format = model_info.prompt_format if model_info else "chatml"
        return requested_model_id, prompt_format

    if model_info is None:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown model '{requested_model_id}'.",
        )

    if backend_name in model_info.backends:
        if backend_name == "mlx" and model_info.mlx_repo:
            return model_info.mlx_repo, model_info.prompt_format
        return model_info.id, model_info.prompt_format

    # Allow custom/test backends to reuse registry prompt formatting and model IDs.
    if backend_name not in {"mlx", "webgpu", "local_api"}:
        return model_info.id, model_info.prompt_format

    raise HTTPException(
        status_code=400,
        detail=(
            f"Model '{requested_model_id}' does not support backend '{backend_name}'. "
            f"Supported: {model_info.backends}"
        ),
    )


def _resolve_preset(
    *,
    presets: dict[str, PresetInfo],
    preset_id: str,
) -> PresetInfo:
    preset = presets.get(preset_id)
    if preset is None:
        available = ", ".join(sorted(presets.keys())) or "none"
        raise HTTPException(
            status_code=400,
            detail=f"Unknown preset '{preset_id}'. Available: {available}",
        )
    return preset


def create_app(
    default_backend: str = "mlx",
    default_model_id: str = "gemma-4-e4b",
    dictionary_path: Path | None = None,
    shared_dir: Path | None = None,
    models_dir: Path | None = None,
) -> FastAPI:
    app = FastAPI(title="Panini", version="0.1.0")

    prompt_engine = PromptEngine()
    models = load_models(shared_dir=shared_dir)
    presets = load_presets(shared_dir=shared_dir)

    if default_model_id not in models:
        default_model = get_default_model(models, default_backend)
        if default_model is not None:
            default_model_id = default_model.id

    dictionary = UserDictionary(dictionary_path or _default_dictionary_path())

    model_storage = ModelStorage(models_dir=models_dir)
    model_downloader = ModelDownloader(storage=model_storage)

    @app.get("/health")
    async def health() -> dict[str, object]:
        backend_states: list[dict[str, object]] = []
        for backend_name in backends.list_backends():
            backend = backends.get_backend(backend_name)
            try:
                healthy = await backend.health()
            except Exception:
                healthy = False
            backend_states.append({"name": backend_name, "healthy": healthy})
        return {"status": "ok", "backends": backend_states}

    @app.post("/correct")
    async def correct(request: CorrectionRequest) -> CorrectionResponse:
        if not request.text.strip():
            raise HTTPException(status_code=400, detail="Text cannot be empty.")

        preset = _resolve_preset(presets=presets, preset_id=request.preset)

        backend_name = request.backend or default_backend
        try:
            backend = backends.get_backend(backend_name)
        except ValueError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc

        requested_model_id = request.model_id or default_model_id
        model_ref, prompt_format = _resolve_model_for_backend(
            models=models,
            backend_name=backend_name,
            requested_model_id=requested_model_id,
        )

        dictionary_words = sorted(dictionary.words) or None

        messages = prompt_engine.format_messages(
            text=request.text,
            preset=preset,
            prompt_format=prompt_format,
            custom_prompt=request.custom_prompt,
            dictionary_words=dictionary_words,
            avoid_outputs=request.avoid_outputs,
        )

        try:
            corrected = await backend.correct(
                messages=messages,
                model_id=model_ref,
                temperature=preset.temperature,
            )
        except Exception as exc:
            raise HTTPException(
                status_code=502,
                detail=f"Backend '{backend_name}' failed: {exc}",
            ) from exc

        if preset.response_mode == ResponseMode.SINGLE:
            changes = compute_changes(request.text, corrected)
            changes = dictionary.filter_changes(changes)

            return SingleCorrectionResult(
                kind="single",
                original=request.text,
                corrected=corrected,
                changes=changes,
                model_used=requested_model_id,
                backend_used=backend.name,
            )

        variants = parse_variants(corrected, expected_count=preset.variant_count)
        if not variants:
            variants = [
                RewriteVariant(
                    id="variant-1",
                    label="Recommended",
                    text=corrected.strip(),
                    is_recommended=True,
                )
            ]

        return VariantCorrectionResult(
            kind="variants",
            original=request.text,
            variants=variants,
            model_used=requested_model_id,
            backend_used=backend.name,
        )

    @app.get("/models")
    async def list_models() -> dict[str, list[dict[str, object]]]:
        return {"models": [model.model_dump() for model in models.values()]}

    @app.get("/dictionary")
    async def list_dictionary() -> dict[str, list[str]]:
        return {"words": sorted(dictionary.words)}

    @app.post("/dictionary")
    async def add_dictionary_word(request: DictionaryWordRequest) -> dict[str, str]:
        word = request.word.strip()
        if not word:
            raise HTTPException(status_code=400, detail="Word cannot be empty.")

        dictionary.add(word)
        return {"status": "added", "word": word}

    @app.delete("/dictionary/{word}")
    async def remove_dictionary_word(word: str) -> dict[str, str]:
        dictionary.remove(word)
        return {"status": "removed", "word": word}

    @app.get("/models/{model_id}/status")
    async def model_status(model_id: str) -> dict[str, object]:
        if model_id not in models:
            raise HTTPException(status_code=404, detail=f"Unknown model '{model_id}'.")
        if model_downloader.is_downloading(model_id):
            status = ModelStatus.DOWNLOADING
        else:
            status = model_storage.status(model_id)
        return {"model_id": model_id, "status": status.value}

    @app.post("/models/{model_id}/download")
    async def start_model_download(model_id: str) -> dict[str, object]:
        model_info = models.get(model_id)
        if model_info is None:
            raise HTTPException(status_code=404, detail=f"Unknown model '{model_id}'.")
        if model_downloader.is_downloading(model_id):
            return {"status": "already_downloading"}
        if model_storage.status(model_id) == ModelStatus.READY:
            return {"status": "already_downloaded"}
        repo_id = model_info.mlx_repo or model_info.id
        model_downloader.start_download(model_id=model_id, repo_id=repo_id)
        return {"status": "started", "model_id": model_id}

    @app.get("/models/{model_id}/download/progress")
    async def model_download_progress(model_id: str) -> dict[str, object]:
        progress = model_downloader.get_progress(model_id)
        if progress is not None:
            return {
                "model_id": progress.model_id,
                "status": progress.status,
                "bytes_downloaded": progress.bytes_downloaded,
                "bytes_total": progress.bytes_total,
                "error": progress.error,
            }
        current_status = model_storage.status(model_id)
        return {"model_id": model_id, "status": current_status.value}

    @app.post("/models/{model_id}/download/cancel")
    async def cancel_model_download(model_id: str) -> dict[str, object]:
        model_downloader.cancel(model_id)
        return {"status": "cancelled", "model_id": model_id}

    @app.delete("/models/{model_id}")
    async def delete_model(model_id: str) -> dict[str, object]:
        if model_id not in models:
            raise HTTPException(status_code=404, detail=f"Unknown model '{model_id}'.")
        if model_storage.status(model_id) != ModelStatus.READY:
            raise HTTPException(
                status_code=404,
                detail=f"Model '{model_id}' is not downloaded.",
            )
        model_storage.delete(model_id)
        return {"status": "deleted", "model_id": model_id}

    return app
