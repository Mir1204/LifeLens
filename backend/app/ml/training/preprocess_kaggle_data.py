# Path: app/ml/training/preprocess_kaggle_data.py
"""
Preprocesses the Kaggle Sleep Health & Lifestyle dataset into a static
per-person feature set suitable for training a snapshot stress classifier.

Input : app/ml/data/raw/sleep_health_lifestyle.csv
Output: app/ml/data/static_stress_data.csv

Feature mapping (aligns with what the Flutter app sends to the backend):
  sleep_hours_today       <- Sleep Duration
  sleep_quality_today     <- Quality of Sleep  (1-10)
  steps_today             <- Daily Steps
  physical_activity_today <- Physical Activity Level  (min/day)
  workload_proxy_today    <- Occupation mapped to 1-5 scale
  sleep_decline_proxy     <- derived from Sleep Disorder + quality + duration

Target:
  stress_risk  (Low / Medium / High)  <- Stress Level  1-4 → Low, 5-6 → Medium, 7-10 → High

Run: python -m app.ml.training.preprocess_kaggle_data
"""

import os
from pathlib import Path

import pandas as pd

DATA_DIR = Path(__file__).resolve().parents[1] / "data"
RAW_PATH = Path(__file__).resolve().parents[2] / "model_data" / "Sleep_health_and_lifestyle_dataset.csv"
OUT_PATH = DATA_DIR / "static_stress_data.csv"

# ── occupation → proxy workload (1 = very light, 5 = very demanding) ──────────
OCCUPATION_WORKLOAD = {
    "Software Engineer":    4,
    "Doctor":               5,
    "Sales Representative": 4,
    "Teacher":              3,
    "Nurse":                5,
    "Engineer":             4,
    "Accountant":           3,
    "Scientist":            4,
    "Lawyer":               5,
    "Salesperson":          3,
    "Manager":              4,
    "Entrepreneur":         5,
}
DEFAULT_WORKLOAD = 3  # for any unseen occupation


def map_stress_label(stress_level: int) -> str:
    """Map Kaggle 1-10 Stress Level to Low/Medium/High."""
    if stress_level <= 4:
        return "Low"
    elif stress_level <= 6:
        return "Medium"
    else:
        return "High"


def compute_sleep_decline_proxy(row: pd.Series) -> int:
    """
    Heuristic 0-3 score that captures sleep-health deterioration signals
    (mirrors what the backend will derive at prediction time when no
    explicit sleep_decline_proxy is in the payload).

    +1  Sleep Disorder present (Sleep Apnea or Insomnia)
    +1  Quality of Sleep ≤ 5  (poor quality)
    +1  Sleep Duration < 6 hours
    """
    score = 0
    if str(row["Sleep Disorder"]).strip().lower() not in {"none", "nan", ""}:
        score += 1
    if row["Quality of Sleep"] <= 5:
        score += 1
    if row["Sleep Duration"] < 6.0:
        score += 1
    return score


def main() -> None:
    df = pd.read_csv(RAW_PATH)
    print(f"Loaded {len(df)} rows from {RAW_PATH}")

    # ── map occupation to workload proxy ──────────────────────────────────────
    df["workload_proxy_today"] = (
        df["Occupation"].map(OCCUPATION_WORKLOAD).fillna(DEFAULT_WORKLOAD).astype(int)
    )

    # ── compute sleep decline proxy ───────────────────────────────────────────
    df["sleep_decline_proxy"] = df.apply(compute_sleep_decline_proxy, axis=1)

    # ── map stress level to label ─────────────────────────────────────────────
    df["stress_risk"] = df["Stress Level"].apply(map_stress_label)

    # ── select and rename final features ─────────────────────────────────────
    out = pd.DataFrame({
        "sleep_hours_today":       df["Sleep Duration"],
        "sleep_quality_today":     df["Quality of Sleep"],
        "steps_today":             df["Daily Steps"],
        "physical_activity_today": df["Physical Activity Level"],
        "workload_proxy_today":    df["workload_proxy_today"],
        "sleep_decline_proxy":     df["sleep_decline_proxy"],
        "stress_risk":             df["stress_risk"],
    })

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    out.to_csv(OUT_PATH, index=False)

    print(f"Saved {len(out)} rows -> {OUT_PATH}")
    print("Label distribution:")
    print(out["stress_risk"].value_counts().to_string())


if __name__ == "__main__":
    main()
