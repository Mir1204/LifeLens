# Database Design

## Current Database Layers

LifeLens now uses two database layers:

1. Flutter SQLite for local source-of-truth app data
2. Backend PostgreSQL/Supabase for daily summaries used by prediction/sync

This keeps the app reliable offline while keeping the backend API simple for ML/scoring.

## Flutter SQLite Design

SQLite service:

```text
lib/services/local_database_service.dart
```

Local database:

```text
lifelens.db
```

### `local_users`

Stores local demo login identity.

| Column | Type | Description |
| --- | --- | --- |
| `user_id` | Text | Stable generated user ID |
| `name` | Text | User name |
| `email` | Text | Login email |
| `password_hash` | Text | Local demo password hash |
| `signed_in` | Integer | Active session flag |
| `created_at` | Text | Created timestamp |

### `expenses`

Stores individual expense records.

| Column | Type | Description |
| --- | --- | --- |
| `id` | Integer | Primary key |
| `user_id` | Text | User owner |
| `amount` | Real | Expense amount |
| `category` | Text | Expense category |
| `note` | Text | User note |
| `expense_date` | Text | Expense date |
| `created_at` | Text | Created timestamp |
| `updated_at` | Text | Last update timestamp |
| `deleted_at` | Text | Soft delete timestamp |

### `planner_tasks`

Stores individual tasks/events.

| Column | Type | Description |
| --- | --- | --- |
| `id` | Integer | Primary key |
| `user_id` | Text | User owner |
| `title` | Text | Task/event title |
| `priority` | Text | Low/Medium/High |
| `workload` | Integer | Workload from 1-5 |
| `task_date` | Text | Task date |
| `is_completed` | Integer | Completion flag |
| `created_at` | Text | Created timestamp |
| `updated_at` | Text | Last update timestamp |
| `deleted_at` | Text | Soft delete timestamp |

### `health_records`

Stores manual or Health Connect daily values.

| Column | Type | Description |
| --- | --- | --- |
| `id` | Integer | Primary key |
| `user_id` | Text | User owner |
| `record_date` | Text | Record date |
| `sleep_hours` | Real | Sleep duration |
| `steps` | Integer | Steps |
| `screen_time_hours` | Real | Total screen time |
| `source` | Text | `manual`, `health_connect`, or `usage_stats` |
| `created_at` | Text | Created timestamp |

### `screen_time_apps`

Stores most-used app details.

| Column | Type | Description |
| --- | --- | --- |
| `id` | Integer | Primary key |
| `user_id` | Text | User owner |
| `usage_date` | Text | Usage date |
| `app_name` | Text | Display app name |
| `package_name` | Text | Android package |
| `usage_hours` | Real | Usage duration |
| `created_at` | Text | Created timestamp |

### `score_snapshots`

Stores score history for trend charts.

| Column | Type | Description |
| --- | --- | --- |
| `id` | Integer | Primary key |
| `user_id` | Text | User owner |
| `score_date` | Text | Score date |
| `productivity` | Integer | Productivity score |
| `financial_health` | Integer | Financial health score |
| `stress_risk` | Integer | Stress risk score |
| `burnout_risk` | Text | Risk label |
| `overspending_risk` | Text | Risk label |
| `spending` | Real | Daily spending at score time |
| `sleep_hours` | Real | Sleep at score time |
| `screen_time_hours` | Real | Screen time at score time |
| `created_at` | Text | Created timestamp |

### `app_settings`

Stores app configuration such as backend URL.

| Column | Type | Description |
| --- | --- | --- |
| `key` | Text | Setting key |
| `value` | Text | Setting value |

### `sync_outbox`

Reserved for offline-first syncing.

| Column | Type | Description |
| --- | --- | --- |
| `id` | Integer | Primary key |
| `user_id` | Text | User owner |
| `entity_type` | Text | Entity being synced |
| `entity_id` | Integer | Local row ID |
| `operation` | Text | Create/update/delete/sync |
| `payload_json` | Text | Serialized payload |
| `status` | Text | `pending`, `synced`, or `failed` |
| `attempts` | Integer | Retry count |
| `last_error` | Text | Last sync error |
| `created_at` | Text | Created timestamp |
| `synced_at` | Text | Sync completion timestamp |

## Database Engineering Notes

- SQLite foreign keys are enabled using `PRAGMA foreign_keys = ON`.
- Raw tables are normalized so charts and summaries can be recomputed.
- `score_snapshots` stores derived values for trend display.
- `screen_time_apps` stores app-level usage detail separately from health totals.
- `sync_outbox` gives the app a future-safe offline sync path.
- The backend keeps a compact daily summary table to avoid disturbing ML/API work.

## Backend Database Layer

Backend database files:

- `backend/app/database.py`
- `backend/app/models/daily_entry.py`
- `backend/app/core/config.py`

The backend uses SQLAlchemy and expects a PostgreSQL database URL by default.

Default database URL:

```text
postgresql://lifelens_user:lifelens_pass@localhost:5432/lifelens_db
```

## Backend Main Table

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

## Future Backend Expansion

If the backend becomes the full source of truth later, it should evolve toward:

- `users`
- `expenses`
- `calendar_tasks`
- `health_records`
- `screen_time_records`
- `recommendations`
- `model_prediction_logs`

For the semester MVP, the Flutter SQLite schema stores raw local detail, and backend `daily_entries` stores sync-ready daily summaries.
