# Path: main.py (backend project root)
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import Base, engine
from app.api.routes import router

# Creates the daily_entries table on startup if it doesn't exist yet.
Base.metadata.create_all(bind=engine)

app = FastAPI(title="LifeLens API", version="1.0.0")

# Allows the Flutter app (running on a device/emulator) to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)


@app.get("/")
def root():
    return {"message": "LifeLens API is running", "docs": "/docs"}