class LifestyleScores {
  LifestyleScores({
    required this.productivity,
    required this.financialHealth,
    required this.stressRisk,
    required this.burnoutRisk,
    required this.overspendingRisk,
    required this.recommendations,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  final int productivity;
  final int financialHealth;
  final int stressRisk;
  final String burnoutRisk;
  final String overspendingRisk;
  final List<String> recommendations;
  final DateTime date;

  factory LifestyleScores.fromJson(Map<String, dynamic> json) {
    return LifestyleScores(
      productivity: json['productivity'] as int,
      financialHealth: json['financial_health'] as int,
      stressRisk: json['stress_risk'] as int,
      burnoutRisk: json['burnout_risk'] as String,
      overspendingRisk: json['overspending_risk'] as String,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((item) => item.toString())
          .toList(),
      date: DateTime.now(),
    );
  }
}

class ScoreSnapshot {
  const ScoreSnapshot({
    required this.date,
    required this.productivity,
    required this.financialHealth,
    required this.stressRisk,
    required this.spending,
    required this.sleepHours,
    required this.screenTimeHours,
  });

  final DateTime date;
  final int productivity;
  final int financialHealth;
  final int stressRisk;
  final double spending;
  final double sleepHours;
  final double screenTimeHours;
}
