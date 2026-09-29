# Path: app/ml/training/train_static_stress_model.py
"""
Trains a static (snapshot) stress-risk classifier using the real Kaggle
Sleep Health & Lifestyle dataset (preprocessed by preprocess_kaggle_data.py).

Tries Logistic Regression and Random Forest; keeps the better one.

Input : app/ml/data/static_stress_data.csv
Output: app/ml/artifacts/static_stress_model.joblib

Run: python -m app.ml.training.train_static_stress_model
"""

import os
from pathlib import Path

import joblib
import pandas as pd
from sklearn.ensemble import HistGradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from app.ml.training.training_utils import balance_classes

DATA_PATH = Path(__file__).resolve().parents[1] / "data" / "static_stress_data.csv"
ARTIFACT_PATH = Path(__file__).resolve().parents[1] / "artifacts" / "static_stress_model.joblib"

FEATURES = [
    "sleep_hours_today",
    "sleep_quality_today",
    "steps_today",
    "physical_activity_today",
    "workload_proxy_today",
    "sleep_decline_proxy",
]
TARGET = "stress_risk"


def build_lr_pipeline() -> Pipeline:
    return Pipeline([
        ("scaler", StandardScaler()),
        ("clf", LogisticRegression(max_iter=1000, random_state=42)),
    ])


def build_rf_pipeline() -> Pipeline:
    return Pipeline([
        ("scaler", StandardScaler()),
        ("clf", RandomForestClassifier(n_estimators=200, random_state=42, n_jobs=-1)),
    ])


def build_hist_gradient_boosting_model() -> HistGradientBoostingClassifier:
    return HistGradientBoostingClassifier(
        learning_rate=0.05,
        max_iter=300,
        max_leaf_nodes=15,
        random_state=42,
    )


def main() -> None:
    df = pd.read_csv(DATA_PATH)
    print(f"Loaded {len(df)} rows from {DATA_PATH}")
    print("Original class distribution:")
    print(df[TARGET].value_counts().to_string())

    train_df, test_df = train_test_split(
        df,
        test_size=0.2,
        random_state=42,
        stratify=df[TARGET],
    )
    train_df = balance_classes(train_df, TARGET)
    print("\nBalanced class distribution:")
    print(train_df[TARGET].value_counts().to_string())

    X_train = train_df[FEATURES]
    y_train = train_df[TARGET]
    X_test = test_df[FEATURES]
    y_test = test_df[TARGET]

    # ── Logistic Regression ────────────────────────────────────────────────────
    lr = build_lr_pipeline()
    lr.fit(X_train, y_train)
    lr_acc = accuracy_score(y_test, lr.predict(X_test))
    print(f"\nLogistic Regression  accuracy: {lr_acc:.4f}")
    print(classification_report(y_test, lr.predict(X_test)))

    # ── Random Forest ──────────────────────────────────────────────────────────
    rf = build_rf_pipeline()
    rf.fit(X_train, y_train)
    rf_acc = accuracy_score(y_test, rf.predict(X_test))
    print(f"Random Forest        accuracy: {rf_acc:.4f}")
    print(classification_report(y_test, rf.predict(X_test)))

    # ── Histogram Gradient Boosting ──────────────────────────────────────────
    hist = build_hist_gradient_boosting_model()
    hist.fit(X_train, y_train)
    hist_acc = accuracy_score(y_test, hist.predict(X_test))
    print(f"HistGradientBoosting  accuracy: {hist_acc:.4f}")
    print(classification_report(y_test, hist.predict(X_test)))

    # ── Keep the winner ────────────────────────────────────────────────────────
    candidates = [
        (lr, "Logistic Regression", lr_acc),
        (rf, "Random Forest", rf_acc),
        (hist, "HistGradientBoosting", hist_acc),
    ]
    best, best_name, best_acc = max(candidates, key=lambda candidate: candidate[2])

    print(f"\n>> Saving {best_name} (acc={best_acc:.4f}) -> {ARTIFACT_PATH}")
    os.makedirs(os.path.dirname(ARTIFACT_PATH), exist_ok=True)
    joblib.dump(best, ARTIFACT_PATH)
    print("Done.")


if __name__ == "__main__":
    main()
