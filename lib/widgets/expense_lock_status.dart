import 'package:flutter/material.dart';
import '../models/expense.dart';

class ExpenseLockStatus extends StatelessWidget {
  final Expense expense;
  final bool showTooltip;

  const ExpenseLockStatus({
    Key? key,
    required this.expense,
    this.showTooltip = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!expense.isLocked) {
      return const SizedBox.shrink();
    }

    final lockWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock,
            size: 16,
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            'Đã khóa',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (!showTooltip) {
      return lockWidget;
    }

    return Tooltip(
      message: expense.lockedStatusText,
      child: lockWidget,
    );
  }
}

class ExpenseActionButtons extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExpenseActionButtons({
    Key? key,
    required this.expense,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit button
        IconButton(
          onPressed: expense.canEdit ? onEdit : null,
          icon: Icon(
            Icons.edit,
            color: expense.canEdit ? Colors.blue : Colors.grey,
          ),
          tooltip: expense.canEdit ? 'Chỉnh sửa' : 'Không thể chỉnh sửa (đã khóa)',
        ),
        // Delete button
        IconButton(
          onPressed: expense.canDelete ? onDelete : null,
          icon: Icon(
            Icons.delete,
            color: expense.canDelete ? Colors.red : Colors.grey,
          ),
          tooltip: expense.canDelete ? 'Xóa' : 'Không thể xóa (đã khóa)',
        ),
      ],
    );
  }
}

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExpenseCard({
    Key? key,
    required this.expense,
    this.onTap,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: expense.isLocked 
                ? Border.all(color: Colors.red.shade200, width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with title and lock status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expense.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (expense.isLocked)
                    ExpenseLockStatus(expense: expense),
                ],
              ),
              const SizedBox(height: 8),
              
              // Amount and date
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expense.formattedConvertedAmount,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  Text(
                    expense.formattedDate,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              
              // Payer and category
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Người trả: ${expense.payerName}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    expense.categoryName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              
              // Action buttons (if provided)
              if (onEdit != null || onDelete != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ExpenseActionButtons(
                      expense: expense,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
