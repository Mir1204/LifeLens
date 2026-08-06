import 'package:flutter/material.dart';

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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
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
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(store.user.email),
                      Text(store.user.userId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
                _ProfileRow(label: 'Productivity', value: '${scores.productivity}/100'),
                _ProfileRow(
                  label: 'Financial health',
                  value: '${scores.financialHealth}/100',
                ),
                _ProfileRow(label: 'Stress risk', value: '${scores.stressRisk}/100'),
                _ProfileRow(label: 'Sleep', value: '${store.health.sleepHours} hrs'),
                _ProfileRow(label: 'Screen time', value: '${store.health.screenTimeHours} hrs'),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
                    onPressed: () => widget.store.saveBackendUrl(
                      controller.text,
                    ),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
