class AppUser {
  const AppUser({
    required this.userId,
    required this.name,
    required this.email,
    this.monthlyIncome,
    this.monthlyBudget,
  });

  final String userId;
  final String name;
  final String email;
  final double? monthlyIncome;
  final double? monthlyBudget;

  AppUser copyWith({
    String? name,
    String? email,
    double? monthlyIncome,
    double? monthlyBudget,
    bool clearMonthlyIncome = false,
    bool clearMonthlyBudget = false,
  }) {
    return AppUser(
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      monthlyIncome: clearMonthlyIncome
          ? null
          : monthlyIncome ?? this.monthlyIncome,
      monthlyBudget: clearMonthlyBudget
          ? null
          : monthlyBudget ?? this.monthlyBudget,
    );
  }
}
