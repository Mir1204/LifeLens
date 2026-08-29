# Path: app/core/config.py
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30
    allowed_origins: str = ""
    google_web_client_id: str
    burnout_model_path: str = "app/ml/artifacts/burnout_model.joblib"
    overspend_model_path: str = "app/ml/artifacts/overspend_model.joblib"
    static_stress_model_path: str = "app/ml/artifacts/static_stress_model.joblib"

    class Config:
        env_file = (".env", ".env.local")

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()]


settings = Settings()
