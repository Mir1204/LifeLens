# API Specification

## Base URL

Development:

```text
http://localhost:8000
```

Android emulator:

```text
http://10.0.2.2:8000
```

Physical Android device:

```text
http://<computer-lan-ip>:8000
```

## Health Check

### GET `/health`

Returns backend status.

#### Response

```json
{
  "status": "ok"
}
```

## Root

### GET `/`

Returns a simple backend status message.

#### Response

```json
{
  "message": "LifeLens API is running",
  "docs": "/docs"
}
```

## Daily Score Prediction

### POST `/predict/daily-score`

Accepts one user's daily lifestyle data, stores/updates the daily record, builds rolling features, and returns scores, risk labels, and recommendations.

### Request Body

```json
{
  "user_id": "mir_demo_user",
  "sleep_hours": 6.5,
  "steps": 4300,
  "screen_time_hours": 6.8,
  "daily_spending": 300,
  "calendar_events": 2,
  "high_priority_tasks": 1,
  "total_workload": 6,
  "entry_date": "2026-08-06"
}
```

### Fields

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `user_id` | string | No | Defaults to `mir_demo_user` |
| `sleep_hours` | float | Yes | Sleep duration for the day |
| `steps` | int | Yes | Step count/activity proxy |
| `screen_time_hours` | float | Yes | Total screen-time hours |
| `daily_spending` | float | Yes | Total spending for the day |
| `calendar_events` | int | Yes | Number of events/tasks |
| `high_priority_tasks` | int | Yes | Count of high-priority tasks |
| `total_workload` | int | No | Sum of task workload values |
| `entry_date` | date/null | No | Defaults to server date |

### Response Body

```json
{
  "productivity": 72,
  "financial_health": 85,
  "stress_risk": 48,
  "burnout_risk": "Medium",
  "overspending_risk": "Low",
  "recommendations": [
    "Sleep is below target. Try a fixed sleep time tonight.",
    "Screen time is high. Reduce late-night phone usage."
  ]
}
```

### Response Fields

| Field | Type | Description |
| --- | --- | --- |
| `productivity` | int | 0-100 productivity score |
| `financial_health` | int | 0-100 financial health score |
| `stress_risk` | int | 0-100 stress/burnout risk score |
| `burnout_risk` | string | `Low`, `Medium`, or `High` |
| `overspending_risk` | string | `Low`, `Medium`, or `High` |
| `recommendations` | list[string] | Daily lifestyle suggestions |

## Flutter Integration Notes

Current Flutter payload file:

```text
lib/services/prediction_api_service.dart
```

Implemented in Flutter:

- Add `user_id`
- Add `total_workload`
- Implement HTTP POST call
- Parse backend response into `LifestyleScores`

The backend URL is configurable from the app Profile screen and persisted locally.

## API Documentation UI

FastAPI automatically exposes:

```text
http://localhost:8000/docs
```

Use this for testing request/response behavior during demos.
