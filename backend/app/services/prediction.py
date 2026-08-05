# Path: app/services/prediction.py
import os
import joblib
import pandas as pd

from app.core.config import settings

_burnout_model = None
_overspend_model = None

BURNOUT_FEATURES = [
    "sleep_hours_avg_3d", "sleep_hours_avg_7d", "sleep_trend_7d",
    "screen_time_avg_3d", "screen_time_avg_7d", "screen_time_trend_7d",
    "workload_avg_7d", "high_priority_tasks_today",
]

OVERSPEND_FEATURES = [
    "spending_today", "spending_avg_7d", "spending_trend_7d",
]


def _load_model(path):
    if os.path.exists(path):
        return joblib.load(path)
    return None


def get_burnout_model():
    global _burnout_model
    if _burnout_model is None:
        _burnout_model = _load_model(settings.burnout_model_path)
    return _burnout_model


def get_overspend_model():
    global _overspend_model
    if _overspend_model is None:
        _overspend_model = _load_model(settings.overspend_model_path)
    return _overspend_model


def _fallback_stress_risk(features: dict) -> int:
    """Used only if the trained model artifact isn't present yet (e.g. before
    Week X model training is complete). Mirrors the old Flutter formula so the
    API never breaks during early development."""
    sleep_score = max(0, min(100, features["sleep_hours_today"] / 8 * 100))
    value = (
        (100 - sleep_score) * 0.35
        + features["screen_time_today"] * 5
        + features["high_priority_tasks_today"] * 10
        + features["workload_today"] * 2
    )
    return round(max(0, min(100, value)))


def predict_burnout_risk(features: dict) -> tuple[int, str]:
    model = get_burnout_model()
    if model is None:
        score = _fallback_stress_risk(features)
        label = "High" if score >= 70 else "Medium" if score >= 40 else "Low"
        return score, label

    row = pd.DataFrame([{k: features[k] for k in BURNOUT_FEATURES}])
    proba = model.predict_proba(row)[0]
    classes = model.classes_
    label = classes[proba.argmax()]
    # Convert class probability into a 0-100 "risk score" for the score card
    high_idx = list(classes).index("High") if "High" in classes else -1
    score = round(proba[high_idx] * 100) if high_idx != -1 else round(proba.max() * 100)
    return score, str(label)


def predict_overspending_risk(features: dict) -> str:
    model = get_overspend_model()
    if model is None:
        spending_ratio = features["spending_today"] / max(features["spending_avg_7d"], 1)
        return "High" if spending_ratio > 1.5 else "Medium" if spending_ratio > 1.15 else "Low"

    row = pd.DataFrame([{k: features[k] for k in OVERSPEND_FEATURES}])
    proba = model.predict_proba(row)[0]
    classes = model.classes_
    label = classes[proba.argmax()]
    return str(label)