import 'package:intl/intl.dart';

class CurrencyFormatter {
  // Các currencies không có phần thập phân
  static const Set<String> _integerCurrencies = {
    'VND', 'JPY', 'KRW', 'IDR', 'CLP', 'PYG', 'UGX', 'COP'
  };

  // Currencies phổ biến cho người Việt Nam
  static const Set<String> _popularCurrencies = {
    'VND', 'USD', 'EUR', 'GBP', 'JPY', 'CNY', 'THB', 'SGD', 'MYR', 'KRW'
  };

  // Currency symbols mapping
  static const Map<String, String> _currencySymbols = {
    'VND': '₫',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'KRW': '₩',
    'THB': '฿',
    'SGD': 'S\$',
    'MYR': 'RM',
    'IDR': 'Rp',
    'PHP': '₱',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'CHF': 'CHF',
    'INR': '₹',
    'HKD': 'HK\$',
    'TWD': 'NT\$',
    'BRL': 'R\$',
    'MXN': 'MX\$',
    'RUB': '₽',
    'ZAR': 'R',
    'EGP': 'E£',
    'NGN': '₦',
    'AED': 'د.إ',
    'SAR': '﷼',
    'QAR': 'ق.ر',
    'KWD': 'د.ك',
    'NOK': 'kr',
    'SEK': 'kr',
    'DKK': 'kr',
    'PLN': 'zł',
    'CZK': 'Kč',
    'HUF': 'Ft',
    'NZD': 'NZ\$',
    'CLP': '\$',
    'COP': '\$',
    'PEN': 'S/.',
    'ARS': '\$',
  };

  // Locale mapping for different currencies
  static const Map<String, String> _localeMapping = {
    'VND': 'vi_VN',
    'USD': 'en_US',
    'EUR': 'de_DE',
    'GBP': 'en_GB',
    'JPY': 'ja_JP',
    'CNY': 'zh_CN',
    'KRW': 'ko_KR',
    'THB': 'th_TH',
    'SGD': 'en_SG',
    'MYR': 'ms_MY',
    'IDR': 'id_ID',
    'PHP': 'en_PH',
    'AUD': 'en_AU',
    'CAD': 'en_CA',
    'CHF': 'de_CH',
    'INR': 'en_IN',
    'HKD': 'zh_HK',
    'BRL': 'pt_BR',
    'RUB': 'ru_RU',
    'ZAR': 'en_ZA',
    'AED': 'ar_AE',
    'NOK': 'nb_NO',
    'SEK': 'sv_SE',
    'DKK': 'da_DK',
    'PLN': 'pl_PL',
    'CZK': 'cs_CZ',
    'HUF': 'hu_HU',
    'NZD': 'en_NZ',
  };

  static bool isIntegerCurrency(String currencyCode) {
    return _integerCurrencies.contains(currencyCode.toUpperCase());
  }

  static bool isPopularCurrency(String currencyCode) {
    return _popularCurrencies.contains(currencyCode.toUpperCase());
  }

  static String getSymbol(String currencyCode) {
    return _currencySymbols[currencyCode.toUpperCase()] ?? currencyCode;
  }

  static String getLocale(String currencyCode) {
    return _localeMapping[currencyCode.toUpperCase()] ?? 'en_US';
  }

  /// Format money với currency symbol
  static String formatMoney(double amount, String currencyCode, {bool showSymbol = true}) {
    final isInteger = isIntegerCurrency(currencyCode);
    final symbol = getSymbol(currencyCode);
    
    if (isInteger) {
      final formatter = NumberFormat('#,##0', 'vi_VN');
      final formatted = formatter.format(amount.round());
      return showSymbol ? '$formatted $symbol' : formatted;
    } else {
      final formatter = NumberFormat('#,##0.00', 'vi_VN');
      final formatted = formatter.format(amount);
      return showSymbol ? '$symbol$formatted' : formatted;
    }
  }

  /// Format money compact (ngắn gọn)
  static String formatMoneyCompact(double amount, String currencyCode) {
    final symbol = getSymbol(currencyCode);
    
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B $symbol';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M $symbol';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K $symbol';
    } else {
      return formatMoney(amount, currencyCode);
    }
  }

  /// Format money với currency code
  static String formatMoneyWithCode(double amount, String currencyCode) {
    final isInteger = isIntegerCurrency(currencyCode);
    
    if (isInteger) {
      final formatter = NumberFormat('#,##0', 'vi_VN');
      return '${formatter.format(amount.round())} $currencyCode';
    } else {
      final formatter = NumberFormat('#,##0.00', 'vi_VN');
      return '${formatter.format(amount)} $currencyCode';
    }
  }

  /// Format exchange rate với high precision để hiển thị tỷ giá chi tiết
  static String formatExchangeRate(double rate) {
    // Dynamically determine precision based on rate magnitude
    if (rate >= 1) {
      return NumberFormat('#,##0.######').format(rate);
    } else if (rate >= 0.001) {
      return NumberFormat('#,##0.######').format(rate);
    } else {
      // Very small rates like 0.000038 need more precision
      return NumberFormat('#,##0.##########').format(rate);
    }
  }

  /// Format currency conversion display
  static String formatConversion({
    required double originalAmount,
    required String originalCurrency,
    required double convertedAmount,
    required String convertedCurrency,
    required double exchangeRate,
  }) {
    final originalFormatted = formatMoney(originalAmount, originalCurrency);
    final convertedFormatted = formatMoney(convertedAmount, convertedCurrency);
    final rateFormatted = NumberFormat('#,##0.######').format(exchangeRate);
    
    return '$originalFormatted → $convertedFormatted (Tỷ giá: 1 $originalCurrency = $rateFormatted $convertedCurrency)';
  }

  /// Get list of popular currencies for Vietnamese users
  static List<String> getPopularCurrencies() {
    return _popularCurrencies.toList()..sort();
  }

  /// Get all supported currencies
  static List<String> getAllSupportedCurrencies() {
    return _currencySymbols.keys.toList()..sort();
  }
}