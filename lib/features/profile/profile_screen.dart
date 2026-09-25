import 'package:flutter/material.dart';

import '../../app/lifelens_app.dart';
import '../../models/app_user.dart';
import '../../services/lifelens_store.dart';
import '../../services/data_portability_service.dart';
import '../../services/device_data_service.dart';
import '../../services/notification_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.store,
    required this.onSignOut,
  });

  final LifeLensStore store;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final scores = store.calculateScores();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Settings',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          'Your account, privacy, devices, and app preferences',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .65),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: .42),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    store.user.name.isEmpty
                        ? 'L'
                        : store.user.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.user.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(store.user.email),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => _showEditProfileDialog(context),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _SettingsSectionLabel(label: 'Account & data'),
        const SizedBox(height: 8),
        _FinanceProfileCard(store: store),
        const SizedBox(height: 12),
        _PrivacyCard(store: store),
        const SizedBox(height: 12),
        _DataPortabilityCard(store: store),
        const SizedBox(height: 12),
        const _SettingsSectionLabel(label: 'Connected services'),
        const SizedBox(height: 8),
        _PermissionCenterCard(store: store),
        const SizedBox(height: 12),
        const _GettingStartedCard(),
        const SizedBox(height: 12),
        const _SettingsSectionLabel(label: 'App preferences'),
        const SizedBox(height: 8),
        _SyncQueueCard(store: store),
        const SizedBox(height: 12),
        const _AppearanceCard(),
        const SizedBox(height: 12),
        _DemoDataCard(store: store),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _ProfileRow(
                  label: 'Productivity',
                  value: '${scores.productivity}/100',
                ),
                _ProfileRow(
                  label: 'Financial health',
                  value: '${scores.financialHealth}/100',
                ),
                _ProfileRow(
                  label: 'Stress risk',
                  value: '${scores.stressRisk}/100',
                ),
                _ProfileRow(
                  label: 'Sleep',
                  value: '${store.health.sleepHours} hrs',
                ),
                _ProfileRow(
                  label: 'Screen time',
                  value: '${store.health.screenTimeHours} hrs',
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
                  'Project Role',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Flutter Android UI'),
                const Text('Manual lifestyle data entry'),
                const Text('Dashboard and recommendation display'),
                const Text('Backend API connection readiness'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => _confirmDeleteAllData(context),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete all account and health data'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final updatedUser = await showDialog<AppUser>(
      context: context,
      builder: (context) => _EditProfileDialog(user: store.user),
    );
    if (updatedUser == null) return;
    await store.updateUserProfile(updatedUser);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmDeleteAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This permanently deletes your local health, screen-time, expenses, tasks, and backend account data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.deleteAllData();
      onSignOut();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to delete backend data. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard();
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.tips_and_updates_outlined),
      title: const Text(
        'Getting started',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        'Permissions are requested only when you use a feature',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: const [
        Text(
          '1. Add sleep, steps, and screen-time data in Trends.\n\n2. Enable notifications only if you want reminders.\n\n3. Allow usage access only for screen-time insights.\n\n4. Connect Google Calendar only when adding a task event.',
        ),
      ],
    ),
  );
}

class _PermissionCenterCard extends StatelessWidget {
  const _PermissionCenterCard({required this.store});
  final LifeLensStore store;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device permissions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enable only the integrations you want. Journal notes remain local.',
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text('Health Connect'),
            subtitle: Text(
              store.health.source.contains('health')
                  ? 'Connected'
                  : 'Not read yet',
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _health(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_android),
            title: const Text('Usage access'),
            subtitle: Text(
              store.appUsage == null
                  ? 'Not granted or not read'
                  : 'Last usage read',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Open usage access settings',
              onPressed: DeviceDataService().openUsageAccessSettings,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Required for task and wellness reminders'),
            trailing: OutlinedButton(
              onPressed: NotificationService.requestPermission,
              child: const Text('Enable'),
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.calendar_month_outlined),
            title: Text('Google Calendar'),
            subtitle: Text(
              'Permission is requested when you add a task to Calendar',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sync),
            title: const Text('Background sync'),
            subtitle: Text(
              store.backgroundSyncScheduledAt == null
                  ? 'Not scheduled yet'
                  : 'Scheduled by Android',
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> _health(BuildContext context) async {
    try {
      await store.updateHealth(
        await DeviceDataService().readHealthConnect(fallback: store.health),
      );
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Health Connect updated.')),
        );
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health Connect needs permission or supported data.'),
          ),
        );
    }
  }
}

class _SyncQueueCard extends StatelessWidget {
  const _SyncQueueCard({required this.store});
  final LifeLensStore store;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.cloud_upload_outlined),
      title: const Text('Offline sync queue'),
      subtitle: Text(
        '${store.pendingSyncItems.length} pending change${store.pendingSyncItems.length == 1 ? '' : 's'}',
      ),
      trailing: OutlinedButton(
        onPressed: store.pendingSyncItems.isEmpty
            ? null
            : store.retryPendingSync,
        child: const Text('Retry'),
      ),
    ),
  );
}

class _DataPortabilityCard extends StatelessWidget {
  const _DataPortabilityCard({required this.store});
  final LifeLensStore store;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your data',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Exports are encrypted with your passphrase (AES-256-GCM). Keep that passphrase safe; it cannot be recovered.',
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _export(context),
                icon: const Icon(Icons.ios_share),
                label: const Text('Export'),
              ),
              OutlinedButton.icon(
                onPressed: () => _import(context),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Future<void> _export(BuildContext context) async {
    final passphrase = await _askPassphrase(context, title: 'Encrypt export');
    if (passphrase == null) return;
    try {
      await DataPortabilityService().shareExport(store, passphrase);
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<String?> _askPassphrase(
    BuildContext context, {
    required String title,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Passphrase (12+ characters)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _import(BuildContext context) async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import LifeLens JSON'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'Paste an export here'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty) return;
    final passphrase = await _askPassphrase(context, title: 'Decrypt import');
    if (passphrase == null) return;
    try {
      await DataPortabilityService().importCheckInsAndGoals(
        store,
        raw,
        passphrase,
      );
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals and check-ins imported.')),
        );
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Import failed. Check the encrypted export and passphrase.',
            ),
          ),
        );
    }
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

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
                  Icons.palette_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, mode, _) {
                return SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) {
                    themeNotifier.value = value.first;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.store});

  final LifeLensStore store;

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
                  Icons.privacy_tip_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Privacy & Data Control',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _PrivacyBullet(
              icon: Icons.receipt_long_outlined,
              text: 'Raw expenses stay on phone',
            ),
            const _PrivacyBullet(
              icon: Icons.apps,
              text: 'App names stay on phone',
            ),
            const _PrivacyBullet(
              icon: Icons.cloud_upload_outlined,
              text: 'Backend receives only daily totals',
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow backend prediction sync'),
              subtitle: const Text(
                'Only daily totals and optional budget are sent. Names, emails, expense notes, task titles, and app names stay on this phone.',
              ),
              value: store.backendSyncConsent,
              onChanged: store.saveBackendSyncConsent,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyBullet extends StatelessWidget {
  const _PrivacyBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _DemoDataCard extends StatelessWidget {
  const _DemoDataCard({required this.store});

  final LifeLensStore store;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.play_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Demo Data',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Load a clear scenario before your presentation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _loadDemo(context, highRisk: false),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Balanced'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _loadDemo(context, highRisk: true),
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('High Risk'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDemo(BuildContext context, {required bool highRisk}) async {
    await store.loadDemoData(highRisk: highRisk);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            highRisk ? 'High-risk demo loaded' : 'Balanced demo loaded',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _FinanceProfileCard extends StatelessWidget {
  const _FinanceProfileCard({required this.store});

  final LifeLensStore store;

  @override
  Widget build(BuildContext context) {
    final monthlyIncome = store.user.monthlyIncome;
    final monthlyBudget = store.user.monthlyBudget;
    final activeBudget = store.monthlySpendingBudget;
    final dailyBudget = store.dailySpendingBudget;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Finance Profile',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit finance profile',
                  onPressed: () => _showFinanceDialog(context),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ProfileRow(
              label: 'Monthly income',
              value: monthlyIncome == null
                  ? 'Not set'
                  : 'Rs ${monthlyIncome.toStringAsFixed(0)}',
            ),
            _ProfileRow(
              label: 'Monthly budget',
              value: monthlyBudget == null
                  ? 'Auto from income'
                  : 'Rs ${monthlyBudget.toStringAsFixed(0)}',
            ),
            _ProfileRow(
              label: 'Active spending budget',
              value: activeBudget <= 0
                  ? 'Not set'
                  : 'Rs ${activeBudget.toStringAsFixed(0)}',
            ),
            _ProfileRow(
              label: 'Daily budget pace',
              value: dailyBudget <= 0
                  ? 'Not set'
                  : 'Rs ${dailyBudget.toStringAsFixed(0)}',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFinanceDialog(BuildContext context) async {
    final updatedUser = await showDialog<AppUser>(
      context: context,
      builder: (context) => _EditProfileDialog(user: store.user),
    );
    if (updatedUser == null) return;
    await store.updateUserProfile(updatedUser);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finance profile updated'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.user});

  final AppUser user;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController incomeController;
  late final TextEditingController budgetController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user.name);
    incomeController = TextEditingController(
      text: widget.user.monthlyIncome?.toStringAsFixed(0) ?? '',
    );
    budgetController = TextEditingController(
      text: widget.user.monthlyBudget?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    incomeController.dispose();
    budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) return 'Enter your name';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: widget.user.email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: incomeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly income or allowance (optional)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: _optionalMoneyValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: budgetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly spending budget (optional)',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: _optionalMoneyValidator,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              widget.user.copyWith(
                name: nameController.text.trim(),
                monthlyIncome: _parseOptionalMoney(incomeController.text),
                monthlyBudget: _parseOptionalMoney(budgetController.text),
                clearMonthlyIncome: incomeController.text.trim().isEmpty,
                clearMonthlyBudget: budgetController.text.trim().isEmpty,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

String? _optionalMoneyValidator(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final parsed = double.tryParse(trimmed);
  if (parsed == null || parsed <= 0) return 'Enter a positive amount';
  return null;
}

double? _parseOptionalMoney(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return double.parse(trimmed);
}
