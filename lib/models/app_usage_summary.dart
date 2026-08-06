class AppUsageSummary {
  AppUsageSummary({
    required this.totalHours,
    required this.apps,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final double totalHours;
  final List<UsedApp> apps;
  final DateTime updatedAt;
}

class UsedApp {
  UsedApp({
    this.id,
    required this.name,
    required this.packageName,
    required this.hours,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  final int? id;
  final String name;
  final String packageName;
  final double hours;
  final DateTime date;
}
