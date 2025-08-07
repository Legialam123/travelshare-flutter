import 'package:intl/intl.dart';
import 'currency.dart';
import 'category.dart';
import 'group.dart'; // for GroupParticipant
import '../utils/currency_formatter.dart';

class Expense {
  final int id;
  final String title;
  final String? description;
  
  // Multi-currency fields (matching backend)
  final double originalAmount;       // Amount user actually spent
  final Currency originalCurrency;   // Currency user actually used
  final double convertedAmount;      // Amount in group default currency
  final Currency convertedCurrency;  // Group default currency
  final double? exchangeRate;        // Exchange rate used for conversion
  final DateTime? exchangeRateDate;  // When the rate was applied
  final bool isMultiCurrency;       // Whether conversion happened
  
  final GroupParticipant payer;      // Người thanh toán
  final Category? category;          // Danh mục
  final DateTime expenseDate;        // Ngày chi tiêu
  final DateTime createdAt;          // Ngày tạo
  final List<ExpenseSplit> splits;   // Danh sách chia bill
  final List<ExpenseAttachment> attachments; // Ảnh minh chứng
  
  // Expense finalization fields
  final bool isLocked;               // Expense có bị khóa không
  final DateTime? lockedAt;          // Thời điểm bị khóa
  final int? lockedByFinalizationId; // ID của finalization khóa expense này

  Expense({
    required this.id,
    required this.title,
    this.description,
    required this.originalAmount,
    required this.originalCurrency,
    required this.convertedAmount,
    required this.convertedCurrency,
    this.exchangeRate,
    this.exchangeRateDate,
    required this.isMultiCurrency,
    required this.payer,
    this.category,
    required this.expenseDate,
    required this.createdAt,
    required this.splits,
    required this.attachments,
    this.isLocked = false,
    this.lockedAt,
    this.lockedByFinalizationId,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      originalAmount: (json['originalAmount'] as num).toDouble(),
      originalCurrency: Currency.fromJson(json['originalCurrency']),
      convertedAmount: (json['convertedAmount'] as num).toDouble(),
      convertedCurrency: Currency.fromJson(json['convertedCurrency']),
      exchangeRate: json['exchangeRate'] != null 
          ? (json['exchangeRate'] as num).toDouble() 
          : null,
      exchangeRateDate: json['exchangeRateDate'] != null
          ? DateTime.parse(json['exchangeRateDate'])
          : null,
      isMultiCurrency: json['isMultiCurrency'] ?? false,
      payer: GroupParticipant.fromJson(json['payer']),
      category: json['category'] != null 
          ? Category.fromJson(json['category']) 
          : null,
      expenseDate: DateTime.parse(json['expenseDate']),
      createdAt: DateTime.parse(json['createdAt']),
      splits: (json['splits'] as List<dynamic>? ?? [])
          .map((e) => ExpenseSplit.fromJson(e))
          .toList(),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => ExpenseAttachment.fromJson(e))
          .toList(),
      isLocked: json['isLocked'] ?? false,
      lockedAt: json['lockedAt'] != null ? DateTime.parse(json['lockedAt']) : null,
      lockedByFinalizationId: json['lockedByFinalizationId'],
    );
  }

  // Helper methods for formatting amounts
  
  /// Format original amount (what user actually spent)
  String get formattedOriginalAmount => 
      originalCurrency.formatAmount(originalAmount);
  
  /// Format converted amount (in group default currency)
  String get formattedConvertedAmount => 
      convertedCurrency.formatAmount(convertedAmount);
  
  /// Compact format for original amount
  String get formattedOriginalAmountCompact => 
      originalCurrency.formatAmountCompact(originalAmount);
      
  /// Compact format for converted amount
  String get formattedConvertedAmountCompact => 
      convertedCurrency.formatAmountCompact(convertedAmount);
  
  // Legacy methods for backward compatibility (use converted amounts)
  @deprecated
  String get formattedAmount => formattedConvertedAmount;
  
  @deprecated
  String get formattedAmountCompact => formattedConvertedAmountCompact;
  
  @deprecated
  Currency get currency => convertedCurrency;
  
  @deprecated
  double get amount => convertedAmount;
  
  /// Format with group default currency (for display after conversion)
  String formatAmountWithGroupCurrency(String groupDefaultCurrency) {
    return CurrencyFormatter.formatMoney(convertedAmount, groupDefaultCurrency);
  }
  
  String formatAmountCompactWithGroupCurrency(String groupDefaultCurrency) {
    return CurrencyFormatter.formatMoneyCompact(convertedAmount, groupDefaultCurrency);
  }
  
  String get payerName => payer.name;
  
  String get categoryName => category?.name ?? 'Không phân loại';
  
  String get categoryIcon => category?.iconCode ?? 'receipt';
  
  String get formattedDate => DateFormat('dd/MM/yyyy').format(expenseDate);
  
  /// Get conversion display text for UI
  String get conversionDisplay {
    if (!isMultiCurrency) return '';
    
    return CurrencyFormatter.formatConversion(
      originalAmount: originalAmount,
      originalCurrency: originalCurrency.code,
      convertedAmount: convertedAmount,
      convertedCurrency: convertedCurrency.code,
      exchangeRate: exchangeRate ?? 1.0,
    );
  }
  
  /// Get exchange rate display text
  String get exchangeRateDisplay {
    if (!isMultiCurrency || exchangeRate == null) return '';
    
    final formatter = NumberFormat('#,##0.####');
    return '1 ${originalCurrency.code} = ${formatter.format(exchangeRate)} ${convertedCurrency.code}';
  }
  
  /// Legacy method for backward compatibility
  @deprecated
  bool hasConversion(String groupDefaultCurrency) => isMultiCurrency;
  
  /// Legacy method for backward compatibility  
  @deprecated
  String getConversionDisplay(String groupDefaultCurrency) => conversionDisplay;
  
  // Helper methods for expense finalization
  
  /// Check if this expense is locked
  bool get isExpenseLocked => isLocked;
  
  /// Get locked status display text
  String get lockedStatusText {
    if (isLocked) {
      if (lockedAt != null) {
        final formatter = DateFormat('dd/MM/yyyy HH:mm');
        return 'Đã khóa vào ${formatter.format(lockedAt!)}';
      }
      return 'Đã bị khóa';
    }
    return 'Có thể chỉnh sửa';
  }
  
  /// Check if user can edit this expense
  bool get canEdit => !isLocked;
  
  /// Check if user can delete this expense
  bool get canDelete => !isLocked;
}

class ExpenseSplit {
  final int id;
  final GroupParticipant participant;
  final double amount;
  final double percentage;
  final bool isPayer;

  ExpenseSplit({
    required this.id,
    required this.participant,
    required this.amount,
    required this.percentage,
    required this.isPayer,
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      id: json['id'] ?? 0,
      participant: GroupParticipant.fromJson(json['participant']),
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
      isPayer: json['isPayer'] ?? false,
    );
  }

  String get participantName => participant.name;
}

class ExpenseAttachment {
  final int id;
  final String fileUrl;
  final String? description;
  final DateTime uploadedAt;

  ExpenseAttachment({
    required this.id,
    required this.fileUrl,
    this.description,
    required this.uploadedAt,
  });

  factory ExpenseAttachment.fromJson(Map<String, dynamic> json) {
    return ExpenseAttachment(
      id: json['id'],
      fileUrl: json['fileUrl'],
      description: json['description'],
      uploadedAt: DateTime.parse(json['uploadedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  String get displayUrl {
    // Replace localhost với actual API URL
    return fileUrl; // Có thể cần xử lý URL replacement ở đây
  }
}

/// User expense summary with multi-currency support
class UserExpenseSummary {
  final double total;                          // Total in unified currency (converted amounts)
  final Map<String, double> totalsByOriginalCurrency; // Totals by original currencies
  final List<Expense> expenses;                // List of expenses

  UserExpenseSummary({
    required this.total,
    required this.totalsByOriginalCurrency,
    required this.expenses,
  });

  factory UserExpenseSummary.fromJson(Map<String, dynamic> json) {
    return UserExpenseSummary(
      total: (json['total'] as num).toDouble(),
      totalsByOriginalCurrency: (json['totalsByOriginalCurrency'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, (value as num).toDouble())),
      expenses: (json['expenses'] as List<dynamic>)
          .map((e) => Expense.fromJson(e))
          .toList(),
    );
  }

  /// Get formatted total amount
  String getFormattedTotal(String currencyCode) {
    return CurrencyFormatter.formatMoney(total, currencyCode);
  }

  /// Get formatted amount for specific original currency
  String getFormattedAmountForCurrency(String currencyCode) {
    final amount = totalsByOriginalCurrency[currencyCode] ?? 0.0;
    return CurrencyFormatter.formatMoney(amount, currencyCode);
  }

  /// Get list of currencies user actually spent in
  List<String> get usedCurrencies => totalsByOriginalCurrency.keys.toList();

  /// Check if user spent in multiple currencies
  bool get isMultiCurrency => totalsByOriginalCurrency.length > 1;

  /// Get primary currency (highest spending amount)
  String? get primaryCurrency {
    if (totalsByOriginalCurrency.isEmpty) return null;
    
    return totalsByOriginalCurrency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}