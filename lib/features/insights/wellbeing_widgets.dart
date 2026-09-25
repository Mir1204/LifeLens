import 'package:flutter/material.dart';

import '../../models/wellbeing_models.dart';
import '../../services/lifelens_store.dart';
import '../../services/notification_service.dart';

class WellbeingCards extends StatelessWidget {
  const WellbeingCards({super.key, required this.store});
  final LifeLensStore store;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _CheckInCard(store: store),
      const SizedBox(height: 12),
      _GoalsCard(store: store),
      const SizedBox(height: 12),
      _WeeklyReportCard(store: store),
      const SizedBox(height: 12),
      _AchievementsCard(store: store),
      const SizedBox(height: 12),
      _RoutineRemindersCard(),
    ],
  );
}

class _RoutineRemindersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.alarm_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Smart routine reminders',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Bedtime 10:00 PM • screen break 3:00 PM • budget check 7:00 PM',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () async {
                final n = NotificationService();
                await n.scheduleDailyRoutine(
                  id: 1,
                  time: const TimeOfDay(hour: 22, minute: 0),
                  title: 'Wind down for sleep',
                  body: 'Start your bedtime routine for tomorrow’s energy.',
                );
                await n.scheduleDailyRoutine(
                  id: 2,
                  time: const TimeOfDay(hour: 15, minute: 0),
                  title: 'Screen break',
                  body: 'Take a 10-minute break away from your phone.',
                );
                await n.scheduleDailyRoutine(
                  id: 3,
                  time: const TimeOfDay(hour: 19, minute: 0),
                  title: 'Daily budget check',
                  body: 'Review today’s spending before the day ends.',
                );
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Routine reminders enabled.')),
                  );
              },
              child: const Text('Enable'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.store});
  final LifeLensStore store;
  @override
  Widget build(BuildContext context) {
    final hasCheckIn = store.checkIns.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: .48),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: .14),
                foregroundColor: scheme.primary,
                child: Icon(
                  hasCheckIn
                      ? Icons.check_circle_outline
                      : Icons.sentiment_satisfied_alt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCheckIn ? 'Check-in complete' : 'Daily check-in',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasCheckIn
                          ? 'Your wellbeing signals are up to date.'
                          : 'Takes less than a minute.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hasCheckIn ? 'Edit' : 'Start',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    var mood = 3, energy = 3, stress = 3;
    final note = TextEditingController();
    final entry = await showDialog<DailyCheckIn>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('How are you feeling?'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A quick private check-in helps personalise Trends.',
                ),
                const SizedBox(height: 16),
                _rating('Mood', mood, (v) => setState(() => mood = v)),
                _rating('Energy', energy, (v) => setState(() => energy = v)),
                _rating('Stress', stress, (v) => setState(() => stress = v)),
                const SizedBox(height: 4),
                TextField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Private note (optional)',
                    hintText: 'What is affecting your day?',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                DailyCheckIn(
                  date: DateTime.now(),
                  mood: mood,
                  energy: energy,
                  stress: stress,
                  note: note.text.trim(),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    if (entry != null) await store.saveCheckIn(entry);
  }

  Widget _rating(String label, int value, ValueChanged<int> change) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        children: List.generate(
          5,
          (index) => ChoiceChip(
            label: Text('${index + 1}'),
            selected: value == index + 1,
            onSelected: (_) => change(index + 1),
          ),
        ),
      ),
      const SizedBox(height: 14),
    ],
  );
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.store});
  final LifeLensStore store;
  @override
  Widget build(BuildContext context) {
    final goals = store.goals;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Your goals',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GoalPill(
                    icon: Icons.bedtime_outlined,
                    label: '${goals.sleepHours.toStringAsFixed(1)}h sleep',
                  ),
                  _GoalPill(
                    icon: Icons.directions_walk_outlined,
                    label: '${goals.steps} steps',
                  ),
                  _GoalPill(
                    icon: Icons.phone_android_outlined,
                    label: '≤${goals.screenTimeHours.toStringAsFixed(1)}h',
                  ),
                  _GoalPill(
                    icon: Icons.account_balance_wallet_outlined,
                    label: '₹${goals.monthlyBudget.toStringAsFixed(0)}/mo',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final g = store.goals;
    final sleep = TextEditingController(text: g.sleepHours.toString());
    final steps = TextEditingController(text: g.steps.toString());
    final screen = TextEditingController(text: g.screenTimeHours.toString());
    final budget = TextEditingController(text: g.monthlyBudget.toString());
    final next = await showDialog<UserGoals>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set goals'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: sleep,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sleep target (hours)',
                ),
              ),
              TextField(
                controller: steps,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Daily steps target',
                ),
              ),
              TextField(
                controller: screen,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Screen-time limit (hours)',
                ),
              ),
              TextField(
                controller: budget,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly spending budget',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              UserGoals(
                sleepHours: double.tryParse(sleep.text) ?? g.sleepHours,
                steps: int.tryParse(steps.text) ?? g.steps,
                screenTimeHours:
                    double.tryParse(screen.text) ?? g.screenTimeHours,
                monthlyBudget: double.tryParse(budget.text) ?? g.monthlyBudget,
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final c in [sleep, steps, screen, budget]) {
      c.dispose();
    }
    if (next != null) await store.saveGoals(next);
  }
}

class _GoalPill extends StatelessWidget {
  const _GoalPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 5), Text(label)],
    ),
  );
}

class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard({required this.store});
  final LifeLensStore store;
  @override
  Widget build(BuildContext context) {
    final r = store.weeklyReport;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly report',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Sleep ${r.sleepAverage.toStringAsFixed(1)}h'),
                Text(
                  'Screen ${r.screenTimeChange >= 0 ? '+' : ''}${r.screenTimeChange.toStringAsFixed(1)}h',
                ),
                Text('Spent ₹${r.spending.toStringAsFixed(0)}'),
                Text('Tasks ${r.completionRate.toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 10),
            Text(r.recommendation),
          ],
        ),
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.store});
  final LifeLensStore store;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progress', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('🌙 ${store.sleepGoalStreak}-day sleep-goal streak'),
          Text('📵 ${store.screenTimeGoalStreak}-day screen-time streak'),
          Text(
            '✅ ${store.tasks.where((t) => t.isCompleted).length} tasks completed',
          ),
        ],
      ),
    ),
  );
}
