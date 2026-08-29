from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import get_db
from app.models.daily_entry import BackendUser, DailyEntry
from app.schemas.prediction import DailyPayload, LoginPayload, RegisterPayload, ScoreResponse, TokenResponse
from app.services.feature_engineering import build_rolling_features
from app.services.prediction import predict_burnout_risk, predict_overspending_risk
from app.services.scoring import calculate_financial_health, calculate_productivity, build_recommendations

router = APIRouter()
security = HTTPBearer(auto_error=False)
password_hash = PasswordHash.recommended()


def _issue_token(user_id: str) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    return jwt.encode({"sub": user_id, "exp": expires_at}, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def current_user_id(credentials: HTTPAuthorizationCredentials | None = Depends(security)) -> str:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
    try:
        payload = jwt.decode(credentials.credentials, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
        user_id = payload.get("sub")
        if not isinstance(user_id, str) or not user_id:
            raise ValueError("missing subject")
        return user_id
    except jwt.PyJWTError as error:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token") from error


@router.post("/auth/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterPayload, db: Session = Depends(get_db)):
    email = str(payload.email).lower()
    if db.query(BackendUser).filter(BackendUser.email == email).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Account already exists")
    user = BackendUser(id=str(uuid4()), email=email, password_hash=password_hash.hash(payload.password))
    db.add(user)
    db.commit()
    return TokenResponse(access_token=_issue_token(user.id))


@router.post("/auth/login", response_model=TokenResponse)
def login(payload: LoginPayload, db: Session = Depends(get_db)):
    user = db.query(BackendUser).filter(BackendUser.email == str(payload.email).lower()).first()
    if user is None or not password_hash.verify(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    return TokenResponse(access_token=_issue_token(user.id))


@router.post("/predict/daily-score", response_model=ScoreResponse)
def predict_daily_score(payload: DailyPayload, user_id: str = Depends(current_user_id), db: Session = Depends(get_db)):
    entry_date = payload.entry_date or datetime.now(timezone.utc).date()
    today_dict = {"sleep_hours": payload.sleep_hours, "steps": payload.steps, "screen_time_hours": payload.screen_time_hours, "daily_spending": payload.daily_spending, "calendar_events": payload.calendar_events, "high_priority_tasks": payload.high_priority_tasks, "total_workload": payload.total_workload}
    existing = db.query(DailyEntry).filter(DailyEntry.user_id == user_id, DailyEntry.entry_date == entry_date).first()
    if existing:
        for key, value in today_dict.items():
            setattr(existing, key, value)
    else:
        db.add(DailyEntry(user_id=user_id, entry_date=entry_date, **today_dict))
    db.commit()
    features = build_rolling_features(db, user_id, today_dict, entry_date)
    productivity = calculate_productivity(payload.sleep_hours, payload.steps, payload.screen_time_hours, payload.total_workload)
    financial_health = calculate_financial_health(payload.daily_spending, payload.monthly_budget)
    stress_risk, burnout_label = predict_burnout_risk(features)
    overspending_label = predict_overspending_risk(features)
    recommendations = build_recommendations(payload.sleep_hours, payload.screen_time_hours, financial_health, stress_risk, productivity, payload.monthly_budget)
    return ScoreResponse(productivity=productivity, financial_health=financial_health, stress_risk=stress_risk, burnout_risk=burnout_label, overspending_risk=overspending_label, recommendations=recommendations)


@router.delete("/me/data", status_code=status.HTTP_204_NO_CONTENT)
def delete_remote_data(user_id: str = Depends(current_user_id), db: Session = Depends(get_db)):
    db.query(DailyEntry).filter(DailyEntry.user_id == user_id).delete(synchronize_session=False)
    db.query(BackendUser).filter(BackendUser.id == user_id).delete(synchronize_session=False)
    db.commit()


@router.get("/health")
def health_check():
    return {"status": "ok"}
