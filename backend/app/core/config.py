# Path: app/core/config.py
import json

from pydantic import field_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    jwt_secret_key: str
    # JSON object of retained signing keys, e.g. {"2026-09":"old-secret",
    # "2026-10":"new-secret"}. Keep old keys until issued tokens expire.
    jwt_secret_keys: str = ""
    jwt_active_key_id: str = "default"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30
    allowed_origins: str = ""
    # Google sign-in is optional. Keeping this optional lets the API start for
    # password-based users when the Google OAuth client has not been configured.
    google_web_client_id: str = ""
    burnout_model_path: str = "app/ml/artifacts/burnout_model.joblib"
    overspend_model_path: str = "app/ml/artifacts/overspend_model.joblib"
    static_stress_model_path: str = "app/ml/artifacts/static_stress_model.joblib"

    @field_validator("database_url")
    @classmethod
    def require_postgres_tls(cls, value: str) -> str:
        # SQLite is allowed only for local development. Production Postgres must
        # negotiate TLS; encryption at rest is enabled in the managed provider.
        if value.startswith("postgresql") and "sslmode=require" not in value:
            raise ValueError("DATABASE_URL must use sslmode=require")
        return value

    class Config:
        env_file = (".env", ".env.local")

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()]

    @property
    def jwt_keys(self) -> dict[str, str]:
        if not self.jwt_secret_keys:
            return {"default": self.jwt_secret_key}
        try:
            keys = json.loads(self.jwt_secret_keys)
        except json.JSONDecodeError as error:
            raise ValueError("JWT_SECRET_KEYS must be a JSON object") from error
        if not isinstance(keys, dict) or not all(
            isinstance(key, str) and isinstance(value, str) and value
            for key, value in keys.items()
        ):
            raise ValueError("JWT_SECRET_KEYS must map key IDs to non-empty secrets")
        if self.jwt_active_key_id not in keys:
            raise ValueError("JWT_ACTIVE_KEY_ID is absent from JWT_SECRET_KEYS")
        return keys


settings = Settings()
