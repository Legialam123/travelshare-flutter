class ReceiptData {
  final String? merchantName;
  final double? amount;
  final DateTime? date;
  final String? description;
  final String rawText;
  final String? categoryName; // Category từ AI
  final int? categoryId; // Category ID để lưu

  ReceiptData({
    this.merchantName,
    this.amount,
    this.date,
    this.description,
    this.rawText = '',
    this.categoryName,
    this.categoryId,
  });

  @override
  String toString() {
    return 'ReceiptData(merchant: $merchantName, amount: $amount, date: $date, category: $categoryName)';
  }

  // Create a copy with updated values
  ReceiptData copyWith({
    String? merchantName,
    double? amount,
    DateTime? date,
    String? description,
    String? rawText,
    String? categoryName,
    int? categoryId,
  }) {
    return ReceiptData(
      merchantName: merchantName ?? this.merchantName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      rawText: rawText ?? this.rawText,
      categoryName: categoryName ?? this.categoryName,
      categoryId: categoryId ?? this.categoryId,
    );
  }
} 