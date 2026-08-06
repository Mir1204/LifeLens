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

  static const _categories = ['Food', 'Travel', 'Study', 'Shopping', 'Other'];

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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),

        // ── Add expense form ──────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a valid amount greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _categories
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => category = value!),
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
                      onPressed: _saveExpense,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Category breakdown chart ──────────────────────────────────
        CategoryPieCard(
          title: 'Category Breakdown',
          values: _categoryTotals(),
        ),
        const SizedBox(height: 12),

        // ── Expense list ─────────────────────────────────────────────
        if (widget.store.expenses.isEmpty)
          const _EmptyExpenses()
        else ...[  
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Swipe left to delete',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .5),
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
                  leading: _categoryIcon(expense.category),
                  title: Text(expense.category),
                  subtitle: Text(
                    expense.note.isEmpty ? 'No note' : expense.note,
                  ),
                  trailing: Text(
                    '₹ ${expense.amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Map<String, double> _categoryTotals() {
    final totals = <String, double>{};
    for (final expense in widget.store.expenses) {
      totals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return totals;
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
      ),
    );
    amountController.clear();
    noteController.clear();
    FocusScope.of(context).unfocus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ₹${amount.toStringAsFixed(0)} · $category'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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
            'Removed ₹${expense.amount.toStringAsFixed(0)} · ${expense.category}',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
      child: Icon(iconData,
          color: Theme.of(context).colorScheme.primary, size: 20),
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: .3),
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
