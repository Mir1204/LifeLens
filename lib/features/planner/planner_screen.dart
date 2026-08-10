import 'package:flutter/material.dart';

import '../../models/lifestyle_entry.dart';
import '../../services/lifelens_store.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.store});

  final LifeLensStore store;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  TaskPriority priority = TaskPriority.medium;
  double workload = 2;

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  static const _workloadLabels = [
    'Light',
    'Moderate',
    'Heavy',
    'Intense',
    'Extreme',
  ];

  String get _workloadLabel => _workloadLabels[(workload.round() - 1).clamp(0, 4)];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        _PlannerOfflineBanner(isOnline: widget.store.isOnline),
        Expanded(
          child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Tasks',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            _PlannerConnectivityBadge(isOnline: widget.store.isOnline),
          ],
        ),
        const SizedBox(height: 12),

        // ── Add task form ─────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: titleController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Task or event',
                      hintText: 'Example: Study ML chapter',
                      prefixIcon: Icon(Icons.task_alt),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a task name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<TaskPriority>(
                    segments: const [
                      ButtonSegment(
                        value: TaskPriority.low,
                        label: Text('Low'),
                        icon: Icon(Icons.keyboard_arrow_down),
                      ),
                      ButtonSegment(
                        value: TaskPriority.medium,
                        label: Text('Medium'),
                        icon: Icon(Icons.remove),
                      ),
                      ButtonSegment(
                        value: TaskPriority.high,
                        label: Text('High'),
                        icon: Icon(Icons.priority_high),
                      ),
                    ],
                    selected: {priority},
                    onSelectionChanged: (value) {
                      setState(() => priority = value.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Workload: '),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF256D85).withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF256D85).withValues(alpha: .3),
                          ),
                        ),
                        child: Text(
                          _workloadLabel,
                          style: const TextStyle(
                            color: Color(0xFF256D85),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: workload,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _workloadLabel,
                    onChanged: (value) => setState(() => workload = value),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveTask,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Task'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Task list ─────────────────────────────────────────────────
        if (widget.store.tasks.isEmpty)
          const _EmptyTasks()
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Tap circle to complete • Swipe left to delete',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .5),
              ),
            ),
          ),
          for (final task in widget.store.tasks)
            Dismissible(
              key: ValueKey(task.id ?? task.hashCode),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => _deleteTask(task),
              child: Card(
                child: ListTile(
                  leading: GestureDetector(
                    onTap: () => widget.store.toggleTask(task),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.isCompleted
                            ? const Color(0xFF287D5A)
                            : Colors.transparent,
                        border: Border.all(
                          color: task.isCompleted
                              ? const Color(0xFF287D5A)
                              : Theme.of(context).colorScheme.outline,
                          width: 2,
                        ),
                      ),
                      width: 28,
                      height: 28,
                      child: task.isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted
                          ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: .4)
                          : null,
                    ),
                  ),
                  subtitle: Text('Workload ${task.workload}/5'),
                  trailing: _PriorityChip(priority: task.priority),
                ),
              ),
            ),
        ],
      ],
    ),
        ),
      ],
    );
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    final title = titleController.text.trim();
    await widget.store.addTask(
      PlannerEntry(
        title: title,
        date: DateTime.now(),
        priority: priority,
        workload: workload.round(),
      ),
    );
    titleController.clear();
    FocusScope.of(context).unfocus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added task: $title'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteTask(PlannerEntry task) async {
    await widget.store.deleteTask(task);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed: ${task.title}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      TaskPriority.low => ('Low', const Color(0xFF287D5A)),
      TaskPriority.medium => ('Medium', const Color(0xFFB88746)),
      TaskPriority.high => ('High', const Color(0xFFC8553D)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .3),
            ),
            const SizedBox(height: 12),
            Text(
              'No tasks yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Add tasks to estimate workload and burnout risk.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Planner Connectivity Badge ─────────────────────────────────────────────────

class _PlannerConnectivityBadge extends StatelessWidget {
  const _PlannerConnectivityBadge({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? const Color(0xFF287D5A) : const Color(0xFFC8553D);
    final label = isOnline ? 'Online' : 'Offline';
    final icon = isOnline ? Icons.wifi : Icons.wifi_off;

    return Tooltip(
      message: isOnline
          ? 'Connected – syncing with backend'
          : 'Working offline – data will sync when connection returns',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Planner Offline Banner ────────────────────────────────────────────────────

class _PlannerOfflineBanner extends StatefulWidget {
  const _PlannerOfflineBanner({required this.isOnline});

  final bool isOnline;

  @override
  State<_PlannerOfflineBanner> createState() => _PlannerOfflineBannerState();
}

class _PlannerOfflineBannerState extends State<_PlannerOfflineBanner>
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
  void didUpdateWidget(_PlannerOfflineBanner old) {
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
        alignment: Alignment.centerLeft,
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
                    'Working offline — tasks saved locally, will sync on reconnect',
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
