import 'currency_input_formatter.dart';

/// Utility class để parse formatted amounts thành pure numbers cho database
class AmountParser {
  /// Parse formatted amount string thành pure number với currency context
  /// 
  /// Examples:
  /// - VND "200.000" → 200000.0
  /// - USD "200,000.00" → 200000.0
  /// - USD "50.50" → 50.5
  /// - JPY "50,000" → 50000.0
  static ParsedAmount? parseAmount(String formattedText, String currencyCode) {
    final pureNumber = CurrencyInputFormatter.extractPureNumber(formattedText, currencyCode);
    
    if (pureNumber == null) return null;
    
    return ParsedAmount(
      amount: pureNumber,
      currencyCode: currencyCode,
      originalText: formattedText,
    );
  }

  /// Parse multiple amounts với cùng currency
  static List<ParsedAmount> parseMultipleAmounts(
    List<String> formattedTexts, 
    String currencyCode
  ) {
    return formattedTexts
        .map((text) => parseAmount(text, currencyCode))
        .where((parsed) => parsed != null)
        .cast<ParsedAmount>()
        .toList();
  }

  /// Validate amount format trước khi submit
  static bool isValidAmount(String text, String currencyCode) {
    return CurrencyInputFormatter.extractPureNumber(text, currencyCode) != null;
  }

  /// Get pure number as double cho API submission
  static double? getPureDouble(String formattedText, String currencyCode) {
    return CurrencyInputFormatter.extractPureNumber(formattedText, currencyCode);
  }

  /// Get pure number as integer cho currencies không có decimal
  static int? getPureInt(String formattedText, String currencyCode) {
    final pureNumber = CurrencyInputFormatter.extractPureNumber(formattedText, currencyCode);
    return pureNumber?.round();
  }
}

/// Data class để hold parsed amount với currency context
class ParsedAmount {
  final double amount;
  final String currencyCode;
  final String originalText;

  const ParsedAmount({
    required this.amount,
    required this.currencyCode,
    required this.originalText,
  });

  /// Convert sang Map cho API submission
  Map<String, dynamic> toApiMap() {
    return {
      'amount': amount,
      'currencyCode': currencyCode,
    };
  }

  /// Convert sang JSON string
  @override
  String toString() {
    return 'ParsedAmount(amount: $amount, currencyCode: $currencyCode, originalText: "$originalText")';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ParsedAmount &&
        other.amount == amount &&
        other.currencyCode == currencyCode &&
        other.originalText == originalText;
  }

  @override
  int get hashCode {
    return amount.hashCode ^ 
           currencyCode.hashCode ^ 
           originalText.hashCode;
  }
} 