# Path: app/ml/training/generate_synthetic_data.py
"""
Generates two labeled CSVs used to train the burnout and overspending
classifiers, since real longitudinal user data isn't available within
one semester (documented as a scope decision in the project report).

Run: python -m app.ml.training.generate_synthetic_data
Output: app/ml/data/burnout_data.csv, app/ml/data/overspend_data.csv
"""
import os
import numpy as np
import pandas as pd

np.random.seed(42)

NUM_USERS = 150
DAYS_PER_USER = 21
OUT_DIR = "app/ml/data"


def simulate_user_days(user_id: int) -> pd.DataFrame:
    burnout_prone = np.random.rand() < 0.35
    overspend_prone = np.random.rand() < 0.35

    base_sleep = np.random.normal(7.2, 0.6)
    base_screen = np.random.normal(4.0, 1.0)
    base_workload = np.random.poisson(2)
    base_spending = np.random.normal(300, 80)

    rows = []
    for day in range(DAYS_PER_USER):
        drift = day / DAYS_PER_USER
        sleep = base_sleep - (2.5 * drift if burnout_prone else 0.3 * drift) + np.random.normal(0, 0.4)
        screen = base_screen + (2.5 * drift if burnout_prone else 0.2 * drift) + np.random.normal(0, 0.5)
        workload = max(0, base_workload + (3 * drift if burnout_prone else 0) + np.random.normal(0, 0.7))
        high_priority = np.random.poisson(1 if burnout_prone else 0.4)
        steps = max(0, np.random.normal(6000 - (1500 * drift if burnout_prone else 0), 1200))
        spend_multiplier = 1 + (0.9 * drift if overspend_prone else 0.05 * drift)
        spending = max(0, base_spending * spend_multiplier + np.random.normal(0, 40))

        rows.append({
            "user_id": user_id, "day": day,
            "sleep_hours": round(max(2, sleep), 2),
            "screen_time_hours": round(max(0, screen), 2),
            "total_workload": round(workload),
            "high_priority_tasks": high_priority,
            "steps": int(steps),
            "daily_spending": round(spending, 2),
        })
    return pd.DataFrame(rows)


def rolling_feature_row(df: pd.DataFrame, t: int) -> dict:
    window7 = df.iloc[max(0, t - 6): t + 1]
    window3 = df.iloc[max(0, t - 2): t + 1]
    first_half = window7.iloc[: len(window7) // 2] if len(window7) > 1 else window7
    second_half = window7.iloc[len(window7) // 2:] if len(window7) > 1 else window7
    today = df.iloc[t]

    return {
        "sleep_hours_avg_3d": window3["sleep_hours"].mean(),
        "sleep_hours_avg_7d": window7["sleep_hours"].mean(),
        "sleep_trend_7d": second_half["sleep_hours"].mean() - first_half["sleep_hours"].mean(),
        "screen_time_avg_3d": window3["screen_time_hours"].mean(),
        "screen_time_avg_7d": window7["screen_time_hours"].mean(),
        "screen_time_trend_7d": second_half["screen_time_hours"].mean() - first_half["screen_time_hours"].mean(),
        "workload_avg_7d": window7["total_workload"].mean(),
        "high_priority_tasks_today": today["high_priority_tasks"],
        "spending_today": today["daily_spending"],
        "spending_avg_7d": window7["daily_spending"].mean(),
        "spending_trend_7d": second_half["daily_spending"].mean() - first_half["daily_spending"].mean(),
    }


def label_burnout(row: dict) -> str:
    score = 0
    if row["sleep_hours_avg_7d"] < 6.2:
        score += 1
    if row["sleep_trend_7d"] < -0.6:
        score += 1
    if row["screen_time_avg_7d"] > 6.0:
        score += 1
    if row["workload_avg_7d"] > 3.5:
        score += 1
    if row["high_priority_tasks_today"] >= 2:
        score += 1

    label = "High" if score >= 4 else "Medium" if score >= 2 else "Low"
    if np.random.rand() < 0.05:
        label = np.random.choice(["Low", "Medium", "High"])
    return label


def label_overspend(row: dict) -> str:
    ratio = row["spending_today"] / max(row["spending_avg_7d"], 1)
    trend_up = row["spending_trend_7d"] > 40

    if ratio > 1.6 or (ratio > 1.3 and trend_up):
        label = "High"
    elif ratio > 1.15 or trend_up:
        label = "Medium"
    else:
        label = "Low"

    if np.random.rand() < 0.05:
        label = np.random.choice(["Low", "Medium", "High"])
    return label


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    burnout_rows, overspend_rows = [], []

    for user_id in range(NUM_USERS):
        df = simulate_user_days(user_id)
        for t in range(6, DAYS_PER_USER):  # need at least 7 days of history
            features = rolling_feature_row(df, t)
            burnout_rows.append({**features, "burnout_risk": label_burnout(features)})
            overspend_rows.append({**features, "overspending_risk": label_overspend(features)})

    burnout_cols = [
        "sleep_hours_avg_3d", "sleep_hours_avg_7d", "sleep_trend_7d",
        "screen_time_avg_3d", "screen_time_avg_7d", "screen_time_trend_7d",
        "workload_avg_7d", "high_priority_tasks_today", "burnout_risk",
    ]
    overspend_cols = ["spending_today", "spending_avg_7d", "spending_trend_7d", "overspending_risk"]

    pd.DataFrame(burnout_rows)[burnout_cols].to_csv(f"{OUT_DIR}/burnout_data.csv", index=False)
    pd.DataFrame(overspend_rows)[overspend_cols].to_csv(f"{OUT_DIR}/overspend_data.csv", index=False)

    print(f"Saved {len(burnout_rows)} rows to burnout_data.csv")
    print(f"Saved {len(overspend_rows)} rows to overspend_data.csv")


if __name__ == "__main__":
    main()