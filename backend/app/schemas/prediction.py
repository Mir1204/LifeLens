# Path: app/schemas/prediction.py
from datetime import date

from pydantic import BaseModel, Field


class DailyPayload(BaseModel):
    """Matches PredictionPayload.toJson() in Flutter's prediction_api_service.dart"""

    user_id: str = Field(default="mir_demo_user")
    sleep_hours: float
    steps: int
    screen_time_hours: float
    daily_spending: float
    calendar_events: int
    high_priority_tasks: int
    total_workload: int = 0
    monthly_budget: float | None = None
    entry_date: date | None = None


class ScoreResponse(BaseModel):
    """Matches the LifestyleScores.fromJson() Mir needs to add on the Flutter side."""

    productivity: int
    financial_health: int
    stress_risk: int
    burnout_risk: str
    overspending_risk: str
    recommendations: list[str]
