import 'package:flutter/material.dart';

import '../../models/lifestyle_scores.dart';
import '../../services/lifelens_store.dart';
import '../../widgets/score_card.dart';
import '../expenses/expenses_screen.dart';
import '../insights/insights_screen.dart';
import '../planner/planner_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LifeLensStore store = LifeLensStore();
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeDashboard(store: store),
      ExpensesScreen(store: store),
      PlannerScreen(store: store),
      InsightsScreen(store: store),
      ProfileScreen(store: store),
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
                onPressed: store.refreshScores,
                icon: const Icon(Icons.sync),
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Today',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your lifestyle snapshot from sleep, spending, tasks, and screen time.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 680;
            return GridView.count(
              crossAxisCount: isWide ? 3 : 1,
              mainAxisExtent: isWide ? 148 : 136,
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
        _SummaryPanel(store: store, scores: scores),
        const SizedBox(height: 16),
        _Recommendations(scores: scores),
      ],
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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

class _Recommendations extends StatelessWidget {
  const _Recommendations({required this.scores});

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
              'Recommendations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            for (final item in scores.recommendations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
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
