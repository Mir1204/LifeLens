import 'dart:async';

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
  String sortBy = 'Date';
  String query = '';
  final Set<int> _celebratingTaskIds = {};
  bool _showAllActive = false;
  bool _showAllCompleted = false;
  bool _isAddingTask = false;
  Timer? _overdueRefreshTimer;

  @override
  void initState() {
    super.initState();
    // A task changes to overdue based on the device's local date and time.
    _overdueRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    _overdueRefreshTimer?.cancel();
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

              TextField(
                onChanged: (value) =>
                    setState(() => query = value.toLowerCase()),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Search tasks',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  Expanded(
                    child: PopupMenuButton<String>(
                      onSelected: (value) => setState(() => sortBy = value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'Date',
                          child: Text('Sort by date'),
                        ),
                        PopupMenuItem(
                          value: 'Priority',
                          child: Text('Sort by priority'),
                        ),
                      ],
                      child: _TaskMenuControl(
                        icon: Icons.sort,
                        label: 'Sort: $sortBy',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _TaskListModule(
                title: 'Current & remaining tasks',
                subtitle: 'Complete what matters next',
                tasks: _displayedActiveTasks,
                totalCount: _activeTasks.length,
                showingAll: _showAllActive,
                onToggleMore: () =>
                    setState(() => _showAllActive = !_showAllActive),
                showCompletionControl: true,
                emptyLabel: query.isEmpty
                    ? 'Nothing remaining — enjoy the breathing room.'
                    : 'No remaining tasks match your search.',
                itemBuilder: _buildTaskCard,
              ),
              const SizedBox(height: 16),

              // ── Add task form ─────────────────────────────────────────────
              if (query.isEmpty)
                Card(
                  child: _isAddingTask
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.add_task, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Add task',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
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
                                const Text('Task importance'),
                                const SizedBox(height: 6),
                                Row(
                                  children: TaskPriority.values
                                      .map(
                                        (value) => Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: value == TaskPriority.high
                                                  ? 0
                                                  : 8,
                                            ),
                                            child: ChoiceChip(
                                              label: Text(
                                                value.name[0].toUpperCase() +
                                                    value.name.substring(1),
                                              ),
                                              selected: priority == value,
                                              onSelected: (_) => setState(
                                                () => priority = value,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _pickTaskDate,
                                        icon: const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 18,
                                        ),
                                        label: Text(_formatDate(taskDate)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _pickTaskTime,
                                        icon: const Icon(
                                          Icons.schedule,
                                          size: 18,
                                        ),
                                        label: Text(taskTime.format(context)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text('Task reminder'),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int?>(
                                  initialValue: reminderMinutes,
                                  isExpanded: true,
                                  isDense: true,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(
                                      Icons.notifications_outlined,
                                    ),
                                    hintText: 'Choose a reminder',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
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
                                  onChanged: (value) => setState(
                                    () => addToGoogleCalendar = value,
                                  ),
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
                        )
                      : ListTile(
                          leading: const Icon(Icons.add_task),
                          title: const Text('Add task'),
                          subtitle: const Text(
                            'Create a task, schedule, and reminder',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => setState(() => _isAddingTask = true),
                        ),
                ),
              const SizedBox(height: 16),
              _TaskListModule(
                title: 'Completed tasks',
                subtitle: 'Your completed work stays here',
                tasks: _completedTasks,
                totalCount: _completedTasks.length,
                showingAll: _showAllCompleted,
                onToggleMore: () =>
                    setState(() => _showAllCompleted = !_showAllCompleted),
                showCompletionControl: false,
                allowSeeMore: false,
                emptyLabel: query.isEmpty
                    ? 'Completed tasks will appear here.'
                    : 'No completed tasks match your search.',
                itemBuilder: _buildTaskCard,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PlannerEntry> get _activeTasks => _tasksFor(completed: false);

  List<PlannerEntry> get _completedTasks => _tasksFor(completed: true);

  List<PlannerEntry> get _displayedActiveTasks =>
      query.isNotEmpty || _showAllActive
      ? _activeTasks
      : _activeTasks.take(4).toList();

  List<PlannerEntry> _tasksFor({required bool completed}) {
    final items = widget.store.tasks
        .where(
          (task) =>
              task.isCompleted == completed &&
              (query.isEmpty ||
                  task.title.toLowerCase().contains(query) ||
                  task.note.toLowerCase().contains(query)),
        )
        .toList();
    items.sort(
      (a, b) => sortBy == 'Priority'
          ? b.priority.index.compareTo(a.priority.index)
          : a.date.compareTo(b.date),
    );
    return items;
  }

  Widget _buildTaskCard(PlannerEntry task) {
    return Dismissible(
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
      child: Builder(
        builder: (context) {
          final isCompleting = _celebratingTaskIds.contains(task.id);
          final showCompleted = task.isCompleted || isCompleting;
          final isOverdue = _isTaskOverdue(task);
          final scheme = Theme.of(context).colorScheme;
          return AnimatedOpacity(
            opacity: isCompleting ? .4 : 1,
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeIn,
            child: AnimatedScale(
              scale: isCompleting ? 0.98 : 1,
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeInOut,
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isOverdue
                    ? scheme.errorContainer.withValues(alpha: .38)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isOverdue
                      ? BorderSide(color: scheme.error.withValues(alpha: .65))
                      : BorderSide.none,
                ),
                child: ListTile(
                  onTap: () => task.isCompleted
                      ? _showCompletedTaskActions(task)
                      : _editTask(task),
                  leading: task.isCompleted
                      ? null
                      : GestureDetector(
                          onTap: isCompleting ? null : () => _toggleTask(task),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: showCompleted
                                  ? const Color(0xFF287D5A)
                                  : Colors.transparent,
                              border: Border.all(
                                color: showCompleted
                                    ? const Color(0xFF287D5A)
                                    : Theme.of(context).colorScheme.outline,
                                width: 2,
                              ),
                            ),
                            child: showCompleted
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
                          : isOverdue
                          ? scheme.error
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    '${isOverdue ? 'Overdue • ' : ''}${_formatDate(task.date)} • ${_formatTaskTime(task.timeMinutes)}${task.note.isEmpty ? '' : ' • ${task.note}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _PriorityChip(priority: task.priority),
                      if (isOverdue) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Overdue',
                          style: TextStyle(
                            color: scheme.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isTaskOverdue(PlannerEntry task) {
    if (task.isCompleted) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(task.date.year, task.date.month, task.date.day);

    if (taskDay.isBefore(today)) return true;
    if (taskDay.isAfter(today)) return false;

    final currentMinutes = now.hour * 60 + now.minute;
    return task.timeMinutes < currentMinutes;
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
    setState(() => _isAddingTask = false);
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

  Future<void> _toggleTask(PlannerEntry task) async {
    final id = task.id;
    if (task.isCompleted || id == null) {
      await widget.store.toggleTask(task);
      return;
    }
    setState(() => _celebratingTaskIds.add(id));
    await Future<void>.delayed(const Duration(milliseconds: 750));
    await widget.store.toggleTask(task);
    if (mounted) setState(() => _celebratingTaskIds.remove(id));
  }

  Future<void> _showCompletedTaskActions(PlannerEntry task) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text('This task is marked as completed.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await widget.store.toggleTask(task);
                  },
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo completion'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final value = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (value != null) setDialogState(() => date = value);
                        },
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 17,
                        ),
                        label: Text(_formatDate(date)),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final value = await showTimePicker(
                            context: context,
                            initialTime: time,
                          );
                          if (value != null) setDialogState(() => time = value);
                        },
                        icon: const Icon(Icons.schedule, size: 17),
                        label: Text(time.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Task reminder'),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int?>(
                  initialValue: selectedReminder,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.notifications_outlined),
                    hintText: 'Choose a reminder',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
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

class _TaskListModule extends StatelessWidget {
  const _TaskListModule({
    required this.title,
    required this.subtitle,
    required this.tasks,
    required this.totalCount,
    required this.showingAll,
    required this.onToggleMore,
    required this.showCompletionControl,
    this.allowSeeMore = true,
    required this.emptyLabel,
    required this.itemBuilder,
  });

  final String title;
  final String subtitle;
  final List<PlannerEntry> tasks;
  final int totalCount;
  final bool showingAll;
  final VoidCallback onToggleMore;
  final bool showCompletionControl;
  final bool allowSeeMore;
  final String emptyLabel;
  final Widget Function(PlannerEntry task) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else ...[
          Text(
            showCompletionControl
                ? 'Tap a circle to complete • Swipe left to delete'
                : 'Swipe left to delete',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .55),
            ),
          ),
          const SizedBox(height: 6),
          for (final task in tasks) itemBuilder(task),
          if (allowSeeMore && totalCount > 4 && tasks.length < totalCount)
            Center(
              child: TextButton(
                onPressed: onToggleMore,
                child: Text(
                  showingAll
                      ? 'Show less'
                      : 'See more (${totalCount - tasks.length})',
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _TaskMenuControl extends StatelessWidget {
  const _TaskMenuControl({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
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
