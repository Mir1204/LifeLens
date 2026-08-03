import 'package:flutter/material.dart';

import '../../models/lifestyle_entry.dart';
import '../../services/lifelens_store.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.store});

  final LifeLensStore store;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late final TextEditingController sleepController;
  late final TextEditingController stepsController;
  late final TextEditingController screenTimeController;

  @override
  void initState() {
    super.initState();
    sleepController = TextEditingController(
      text: widget.store.health.sleepHours.toString(),
    );
    stepsController = TextEditingController(
      text: widget.store.health.steps.toString(),
    );
    screenTimeController = TextEditingController(
      text: widget.store.health.screenTimeHours.toString(),
    );
  }

  @override
  void dispose() {
    sleepController.dispose();
    stepsController.dispose();
    screenTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scores = widget.store.calculateScores();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Health & Screen Time',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: sleepController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sleep hours',
                    prefixIcon: Icon(Icons.bedtime),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stepsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Steps',
                    prefixIcon: Icon(Icons.directions_walk),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: screenTimeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Screen time hours',
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveHealth,
                    icon: const Icon(Icons.save),
                    label: const Text('Update Inputs'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend Ready Payload',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text('sleep_hours: ${widget.store.health.sleepHours}'),
                Text('steps: ${widget.store.health.steps}'),
                Text('screen_time_hours: ${widget.store.health.screenTimeHours}'),
                Text('daily_spending: ${widget.store.todaySpending}'),
                Text('calendar_events: ${widget.store.tasks.length}'),
                Text('high_priority_tasks: ${widget.store.highPriorityTasks}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Warning notification'),
            subtitle: Text(
              scores.stressRisk > 65
                  ? 'High stress risk detected'
                  : 'No urgent warning right now',
            ),
          ),
        ),
      ],
    );
  }

  void _saveHealth() {
    final sleep = double.tryParse(sleepController.text.trim());
    final steps = int.tryParse(stepsController.text.trim());
    final screenTime = double.tryParse(screenTimeController.text.trim());
    if (sleep == null || steps == null || screenTime == null) return;

    widget.store.updateHealth(
      DailyHealthEntry(
        sleepHours: sleep,
        steps: steps,
        screenTimeHours: screenTime,
      ),
    );
    FocusScope.of(context).unfocus();
  }
}
