import 'package:flutter/material.dart';

import '../../services/lifelens_store.dart';
import '../../services/notification_service.dart';

class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key, required this.store});
  final LifeLensStore store;

  @override
  Widget build(BuildContext context) {
    final color = store.syncError == null
        ? const Color(0xFF287D5A)
        : const Color(0xFFC8553D);
    final last = store.lastSyncedAt;
    final background = store.lastBackgroundSyncedAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync status',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              store.isSyncing
                  ? 'Syncing now…'
                  : store.isOnline
                  ? 'Online'
                  : 'Offline',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            Text('Foreground sync: ${last == null ? 'Not yet' : _stamp(last)}'),
            Text(
              'Background sync: ${background == null ? 'Waiting for Android schedule' : _stamp(background)}',
            ),
            Text(
              'Health Connect: ${store.health.source.contains('health') || store.health.source == 'device_sync' ? 'Last read available' : 'Manual / permission needed'}',
            ),
            Text(
              'Screen-time access: ${store.appUsage == null ? 'Permission needed or not yet read' : 'Last read ${_stamp(store.appUsage!.updatedAt)}'}',
            ),
            if (store.syncError != null ||
                (store.lastBackgroundSyncError?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Text(
                store.syncError ?? store.lastBackgroundSyncError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _stamp(DateTime value) =>
      '${value.day}/${value.month} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class NotificationSettingsCard extends StatelessWidget {
  const NotificationSettingsCard({super.key, required this.store});
  final LifeLensStore store;

  @override
  Widget build(BuildContext context) {
    final p = store.notificationPreferences;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.notifications_active_outlined),
        title: const Text(
          'Notification settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          p.isQuietNow
              ? 'Quiet hours active'
              : 'Alerts use your saved thresholds',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _toggle(
            'Stress risk',
            p.stressEnabled,
            (v) => _save(p.copyWith(stressEnabled: v)),
          ),
          _slider(
            'Stress alert at ${p.stressThreshold}/100',
            p.stressThreshold.toDouble(),
            40,
            95,
            (v) => _save(p.copyWith(stressThreshold: v.round())),
          ),
          _toggle(
            'Spending alert',
            p.spendingEnabled,
            (v) => _save(p.copyWith(spendingEnabled: v)),
          ),
          _slider(
            'Financial health at or below ${p.financialHealthThreshold}',
            p.financialHealthThreshold.toDouble(),
            20,
            80,
            (v) => _save(p.copyWith(financialHealthThreshold: v.round())),
          ),
          _toggle(
            'Screen-time alert',
            p.screenTimeEnabled,
            (v) => _save(p.copyWith(screenTimeEnabled: v)),
          ),
          _slider(
            'Screen time at ${p.screenTimeThreshold.toStringAsFixed(1)} hours',
            p.screenTimeThreshold,
            3,
            12,
            (v) => _save(p.copyWith(screenTimeThreshold: v)),
          ),
          _toggle(
            'Low-sleep alert',
            p.sleepEnabled,
            (v) => _save(p.copyWith(sleepEnabled: v)),
          ),
          _slider(
            'Sleep below ${p.sleepThreshold.toStringAsFixed(1)} hours',
            p.sleepThreshold,
            3,
            8,
            (v) => _save(p.copyWith(sleepThreshold: v)),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quiet hours'),
            subtitle: Text(_quietLabel(context, p)),
            trailing: const Icon(Icons.schedule),
            onTap: () => _setQuietHours(context, p),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      );
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12)),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: (max - min).round(),
        onChanged: onChanged,
      ),
    ],
  );
  Future<void> _save(NotificationPreferences p) =>
      store.saveNotificationPreferences(p);

  String _quietLabel(BuildContext context, NotificationPreferences p) {
    if (p.quietStartMinutes == null) return 'Off';
    TimeOfDay asTime(int v) => TimeOfDay(hour: v ~/ 60, minute: v % 60);
    return '${asTime(p.quietStartMinutes!).format(context)} – ${asTime(p.quietEndMinutes!).format(context)}';
  }

  Future<void> _setQuietHours(
    BuildContext context,
    NotificationPreferences p,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (p.quietStartMinutes ?? 1320) ~/ 60,
        minute: (p.quietStartMinutes ?? 1320) % 60,
      ),
    );
    if (start == null) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (p.quietEndMinutes ?? 420) ~/ 60,
        minute: (p.quietEndMinutes ?? 420) % 60,
      ),
    );
    if (end != null)
      await _save(
        p.copyWith(
          quietStartMinutes: start.hour * 60 + start.minute,
          quietEndMinutes: end.hour * 60 + end.minute,
        ),
      );
  }
}
