import 'package:flutter/material.dart';

import '../../models/wellbeing_models.dart';
import '../../services/lifelens_store.dart';

class WellbeingCards extends StatelessWidget {
  const WellbeingCards({super.key, required this.store});
  final LifeLensStore store;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _CheckInCard(store: store),
      const SizedBox(height: 12),
      _GoalsCard(store: store),
    ],
  );
}

class RoutineRemindersCard extends StatelessWidget {
  const RoutineRemindersCard({super.key, required this.store});
  final LifeLensStore store;

  @override
  Widget build(BuildContext context) {
    final p = store.routineReminderPreferences;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.alarm_outlined),
        title: const Text(
          'Smart routine reminders',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Choose only the reminders that help your routine',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _routineRow(
            context: context,
            icon: Icons.bedtime_outlined,
            title: 'Bedtime',
            enabled: p.bedtimeEnabled,
            minutes: p.bedtimeMinutes,
            onChanged: (value) => store.saveRoutineReminderPreferences(
              p.copyWith(bedtimeEnabled: value),
            ),
            onTimeChanged: (minutes) => store.saveRoutineReminderPreferences(
              p.copyWith(bedtimeMinutes: minutes),
            ),
          ),
          _routineRow(
            context: context,
            icon: Icons.phone_paused_outlined,
            title: 'Screen break',
            enabled: p.screenBreakEnabled,
            minutes: p.screenBreakMinutes,
            onChanged: (value) => store.saveRoutineReminderPreferences(
              p.copyWith(screenBreakEnabled: value),
            ),
            onTimeChanged: (minutes) => store.saveRoutineReminderPreferences(
              p.copyWith(screenBreakMinutes: minutes),
            ),
          ),
          _routineRow(
            context: context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Budget check',
            enabled: p.budgetCheckEnabled,
            minutes: p.budgetCheckMinutes,
            onChanged: (value) => store.saveRoutineReminderPreferences(
              p.copyWith(budgetCheckEnabled: value),
            ),
            onTimeChanged: (minutes) => store.saveRoutineReminderPreferences(
              p.copyWith(budgetCheckMinutes: minutes),
            ),
          ),
          _routineRow(
            context: context,
            icon: Icons.fact_check_outlined,
            title: 'Daily check-in',
            enabled: p.checkInEnabled,
            minutes: p.checkInMinutes,
            onChanged: (value) => store.saveRoutineReminderPreferences(
              p.copyWith(checkInEnabled: value),
            ),
            onTimeChanged: (minutes) => store.saveRoutineReminderPreferences(
              p.copyWith(checkInMinutes: minutes),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routineRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool enabled,
    required int minutes,
    required ValueChanged<bool> onChanged,
    required ValueChanged<int> onTimeChanged,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context),
    ),
    trailing: Switch.adaptive(value: enabled, onChanged: onChanged),
    onTap: () async {
      final selected = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      );
      if (selected != null) onTimeChanged(selected.hour * 60 + selected.minute);
    },
  );
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.store});
  final LifeLensStore store;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayCheckIn = store.checkIns
        .where(
          (entry) =>
              entry.date.year == now.year &&
              entry.date.month == now.month &&
              entry.date.day == now.day,
        )
        .firstOrNull;
    final hasCheckIn = todayCheckIn != null;
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
                      hasCheckIn
                          ? 'Today’s wellbeing snapshot'
                          : 'Daily wellbeing check-in',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasCheckIn
                          ? 'Mood ${todayCheckIn.mood}/5 · Energy ${todayCheckIn.energy}/5 · Stress ${todayCheckIn.stress}/5'
                          : 'Helps personalise your stress estimate.',
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
        builder: (ctx, setState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.insights_outlined),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'How are you feeling?',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your one-minute reflection helps LifeLens tailor practical wellbeing guidance for today.',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    _rating('Mood', mood, const [
                      'Very low',
                      'Low',
                      'Okay',
                      'Good',
                      'Great',
                    ], (v) => setState(() => mood = v)),
                    _rating('Energy', energy, const [
                      'Drained',
                      'Low',
                      'Steady',
                      'Good',
                      'High',
                    ], (v) => setState(() => energy = v)),
                    _rating('Stress', stress, const [
                      'Calm',
                      'Light',
                      'Moderate',
                      'High',
                      'Very high',
                    ], (v) => setState(() => stress = v)),
                    const SizedBox(height: 2),
                    TextField(
                      controller: note,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Private note (optional)',
                        hintText:
                            'What would you like to remember about today?',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 36),
                          child: Icon(Icons.edit_note_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Not now'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
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
                          icon: const Icon(Icons.check),
                          label: const Text('Save check-in'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    note.dispose();
    if (entry != null) await store.saveCheckIn(entry);
  }

  Widget _rating(
    String label,
    int value,
    List<String> labels,
    ValueChanged<int> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(
            labels[value - 1],
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 6),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: List.generate(
          5,
          (index) =>
              ButtonSegment(value: index + 1, label: Text('${index + 1}')),
        ),
        selected: {value},
        onSelectionChanged: (selection) => change(selection.first),
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
              _GoalRow(
                icon: Icons.bedtime_outlined,
                label: 'Sleep',
                value:
                    '${store.health.sleepHours.toStringAsFixed(1)} / ${goals.sleepHours.toStringAsFixed(1)} hours',
              ),
              _GoalRow(
                icon: Icons.directions_walk_outlined,
                label: 'Steps',
                value: '${store.health.steps} / ${goals.steps}',
              ),
              _GoalRow(
                icon: Icons.phone_android_outlined,
                label: 'Screen time',
                value:
                    '${store.health.screenTimeHours.toStringAsFixed(1)} / ${goals.screenTimeHours.toStringAsFixed(1)} hours',
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final sleepValue = double.tryParse(sleep.text);
              final stepsValue = int.tryParse(steps.text);
              final screenValue = double.tryParse(screen.text);
              if (sleepValue == null ||
                  sleepValue <= 0 ||
                  stepsValue == null ||
                  stepsValue <= 0 ||
                  screenValue == null ||
                  screenValue <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Use positive values for each goal.'),
                  ),
                );
                return;
              }
              Navigator.pop(
                ctx,
                UserGoals(
                  sleepHours: sleepValue,
                  steps: stepsValue,
                  screenTimeHours: screenValue,
                  monthlyBudget: g.monthlyBudget,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final c in [sleep, steps, screen]) {
      c.dispose();
    }
    if (next != null) await store.saveGoals(next);
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

// ignore: unused_element
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
                _ReportMetric(
                  label: 'Sleep',
                  value: '${r.sleepAverage.toStringAsFixed(1)}h',
                ),
                _ReportMetric(
                  label: 'Screen',
                  value:
                      '${r.screenTimeChange >= 0 ? '+' : ''}${r.screenTimeChange.toStringAsFixed(1)}h',
                ),
                _ReportMetric(
                  label: 'Spent',
                  value: '₹${r.spending.toStringAsFixed(0)}',
                ),
                _ReportMetric(
                  label: 'Tasks',
                  value: '${r.completionRate.toStringAsFixed(0)}%',
                ),
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

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}
