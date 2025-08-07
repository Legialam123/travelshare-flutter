import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class CurrencyConversionDisplay extends StatelessWidget {
  final Expense expense;
  final String groupDefaultCurrency;
  final bool showDetails;
  final bool showCompact;

  const CurrencyConversionDisplay({
    super.key,
    required this.expense,
    required this.groupDefaultCurrency,
    this.showDetails = false,
    this.showCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasConversion = expense.isMultiCurrency;
    
    if (!hasConversion) {
      // Không có chuyển đổi - hiển thị theo group default currency
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          showCompact 
              ? expense.formatAmountCompactWithGroupCurrency(groupDefaultCurrency)
              : expense.formatAmountWithGroupCurrency(groupDefaultCurrency),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: showCompact ? 14 : 18,
            color: Colors.green[700],
          ),
        ),
      );
    }

    if (showCompact) {
      // Hiển thị compact cho list view
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              expense.formatAmountCompactWithGroupCurrency(groupDefaultCurrency),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Gốc: ${expense.formattedOriginalAmount}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    if (showDetails) {
      // Hiển thị chi tiết đầy đủ
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 16,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 4),
                Text(
                  'Chuyển đổi tiền tệ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Original amount
            _buildAmountRow(
              'Số tiền gốc:',
              expense.formattedOriginalAmount,
              isOriginal: true,
            ),
            
            const SizedBox(height: 4),
            
            // Converted amount  
            _buildAmountRow(
              'Số tiền quy đổi:',
              expense.formatAmountWithGroupCurrency(groupDefaultCurrency),
              isOriginal: false,
            ),
            
            const SizedBox(height: 4),
            
            // Exchange rate
            if (expense.exchangeRate != null)
              Text(
                'Tỷ giá: 1 ${expense.currency.code} = ${NumberFormat('#,##0.######').format(expense.exchangeRate)} $groupDefaultCurrency',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      );
    }

    // Default: hiển thị cả hai amount
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            expense.formatAmountWithGroupCurrency(groupDefaultCurrency),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.green[700],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gốc: ${expense.formattedOriginalAmount}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(String label, String amount, {required bool isOriginal}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isOriginal ? FontWeight.normal : FontWeight.bold,
            color: isOriginal ? Colors.grey[700] : Colors.green[700],
          ),
        ),
      ],
    );
  }
} 