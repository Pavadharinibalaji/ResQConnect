from typing import List, Union
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import AnyHttpUrl, field_validator, PostgresDsn

ALLOWED_ENVIRONMENTS = ("development", "staging", "production")
MIN_SECRET_KEY_LENGTH = 32
# Marker used by the placeholders in .env.example; a copied template must not start.
PLACEHOLDER_MARKER = "replace-with"

class Settings(BaseSettings):
    PROJECT_NAME: str = "ResQConnect API"
    VERSION: str = "1.0.0"
    # Required on purpose: development-only behaviour must be selected explicitly,
    # and a deployment must never fall into it by omission.
    ENVIRONMENT: str
    API_V1_STR: str = "/api/v1"
    
    # Security — secrets have no fallbacks; they must come from the environment / .env.
    SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    ALLOWED_HOSTS: List[str] = ["*"]
    CORS_ORIGINS: List[str] = ["*"]

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "firebase-adminsdk.json"
    
    # Database
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str
    POSTGRES_DB: str = "resqconnect"
    POSTGRES_PORT: str = "5432"

    @field_validator("ENVIRONMENT", mode="before")
    @classmethod
    def _normalise_environment(cls, value):
        normalised = str(value).strip().lower()
        if normalised not in ALLOWED_ENVIRONMENTS:
            raise ValueError(f"ENVIRONMENT must be one of: {', '.join(ALLOWED_ENVIRONMENTS)}")
        return normalised

    # Error messages below never include the value (see also hide_input_in_errors).
    @field_validator("SECRET_KEY")
    @classmethod
    def _validate_secret_key(cls, value: str) -> str:
        if len(value.strip()) < MIN_SECRET_KEY_LENGTH or PLACEHOLDER_MARKER in value.lower():
            raise ValueError(
                f"SECRET_KEY must be configured with a random value of at least {MIN_SECRET_KEY_LENGTH} characters"
            )
        return value

    @field_validator("POSTGRES_PASSWORD")
    @classmethod
    def _validate_db_password(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("POSTGRES_PASSWORD must be configured")
        return value

    @property
    def async_database_uri(self) -> str:
        return f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    # hide_input_in_errors: validation errors must never echo configured values (secrets).
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True, extra="ignore", hide_input_in_errors=True)

settings = Settings()
