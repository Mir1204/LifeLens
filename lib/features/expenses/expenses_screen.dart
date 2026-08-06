import 'package:flutter/material.dart';

import '../../models/lifestyle_entry.dart';
import '../../services/lifelens_store.dart';
import '../../widgets/trend_chart_card.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.store});

  final LifeLensStore store;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  String category = 'Food';
  String recurringLabel = 'None';

  static const _categories = ['Food', 'Travel', 'Study', 'Shopping', 'Other'];
  static const _recurringLabelsByCategory = {
    'Food': ['None', 'Groceries', 'Mess', 'Coffee', 'Snacks'],
    'Travel': ['None', 'Travel pass', 'Fuel', 'Cab', 'Bus/Metro'],
    'Study': ['None', 'Tuition', 'Books', 'Course', 'Exam fee'],
    'Shopping': ['None', 'Clothes', 'Accessories', 'Electronics'],
    'Other': ['None', 'Rent', 'Subscription', 'Bills', 'Medicine', 'EMI'],
  };

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Expenses',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _ExpenseSummary(
          todayTotal: widget.store.todaySpending,
          overallTotal: _overallTotal(),
          topCategory: _topCategory(),
          weekComparison: _weekComparisonText(),
        ),
        const SizedBox(height: 12),
        _BudgetStatusCard(store: widget.store),
        const SizedBox(height: 12),
        _CategoryInsightCard(message: _categoryInsight()),
        const SizedBox(height: 12),
        _ExpenseForm(
          formKey: _formKey,
          amountController: amountController,
          noteController: noteController,
          category: category,
          recurringLabel: recurringLabel,
          categories: _categories,
          recurringLabels: _recurringLabelsFor(category),
          onCategoryChanged: (value) {
            setState(() {
              category = value;
              recurringLabel = 'None';
            });
          },
          onRecurringChanged: (value) => setState(() => recurringLabel = value),
          onSave: _saveExpense,
        ),
        const SizedBox(height: 12),
        CategoryPieCard(title: 'Category Breakdown', values: _categoryTotals()),
        const SizedBox(height: 12),
        TrendChartCard(
          title: 'Last 7 Days',
          points: _dailySpendingTrend(),
          color: Theme.of(context).colorScheme.primary,
          suffix: ' Rs',
        ),
        const SizedBox(height: 12),
        if (widget.store.expenses.isEmpty)
          const _EmptyExpenses()
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Tap to edit. Swipe left to delete.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .5),
              ),
            ),
          ),
          for (final expense in widget.store.expenses)
            Dismissible(
              key: ValueKey(expense.id ?? expense.hashCode),
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
              onDismissed: (_) => _deleteExpense(expense),
              child: Card(
                child: ListTile(
                  onTap: () => _showEditExpenseDialog(expense),
                  leading: _categoryIcon(expense.category),
                  title: Text(expense.category),
                  subtitle: Text(_expenseSubtitle(expense)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rs ${expense.amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 18),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Map<String, double> _categoryTotals({bool todayOnly = false}) {
    final totals = <String, double>{};
    final now = DateTime.now();
    for (final expense in widget.store.expenses) {
      if (todayOnly && !_isSameDay(expense.date, now)) continue;
      totals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return totals;
  }

  double _overallTotal() {
    return widget.store.expenses.fold(
      0.0,
      (total, expense) => total + expense.amount,
    );
  }

  String _topCategory() {
    final totals = _categoryTotals();
    if (totals.isEmpty) return 'None';
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  String _weekComparisonText() {
    final thisWeek = _spendingBetween(0, 6);
    final lastWeek = _spendingBetween(7, 13);
    if (lastWeek == 0 && thisWeek == 0) return 'No weekly data';
    if (lastWeek == 0) return 'New this week';
    final change = ((thisWeek - lastWeek) / lastWeek * 100).round();
    if (change == 0) return 'Same as last week';
    return change > 0 ? '+$change% vs last week' : '$change% vs last week';
  }

  double _spendingBetween(int startOffset, int endOffset) {
    final now = DateTime.now();
    return widget.store.expenses
        .where((expense) {
          final age = _dayOnly(now).difference(_dayOnly(expense.date)).inDays;
          return age >= startOffset && age <= endOffset;
        })
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  String _categoryInsight() {
    final todayTotal = widget.store.todaySpending;
    if (todayTotal <= 0) return 'Add today expenses to see spending mix.';
    final totals = _categoryTotals(todayOnly: true);
    if (totals.isEmpty) return 'Add today expenses to see spending mix.';
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.first;
    final percentage = (top.value / todayTotal * 100).round();
    return '${top.key} is $percentage% of today spending.';
  }

  List<TrendPoint> _dailySpendingTrend() {
    final now = DateTime.now();
    return [
      for (var offset = 6; offset >= 0; offset--)
        _dailyPoint(now.subtract(Duration(days: offset))),
    ];
  }

  TrendPoint _dailyPoint(DateTime day) {
    final total = widget.store.expenses
        .where((expense) => _isSameDay(expense.date, day))
        .fold(0.0, (sum, expense) => sum + expense.amount);
    return TrendPoint(label: '${day.day}/${day.month}', value: total);
  }

  String _expenseSubtitle(ExpenseEntry expense) {
    final parts = [
      _formatDate(expense.date),
      if (expense.recurringLabel != null) expense.recurringLabel!,
      if (expense.note.isNotEmpty) expense.note,
    ];
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(amountController.text.trim());
    await widget.store.addExpense(
      ExpenseEntry(
        amount: amount,
        category: category,
        date: DateTime.now(),
        note: noteController.text.trim(),
        recurringLabel: _normalizeRecurringLabel(recurringLabel),
      ),
    );
    amountController.clear();
    noteController.clear();
    setState(() => recurringLabel = 'None');
    FocusScope.of(context).unfocus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added Rs ${amount.toStringAsFixed(0)} · $category'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showEditExpenseDialog(ExpenseEntry expense) async {
    final result = await showDialog<ExpenseEntry>(
      context: context,
      builder: (context) => _EditExpenseDialog(
        expense: expense,
        categories: _categories,
        recurringLabelsByCategory: _recurringLabelsByCategory,
      ),
    );
    if (result == null) return;
    await widget.store.updateExpense(result);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense updated'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteExpense(ExpenseEntry expense) async {
    await widget.store.deleteExpense(expense);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Removed Rs ${expense.amount.toStringAsFixed(0)} · ${expense.category}',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String? _normalizeRecurringLabel(String value) {
    return value == 'None' ? null : value;
  }

  List<String> _recurringLabelsFor(String category) {
    return _recurringLabelsByCategory[category] ?? const ['None'];
  }

  Widget _categoryIcon(String cat) {
    final iconData = switch (cat) {
      'Food' => Icons.fastfood,
      'Travel' => Icons.directions_car,
      'Study' => Icons.school,
      'Shopping' => Icons.shopping_bag,
      _ => Icons.receipt_long,
    };
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        iconData,
        color: Theme.of(context).colorScheme.primary,
        size: 20,
      ),
    );
  }
}

class _ExpenseForm extends StatelessWidget {
  const _ExpenseForm({
    required this.formKey,
    required this.amountController,
    required this.noteController,
    required this.category,
    required this.recurringLabel,
    required this.categories,
    required this.recurringLabels,
    required this.onCategoryChanged,
    required this.onRecurringChanged,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final String category;
  final String recurringLabel;
  final List<String> categories;
  final List<String> recurringLabels;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onRecurringChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (Rs)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: _amountValidator,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  for (final item in categories)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) => onCategoryChanged(value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: recurringLabel,
                decoration: const InputDecoration(
                  labelText: 'Recurring label',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: [
                  for (final item in recurringLabels)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) => onRecurringChanged(value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditExpenseDialog extends StatefulWidget {
  const _EditExpenseDialog({
    required this.expense,
    required this.categories,
    required this.recurringLabelsByCategory,
  });

  final ExpenseEntry expense;
  final List<String> categories;
  final Map<String, List<String>> recurringLabelsByCategory;

  @override
  State<_EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<_EditExpenseDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController amountController;
  late final TextEditingController noteController;
  late String category;
  late String recurringLabel;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(
      text: widget.expense.amount.toStringAsFixed(0),
    );
    noteController = TextEditingController(text: widget.expense.note);
    category = widget.expense.category;
    final labels = _recurringLabelsFor(category);
    recurringLabel = labels.contains(widget.expense.recurringLabel)
        ? widget.expense.recurringLabel!
        : 'None';
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Expense'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (Rs)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: _amountValidator,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  for (final item in widget.categories)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  setState(() {
                    category = value!;
                    recurringLabel = 'None';
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: recurringLabel,
                decoration: const InputDecoration(
                  labelText: 'Recurring label',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: [
                  for (final item in _recurringLabelsFor(category))
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) => setState(() => recurringLabel = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
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
              widget.expense.copyWith(
                amount: double.parse(amountController.text.trim()),
                category: category,
                note: noteController.text.trim(),
                recurringLabel: recurringLabel == 'None'
                    ? null
                    : recurringLabel,
                clearRecurringLabel: recurringLabel == 'None',
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  List<String> _recurringLabelsFor(String category) {
    return widget.recurringLabelsByCategory[category] ?? const ['None'];
  }
}

String? _amountValidator(String? value) {
  final parsed = double.tryParse(value?.trim() ?? '');
  if (parsed == null || parsed <= 0) {
    return 'Enter a valid amount greater than 0';
  }
  return null;
}

class _BudgetStatusCard extends StatelessWidget {
  const _BudgetStatusCard({required this.store});

  final LifeLensStore store;

  @override
  Widget build(BuildContext context) {
    final dailyBudget = store.dailySpendingBudget;
    if (dailyBudget <= 0) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.account_balance_wallet_outlined),
          title: Text('Budget not set'),
          subtitle: Text('Add monthly income or budget in Profile.'),
        ),
      );
    }
    final progress = (store.todaySpending / dailyBudget).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Daily Budget Pace',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Rs ${store.todaySpending.toStringAsFixed(0)} / ${dailyBudget.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class _CategoryInsightCard extends StatelessWidget {
  const _CategoryInsightCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.pie_chart_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Category Insight'),
        subtitle: Text(message),
      ),
    );
  }
}

class _ExpenseSummary extends StatelessWidget {
  const _ExpenseSummary({
    required this.todayTotal,
    required this.overallTotal,
    required this.topCategory,
    required this.weekComparison,
  });

  final double todayTotal;
  final double overallTotal;
  final String topCategory;
  final String weekComparison;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.today,
            label: 'Today',
            value: 'Rs ${todayTotal.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            icon: Icons.compare_arrows,
            label: 'Week',
            value: weekComparison,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            icon: Icons.trending_up,
            label: 'Top',
            value: topCategory,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: .55),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .3),
            ),
            const SizedBox(height: 12),
            Text(
              'No expenses yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Add your first expense above',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
