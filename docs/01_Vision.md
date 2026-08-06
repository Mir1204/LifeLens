# LifeLens Vision

## Project Title

LifeLens - AI-Powered Personal Life Management Assistant

## Purpose

LifeLens is an Android-first mobile application that helps users understand their daily lifestyle patterns by combining sleep, physical activity, screen time, expenses, and calendar workload into one dashboard.

Most users currently track these areas using separate apps. LifeLens connects them into a single view and turns raw lifestyle data into:

- Productivity Score
- Financial Health Score
- Stress Risk Score
- Burnout risk prediction
- Overspending risk prediction
- Personalized recommendations

## Problem Statement

Users often notice unhealthy lifestyle patterns too late. Poor sleep, high screen time, overspending, and overloaded schedules may appear unrelated when viewed in separate apps, but together they can indicate future stress, burnout, or financial strain.

LifeLens aims to provide early warnings and simple daily recommendations before these patterns become serious.

## Target Users

- Students managing study workload, spending, sleep, and screen time
- Young professionals balancing tasks and personal habits
- Users who want a simple daily lifestyle summary instead of multiple disconnected tracking apps

## Semester Scope

### In Scope

- Flutter Android application
- Manual entry for expenses, tasks, sleep, steps, and screen time
- Dashboard with scores and recommendations
- FastAPI backend endpoint for daily score prediction
- PostgreSQL-backed daily history table
- Rule-based scoring
- ML-ready prediction layer with fallback logic
- Synthetic dataset generation for overspending and burnout model training

### Out of Scope

- iOS application
- Direct bank or UPI integration
- Large-scale real user training data
- Production-grade authentication
- Long-term analytics at scale
- Fully implemented federated learning

## Team Roles

### Mir Patel

- Flutter Android app
- Dashboard and profile UI
- Expense and planner entry screens
- Manual health and screen-time input screen
- API payload preparation and future backend integration

### Mark Patel

- FastAPI backend
- Database schema
- Feature engineering
- Scoring and prediction logic
- ML training scripts and model artifacts

## Success Criteria

- User can enter daily lifestyle data from the mobile app.
- App can show three daily scores clearly.
- Backend can accept a daily payload and return risks/recommendations.
- Historical daily records can be stored for rolling feature calculation.
- Project can be demonstrated as a working app + backend prototype.
