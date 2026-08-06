# Database Design

## Current Database Layer

Backend database files:

- `backend/app/database.py`
- `backend/app/models/daily_entry.py`
- `backend/app/core/config.py`

The backend uses SQLAlchemy and expects a PostgreSQL database URL by default.

Default database URL:

```text
postgresql://lifelens_user:lifelens_pass@localhost:5432/lifelens_db
```

## Main Table

### `daily_entries`

Stores one lifestyle snapshot per user per day.

| Column | Type | Description |
| --- | --- | --- |
| `id` | Integer | Primary key |
| `user_id` | String | User identifier |
| `entry_date` | Date | Date of the lifestyle entry |
| `sleep_hours` | Float | Sleep duration |
| `steps` | Integer | Daily steps/activity |
| `screen_time_hours` | Float | Total screen time |
| `daily_spending` | Float | Total spending |
| `calendar_events` | Integer | Number of tasks/events |
| `high_priority_tasks` | Integer | Number of high-priority tasks |
| `total_workload` | Integer | Sum of task workload |
| `created_at` | DateTime | Record creation timestamp |

## Constraints

The table has a unique constraint:

```text
user_id + entry_date
```

This means each user can have only one record per day. If the same user submits data again for the same date, the backend updates the existing record.

## Why Historical Storage Is Needed

Daily score calculation can work from same-day values, but prediction needs trends.

The backend uses stored records to calculate:

- 3-day average sleep
- 7-day average sleep
- Sleep trend
- 3-day and 7-day screen-time averages
- Screen-time trend
- 7-day workload average
- Spending average and spending trend

Without this table, the backend could only score today and could not support meaningful risk prediction.

## Development Database Options

### Option 1: PostgreSQL

Best for backend + deployment readiness.

Use when Mark is testing FastAPI fully.

### Option 2: SQLite

Useful for quick local demos if PostgreSQL setup is slow.

Requires changing the database URL to:

```text
sqlite:///./lifelens.db
```

Some PostgreSQL-specific deployment assumptions should be reviewed if SQLite is used.

## Future Tables

Possible future schema expansion:

- `users`
- `expenses`
- `calendar_tasks`
- `health_records`
- `screen_time_records`
- `recommendations`
- `model_prediction_logs`

For the semester MVP, `daily_entries` is enough because the app aggregates raw data before sending it to the backend.
