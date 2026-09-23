import os
import firebase_admin
from firebase_admin import credentials, auth
from app.core.config import settings
from app.auth.exceptions import FirebaseVerificationException
import logging

logger = logging.getLogger("resqconnect")

def initialize_firebase():
    if not firebase_admin._apps:
        try:
            if os.path.exists(settings.FIREBASE_CREDENTIALS_PATH):
                cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
                firebase_admin.initialize_app(cred)
                logger.info("Firebase Admin SDK initialized successfully.")
            else:
                logger.warning(f"Firebase credentials not found at {settings.FIREBASE_CREDENTIALS_PATH}. Mocking Firebase verification for development.")
        except Exception as e:
            logger.error(f"Failed to initialize Firebase: {e}")

initialize_firebase()

async def verify_firebase_token(id_token: str) -> dict:
    """
    Verifies the Firebase ID token.
    Returns a dict containing uid and phone_number.
    """
    if not firebase_admin._apps:
        # Mock behavior for local dev without credentials
        logger.warning("Using MOCKED Firebase verification! Do not use in production.")
        if id_token == "mock-token":
            return {"uid": "mock-uid-123", "phone_number": "+1234567890"}
        raise FirebaseVerificationException("Firebase is not configured")

    try:
        # verify_id_token is blocking, so in a real async high-throughput app, 
        # this could be run in a threadpool (run_in_executor)
        decoded_token = auth.verify_id_token(id_token)
        uid = decoded_token.get("uid")
        phone_number = decoded_token.get("phone_number")
        
        if not uid or not phone_number:
            raise FirebaseVerificationException("Token missing uid or phone_number")
            
        return {"uid": uid, "phone_number": phone_number}
    except Exception as e:
        logger.error(f"Firebase token verification error: {e}")
        raise FirebaseVerificationException()
