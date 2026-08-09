# Path: app/services/prediction.py
"""
Prediction service – loads trained model artifacts and produces risk scores.

Burnout / Stress  → dual-model ensemble:
    1. static_stress_model  (trained on real Kaggle data, snapshot features)
    2. burnout_model        (trained on synthetic time-series rolling features)
    Both models are optional; the service degrades gracefully to formula-based
    fallback if neither artifact exists.

Overspending → single model (synthetic-trained Logistic Regression).
"""

import os
import joblib
import pandas as pd

from app.core.config import settings

# ── cached model handles ───────────────────────────────────────────────────────
_burnout_model = None
_overspend_model = None
_static_stress_model = None

# ── feature lists ─────────────────────────────────────────────────────────────
BURNOUT_FEATURES = [
    "sleep_hours_avg_3d",
    "sleep_hours_avg_7d",
    "sleep_trend_7d",
    "screen_time_avg_3d",
    "screen_time_avg_7d",
    "screen_time_trend_7d",
    "workload_avg_7d",
    "high_priority_tasks_today",
]

STATIC_STRESS_FEATURES = [
    "sleep_hours_today",
    "sleep_quality_today",
    "steps_today",
    "physical_activity_today",
    "workload_proxy_today",
    "sleep_decline_proxy",
]

OVERSPEND_FEATURES = [
    "spending_today",
    "spending_avg_7d",
    "spending_trend_7d",
]

# ── label ordering ─────────────────────────────────────────────────────────────
_LABEL_SCORE = {"Low": 0, "Medium": 1, "High": 2}
_SCORE_LABEL = {0: "Low", 1: "Medium", 2: "High"}


# ── loaders ───────────────────────────────────────────────────────────────────
def _load_model(path: str):
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


def get_static_stress_model():
    global _static_stress_model
    if _static_stress_model is None:
        _static_stress_model = _load_model(settings.static_stress_model_path)
    return _static_stress_model


# ── static feature derivation ─────────────────────────────────────────────────
def _derive_static_features(features: dict) -> dict:
    """
    Build the 6 static stress features from the rolling-feature dict that
    feature_engineering.py already produces.  All derivations are fallback-safe
    so the static model always gets a valid input row even when optional fields
    are absent.

    Mapping (aligns with preprocess_kaggle_data.py):
      sleep_hours_today        <- features["sleep_hours_today"]          (direct)
      sleep_quality_today      <- scaled from sleep_hours (proxy if not supplied)
      steps_today              <- features["steps_today"]                (direct)
      physical_activity_today  <- steps converted to approx. active-minutes proxy
      workload_proxy_today     <- total_workload mapped to 1-5 scale
      sleep_decline_proxy      <- derived from sleep trend + screen time
    """
    sleep_hours = features.get("sleep_hours_today", 7.0)

    # sleep_quality_today: ideally 1-10; proxy = sleep_hours mapped to 1-10
    sleep_quality = min(10.0, max(1.0, (sleep_hours / 9.0) * 10.0))

    # steps_today: direct from payload
    steps = features.get("steps_today", 5000)

    # physical_activity_today (approx minutes of activity from steps)
    # 100 steps ≈ 1 active minute is a reasonable heuristic
    physical_activity = min(120, max(0, steps // 100))

    # workload_proxy_today: total_workload from app (task-unit count) → 1-5 scale
    raw_workload = features.get("workload_today", 0)
    # tasks: 0→1, 1-2→2, 3-4→3, 5-7→4, 8+→5
    if raw_workload == 0:
        workload_proxy = 1
    elif raw_workload <= 2:
        workload_proxy = 2
    elif raw_workload <= 4:
        workload_proxy = 3
    elif raw_workload <= 7:
        workload_proxy = 4
    else:
        workload_proxy = 5

    # sleep_decline_proxy (0-3): mirrors preprocess_kaggle_data logic
    # +1 if 7-day sleep trend is declining
    # +1 if avg sleep < 6 hours
    # +1 if screen time avg is high (>6 h, a sleep-quality inhibitor)
    decline = 0
    if features.get("sleep_trend_7d", 0.0) < -0.3:
        decline += 1
    if features.get("sleep_hours_avg_7d", sleep_hours) < 6.0:
        decline += 1
    if features.get("screen_time_avg_7d", 0.0) > 6.0:
        decline += 1

    return {
        "sleep_hours_today":       sleep_hours,
        "sleep_quality_today":     sleep_quality,
        "steps_today":             steps,
        "physical_activity_today": physical_activity,
        "workload_proxy_today":    workload_proxy,
        "sleep_decline_proxy":     decline,
    }


# ── helpers ───────────────────────────────────────────────────────────────────
def _model_high_proba(model, row_df: pd.DataFrame) -> tuple[float, str]:
    """
    Returns (high_class_probability, predicted_label) for a model that exposes
    predict_proba and classes_ (sklearn / wrapped XGB both do).
    """
    proba = model.predict_proba(row_df)[0]
    classes = list(model.classes_)
    label = classes[proba.argmax()]
    high_idx = classes.index("High") if "High" in classes else proba.argmax()
    return float(proba[high_idx]), str(label)


def _fallback_stress_risk(features: dict) -> tuple[int, str]:
    """
    Formula-based fallback used only when both ML models are unavailable.
    Mirrors the Flutter local formula so the API never breaks during early dev.
    """
    sleep_score = max(0.0, min(100.0, features.get("sleep_hours_today", 7.0) / 8 * 100))
    value = (
        (100 - sleep_score) * 0.35
        + features.get("screen_time_today", 0.0) * 5
        + features.get("high_priority_tasks_today", 0) * 10
        + features.get("workload_today", 0) * 2
    )
    score = round(max(0, min(100, value)))
    label = "High" if score >= 70 else "Medium" if score >= 40 else "Low"
    return score, label


# ── public API ────────────────────────────────────────────────────────────────
def predict_burnout_risk(features: dict) -> tuple[int, str]:
    """
    Returns (stress_risk_score: int 0-100, burnout_label: 'Low'|'Medium'|'High').

    Ensemble strategy:
      • If both models available:
            final_label_score = 0.4 × static_score + 0.6 × trend_score
            numeric score = weighted average of 'High'-class probabilities
      • If only one model available:  use it directly
      • If neither:  fall back to rule-based formula
    """
    static_model = get_static_stress_model()
    trend_model  = get_burnout_model()

    static_high_p: float | None = None
    static_label: str | None   = None
    trend_high_p: float | None = None
    trend_label: str | None    = None

    # ── static model (Kaggle-based snapshot) ──────────────────────────────────
    if static_model is not None:
        static_feats = _derive_static_features(features)
        static_row = pd.DataFrame([static_feats])[STATIC_STRESS_FEATURES]
        static_high_p, static_label = _model_high_proba(static_model, static_row)

    # ── trend model (synthetic time-series) ───────────────────────────────────
    if trend_model is not None:
        trend_row = pd.DataFrame([{k: features.get(k, 0) for k in BURNOUT_FEATURES}])
        trend_high_p, trend_label = _model_high_proba(trend_model, trend_row)

    # ── combine ───────────────────────────────────────────────────────────────
    if static_label is not None and trend_label is not None:
        # Weighted ensemble: static 40%, trend 60%
        s_score = _LABEL_SCORE[static_label]
        t_score = _LABEL_SCORE[trend_label]
        combined_label_score = 0.4 * s_score + 0.6 * t_score
        final_label = _SCORE_LABEL[round(combined_label_score)]

        # Numeric 0-100 score = weighted High-class probability
        high_p = 0.4 * static_high_p + 0.6 * trend_high_p
        numeric_score = round(high_p * 100)

    elif static_label is not None:
        final_label  = static_label
        numeric_score = round(static_high_p * 100)

    elif trend_label is not None:
        final_label   = trend_label
        numeric_score = round(trend_high_p * 100)

    else:
        return _fallback_stress_risk(features)

    return numeric_score, final_label


def predict_overspending_risk(features: dict) -> str:
    """Returns 'Low' | 'Medium' | 'High'."""
    model = get_overspend_model()

    if model is None:
        spending_ratio = features.get("spending_today", 0) / max(
            features.get("spending_avg_7d", 1), 1
        )
        return "High" if spending_ratio > 1.5 else "Medium" if spending_ratio > 1.15 else "Low"

    row = pd.DataFrame([{k: features.get(k, 0) for k in OVERSPEND_FEATURES}])
    proba  = model.predict_proba(row)[0]
    classes = list(model.classes_)
    label  = classes[proba.argmax()]
    return str(label)