import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/lifestyle_scores.dart';
import '../../services/lifelens_store.dart';
import '../../widgets/score_card.dart';
import '../../widgets/trend_chart_card.dart';
import '../expenses/expenses_screen.dart';
import '../insights/insights_screen.dart';
import '../planner/planner_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final LifeLensStore store = LifeLensStore(user: widget.user);
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeDashboard(store: store),
      ExpensesScreen(store: store),
      PlannerScreen(store: store),
      InsightsScreen(store: store),
      ProfileScreen(store: store, onSignOut: widget.onSignOut),
    ];

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('LifeLens'),
            actions: [
              IconButton(
                tooltip: 'Refresh scores',
                onPressed: store.isSyncing ? null : store.syncWithBackend,
                icon: store.isSyncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
            ],
          ),
          body: SafeArea(child: pages[currentIndex]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              setState(() => currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Expenses',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'Planner',
              ),
              NavigationDestination(
                icon: Icon(Icons.psychology_outlined),
                selectedIcon: Icon(Icons.psychology),
                label: 'Insights',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({required this.store});

  final LifeLensStore store;

  @override
  Widget build(BuildContext context) {
    final scores = store.calculateScores();
    final recommendations = _recommendations(scores);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (store.isLoading) const LinearProgressIndicator(),
        Text(
          'Dashboard',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Your routine score and next best action.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 680;
            return GridView.count(
              crossAxisCount: isWide ? 3 : 1,
              mainAxisExtent: isWide ? 174 : 158,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                ScoreCard(
                  title: 'Productivity',
                  value: scores.productivity,
                  icon: Icons.trending_up,
                  color: const Color(0xFF287D5A),
                ),
                ScoreCard(
                  title: 'Financial Health',
                  value: scores.financialHealth,
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFF256D85),
                ),
                ScoreCard(
                  title: 'Stress Risk',
                  value: scores.stressRisk,
                  icon: Icons.bolt,
                  color: const Color(0xFFC8553D),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _TargetCard(store: store, scores: scores),
        const SizedBox(height: 12),
        _RecommendationCard(items: recommendations),
        const SizedBox(height: 12),
        _SummaryPanel(store: store, scores: scores),
        if (store.syncError != null) ...[
          const SizedBox(height: 12),
          _SyncStatusCard(
            icon: Icons.cloud_off,
            title: 'Backend sync failed',
            value: 'Using local scores for now',
            color: Theme.of(context).colorScheme.error,
          ),
        ] else if (store.lastSyncedAt != null) ...[
          const SizedBox(height: 12),
          _SyncStatusCard(
            icon: Icons.cloud_done,
            title: 'Backend synced',
            value:
                '${store.lastSyncedAt!.hour.toString().padLeft(2, '0')}:'
                '${store.lastSyncedAt!.minute.toString().padLeft(2, '0')}',
            color: const Color(0xFF287D5A),
          ),
        ],
        const SizedBox(height: 16),
        TrendChartCard(
          title: 'Productivity Trend',
          points: _productivityTrend(scores),
          color: const Color(0xFF287D5A),
        ),
        const SizedBox(height: 12),
        TrendChartCard(
          title: 'Spending Trend',
          points: _spendingTrend(),
          color: const Color(0xFFC8553D),
          suffix: ' Rs',
        ),
      ],
    );
  }

  List<TrendPoint> _productivityTrend(LifestyleScores scores) {
    final history = [
      for (final item in store.scoreHistory)
        TrendPoint(
          label: item.date.day.toString(),
          value: item.productivity.toDouble(),
        ),
    ];
    if (history.isNotEmpty) return history;
    return [
      TrendPoint(
        label: DateTime.now().day.toString(),
        value: scores.productivity.toDouble(),
      ),
    ];
  }

  List<TrendPoint> _spendingTrend() {
    final now = DateTime.now();
    return [
      for (var offset = 6; offset >= 0; offset--)
        _dailySpendingPoint(now.subtract(Duration(days: offset))),
    ];
  }

  TrendPoint _dailySpendingPoint(DateTime day) {
    final total = store.expenses
        .where((expense) => _isSameDay(expense.date, day))
        .fold(0.0, (sum, expense) => sum + expense.amount);
    return TrendPoint(label: '${day.day}/${day.month}', value: total);
  }

  List<String> _recommendations(LifestyleScores scores) {
    final items = <String>[];
    final todaySpending = store.todaySpending;
    final dailyBudget = store.dailySpendingBudget;

    if (dailyBudget <= 0 && todaySpending > 0) {
      items.add(
        'Add a monthly budget in Profile so money advice is based on your real limit.',
      );
    } else if (todaySpending > dailyBudget) {
      items.add(
        'Keep tomorrow essentials-only to recover today’s financial score.',
      );
    }

    final weekChange = _weekChangePercent();
    if (weekChange != null && weekChange > 20) {
      items.add(
        'Mark recurring expenses clearly; this helps separate fixed costs from avoidable spikes.',
      );
    }

    if (store.health.sleepHours < 7 && store.health.screenTimeHours > 6) {
      items.add(
        'Move 30 minutes of phone use away from bedtime to improve both sleep and focus.',
      );
    } else if (store.health.sleepHours < 7) {
      items.add(
        'Protect one fixed sleep time tonight instead of trying to recover productivity tomorrow.',
      );
    } else if (store.health.screenTimeHours > 6) {
      items.add(
        'Set one phone-free study block; screen time is the easiest score to improve quickly.',
      );
    }

    if (store.highPriorityTasks >= 2 || scores.stressRisk >= 65) {
      items.add(
        'Choose one high-priority task as the finish line and move one low-priority task to tomorrow.',
      );
    }

    if (items.isEmpty) {
      items.add(
        'Your routine is balanced. Repeat the same sleep, movement, and spending pattern tomorrow.',
      );
    }
    return items.take(4).toList();
  }

  int? _weekChangePercent() {
    final thisWeek = _spendingBetween(0, 6);
    final lastWeek = _spendingBetween(7, 13);
    if (lastWeek <= 0) return null;
    return ((thisWeek - lastWeek) / lastWeek * 100).round();
  }

  double _spendingBetween(int startOffset, int endOffset) {
    final now = DateTime.now();
    return store.expenses
        .where((expense) {
          final age = _dayOnly(now).difference(_dayOnly(expense.date)).inDays;
          return age >= startOffset && age <= endOffset;
        })
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.store, required this.scores});

  final LifeLensStore store;
  final LifestyleScores scores;

  @override
  Widget build(BuildContext context) {
    final target = _target();
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(target.icon, color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(target.body),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: target.progress,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _Target _target() {
    if (store.dailySpendingBudget > 0 &&
        store.todaySpending > store.dailySpendingBudget) {
      return const _Target(
        icon: Icons.savings_outlined,
        title: 'Tomorrow Reset Target',
        body:
            'Keep tomorrow essentials-only. One calm spending day can recover today’s financial score.',
        progress: .35,
      );
    }
    if (store.health.sleepHours < 7) {
      return _Target(
        icon: Icons.bedtime_outlined,
        title: 'Sleep Recovery Target',
        body:
            'Reach 7 hours tonight. Better sleep directly raises productivity and lowers stress risk.',
        progress: (store.health.sleepHours / 7).clamp(0.0, 1.0),
      );
    }
    if (store.health.steps < 8000) {
      return _Target(
        icon: Icons.directions_walk,
        title: 'Activity Target',
        body:
            'Close the 8,000-step gap today. A short walk is the fastest way to lift activity score.',
        progress: (store.health.steps / 8000).clamp(0.0, 1.0),
      );
    }
    return _Target(
      icon: Icons.flag_outlined,
      title: 'Consistency Target',
      body:
          'Repeat today’s routine tomorrow. Consistency keeps productivity high without adding stress.',
      progress: scores.productivity / 100,
    );
  }
}

class _Target {
  const _Target({
    required this.icon,
    required this.title,
    required this.body,
    required this.progress,
  });

  final IconData icon;
  final String title;
  final String body;
  final double progress;
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Recommendations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.store, required this.scores});

  final LifeLensStore store;
  final LifestyleScores scores;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Inputs',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _MetricRow(
              icon: Icons.bedtime,
              label: 'Sleep',
              value: '${store.health.sleepHours.toStringAsFixed(1)} hrs',
            ),
            _MetricRow(
              icon: Icons.directions_walk,
              label: 'Steps',
              value: '${store.health.steps}',
            ),
            _MetricRow(
              icon: Icons.phone_android,
              label: 'Screen time',
              value: '${store.health.screenTimeHours.toStringAsFixed(1)} hrs',
            ),
            _MetricRow(
              icon: Icons.currency_rupee,
              label: 'Today spending',
              value: store.todaySpending.toStringAsFixed(0),
            ),
            _MetricRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Daily budget pace',
              value: store.dailySpendingBudget <= 0
                  ? 'Not set'
                  : store.dailySpendingBudget.toStringAsFixed(0),
            ),
            _MetricRow(
              icon: Icons.priority_high,
              label: 'Burnout risk',
              value: scores.burnoutRisk,
            ),
            _MetricRow(
              icon: Icons.warning_amber,
              label: 'Overspending risk',
              value: scores.overspendingRisk,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
