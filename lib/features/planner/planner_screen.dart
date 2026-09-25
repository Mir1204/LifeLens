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
  final noteController = TextEditingController();
  TaskPriority priority = TaskPriority.medium;
  DateTime taskDate = DateTime.now();
  TimeOfDay taskTime = const TimeOfDay(hour: 9, minute: 0);
  bool addToGoogleCalendar = false;
  int? reminderMinutes = 15;
  String taskFilter = 'Today';
  String sortBy = 'Date';
  String query = '';

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
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
    return Column(
      children: [
        _PlannerOfflineBanner(isOnline: widget.store.isOnline),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Tasks',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => query = value.toLowerCase()),
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Search tasks',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<String>(
                    tooltip: 'Show tasks',
                    icon: const Icon(Icons.filter_list),
                    onSelected: (value) => setState(() => taskFilter = value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'Today', child: Text('Today')),
                      PopupMenuItem(value: 'Upcoming', child: Text('Upcoming')),
                      PopupMenuItem(
                        value: 'Completed',
                        child: Text('Completed'),
                      ),
                      PopupMenuItem(value: 'All', child: Text('All tasks')),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Sort tasks',
                    icon: const Icon(Icons.sort),
                    onSelected: (value) => setState(() => sortBy = value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'Date', child: Text('Sort by date')),
                      PopupMenuItem(
                        value: 'Priority',
                        child: Text('Sort by priority'),
                      ),
                    ],
                  ),
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
                        const SizedBox(height: 10),
                        TextField(
                          controller: noteController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            prefixIcon: Icon(Icons.notes_outlined),
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
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickTaskDate,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text('Due ${_formatDate(taskDate)}'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickTaskTime,
                          icon: const Icon(Icons.schedule),
                          label: Text('Time ${taskTime.format(context)}'),
                        ),
                        DropdownButtonFormField<int?>(
                          initialValue: reminderMinutes,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Task reminder',
                            prefixIcon: Icon(Icons.notifications_outlined),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('No reminder'),
                            ),
                            DropdownMenuItem(
                              value: 10,
                              child: Text('10 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: 15,
                              child: Text('15 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text('30 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: 60,
                              child: Text('1 hour before'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => reminderMinutes = value),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: addToGoogleCalendar,
                          onChanged: (value) =>
                              setState(() => addToGoogleCalendar = value),
                          title: const Text('Add to Google Calendar'),
                          subtitle: const Text(
                            'Creates a one-hour event at the selected time',
                          ),
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
              if (_visibleTasks.isEmpty)
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
                for (final task in _visibleTasks)
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
                        onTap: () => _editTask(task),
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
                        subtitle: Text(
                          '${_formatTaskTime(task.timeMinutes)}${task.note.isEmpty ? '' : ' • ${task.note}'}',
                        ),
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

  List<PlannerEntry> get _visibleTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = widget.store.tasks.where((task) {
      final day = DateTime(task.date.year, task.date.month, task.date.day);
      final filterOk = switch (taskFilter) {
        'Today' => day == today && !task.isCompleted,
        'Upcoming' => day.isAfter(today) && !task.isCompleted,
        'Completed' => task.isCompleted,
        _ => true,
      };
      return filterOk &&
          (query.isEmpty ||
              task.title.toLowerCase().contains(query) ||
              task.note.toLowerCase().contains(query));
    }).toList();
    items.sort(
      (a, b) => sortBy == 'Priority'
          ? b.priority.index.compareTo(a.priority.index)
          : a.date.compareTo(b.date),
    );
    return items;
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    final title = titleController.text.trim();
    try {
      await widget.store.addTask(
        PlannerEntry(
          title: title,
          date: taskDate,
          priority: priority,
          workload: _workloadForPriority(priority),
          timeMinutes: taskTime.hour * 60 + taskTime.minute,
          note: noteController.text.trim(),
          reminderMinutes: reminderMinutes,
        ),
        addToGoogleCalendar: addToGoogleCalendar,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task saved, but calendar event was not added: $error',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    titleController.clear();
    noteController.clear();
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

  Future<void> _pickTaskDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: taskDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => taskDate = selected);
  }

  Future<void> _pickTaskTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: taskTime,
    );
    if (selected != null) setState(() => taskTime = selected);
  }

  String _formatTaskTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  Future<void> _editTask(PlannerEntry task) async {
    final controller = TextEditingController(text: task.title);
    final notesController = TextEditingController(text: task.note);
    var date = task.date;
    var time = TimeOfDay(
      hour: task.timeMinutes ~/ 60,
      minute: task.timeMinutes % 60,
    );
    var selectedPriority = task.priority;
    int? selectedReminder = task.reminderMinutes;
    final updated = await showDialog<PlannerEntry>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Task'),
                ),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                DropdownButton<TaskPriority>(
                  value: selectedPriority,
                  isExpanded: true,
                  items: TaskPriority.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedPriority = value!),
                ),
                TextButton(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (value != null) setDialogState(() => date = value);
                  },
                  child: Text(_formatDate(date)),
                ),
                TextButton(
                  onPressed: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (value != null) setDialogState(() => time = value);
                  },
                  child: Text(time.format(context)),
                ),
                DropdownButtonFormField<int?>(
                  initialValue: selectedReminder,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Task reminder',
                    prefixIcon: Icon(Icons.notifications_outlined),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No reminder'),
                    ),
                    DropdownMenuItem(
                      value: 10,
                      child: Text('10 minutes before'),
                    ),
                    DropdownMenuItem(
                      value: 15,
                      child: Text('15 minutes before'),
                    ),
                    DropdownMenuItem(
                      value: 30,
                      child: Text('30 minutes before'),
                    ),
                    DropdownMenuItem(value: 60, child: Text('1 hour before')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedReminder = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                task.copyWith(
                  title: controller.text.trim(),
                  date: date,
                  priority: selectedPriority,
                  workload: _workloadForPriority(selectedPriority),
                  timeMinutes: time.hour * 60 + time.minute,
                  note: notesController.text.trim(),
                  reminderMinutes: selectedReminder,
                  clearReminder: selectedReminder == null,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    notesController.dispose();
    if (updated != null && updated.title.isNotEmpty)
      await widget.store.updateTask(updated);
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  int _workloadForPriority(TaskPriority value) => switch (value) {
    TaskPriority.low => 1,
    TaskPriority.medium => 3,
    TaskPriority.high => 5,
  };

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
