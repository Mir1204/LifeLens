import 'package:flutter/material.dart';

import '../../services/lifelens_store.dart';

class DeveloperTools extends StatelessWidget {
  const DeveloperTools({super.key, required this.store});
  final LifeLensStore store;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.developer_mode_outlined),
      title: const Text(
        'Developer tools',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        '30-day health, tasks, check-ins, spending and risk scenarios',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _load(context, false),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Load 30-day balanced'),
            ),
            FilledButton.icon(
              onPressed: () => _load(context, true),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Load 30-day high risk'),
            ),
            TextButton.icon(
              onPressed: () => _remove(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove demo data'),
            ),
            OutlinedButton.icon(
              onPressed: () => _testNotification(context),
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Send test notification'),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _load(BuildContext context, bool highRisk) async {
    await store.loadDemoData(highRisk: highRisk);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            highRisk
                ? '30-day high-risk demo loaded'
                : '30-day balanced demo loaded',
          ),
        ),
      );
    }
  }

  Future<void> _remove(BuildContext context) async {
    await store.clearDemoData();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Demo data removed.')));
    }
  }

  Future<void> _testNotification(BuildContext context) async {
    final sent = await store.notificationService.showTestNotification();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Test notification sent.'
                : 'Allow notifications in Android settings, then try again.',
          ),
        ),
      );
    }
  }
}
