"""Evaluate the three trained LifeLens risk-classification models.

Run from the backend folder:
    python -m app.ml.training.evaluation

The evaluation recreates the deterministic balanced train/test split used by
the training scripts and evaluates each saved model on its held-out test set.
All three models predict categorical labels (Low, Medium, High), so accuracy,
balanced accuracy, and classification reports are used instead of MSE.
"""

from dataclasses import dataclass
from pathlib import Path

import joblib
import pandas as pd
from sklearn.metrics import accuracy_score, balanced_accuracy_score, classification_report
from sklearn.model_selection import train_test_split

from app.ml.training.training_utils import add_overspend_features, balance_classes


BASE_DIR = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class ModelEvaluationConfig:
    name: str
    data_path: Path
    artifact_path: Path
    features: list[str]
    target: str


MODEL_CONFIGS = [
    ModelEvaluationConfig(
        name="Static stress",
        data_path=BASE_DIR / "data" / "static_stress_data.csv",
        artifact_path=BASE_DIR / "artifacts" / "static_stress_model.joblib",
        features=[
            "sleep_hours_today",
            "sleep_quality_today",
            "steps_today",
            "physical_activity_today",
            "workload_proxy_today",
            "sleep_decline_proxy",
        ],
        target="stress_risk",
    ),
    ModelEvaluationConfig(
        name="Burnout",
        data_path=BASE_DIR / "data" / "burnout_data.csv",
        artifact_path=BASE_DIR / "artifacts" / "burnout_model.joblib",
        features=[
            "sleep_hours_avg_3d",
            "sleep_hours_avg_7d",
            "sleep_trend_7d",
            "screen_time_avg_3d",
            "screen_time_avg_7d",
            "screen_time_trend_7d",
            "workload_avg_7d",
            "high_priority_tasks_today",
        ],
        target="burnout_risk",
    ),
    ModelEvaluationConfig(
        name="Overspending",
        data_path=BASE_DIR / "data" / "overspend_data.csv",
        artifact_path=BASE_DIR / "artifacts" / "overspend_model.joblib",
        features=[
            "spending_today",
            "spending_avg_7d",
            "spending_trend_7d",
            "spending_ratio_7d",
            "spending_trend_up",
            "spending_high_signal",
        ],
        target="overspending_risk",
    ),
]


def evaluate_model(config: ModelEvaluationConfig) -> None:
    """Evaluate one saved classifier using its recreated held-out test set."""
    if not config.data_path.exists():
        raise FileNotFoundError(f"Dataset not found: {config.data_path}")
    if not config.artifact_path.exists():
        raise FileNotFoundError(
            f"Model artifact not found: {config.artifact_path}. "
            "Run the corresponding training script first."
        )

    df = pd.read_csv(config.data_path)
    train_df, test_df = train_test_split(
        df,
        test_size=0.2,
        random_state=42,
        stratify=df[config.target],
    )
    train_df = balance_classes(train_df, config.target)
    if config.name == "Overspending":
        train_df = add_overspend_features(train_df)
        test_df = add_overspend_features(test_df)

    X_test = test_df[config.features]
    y_test = test_df[config.target]

    model = joblib.load(config.artifact_path)
    predictions = model.predict(X_test)

    print(f"\n{config.name} model")
    print(f"Test samples: {len(y_test)}")
    print(f"Accuracy: {accuracy_score(y_test, predictions):.4f}")
    print(f"Balanced accuracy: {balanced_accuracy_score(y_test, predictions):.4f}")
    print("Classification report:")
    print(classification_report(y_test, predictions, zero_division=0))


def main() -> None:
    print("LifeLens model evaluation")
    for config in MODEL_CONFIGS:
        evaluate_model(config)


if __name__ == "__main__":
    main()