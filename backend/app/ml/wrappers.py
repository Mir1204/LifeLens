# Path: app/ml/wrappers.py
"""
Shared model wrapper classes.

Defining wrappers here (rather than inside training scripts) ensures that
joblib can unpickle them at prediction time — the module path
'app.ml.wrappers.LabeledXGB' is stable and importable from anywhere.
"""
from sklearn.preprocessing import LabelEncoder


class LabeledXGB:
    """
    Thin sklearn-compatible wrapper around XGBClassifier so it returns
    string labels (e.g. Low/Medium/High) from predict() and predict_proba(),
    matching the interface expected by prediction.py.
    """

    def __init__(self, clf, le: LabelEncoder):
        self._clf = clf
        self._le = le
        self.classes_ = le.classes_

    def predict(self, X):
        return self._le.inverse_transform(self._clf.predict(X))

    def predict_proba(self, X):
        return self._clf.predict_proba(X)
