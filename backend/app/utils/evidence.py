"""
Server-side validation for incident evidence uploads.

The client-provided evidence type, filename and Content-Type are never trusted on
their own: the stored format is decided by the file's leading bytes (magic
signature), and the declared metadata must agree with it. Only the standard
library is used; this is a signature check, not a full media decode.
"""
import os
from dataclasses import dataclass
from typing import Optional

MB = 1024 * 1024
MAX_UPLOAD_BYTES = {"photo": 10 * MB, "video": 50 * MB}

# Declared Content-Type values that carry no format information (e.g. the Flutter
# client's MultipartFile default); the content signature decides for these.
GENERIC_CONTENT_TYPES = {"", "application/octet-stream"}

# ISO-BMFF major brands that are still images, not video.
_IMAGE_BRANDS = {b"heic", b"heix", b"heim", b"heis", b"hevc", b"mif1", b"msf1", b"avif", b"avis"}
_LEGACY_QUICKTIME_ATOMS = {b"moov", b"mdat", b"wide", b"free", b"skip", b"pnot"}


@dataclass(frozen=True)
class EvidenceFormat:
    name: str
    evidence_type: str
    extensions: frozenset
    content_types: frozenset


FORMATS = {
    "jpeg": EvidenceFormat("jpeg", "photo", frozenset({".jpg", ".jpeg"}), frozenset({"image/jpeg", "image/jpg"})),
    "png": EvidenceFormat("png", "photo", frozenset({".png"}), frozenset({"image/png"})),
    "webp": EvidenceFormat("webp", "photo", frozenset({".webp"}), frozenset({"image/webp"})),
    # MP4 and QuickTime share the ISO-BMFF container; clients label them loosely.
    "mp4": EvidenceFormat("mp4", "video", frozenset({".mp4", ".mov"}), frozenset({"video/mp4", "video/quicktime"})),
    "webm": EvidenceFormat("webm", "video", frozenset({".webm"}), frozenset({"video/webm"})),
    "avi": EvidenceFormat("avi", "video", frozenset({".avi"}), frozenset({"video/x-msvideo", "video/avi"})),
}

ALLOWED_EXTENSIONS = {
    t: frozenset().union(*(f.extensions for f in FORMATS.values() if f.evidence_type == t)) for t in MAX_UPLOAD_BYTES
}
ALLOWED_CONTENT_TYPES = {
    t: frozenset().union(*(f.content_types for f in FORMATS.values() if f.evidence_type == t)) for t in MAX_UPLOAD_BYTES
}


# Media types used when serving stored evidence; keyed by the server-chosen extension
# (see validate_evidence_content), never by client-supplied metadata.
STORED_MEDIA_TYPES = {
    ".jpg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".mp4": "video/mp4",
    ".mov": "video/quicktime",
    ".webm": "video/webm",
    ".avi": "video/x-msvideo",
}


class EvidenceValidationError(Exception):
    def __init__(self, message: str, too_large: bool = False):
        super().__init__(message)
        self.message = message
        self.too_large = too_large


def normalize_evidence_type(value: Optional[str]) -> str:
    evidence_type = (value or "").strip().lower()
    if evidence_type not in MAX_UPLOAD_BYTES:
        raise EvidenceValidationError("Unsupported evidence type. Allowed types: photo, video.")
    return evidence_type


def client_extension(filename: Optional[str]) -> str:
    """Lower-cased extension of the client filename's last path component ('' if none)."""
    basename = (filename or "").replace("\\", "/").rsplit("/", 1)[-1]
    return os.path.splitext(basename)[1].lower()


def normalize_content_type(value: Optional[str]) -> str:
    return (value or "").split(";", 1)[0].strip().lower()


def check_declared_metadata(evidence_type: str, extension: str, content_type: str) -> None:
    """Cheap checks before reading the body: extension and Content-Type must be plausible for the type."""
    if extension and extension not in ALLOWED_EXTENSIONS[evidence_type]:
        raise EvidenceValidationError(f"Unsupported file extension for {evidence_type} evidence.")
    if content_type not in GENERIC_CONTENT_TYPES and content_type not in ALLOWED_CONTENT_TYPES[evidence_type]:
        raise EvidenceValidationError(f"Unsupported content type for {evidence_type} evidence.")


def detect_format(data: bytes) -> Optional[EvidenceFormat]:
    if data.startswith(b"\xff\xd8\xff"):
        return FORMATS["jpeg"]
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return FORMATS["png"]
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return FORMATS["webp"]
    if data[:4] == b"RIFF" and data[8:12] == b"AVI ":
        return FORMATS["avi"]
    if data.startswith(b"\x1a\x45\xdf\xa3"):
        return FORMATS["webm"]
    if data[4:8] == b"ftyp" and data[8:12] not in _IMAGE_BRANDS:
        return FORMATS["mp4"]
    if data[4:8] in _LEGACY_QUICKTIME_ATOMS:
        return FORMATS["mp4"]
    return None


def validate_evidence_content(evidence_type: str, extension: str, content_type: str, data: bytes) -> str:
    """
    Validates size and content signature; returns the server-chosen file extension.
    The declared extension/Content-Type (when specific) must match the detected format.
    """
    if len(data) > MAX_UPLOAD_BYTES[evidence_type]:
        limit_mb = MAX_UPLOAD_BYTES[evidence_type] // MB
        raise EvidenceValidationError(f"{evidence_type.capitalize()} evidence exceeds the {limit_mb} MB limit.", too_large=True)
    if not data:
        raise EvidenceValidationError("Uploaded evidence file is empty.")

    detected = detect_format(data)
    if detected is None or detected.evidence_type != evidence_type:
        raise EvidenceValidationError(f"File content is not a supported {evidence_type} format.")
    if extension and extension not in detected.extensions:
        raise EvidenceValidationError("File extension does not match the file content.")
    if content_type not in GENERIC_CONTENT_TYPES and content_type not in detected.content_types:
        raise EvidenceValidationError("Declared content type does not match the file content.")

    if detected.name == "mp4":
        if extension in detected.extensions:
            return extension
        return ".mov" if data[8:12] == b"qt  " or data[4:8] in _LEGACY_QUICKTIME_ATOMS else ".mp4"
    return {"jpeg": ".jpg", "png": ".png", "webp": ".webp", "webm": ".webm", "avi": ".avi"}[detected.name]
