from datetime import datetime, timedelta, timezone
import logging
from uuid import uuid4

import jwt
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import get_db
from app.models.daily_entry import BackendUser, DailyEntry, RefreshSession
from app.schemas.prediction import DailyPayload, GoogleSignInPayload, LoginPayload, RefreshTokenPayload, RegisterPayload, ScoreResponse, TokenResponse
from app.services.feature_engineering import build_rolling_features
from app.services.prediction import predict_burnout_risk, predict_overspending_risk
from app.services.scoring import calculate_financial_health, calculate_productivity, build_recommendations

router = APIRouter()
security = HTTPBearer(auto_error=False)
password_hash = PasswordHash.recommended()
logger = logging.getLogger(__name__)


def _encode_token(claims: dict) -> str:
    return jwt.encode(
        claims,
        settings.jwt_keys[settings.jwt_active_key_id],
        algorithm=settings.jwt_algorithm,
        headers={"kid": settings.jwt_active_key_id},
    )


def _decode_token(token: str) -> dict:
    header = jwt.get_unverified_header(token)
    key_id = header.get("kid", "default")
    key = settings.jwt_keys.get(key_id)
    if not isinstance(key, str):
        raise jwt.InvalidTokenError("Unknown signing key")
    return jwt.decode(token, key, algorithms=[settings.jwt_algorithm])


def _issue_access_token(user_id: str, session_token_id: str) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    return _encode_token(
        {"sub": user_id, "sid": session_token_id, "type": "access", "exp": expires_at},
    )


def _issue_tokens(user_id: str, db: Session) -> TokenResponse:
    refresh_expires_at = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    token_id = str(uuid4())
    refresh_token = _encode_token(
        {"sub": user_id, "type": "refresh", "jti": token_id, "exp": refresh_expires_at},
    )
    db.add(RefreshSession(user_id=user_id, token_id=token_id, expires_at=refresh_expires_at))
    db.commit()
    return TokenResponse(
        access_token=_issue_access_token(user_id, token_id),
        refresh_token=refresh_token,
    )


def current_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: Session = Depends(get_db),
) -> str:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
    try:
        payload = _decode_token(credentials.credentials)
        user_id = payload.get("sub")
        session_token_id = payload.get("sid")
        if (not isinstance(user_id, str) or not user_id or
                not isinstance(session_token_id, str) or
                payload.get("type") != "access"):
            raise ValueError("missing subject")
        active_session = db.query(RefreshSession).filter(
            RefreshSession.user_id == user_id,
            RefreshSession.token_id == session_token_id,
            RefreshSession.revoked.is_(False),
        ).first()
        if active_session is None:
            raise ValueError("session revoked")
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
    return _issue_tokens(user.id, db)


@router.post("/auth/login", response_model=TokenResponse)
def login(payload: LoginPayload, db: Session = Depends(get_db)):
    user = db.query(BackendUser).filter(BackendUser.email == str(payload.email).lower()).first()
    if user is None or user.password_hash is None or not password_hash.verify(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    return _issue_tokens(user.id, db)


@router.post("/auth/google", response_model=TokenResponse)
def google_sign_in(payload: GoogleSignInPayload, db: Session = Depends(get_db)):
    """Exchange a Google-verified ID token for a LifeLens bearer token."""
    if not settings.google_web_client_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google sign-in is not configured on this server",
        )
    try:
        claims = google_id_token.verify_oauth2_token(
            payload.id_token,
            google_requests.Request(),
            settings.google_web_client_id,
        )
    except ValueError as error:
        # Token contents must never be logged. The detail is safe to return to
        # the client and tells it that the token audience or issuer was rejected.
        logger.info("Google ID token rejected")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google token could not be verified",
        ) from error
    except Exception as error:
        # Google certificate retrieval and other upstream failures are not an
        # authentication failure. Keep only a non-sensitive error category in
        # Render logs; exceptions can include request context.
        logger.error(
            "Google token verification service failed (%s)",
            type(error).__name__,
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google verification is temporarily unavailable",
        ) from error

    subject = claims.get("sub")
    email = claims.get("email")
    if not isinstance(subject, str) or not isinstance(email, str) or not claims.get("email_verified"):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Google account email is not verified")

    user = db.query(BackendUser).filter(BackendUser.google_subject == subject).first()
    if user is None:
        user = db.query(BackendUser).filter(BackendUser.email == email.lower()).first()
        if user is None:
            user = BackendUser(
                id=str(uuid4()),
                email=email.lower(),
                google_subject=subject,
                display_name=claims.get("name") if isinstance(claims.get("name"), str) else None,
            )
            db.add(user)
        else:
            user.google_subject = subject
        db.commit()
    return _issue_tokens(user.id, db)


@router.post("/auth/refresh", response_model=TokenResponse)
def refresh_token(payload: RefreshTokenPayload, db: Session = Depends(get_db)):
    try:
        claims = _decode_token(payload.refresh_token)
        user_id = claims.get("sub")
        token_id = claims.get("jti")
        if (claims.get("type") != "refresh" or not isinstance(user_id, str)
                or not isinstance(token_id, str)):
            raise ValueError("invalid refresh token")
    except (jwt.PyJWTError, ValueError) as error:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token") from error
    if db.query(BackendUser).filter(BackendUser.id == user_id).first() is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account no longer exists")
    session = db.query(RefreshSession).filter(
        RefreshSession.user_id == user_id,
        RefreshSession.token_id == token_id,
        RefreshSession.revoked.is_(False),
    ).first()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    if session is None or session.expires_at <= now:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh session was revoked or expired")
    session.revoked = True
    session.revoked_at = now
    db.commit()
    return _issue_tokens(user_id, db)


@router.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(payload: RefreshTokenPayload, db: Session = Depends(get_db)):
    """Revoke this device's refresh session; access tokens expire quickly."""
    try:
        claims = _decode_token(payload.refresh_token)
        token_id = claims.get("jti")
        if claims.get("type") != "refresh" or not isinstance(token_id, str):
            raise ValueError("invalid refresh token")
    except (jwt.PyJWTError, ValueError) as error:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token") from error
    session = db.query(RefreshSession).filter(RefreshSession.token_id == token_id).first()
    if session is not None:
        session.revoked = True
        session.revoked_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.commit()


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
    db.query(RefreshSession).filter(RefreshSession.user_id == user_id).delete(synchronize_session=False)
    db.query(BackendUser).filter(BackendUser.id == user_id).delete(synchronize_session=False)
    db.commit()


@router.get("/health")
def health_check():
    return {"status": "ok"}
