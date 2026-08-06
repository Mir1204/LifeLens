# AI Architecture

## AI Goal

LifeLens uses AI/ML to identify lifestyle risks before they become serious.

The current AI layer focuses on:

- Burnout risk prediction
- Overspending risk prediction
- Recommendation generation

The score cards are intentionally rule-based for explainability.

## Current Components

### Rule-Based Scoring

File:

```text
backend/app/services/scoring.py
```

Rule-based scoring calculates:

- Productivity Score
- Financial Health Score
- Recommendation triggers

This is explainable and easy to demonstrate.

### Feature Engineering

File:

```text
backend/app/services/feature_engineering.py
```

Features include:

- `sleep_hours_avg_3d`
- `sleep_hours_avg_7d`
- `sleep_trend_7d`
- `screen_time_avg_3d`
- `screen_time_avg_7d`
- `screen_time_trend_7d`
- `workload_avg_7d`
- `high_priority_tasks_today`
- `spending_today`
- `spending_avg_7d`
- `spending_trend_7d`

### Prediction Service

File:

```text
backend/app/services/prediction.py
```

The prediction service tries to load trained model artifacts:

- `app/ml/artifacts/burnout_model.joblib`
- `app/ml/artifacts/overspend_model.joblib`

If artifacts are missing, it uses fallback formulas so the API keeps working.

## Burnout Prediction

Burnout risk uses:

- Sleep average and trend
- Screen-time average and trend
- Workload average
- High-priority task count

Output:

```text
Low / Medium / High
```

Also produces a 0-100 stress risk score.

## Overspending Prediction

Overspending risk uses:

- Today's spending
- 7-day average spending
- 7-day spending trend

Output:

```text
Low / Medium / High
```

## Synthetic Data

File:

```text
backend/app/ml/training/generate_synthetic_data.py
```

Synthetic data is used because the project does not have long-term real user data during one semester.

Generated datasets:

- `app/ml/data/burnout_data.csv`
- `app/ml/data/overspend_data.csv`

## Training Scripts

Implemented:

```text
backend/app/ml/training/train_overspend_model.py
```

Empty / pending:

```text
backend/app/ml/training/train_burnout_model.py
```

## Model Choice

Current overspending model:

- Logistic Regression
- Multiclass labels: `Low`, `Medium`, `High`

Planned burnout model:

- Logistic Regression, Random Forest, or XGBoost
- Use the existing synthetic burnout dataset
- Save artifact as `app/ml/artifacts/burnout_model.joblib`

## AI Limitations

- Synthetic data does not fully represent real user behavior.
- Predictions are risk estimates, not medical or financial advice.
- No clinical burnout diagnosis is provided.
- Model performance depends on quality and quantity of historical data.
