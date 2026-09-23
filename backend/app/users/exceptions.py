from fastapi import status
from app.core.exceptions import ResQConnectException

class UserNotFoundException(ResQConnectException):
    def __init__(self, message: str = "User not found"):
        super().__init__(message=message, status_code=status.HTTP_404_NOT_FOUND)

class UserAlreadyExistsException(ResQConnectException):
    def __init__(self, message: str = "User already exists"):
        super().__init__(message=message, status_code=status.HTTP_409_CONFLICT)
