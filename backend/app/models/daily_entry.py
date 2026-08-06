# Path: app/models/daily_entry.py
from datetime import datetime, date

from sqlalchemy import Column, Integer, String, Float, Date, DateTime, UniqueConstraint

from app.database import Base


class DailyEntry(Base):
    """
    One row per user per day. Acts as the historical record that
    feature_engineering.py reads to build rolling 3-day/7-day windows.
    Without this table, the backend has no memory across days and
    cannot support real prediction (only same-day snapshot scoring).
    """

    __tablename__ = "daily_entries"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, nullable=False, index=True)
    entry_date = Column(Date, nullable=False, default=date.today, index=True)

    sleep_hours = Column(Float, nullable=False)
    steps = Column(Integer, nullable=False)
    screen_time_hours = Column(Float, nullable=False)
    daily_spending = Column(Float, nullable=False)
    calendar_events = Column(Integer, nullable=False)
    high_priority_tasks = Column(Integer, nullable=False)
    total_workload = Column(Integer, nullable=False, default=0)

    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("user_id", "entry_date", name="uq_user_date"),
    )