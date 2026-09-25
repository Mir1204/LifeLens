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
    // AnimatedBuilder wraps the ENTIRE scaffold so every child
    // (including all tab pages) rebuilds whenever store notifies.
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final pages = [
          _HomeDashboard(store: store),
          ExpensesScreen(store: store),
          PlannerScreen(store: store),
          InsightsScreen(store: store),
          ProfileScreen(store: store, onSignOut: widget.onSignOut),
        ];

        // ── Greeting ──────────────────────────────────────────────────
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good morning'
            : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
        final firstName = store.user.name.split(' ').first;

        return Scaffold(
          appBar: AppBar(
            title: Text('$greeting, $firstName!'),
            actions: [
              _ConnectivityBadge(isOnline: store.isOnline),
              const SizedBox(width: 4),
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
          body: SafeArea(
            child: Column(
              children: [
                _OfflineBanner(isOnline: store.isOnline),
                Expanded(child: pages[currentIndex]),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              setState(() => currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Money',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.show_chart_outlined),
                selectedIcon: Icon(Icons.show_chart),
                label: 'Trends',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Me',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Home tab ────────────────────────────────────────────────────────────────

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({required this.store});

  final LifeLensStore store;

  @override
  Widget build(BuildContext context) {
    final scores = store.calculateScores();
    final recommendations = _recommendations(scores);
    final sync = _syncState();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (store.isLoading) const LinearProgressIndicator(),
        _LifeLensStatusHero(scores: scores, sync: sync, store: store),
        const SizedBox(height: 12),
        _TodayProgressCard(store: store),
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
                  color: _positiveScoreColor(scores.productivity),
                ),
                ScoreCard(
                  title: 'Financial Health',
                  value: scores.financialHealth,
                  icon: Icons.account_balance_wallet,
                  color: _positiveScoreColor(scores.financialHealth),
                ),
                ScoreCard(
                  title: 'Stress Risk',
                  value: scores.stressRisk,
                  icon: Icons.bolt,
                  color: _riskScoreColor(scores.stressRisk),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _TargetCard(store: store, scores: scores),
        const SizedBox(height: 12),
        _AiPredictionPanel(store: store, scores: scores),
        const SizedBox(height: 12),
        _RecommendationCard(items: recommendations),
        const SizedBox(height: 12),
        _SummaryPanel(store: store, scores: scores),
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

  _SyncState _syncState() {
    if (!store.backendSyncConsent) {
      return const _SyncState(
        label: 'Consent Required',
        icon: Icons.lock_outline,
        color: Color(0xFFB88746),
      );
    }
    if (store.lastSyncedAt != null && store.syncError == null) {
      return const _SyncState(
        label: 'Backend Synced',
        icon: Icons.cloud_done,
        color: Color(0xFF287D5A),
      );
    }
    if (store.syncError != null) {
      return const _SyncState(
        label: 'Local Mode',
        icon: Icons.cloud_off,
        color: Color(0xFFC8553D),
      );
    }
    return const _SyncState(
      label: 'Local Mode',
      icon: Icons.phone_android,
      color: Color(0xFF256D85),
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
        'Keep tomorrow essentials-only to recover your financial score.',
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

// ── Sync state value object ──────────────────────────────────────────────────

class _SyncState {
  const _SyncState({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _TodayProgressCard extends StatelessWidget {
  const _TodayProgressCard({required this.store});

  final LifeLensStore store;

  @override
  Widget build(BuildContext context) {
    final goals = store.goals;
    final today = DateTime.now();
    final todayTasks = store.tasks.where(
      (task) =>
          task.date.year == today.year &&
          task.date.month == today.month &&
          task.date.day == today.day,
    );
    final taskTotal = todayTasks.length;
    final taskDone = todayTasks.where((task) => task.isCompleted).length;
    final metrics = [
      _ProgressMetric(
        icon: Icons.bedtime_outlined,
        label: 'Sleep',
        value: '${store.health.sleepHours.toStringAsFixed(1)}h',
        progress: store.health.sleepHours / goals.sleepHours,
      ),
      _ProgressMetric(
        icon: Icons.directions_walk_outlined,
        label: 'Steps',
        value: '${store.health.steps}',
        progress: store.health.steps / goals.steps,
      ),
      _ProgressMetric(
        icon: Icons.task_alt_outlined,
        label: 'Tasks',
        value: '$taskDone/$taskTotal',
        progress: taskTotal == 0 ? 0 : taskDone / taskTotal,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today’s progress',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final metric in metrics) ...[
                  Expanded(child: _ProgressMetricView(metric: metric)),
                  if (metric != metrics.last) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressMetric {
  const _ProgressMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final double progress;
}

class _ProgressMetricView extends StatelessWidget {
  const _ProgressMetricView({required this.metric});
  final _ProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(metric.icon, size: 18, color: scheme.primary),
        const SizedBox(height: 6),
        Text(metric.label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 1),
        Text(metric.value, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: metric.progress.clamp(0.0, 1.0),
            backgroundColor: scheme.primary.withValues(alpha: .12),
          ),
        ),
      ],
    );
  }
}

// ── Hero status card ─────────────────────────────────────────────────────────

class _LifeLensStatusHero extends StatelessWidget {
  const _LifeLensStatusHero({
    required this.scores,
    required this.sync,
    required this.store,
  });

  final LifestyleScores scores;
  final _SyncState sync;
  final LifeLensStore store;

  @override
  Widget build(BuildContext context) {
    final riskText = _riskHeadline(scores);
    final color = _riskLabelColor(
      scores.burnoutRisk == 'High'
          ? 80
          : scores.burnoutRisk == 'Medium'
          ? 50
          : scores.stressRisk,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .12), color.withValues(alpha: .05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today\'s LifeLens Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              // Animated chip so it visually transitions when state changes
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _StatusChip(sync: sync, key: ValueKey(sync.label)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            riskText,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '${scores.burnoutRisk} burnout risk • ${scores.overspendingRisk} overspending risk',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .68),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _riskHeadline(LifestyleScores scores) {
    if (scores.stressRisk >= 70 ||
        scores.burnoutRisk == 'High' ||
        scores.overspendingRisk == 'High') {
      return 'Today needs attention';
    }
    if (scores.stressRisk >= 40 ||
        scores.burnoutRisk == 'Medium' ||
        scores.overspendingRisk == 'Medium') {
      return 'Today is mostly steady';
    }
    return 'Today looks balanced';
  }
}

// ── Sync status chip ─────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({super.key, required this.sync});

  final _SyncState sync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: sync.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: sync.color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sync.icon, size: 14, color: sync.color),
          const SizedBox(width: 5),
          Text(
            sync.label,
            style: TextStyle(
              color: sync.color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI prediction panel ──────────────────────────────────────────────────────

class _AiPredictionPanel extends StatelessWidget {
  const _AiPredictionPanel({required this.store, required this.scores});

  final LifeLensStore store;
  final LifestyleScores scores;

  @override
  Widget build(BuildContext context) {
    final synced = store.lastSyncedAt != null && store.syncError == null;
    final source = synced ? 'Backend' : 'Local fallback';
    final syncedAt = store.lastSyncedAt;
    final syncTime = syncedAt == null
        ? 'Not synced'
        : '${syncedAt.hour.toString().padLeft(2, '0')}:${syncedAt.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology_outlined,
                  color: synced
                      ? const Color(0xFF256D85)
                      : const Color(0xFFB88746),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Prediction Output',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Chip grid layout ─────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AiChip(
                  label: 'Source',
                  value: source,
                  icon: Icons.cloud_done_outlined,
                  color: synced
                      ? const Color(0xFF287D5A)
                      : const Color(0xFFB88746),
                ),
                _AiChip(
                  label: 'Last sync',
                  value: syncTime,
                  icon: Icons.schedule,
                  color: const Color(0xFF256D85),
                ),
                _AiChip(
                  label: 'Burnout',
                  value: scores.burnoutRisk,
                  icon: Icons.local_fire_department_outlined,
                  color: _riskColor(scores.burnoutRisk),
                ),
                _AiChip(
                  label: 'Overspend',
                  value: scores.overspendingRisk,
                  icon: Icons.account_balance_wallet_outlined,
                  color: _riskColor(scores.overspendingRisk),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _riskColor(String label) => switch (label) {
    'High' => const Color(0xFFC8553D),
    'Medium' => const Color(0xFFB88746),
    _ => const Color(0xFF287D5A),
  };
}

class _AiChip extends StatelessWidget {
  const _AiChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: .8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Colour helpers ────────────────────────────────────────────────────────────

Color _positiveScoreColor(int value) {
  if (value >= 75) return const Color(0xFF287D5A);
  if (value >= 55) return const Color(0xFF256D85);
  if (value >= 40) return const Color(0xFFB88746);
  return const Color(0xFFC8553D);
}

Color _riskScoreColor(int value) {
  if (value >= 70) return const Color(0xFFC8553D);
  if (value >= 40) return const Color(0xFFB88746);
  return const Color(0xFF287D5A);
}

Color _riskLabelColor(int value) => _riskScoreColor(value);

// ── Target card ───────────────────────────────────────────────────────────────

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
            'Keep tomorrow essentials-only. One calm spending day can recover your financial score.',
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
          'Repeat today\'s routine tomorrow. Consistency keeps productivity high without adding stress.',
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

// ── Recommendation card ───────────────────────────────────────────────────────

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
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recommendationCategory(item),
                      style: TextStyle(
                        color: _recommendationColor(item),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: .4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: _recommendationColor(item),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _recommendationCategory(String item) {
    final lower = item.toLowerCase();
    if (lower.contains('sleep') || lower.contains('bedtime')) return 'SLEEP';
    if (lower.contains('spending') ||
        lower.contains('expense') ||
        lower.contains('budget')) {
      return 'FINANCE';
    }
    if (lower.contains('screen') || lower.contains('phone')) return 'FOCUS';
    if (lower.contains('task') || lower.contains('priority')) {
      return 'WORKLOAD';
    }
    return 'ROUTINE';
  }

  Color _recommendationColor(String item) {
    return switch (_recommendationCategory(item)) {
      'FINANCE' => const Color(0xFF256D85),
      'SLEEP' => const Color(0xFF287D5A),
      'FOCUS' => const Color(0xFFB88746),
      'WORKLOAD' => const Color(0xFFC8553D),
      _ => const Color(0xFF287D5A),
    };
  }
}

// ── Summary / Daily inputs panel ─────────────────────────────────────────────

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
            const SizedBox(height: 4),
            Text(
              'Sleep & Activity',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .45),
                fontWeight: FontWeight.w700,
                letterSpacing: .4,
              ),
            ),
            const SizedBox(height: 6),
            _MetricRow(
              icon: Icons.bedtime,
              label: 'Sleep',
              value: '${store.health.sleepHours.toStringAsFixed(1)} hrs',
              valueColor: store.health.sleepHours < 7
                  ? const Color(0xFFC8553D)
                  : const Color(0xFF287D5A),
            ),
            _MetricRow(
              icon: Icons.directions_walk,
              label: 'Steps',
              value: '${store.health.steps}',
              valueColor: store.health.steps < 5000
                  ? const Color(0xFFB88746)
                  : const Color(0xFF287D5A),
            ),
            _MetricRow(
              icon: Icons.phone_android,
              label: 'Screen time',
              value: '${store.health.screenTimeHours.toStringAsFixed(1)} hrs',
              valueColor: store.health.screenTimeHours > 6
                  ? const Color(0xFFC8553D)
                  : const Color(0xFF287D5A),
            ),
            const SizedBox(height: 10),
            Text(
              'Finance',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .45),
                fontWeight: FontWeight.w700,
                letterSpacing: .4,
              ),
            ),
            const SizedBox(height: 6),
            _MetricRow(
              icon: Icons.currency_rupee,
              label: 'Today spending',
              value: 'Rs ${store.todaySpending.toStringAsFixed(0)}',
            ),
            _MetricRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Daily budget pace',
              value: store.dailySpendingBudget <= 0
                  ? 'Not set'
                  : 'Rs ${store.dailySpendingBudget.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 10),
            Text(
              'Risk',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .45),
                fontWeight: FontWeight.w700,
                letterSpacing: .4,
              ),
            ),
            const SizedBox(height: 6),
            _MetricRow(
              icon: Icons.local_fire_department_outlined,
              label: 'Burnout risk',
              value: scores.burnoutRisk,
              valueColor: _riskColor(scores.burnoutRisk),
            ),
            _MetricRow(
              icon: Icons.warning_amber,
              label: 'Overspending risk',
              value: scores.overspendingRisk,
              valueColor: _riskColor(scores.overspendingRisk),
            ),
          ],
        ),
      ),
    );
  }

  Color _riskColor(String label) => switch (label) {
    'High' => const Color(0xFFC8553D),
    'Medium' => const Color(0xFFB88746),
    _ => const Color(0xFF287D5A),
  };
}

// ── Shared metric row ─────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, color: valueColor),
          ),
        ],
      ),
    );
  }
}

// ── Connectivity Badge ────────────────────────────────────────────────────────

class _ConnectivityBadge extends StatelessWidget {
  const _ConnectivityBadge({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? const Color(0xFF287D5A) : const Color(0xFFC8553D);
    final label = isOnline ? 'Online' : 'Offline';
    final icon = isOnline ? Icons.wifi : Icons.wifi_off;

    return Tooltip(
      message: isOnline
          ? 'Connected – syncing with backend'
          : 'Working offline – data will sync when connection returns',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Offline Banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatefulWidget {
  const _OfflineBanner({required this.isOnline});

  final bool isOnline;

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (!widget.isOnline) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_OfflineBanner old) {
    super.didUpdateWidget(old);
    if (widget.isOnline != old.isOnline) {
      if (widget.isOnline) {
        _ctrl.reverse();
        _dismissed = false;
      } else {
        _dismissed = false;
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fade,
      child: SizeTransition(
        sizeFactor: _fade,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          decoration: BoxDecoration(
            color: const Color(0xFFC8553D).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFC8553D).withValues(alpha: .35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFC8553D),
                  size: 18,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Working offline — data will sync when connection returns',
                    style: TextStyle(
                      color: Color(0xFFC8553D),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _dismissed = true),
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFFC8553D),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
