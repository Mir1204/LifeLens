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