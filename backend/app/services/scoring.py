# Path: app/services/scoring.py
"""
Rule-based scoring, ported directly from Flutter's lifelens_store.dart
calculateScores(). Kept rule-based intentionally (see project report,
Prediction & Algorithm Justification) since these are direct explainable
transformations, not patterns that need learning.
"""


def clamp(value, low=0, high=100):
    return max(low, min(high, value))


def calculate_productivity(sleep_hours: float, steps: int, screen_time_hours: float, total_workload: int) -> int:
    sleep_score = clamp(sleep_hours / 8 * 100)
    activity_score = clamp(steps / 8000 * 100)
    focus_score = clamp(100 - (screen_time_hours - 4) * 10)
    workload_penalty = clamp(total_workload * 4, 0, 40)

    productivity = (
        sleep_score * 0.30
        + activity_score * 0.25
        + focus_score * 0.30
        + (100 - workload_penalty) * 0.15
    )
    return round(clamp(productivity))


def calculate_financial_health(daily_spending: float) -> int:
    spending_penalty = clamp(daily_spending / 20, 0, 45)
    return round(clamp(100 - spending_penalty))


def risk_label(value: int) -> str:
    if value >= 70:
        return "High"
    if value >= 40:
        return "Medium"
    return "Low"


def build_recommendations(sleep_hours, screen_time_hours, financial_health, stress_risk, productivity) -> list[str]:
    items = []
    if sleep_hours < 7:
        items.append("Sleep is below target. Try a fixed sleep time tonight.")
    if screen_time_hours > 6:
        items.append("Screen time is high. Reduce late-night phone usage.")
    if financial_health < 70:
        items.append("Spending is rising today. Avoid non-essential expenses.")
    if stress_risk > 65:
        items.append("Stress risk is high. Move one low-priority task to tomorrow.")
    if productivity >= 75 and stress_risk < 55:
        items.append("Your routine is balanced today. Keep the same rhythm.")
    return items