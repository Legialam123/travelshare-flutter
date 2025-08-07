import '../utils/currency_formatter.dart';

class Currency {
  final int id;
  final String code;
  final String name;
  final String symbol;

  Currency({
    required this.id,
    required this.code,
    required this.name,
    required this.symbol,
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'symbol': symbol,
    };
  }

  // Helper getters
  String get displayName => '$name ($code)';
  String get displaySymbol => '$symbol ($code)';
  bool get isIntegerCurrency => CurrencyFormatter.isIntegerCurrency(code);
  bool get isPopular => CurrencyFormatter.isPopularCurrency(code);
  String get locale => CurrencyFormatter.getLocale(code);

  // Format methods using CurrencyFormatter
  String formatAmount(double amount, {bool showSymbol = true}) {
    return CurrencyFormatter.formatMoney(amount, code, showSymbol: showSymbol);
  }

  String formatAmountCompact(double amount) {
    return CurrencyFormatter.formatMoneyCompact(amount, code);
  }

  String formatAmountWithCode(double amount) {
    return CurrencyFormatter.formatMoneyWithCode(amount, code);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Currency && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'Currency(code: $code, name: $name, symbol: $symbol)';
}