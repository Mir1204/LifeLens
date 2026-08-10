import 'package:flutter/material.dart';

import '../../models/lifestyle_entry.dart';
import '../../models/lifestyle_scores.dart';
import '../../models/app_usage_summary.dart';
import '../../services/device_data_service.dart';
import '../../services/lifelens_store.dart';
import '../../widgets/trend_chart_card.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.store});

  final LifeLensStore store;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final deviceDataService = DeviceDataService();
  late final TextEditingController sleepController;
  late final TextEditingController stepsController;
  late final TextEditingController screenTimeController;
  AppUsageSummary? appUsage;
  bool isReadingHealth = false;
  bool isReadingUsage = false;
  String? deviceError;

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
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final scores = widget.store.calculateScores();
    final currentUsage = appUsage ?? widget.store.appUsage;
    final avgSleep = widget.store.health.sleepHours;
    final todaySpend = widget.store.todaySpending;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trends & Health',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Avg ${avgSleep.toStringAsFixed(1)} hrs sleep · Rs ${todaySpend.toStringAsFixed(0)}/day',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: 7,
                  isDense: true,
                  iconSize: 16,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
                    DropdownMenuItem(value: 30, child: Text('Last 30 Days')),
                  ],
                  onChanged: (val) {},
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _LifestyleAlertCard(scores: scores, health: widget.store.health),
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Card(
            child: ExpansionTile(
              title: Text(
                'Manual Health Entry',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              leading: Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
              childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isReadingHealth ? null : _readHealthConnect,
                    icon: isReadingHealth
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.health_and_safety),
                    label: const Text('Read Health Connect'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isReadingUsage ? null : _readScreenTime,
                    icon: isReadingUsage
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.phone_android),
                    label: const Text('Read Screen Time'),
                  ),
                ),
                TextButton.icon(
                  onPressed: deviceDataService.openUsageAccessSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Usage Access Settings'),
                ),
                if (deviceError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    deviceError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ScreenTimeHero(
          summary: currentUsage,
          fallbackHours: widget.store.health.screenTimeHours,
        ),
        if (widget.store.scoreHistory.isEmpty && currentUsage == null) ...[
          const SizedBox(height: 12),
          const _HealthEmptyState(),
        ],
        if (currentUsage != null) ...[
          const SizedBox(height: 12),
          _MostUsedApps(summary: currentUsage),
        ],
        const SizedBox(height: 12),
        TrendChartCard(
          title: 'Sleep Trend',
          points: [
            for (final item in widget.store.scoreHistory)
              TrendPoint(
                label: item.date.day.toString(),
                value: item.sleepHours,
              ),
          ],
          color: const Color(0xFF256D85),
          suffix: 'h',
        ),
        const SizedBox(height: 12),
        TrendChartCard(
          title: 'Screen Time Trend',
          points: [
            for (final item in widget.store.scoreHistory)
              TrendPoint(
                label: item.date.day.toString(),
                value: item.screenTimeHours,
              ),
          ],
          color: const Color(0xFFC8553D),
          suffix: 'h',
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
                Text(
                  'screen_time_hours: ${widget.store.health.screenTimeHours}',
                ),
                Text('daily_spending: ${widget.store.todaySpending}'),
                Text('calendar_events: ${widget.store.tasks.length}'),
                Text('high_priority_tasks: ${widget.store.highPriorityTasks}'),
                Text('total_workload: ${widget.store.totalWorkload}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveHealth() async {
    final sleep = double.tryParse(sleepController.text.trim());
    final steps = int.tryParse(stepsController.text.trim());
    final screenTime = double.tryParse(screenTimeController.text.trim());
    if (sleep == null || steps == null || screenTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid sleep, steps, and screen-time values.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await widget.store.updateHealth(
      DailyHealthEntry(
        sleepHours: sleep,
        steps: steps,
        screenTimeHours: screenTime,
      ),
    );
    FocusScope.of(context).unfocus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Health inputs updated'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _readHealthConnect() async {
    setState(() {
      isReadingHealth = true;
      deviceError = null;
    });

    try {
      final entry = await deviceDataService.readHealthConnect(
        fallback: widget.store.health,
      );
      await widget.store.updateHealth(entry);
      sleepController.text = entry.sleepHours.toStringAsFixed(1);
      stepsController.text = entry.steps.toString();
    } catch (error) {
      setState(() => deviceError = 'Health Connect: $error');
    } finally {
      if (mounted) setState(() => isReadingHealth = false);
    }
  }

  Future<void> _readScreenTime() async {
    setState(() {
      isReadingUsage = true;
      deviceError = null;
    });

    try {
      final summary = await deviceDataService.readAppUsage();
      await widget.store.saveAppUsage(summary);
      screenTimeController.text = summary.totalHours.toStringAsFixed(1);
      setState(() => appUsage = summary);
    } catch (error) {
      setState(
        () => deviceError =
            'Usage access is required. Open settings and allow LifeLens.',
      );
    } finally {
      if (mounted) setState(() => isReadingUsage = false);
    }
  }
}

class _HealthEmptyState extends StatelessWidget {
  const _HealthEmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 44,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .32),
            ),
            const SizedBox(height: 10),
            Text(
              'No health history yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Enter sleep and steps manually or connect Health Connect.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenTimeHero extends StatelessWidget {
  const _ScreenTimeHero({required this.summary, required this.fallbackHours});

  final AppUsageSummary? summary;
  final double fallbackHours;

  @override
  Widget build(BuildContext context) {
    final hours = fallbackHours;
    final updated = summary?.updatedAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.phone_android,
              color: Theme.of(context).colorScheme.primary,
              size: 34,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${hours.toStringAsFixed(1)} hours',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    updated == null
                        ? 'Manual or last saved screen time'
                        : 'Updated ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MostUsedApps extends StatelessWidget {
  const _MostUsedApps({required this.summary});

  final AppUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Used Apps',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final app in summary.apps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.apps),
                title: Text(app.name),
                subtitle: Text(app.packageName),
                trailing: Text('${app.hours.toStringAsFixed(1)}h'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Color-coded lifestyle alert card ──────────────────────────────────────────

class _LifestyleAlertCard extends StatelessWidget {
  const _LifestyleAlertCard({required this.scores, required this.health});

  final LifestyleScores scores;
  final DailyHealthEntry health;

  @override
  Widget build(BuildContext context) {
    final alerts = _buildAlerts();
    final isAllClear = alerts.isEmpty;

    final cardColor = isAllClear
        ? const Color(0xFF287D5A).withValues(alpha: .08)
        : const Color(0xFFC8553D).withValues(alpha: .08);
    final borderColor = isAllClear
        ? const Color(0xFF287D5A).withValues(alpha: .3)
        : const Color(0xFFC8553D).withValues(alpha: .3);
    final iconColor = isAllClear
        ? const Color(0xFF287D5A)
        : const Color(0xFFC8553D);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAllClear
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: iconColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                isAllClear ? 'All Clear' : 'Lifestyle Alerts',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
              ),
            ],
          ),
          if (isAllClear) ...[
            const SizedBox(height: 6),
            Text(
              'Your lifestyle looks balanced today. Keep it up!',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (final group in alerts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(group.icon, size: 14, color: group.color),
                        const SizedBox(width: 6),
                        Text(
                          group.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: group.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (final msg in group.messages)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 4),
                        child: Text(
                          msg,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<_AlertGroup> _buildAlerts() {
    final alerts = <_AlertGroup>[];
    
    final stressAlerts = <String>[];
    if (scores.stressRisk >= 70) {
      stressAlerts.add('High stress risk (${scores.stressRisk}/100) — reduce task load');
    }
    if (health.screenTimeHours >= 7) {
      stressAlerts.add('Screen time is ${health.screenTimeHours.toStringAsFixed(1)}h — try a break');
    }
    if (stressAlerts.isNotEmpty) {
      alerts.add(_AlertGroup(title: 'Workload & Focus', icon: Icons.bolt, color: const Color(0xFFC8553D), messages: stressAlerts));
    }

    final sleepAlerts = <String>[];
    if (health.sleepHours < 6) {
      sleepAlerts.add('Sleep is below 6 hours — plan an earlier bedtime');
    }
    if (sleepAlerts.isNotEmpty) {
      alerts.add(_AlertGroup(title: 'Sleep', icon: Icons.bedtime, color: const Color(0xFF287D5A), messages: sleepAlerts));
    }

    final financeAlerts = <String>[];
    if (scores.financialHealth <= 60) {
      financeAlerts.add('Financial health is low — review today\'s spending');
    }
    if (financeAlerts.isNotEmpty) {
      alerts.add(_AlertGroup(title: 'Finance', icon: Icons.account_balance_wallet, color: const Color(0xFFB88746), messages: financeAlerts));
    }

    return alerts;
  }
}

class _AlertGroup {
  const _AlertGroup({required this.title, required this.icon, required this.color, required this.messages});
  final String title;
  final IconData icon;
  final Color color;
  final List<String> messages;
}

