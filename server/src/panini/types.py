"""Shared types for Panini."""

from enum import Enum
from typing import Literal

from pydantic import BaseModel, Field


class CorrectionMode(str, Enum):
    """Supported correction modes."""

    REVIEW = "review"
    AUTOFIX = "autofix"


class ChangeCategory(str, Enum):
    """High-level change categories."""

    SPELLING = "spelling"
    GRAMMAR = "grammar"
    CLARITY = "clarity"
    TONE = "tone"
    STYLE = "style"


class Change(BaseModel):
    """A single replacement span in the original text."""

    offset_start: int = Field(ge=0)
    offset_end: int = Field(ge=0)
    original_text: str
    replacement: str
    category: ChangeCategory = ChangeCategory.GRAMMAR


class ResponseMode(str, Enum):
    """How a preset should respond."""

    SINGLE = "single"
    VARIANTS = "variants"


class RewriteVariant(BaseModel):
    """A single rewrite option returned by the model."""

    id: str
    label: str
    text: str
    is_recommended: bool = False


class SingleCorrectionResult(BaseModel):
    """Structured response for single-output presets."""

    kind: Literal["single"] = "single"
    original: str
    corrected: str
    changes: list[Change]
    model_used: str
    backend_used: str


class VariantCorrectionResult(BaseModel):
    """Structured response for variant-output presets."""

    kind: Literal["variants"] = "variants"
    original: str
    variants: list[RewriteVariant]
    model_used: str
    backend_used: str


CorrectionResponse = SingleCorrectionResult | VariantCorrectionResult


class CorrectionRequest(BaseModel):
    """Request payload for /correct."""

    text: str
    mode: CorrectionMode = CorrectionMode.REVIEW
    preset: str = "fix"
    custom_prompt: str | None = None
    model_id: str | None = None
    backend: str | None = None
    language: str = "en"
    avoid_outputs: list[str] = Field(default_factory=list)


CorrectionResult = CorrectionResponse


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


class PresetInfo(BaseModel):
    """Prompt preset loaded from shared/presets/*.json."""

    id: str
    name: str
    description: str
    system_prompt: str
    temperature: float = Field(ge=0.0, le=2.0)
    response_mode: ResponseMode = ResponseMode.SINGLE
    variant_count: int = Field(default=1, ge=1, le=3)
