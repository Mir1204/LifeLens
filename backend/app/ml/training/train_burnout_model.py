# Path: app/ml/training/train_burnout_model.py
"""
Trains the burnout-risk classifier (Low/Medium/High) on the synthetic
time-series dataset. Run generate_synthetic_data.py first.

Tries Logistic Regression and XGBoost; keeps the better one.

Input : app/ml/data/burnout_data.csv
Output: app/ml/artifacts/burnout_model.joblib

Run: python -m app.ml.training.train_burnout_model
"""

import os
import joblib
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler, LabelEncoder

from app.ml.wrappers import LabeledXGB

DATA_PATH = "app/ml/data/burnout_data.csv"
ARTIFACT_PATH = "app/ml/artifacts/burnout_model.joblib"

FEATURES = [
    "sleep_hours_avg_3d",
    "sleep_hours_avg_7d",
    "sleep_trend_7d",
    "screen_time_avg_3d",
    "screen_time_avg_7d",
    "screen_time_trend_7d",
    "workload_avg_7d",
    "high_priority_tasks_today",
]
TARGET = "burnout_risk"



def build_lr_pipeline() -> Pipeline:
    return Pipeline([
        ("scaler", StandardScaler()),
        ("clf", LogisticRegression(max_iter=1000, random_state=42)),
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
    print(classification_report(y_test, lr.predict(X_test), zero_division=0))

    best, best_name, best_acc = lr, "Logistic Regression", lr_acc

    # ── XGBoost (optional) ────────────────────────────────────────────────────
    try:
        from xgboost import XGBClassifier

        le = LabelEncoder()
        y_train_enc = le.fit_transform(y_train)
        y_test_enc  = le.transform(y_test)

        xgb_clf = XGBClassifier(
            n_estimators=200,
            max_depth=4,
            learning_rate=0.1,
            eval_metric="mlogloss",
            random_state=42,
            n_jobs=-1,
        )
        xgb_clf.fit(X_train, y_train_enc)
        xgb_acc = accuracy_score(y_test_enc, xgb_clf.predict(X_test))

        xgb_wrapped = LabeledXGB(xgb_clf, le)

        print(f"XGBoost              accuracy: {xgb_acc:.4f}")
        print(classification_report(y_test_enc, xgb_clf.predict(X_test),
                                    target_names=le.classes_, zero_division=0))

        if xgb_acc > best_acc:
            best, best_name, best_acc = xgb_wrapped, "XGBoost", xgb_acc

    except ImportError:
        print("xgboost not installed — using Logistic Regression only.")

    # ── Save winner ────────────────────────────────────────────────────────────
    print(f"\n>> Saving {best_name} (acc={best_acc:.4f}) -> {ARTIFACT_PATH}")
    os.makedirs(os.path.dirname(ARTIFACT_PATH), exist_ok=True)
    joblib.dump(best, ARTIFACT_PATH)
    print("Done.")


if __name__ == "__main__":
    main()
