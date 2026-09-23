import os
import logging

import firebase_admin
import jwt
from firebase_admin import auth, credentials

from app.core.config import settings

logger = logging.getLogger("resqconnect.auth")

firebase_initialized = False

try:
    cred_path = settings.FIREBASE_CREDENTIALS_PATH
    if cred_path and os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        firebase_initialized = True
        logger.info("Firebase Admin SDK initialized with certificate file.")
    else:
        logger.warning(
            f"Firebase credentials not found at {cred_path}. "
            "Development mode will decode Firebase ID tokens without Admin SDK verification."
        )
except Exception as e:
    logger.warning(
        f"Firebase Admin SDK initialization skipped or failed: {e}. "
        "Development mode will decode Firebase ID tokens without Admin SDK verification."
    )


def _decode_firebase_token_for_development(id_token: str) -> dict:
    """Decode Firebase ID token claims for local development only."""
    if id_token.startswith("mock-token-"):
        phone = "+15555555555"
        parts = id_token.split("mock-token-")
        if len(parts) > 1 and parts[1]:
            phone = parts[1]
        return {
            "uid": f"mock-uid-{phone.replace('+', '')}",
            "phone_number": phone,
            "name": "Mock Responder",
        }

    if id_token == "mock-firebase-token-123":
        return {
            "uid": "mock-uid-123",
            "phone_number": "+15555555555",
            "name": "Mock Responder",
        }

    try:
        payload = jwt.decode(
            id_token,
            options={
                "verify_signature": False,
                "verify_aud": False,
                "verify_exp": True,
            },
        )
    except jwt.PyJWTError as exc:
        raise ValueError(f"Unable to decode Firebase ID token in development mode: {exc}") from exc

    uid = payload.get("user_id") or payload.get("sub")
    phone_number = payload.get("phone_number")

    if not uid:
        raise ValueError("Firebase ID token is missing uid/sub claim.")
    if not phone_number:
        raise ValueError("Firebase ID token is missing phone_number claim.")

    return {
        "uid": uid,
        "phone_number": phone_number,
        "name": payload.get("name"),
    }


def _development_auth_allowed() -> bool:
    """The unverified development decoder is only permitted when ENVIRONMENT is 'development'."""
    return settings.ENVIRONMENT.strip().lower() == "development"


class FirebaseConfigurationError(RuntimeError):
    """Raised at startup when a non-development environment lacks Firebase Admin SDK credentials."""


def ensure_firebase_configured() -> None:
    """
    Startup check: outside development, the Admin SDK must be initialised (the service
    account file at FIREBASE_CREDENTIALS_PATH loaded successfully). Uses the state from
    the one-time initialisation above; it does not initialise Firebase again.
    """
    if _development_auth_allowed() or firebase_initialized:
        return
    raise FirebaseConfigurationError(
        f"Firebase Admin SDK is not configured for ENVIRONMENT='{settings.ENVIRONMENT}'. "
        "Provide a valid service account file via FIREBASE_CREDENTIALS_PATH; "
        "unverified token decoding is only available in development."
    )


def verify_firebase_id_token(id_token: str) -> dict:
    """
    Verifies a Firebase ID token.
    Uses Firebase Admin SDK when credentials are configured. Without credentials,
    falls back to unverified claim decoding in the development environment only;
    in any other environment every token is rejected.
    """
    if not firebase_initialized:
        if _development_auth_allowed():
            return _decode_firebase_token_for_development(id_token)
        logger.error(
            "Firebase Admin SDK is not configured in the '%s' environment; rejecting ID token.",
            settings.ENVIRONMENT,
        )
        raise ValueError("Invalid Firebase ID token.")

    try:
        decoded_token = auth.verify_id_token(id_token)
        uid = decoded_token.get("uid")
        phone_number = decoded_token.get("phone_number")

        if not phone_number:
            user_record = auth.get_user(uid)
            phone_number = user_record.phone_number

        if not phone_number:
            raise ValueError("Firebase account has no verified phone number.")

        return {
            "uid": uid,
            "phone_number": phone_number,
            "name": decoded_token.get("name"),
        }
    except Exception as e:
        logger.error(f"Firebase Token Verification exception: {e}")
        raise ValueError("Invalid Firebase ID token.")
