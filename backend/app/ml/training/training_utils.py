from __future__ import annotations

import pandas as pd


def balance_classes(df: pd.DataFrame, target_column: str, random_state: int = 42) -> pd.DataFrame:
    """Oversample each class to the size of the majority class."""
    class_counts = df[target_column].value_counts()
    if class_counts.empty:
        return df.copy()

    target_size = int(class_counts.max())
    balanced_parts = []

    for label in class_counts.index:
        class_rows = df[df[target_column] == label]
        if len(class_rows) == target_size:
            balanced_parts.append(class_rows)
        else:
            balanced_parts.append(
                class_rows.sample(
                    n=target_size,
                    replace=True,
                    random_state=random_state,
                )
            )

    balanced = pd.concat(balanced_parts, ignore_index=True)
    return balanced.sample(frac=1.0, random_state=random_state).reset_index(drop=True)


def add_overspend_features(df: pd.DataFrame) -> pd.DataFrame:
    """Add the ratio and threshold flag used by overspending classification."""
    enriched = df.copy()
    enriched["spending_ratio_7d"] = (
        enriched["spending_today"] / enriched["spending_avg_7d"].clip(lower=1)
    )
    enriched["spending_trend_up"] = (enriched["spending_trend_7d"] > 40).astype(int)
    enriched["spending_high_signal"] = (
        (enriched["spending_ratio_7d"] > 1.6)
        | ((enriched["spending_ratio_7d"] > 1.3) & (enriched["spending_trend_up"] == 1))
    ).astype(int)
    return enriched