import 'package:flutter/material.dart';

import '../../models/lifestyle_entry.dart';
import '../../models/lifestyle_scores.dart';
import '../../models/app_usage_summary.dart';
import '../../services/device_data_service.dart';
import '../../services/lifelens_store.dart';
import '../../widgets/trend_chart_card.dart';
import 'sync_settings_widgets.dart';
import 'wellbeing_widgets.dart';
import 'prediction_explanation_card.dart';

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
      builder: (context, _) {
        try {
          return _buildContent(context);
        } catch (error, stackTrace) {
          debugPrint('LifeLens Trends build failure: $error\n$stackTrace');
          return _TrendsRecoveryCard(onRetry: () => setState(() {}));
        }
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final scores = widget.store.calculateScores();
    final currentUsage = appUsage ?? widget.store.appUsage;
    final avgSleep = widget.store.health.sleepHours;
    final todaySpend = widget.store.todaySpending;

    return Column(
      children: [
        _InsightsOfflineBanner(isOnline: widget.store.isOnline),
        Expanded(
          child: ListView(
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Avg ${avgSleep.toStringAsFixed(1)} hrs sleep · Rs ${todaySpend.toStringAsFixed(0)}/day',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .1),
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
                          DropdownMenuItem(
                            value: 7,
                            child: Text('Last 7 Days'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('Last 30 Days'),
                          ),
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
              PredictionExplanationCard(
                stressRisk: scores.stressRisk,
                explanations: widget.store.predictionExplanations,
              ),
              const SizedBox(height: 16),
              SyncStatusCard(store: widget.store),
              const SizedBox(height: 12),
              NotificationSettingsCard(store: widget.store),
              const SizedBox(height: 16),
              WellbeingCards(store: widget.store),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: Icon(
                    widget.store.isSyncing
                        ? Icons.sync
                        : Icons.cloud_done_outlined,
                  ),
                  title: Text(
                    widget.store.isSyncing
                        ? 'Syncing health data'
                        : 'Sync status',
                  ),
                  subtitle: Text(
                    widget.store.syncError ??
                        (widget.store.lastSyncedAt == null
                            ? 'Waiting for first secure sync'
                            : 'Last synced ${widget.store.lastSyncedAt!.toLocal()}'),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: widget.store.isSyncing
                        ? null
                        : widget.store.syncWithBackend,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: Card(
                  child: ExpansionTile(
                    title: const Text(
                      'Manual Health Entry',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    leading: Icon(
                      Icons.edit_note,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
                          onPressed: isReadingHealth
                              ? null
                              : _readHealthConnect,
                          icon: isReadingHealth
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
              if (widget.store.scoreHistory.isEmpty &&
                  currentUsage == null) ...[
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text('sleep_hours: ${widget.store.health.sleepHours}'),
                      Text('steps: ${widget.store.health.steps}'),
                      Text(
                        'screen_time_hours: ${widget.store.health.screenTimeHours}',
                      ),
                      Text('daily_spending: ${widget.store.todaySpending}'),
                      Text('calendar_events: ${widget.store.tasks.length}'),
                      Text(
                        'high_priority_tasks: ${widget.store.highPriorityTasks}',
                      ),
                      Text('total_workload: ${widget.store.totalWorkload}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
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

class _TrendsRecoveryCard extends StatelessWidget {
  const _TrendsRecoveryCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insights_outlined, size: 42),
              const SizedBox(height: 12),
              Text(
                'Trends needs a refresh',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your saved data is safe. Try refreshing this screen.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Trends'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
    final maxHours = summary.apps.fold<double>(
      0.01,
      (m, app) => app.hours > m ? app.hours : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Most Used Apps',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: summary.apps.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final app = summary.apps[i];
              final ratio = (app.hours / maxHours).clamp(0.0, 1.0);
              final barColor = _appColor(i);

              return Container(
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      barColor.withValues(alpha: .18),
                      barColor.withValues(alpha: .07),
                    ],
                  ),
                  border: Border.all(
                    color: barColor.withValues(alpha: .28),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.apps_rounded, color: barColor, size: 22),
                    const Spacer(),
                    Text(
                      app.name.length > 12
                          ? '${app.name.substring(0, 11)}…'
                          : app.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${app.hours.toStringAsFixed(1)}h',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: barColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 4,
                        backgroundColor: barColor.withValues(alpha: .18),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _appColor(int i) {
    const palette = [
      Color(0xFF256D85),
      Color(0xFF287D5A),
      Color(0xFFB88746),
      Color(0xFFC8553D),
      Color(0xFF7B5EA7),
    ];
    return palette[i % palette.length];
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
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
      stressAlerts.add(
        'High stress risk (${scores.stressRisk}/100) — reduce task load',
      );
    }
    if (health.screenTimeHours >= 7) {
      stressAlerts.add(
        'Screen time is ${health.screenTimeHours.toStringAsFixed(1)}h — try a break',
      );
    }
    if (stressAlerts.isNotEmpty) {
      alerts.add(
        _AlertGroup(
          title: 'Workload & Focus',
          icon: Icons.bolt,
          color: const Color(0xFFC8553D),
          messages: stressAlerts,
        ),
      );
    }

    final sleepAlerts = <String>[];
    if (health.sleepHours < 6) {
      sleepAlerts.add('Sleep is below 6 hours — plan an earlier bedtime');
    }
    if (sleepAlerts.isNotEmpty) {
      alerts.add(
        _AlertGroup(
          title: 'Sleep',
          icon: Icons.bedtime,
          color: const Color(0xFF287D5A),
          messages: sleepAlerts,
        ),
      );
    }

    final financeAlerts = <String>[];
    if (scores.financialHealth <= 60) {
      financeAlerts.add('Financial health is low — review today\'s spending');
    }
    if (financeAlerts.isNotEmpty) {
      alerts.add(
        _AlertGroup(
          title: 'Finance',
          icon: Icons.account_balance_wallet,
          color: const Color(0xFFB88746),
          messages: financeAlerts,
        ),
      );
    }

    return alerts;
  }
}

class _AlertGroup {
  const _AlertGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.messages,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<String> messages;
}

// ── Offline Banner for Insights ───────────────────────────────────────────────

class _InsightsOfflineBanner extends StatefulWidget {
  const _InsightsOfflineBanner({required this.isOnline});

  final bool isOnline;

  @override
  State<_InsightsOfflineBanner> createState() => _InsightsOfflineBannerState();
}

class _InsightsOfflineBannerState extends State<_InsightsOfflineBanner>
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
  void didUpdateWidget(_InsightsOfflineBanner old) {
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
                    'Working offline — health sync will resume when connected',
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
