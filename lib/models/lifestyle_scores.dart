class LifestyleScores {
  const LifestyleScores({
    required this.productivity,
    required this.financialHealth,
    required this.stressRisk,
    required this.burnoutRisk,
    required this.overspendingRisk,
    required this.recommendations,
  });

  final int productivity;
  final int financialHealth;
  final int stressRisk;
  final String burnoutRisk;
  final String overspendingRisk;
  final List<String> recommendations;
}
