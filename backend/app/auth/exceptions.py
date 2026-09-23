from fastapi import status
from app.core.exceptions import ResQConnectException

class InvalidTokenException(ResQConnectException):
    def __init__(self, message: str = "Invalid or expired token"):
        super().__init__(message=message, status_code=status.HTTP_401_UNAUTHORIZED)

class UserNotAuthenticatedException(ResQConnectException):
    def __init__(self, message: str = "Not authenticated"):
        super().__init__(message=message, status_code=status.HTTP_401_UNAUTHORIZED)

class FirebaseVerificationException(ResQConnectException):
    def __init__(self, message: str = "Firebase token verification failed"):
        super().__init__(message=message, status_code=status.HTTP_401_UNAUTHORIZED)
