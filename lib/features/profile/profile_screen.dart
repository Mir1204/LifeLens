import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/lifelens_store.dart';

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
    final scores = store.calculateScores();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Profile',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Card(
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
                      Text(store.user.userId),
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
        _FinanceProfileCard(store: store),
        const SizedBox(height: 12),
        _BackendSettings(store: store),
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

class _BackendSettings extends StatefulWidget {
  const _BackendSettings({required this.store});

  final LifeLensStore store;

  @override
  State<_BackendSettings> createState() => _BackendSettingsState();
}

class _BackendSettingsState extends State<_BackendSettings> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.store.backendUrl);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Backend Settings',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        widget.store.saveBackendUrl(controller.text),
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.store.isTestingBackend
                        ? null
                        : widget.store.testBackendConnection,
                    icon: widget.store.isTestingBackend
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Test'),
                  ),
                ),
              ],
            ),
            if (widget.store.backendStatus != null) ...[
              const SizedBox(height: 10),
              Text(widget.store.backendStatus!),
            ],
          ],
        ),
      ),
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
