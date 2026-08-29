# Path: app/schemas/prediction.py
from datetime import date

from pydantic import BaseModel, EmailStr, Field


class DailyPayload(BaseModel):
    """Matches PredictionPayload.toJson() in Flutter's prediction_api_service.dart"""

    sleep_hours: float = Field(ge=0, le=24)
    steps: int = Field(ge=0, le=200_000)
    screen_time_hours: float = Field(ge=0, le=24)
    daily_spending: float = Field(ge=0, le=10_000_000)
    calendar_events: int = Field(ge=0, le=1000)
    high_priority_tasks: int = Field(ge=0, le=1000)
    total_workload: int = Field(default=0, ge=0, le=10000)
    monthly_budget: float | None = Field(default=None, ge=0, le=100_000_000)
    entry_date: date | None = None


class ScoreResponse(BaseModel):
    """Matches the LifestyleScores.fromJson() Mir needs to add on the Flutter side."""

    productivity: int
    financial_health: int
    stress_risk: int
    burnout_risk: str
    overspending_risk: str
    recommendations: list[str]


class RegisterPayload(BaseModel):
    email: EmailStr
    password: str = Field(min_length=12, max_length=128)


class LoginPayload(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class GoogleSignInPayload(BaseModel):
    id_token: str = Field(min_length=20, max_length=4096)
