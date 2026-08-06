# Path: app/core/config.py
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://lifelens_user:lifelens_pass@localhost:5432/lifelens_db"
    burnout_model_path: str = "app/ml/artifacts/burnout_model.joblib"
    overspend_model_path: str = "app/ml/artifacts/overspend_model.joblib"

    class Config:
        env_file = (".env", ".env.local")


settings = Settings()
