# Path: app/services/feature_engineering.py
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.models.daily_entry import DailyEntry


def get_recent_entries(db: Session, user_id: str, days: int, before: date):
    start = before - timedelta(days=days - 1)
    return (
        db.query(DailyEntry)
        .filter(
            DailyEntry.user_id == user_id,
            DailyEntry.entry_date >= start,
            DailyEntry.entry_date <= before,
        )
        .order_by(DailyEntry.entry_date.asc())
        .all()
    )


def build_rolling_features(db: Session, user_id: str, today_entry: dict, entry_date: date) -> dict:
    """
    Builds rolling window features by combining today's live payload with
    stored history. If history is thin (e.g. first week of use), rolling
    averages gracefully fall back to today's values so predictions still work.
    """

    last_7 = get_recent_entries(db, user_id, days=7, before=entry_date)
    last_3 = get_recent_entries(db, user_id, days=3, before=entry_date)

    def avg(entries, field, fallback):
        values = [getattr(e, field) for e in entries] + [fallback]
        return sum(values) / len(values)

    def trend_delta(entries, field, fallback):
        # positive = rising trend, negative = declining trend
        if len(entries) < 2:
            return 0.0
        first_half = entries[: len(entries) // 2]
        second_half = entries[len(entries) // 2 :]
        first_avg = sum(getattr(e, field) for e in first_half) / len(first_half)
        second_avg = sum(getattr(e, field) for e in second_half) / len(second_half)
        return second_avg - first_avg

    features = {
        "sleep_hours_today": today_entry["sleep_hours"],
        "sleep_hours_avg_3d": avg(last_3, "sleep_hours", today_entry["sleep_hours"]),
        "sleep_hours_avg_7d": avg(last_7, "sleep_hours", today_entry["sleep_hours"]),
        "sleep_trend_7d": trend_delta(last_7, "sleep_hours", today_entry["sleep_hours"]),

        "screen_time_today": today_entry["screen_time_hours"],
        "screen_time_avg_3d": avg(last_3, "screen_time_hours", today_entry["screen_time_hours"]),
        "screen_time_avg_7d": avg(last_7, "screen_time_hours", today_entry["screen_time_hours"]),
        "screen_time_trend_7d": trend_delta(last_7, "screen_time_hours", today_entry["screen_time_hours"]),

        "workload_today": today_entry["total_workload"],
        "workload_avg_7d": avg(last_7, "total_workload", today_entry["total_workload"]),
        "high_priority_tasks_today": today_entry["high_priority_tasks"],

        "spending_today": today_entry["daily_spending"],
        "spending_avg_7d": avg(last_7, "daily_spending", today_entry["daily_spending"]),
        "spending_trend_7d": trend_delta(last_7, "daily_spending", today_entry["daily_spending"]),

        "steps_today": today_entry["steps"],
        "steps_avg_7d": avg(last_7, "steps", today_entry["steps"]),

        "history_days_available": len(last_7),
    }
    return features