# Path: app/api/routes.py
from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.daily_entry import DailyEntry
from app.schemas.prediction import DailyPayload, ScoreResponse
from app.services.feature_engineering import build_rolling_features
from app.services.scoring import (
    calculate_productivity,
    calculate_financial_health,
    risk_label,
    build_recommendations,
)
from app.services.prediction import predict_burnout_risk, predict_overspending_risk

router = APIRouter()


@router.post("/predict/daily-score", response_model=ScoreResponse)
def predict_daily_score(payload: DailyPayload, db: Session = Depends(get_db)):
    entry_date = payload.entry_date or date.today()

    today_dict = {
        "sleep_hours": payload.sleep_hours,
        "steps": payload.steps,
        "screen_time_hours": payload.screen_time_hours,
        "daily_spending": payload.daily_spending,
        "calendar_events": payload.calendar_events,
        "high_priority_tasks": payload.high_priority_tasks,
        "total_workload": payload.total_workload,
    }

    # 1. Persist today's payload so future requests have history to look back on
    existing = (
        db.query(DailyEntry)
        .filter(DailyEntry.user_id == payload.user_id, DailyEntry.entry_date == entry_date)
        .first()
    )
    if existing:
        for key, value in today_dict.items():
            setattr(existing, key, value)
    else:
        db.add(DailyEntry(user_id=payload.user_id, entry_date=entry_date, **today_dict))
    db.commit()

    # 2. Build rolling window features from stored history + today's values
    features = build_rolling_features(db, payload.user_id, today_dict, entry_date)

    # 3. Rule-based scores (explainable, no ML needed)
    productivity = calculate_productivity(
        sleep_hours=payload.sleep_hours,
        steps=payload.steps,
        screen_time_hours=payload.screen_time_hours,
        total_workload=payload.total_workload,
    )
    financial_health = calculate_financial_health(payload.daily_spending)

    # 4. ML predictions (fallback to formula automatically if model not trained yet)
    stress_risk, burnout_label = predict_burnout_risk(features)
    overspending_label = predict_overspending_risk(features)

    # 5. Recommendations
    recommendations = build_recommendations(
        sleep_hours=payload.sleep_hours,
        screen_time_hours=payload.screen_time_hours,
        financial_health=financial_health,
        stress_risk=stress_risk,
        productivity=productivity,
    )

    return ScoreResponse(
        productivity=productivity,
        financial_health=financial_health,
        stress_risk=stress_risk,
        burnout_risk=burnout_label,
        overspending_risk=overspending_label,
        recommendations=recommendations,
    )


@router.get("/health")
def health_check():
    return {"status": "ok"}