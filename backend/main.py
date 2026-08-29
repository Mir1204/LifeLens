# Path: main.py (backend project root)
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from sqlalchemy import text

from app.database import Base, engine
from app.api.routes import router
from app.core.config import settings

# Creates the daily_entries table on startup if it doesn't exist yet.
Base.metadata.create_all(bind=engine)

# Lightweight migration for existing semester-project deployments.
with engine.begin() as connection:
    if engine.dialect.name == "postgresql":
        connection.execute(text("ALTER TABLE backend_users ALTER COLUMN password_hash DROP NOT NULL"))
        connection.execute(text("ALTER TABLE backend_users ADD COLUMN IF NOT EXISTS google_subject VARCHAR UNIQUE"))
        connection.execute(text("ALTER TABLE backend_users ADD COLUMN IF NOT EXISTS display_name VARCHAR"))
    elif engine.dialect.name == "sqlite":
        columns = {row[1] for row in connection.execute(text("PRAGMA table_info(backend_users)"))}
        if "google_subject" not in columns:
            connection.execute(text("ALTER TABLE backend_users ADD COLUMN google_subject VARCHAR"))
            connection.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_backend_users_google_subject ON backend_users (google_subject)"))
        if "display_name" not in columns:
            connection.execute(text("ALTER TABLE backend_users ADD COLUMN display_name VARCHAR"))

app = FastAPI(title="LifeLens API", version="1.0.0")

# Allows the Flutter app (running on a device/emulator) to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["POST", "GET"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(router)


@app.get("/")
def root():
    return {"message": "LifeLens API is running", "docs": "/docs"}
