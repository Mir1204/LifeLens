# Path: app/ml/training/train_overspend_model.py
"""
Trains the overspending risk classifier (Low/Medium/High) on the
synthetic dataset. Run generate_synthetic_data.py first.

Run: python -m app.ml.training.train_overspend_model
Output: app/ml/artifacts/overspend_model.joblib
"""
import os
import joblib
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report

DATA_PATH = "app/ml/data/overspend_data.csv"
ARTIFACT_PATH = "app/ml/artifacts/overspend_model.joblib"

FEATURES = ["spending_today", "spending_avg_7d", "spending_trend_7d"]
TARGET = "overspending_risk"


def main():
    df = pd.read_csv(DATA_PATH)
    X = df[FEATURES]
    y = df[TARGET]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    model = LogisticRegression(max_iter=1000, multi_class="multinomial")
    model.fit(X_train, y_train)
    pred = model.predict(X_test)
    acc = accuracy_score(y_test, pred)

    print(f"Logistic Regression accuracy: {acc:.3f}")
    print("\nClassification report:\n", classification_report(y_test, pred))

    os.makedirs(os.path.dirname(ARTIFACT_PATH), exist_ok=True)
    joblib.dump(model, ARTIFACT_PATH)
    print(f"Saved model to {ARTIFACT_PATH}")


if __name__ == "__main__":
    main()