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
import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

DATA_PATH = "app/ml/data/static_stress_data.csv"
ARTIFACT_PATH = "app/ml/artifacts/static_stress_model.joblib"

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


def main() -> None:
    df = pd.read_csv(DATA_PATH)
    print(f"Loaded {len(df)} rows from {DATA_PATH}")

    X = df[FEATURES]
    y = df[TARGET]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

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

    # ── Keep the winner ────────────────────────────────────────────────────────
    if rf_acc >= lr_acc:
        best, best_name, best_acc = rf, "Random Forest", rf_acc
    else:
        best, best_name, best_acc = lr, "Logistic Regression", lr_acc

    print(f"\n>> Saving {best_name} (acc={best_acc:.4f}) -> {ARTIFACT_PATH}")
    os.makedirs(os.path.dirname(ARTIFACT_PATH), exist_ok=True)
    joblib.dump(best, ARTIFACT_PATH)
    print("Done.")


if __name__ == "__main__":
    main()
