import os
import sys
import unittest

import pandas as pd

os.environ.setdefault("DATABASE_URL", "sqlite:///./validation.db")
os.environ.setdefault("JWT_SECRET_KEY", "validation-secret-key-at-least-32-characters")
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from app.services.prediction import (  # noqa: E402
    BURNOUT_FEATURES,
    OVERSPEND_FEATURES,
    STATIC_STRESS_FEATURES,
    get_burnout_model,
    get_overspend_model,
    get_static_stress_model,
    predict_burnout_risk,
    predict_overspending_risk,
)
from app.services.scoring import (  # noqa: E402
    calculate_financial_health,
    calculate_productivity,
)


FEATURES = {
    "sleep_hours_today": 7.0,
    "sleep_hours_avg_3d": 7.0,
    "sleep_hours_avg_7d": 7.0,
    "sleep_trend_7d": 0.0,
    "screen_time_today": 4.0,
    "screen_time_avg_3d": 4.0,
    "screen_time_avg_7d": 4.0,
    "screen_time_trend_7d": 0.0,
    "workload_today": 2,
    "workload_avg_7d": 2.0,
    "high_priority_tasks_today": 1,
    "spending_today": 300.0,
    "spending_avg_7d": 300.0,
    "spending_trend_7d": 0.0,
    "steps_today": 8000,
}


class MlPipelineTests(unittest.TestCase):
    def test_all_artifacts_load_and_match_feature_contracts(self):
        for model, expected_features in (
            (get_burnout_model(), BURNOUT_FEATURES),
            (get_overspend_model(), OVERSPEND_FEATURES),
            (get_static_stress_model(), STATIC_STRESS_FEATURES),
        ):
            self.assertIsNotNone(model)
            if hasattr(model, "feature_names_in_"):
                self.assertEqual(list(model.feature_names_in_), expected_features)

    def test_all_models_return_valid_predictions(self):
        stress_score, burnout_label = predict_burnout_risk(FEATURES)
        overspending_label = predict_overspending_risk(FEATURES)
        self.assertGreaterEqual(stress_score, 0)
        self.assertLessEqual(stress_score, 100)
        self.assertIn(burnout_label, {"Low", "Medium", "High"})
        self.assertIn(overspending_label, {"Low", "Medium", "High"})

    def test_formula_scores_stay_bounded(self):
        for sleep in (0, 8, 24):
            self.assertIn(calculate_productivity(sleep, 0, 24, 100), range(101))
        for spending in (0, 100, 10_000_000):
            self.assertIn(calculate_financial_health(spending, 1000), range(101))

    def test_prediction_rows_use_named_columns(self):
        self.assertEqual(list(pd.DataFrame([FEATURES])[BURNOUT_FEATURES].columns), BURNOUT_FEATURES)
        self.assertEqual(list(pd.DataFrame([FEATURES])[OVERSPEND_FEATURES].columns), OVERSPEND_FEATURES)


if __name__ == "__main__":
    unittest.main()
