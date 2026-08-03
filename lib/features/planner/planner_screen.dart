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
  final titleController = TextEditingController();
  TaskPriority priority = TaskPriority.medium;
  double workload = 2;

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Planner',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task or event',
                    prefixIcon: Icon(Icons.task_alt),
                  ),
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
                Text('Workload: ${workload.round()} / 5'),
                Slider(
                  value: workload,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: workload.round().toString(),
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
        const SizedBox(height: 12),
        for (final task in widget.store.tasks)
          Card(
            child: ListTile(
              leading: Icon(_priorityIcon(task.priority)),
              title: Text(task.title),
              subtitle: Text('Workload ${task.workload}/5'),
              trailing: Text(_priorityLabel(task.priority)),
            ),
          ),
      ],
    );
  }

  void _saveTask() {
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    widget.store.addTask(
      PlannerEntry(
        title: title,
        date: DateTime.now(),
        priority: priority,
        workload: workload.round(),
      ),
    );
    titleController.clear();
    FocusScope.of(context).unfocus();
  }

  IconData _priorityIcon(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => Icons.keyboard_arrow_down,
      TaskPriority.medium => Icons.remove,
      TaskPriority.high => Icons.priority_high,
    };
  }

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
    };
  }
}
