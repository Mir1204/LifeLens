import 'package:flutter/material.dart';

import '../../models/lifestyle_entry.dart';
import '../../services/lifelens_store.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.store});

  final LifeLensStore store;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  String category = 'Food';

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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const ['Food', 'Travel', 'Study', 'Shopping', 'Other']
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
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note',
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
        const SizedBox(height: 12),
        for (final expense in widget.store.expenses)
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(expense.category),
              subtitle: Text(expense.note.isEmpty ? 'No note' : expense.note),
              trailing: Text(
                'Rs ${expense.amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  void _saveExpense() {
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;
    widget.store.addExpense(
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
  }
}
