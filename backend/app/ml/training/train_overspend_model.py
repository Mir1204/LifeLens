# Path: app/ml/training/train_overspend_model.py
"""
Trains the overspending risk classifier (Low/Medium/High) on real income
and expense data.

Run: python -m app.ml.training.train_overspend_model
Output: app/ml/artifacts/overspend_model.joblib
"""
import os
from pathlib import Path

import joblib
import pandas as pd
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split

from app.ml.training.training_utils import balance_classes, prepare_income_overspend_data

DATA_PATH = Path(__file__).resolve().parents[2] / "model_data" / "data.csv"
ARTIFACT_PATH = Path(__file__).resolve().parents[1] / "artifacts" / "overspend_model.joblib"

FEATURES = [
    "Income",
    "monthly_spending",
    "expense_ratio",
]
TARGET = "overspending_risk"


def main():
    df = prepare_income_overspend_data(pd.read_csv(DATA_PATH))
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

    model = HistGradientBoostingClassifier(
        learning_rate=0.05,
        max_iter=300,
        max_leaf_nodes=15,
        random_state=42,
    )
    model.fit(X_train, y_train)
    pred = model.predict(X_test)
    acc = accuracy_score(y_test, pred)

    print(f"HistGradientBoosting accuracy: {acc:.3f}")
    print("\nClassification report:\n", classification_report(y_test, pred))

    os.makedirs(os.path.dirname(ARTIFACT_PATH), exist_ok=True)
    joblib.dump(model, ARTIFACT_PATH)
    print(f"Saved model to {ARTIFACT_PATH}")


if __name__ == "__main__":
    main()