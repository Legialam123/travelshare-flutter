class CurrencyUtils {
  // Mapping currency codes to country flags
  static const Map<String, String> currencyFlags = {
    'VND': '🇻🇳',  // Vietnam
    'USD': '🇺🇸',  // United States
    'EUR': '🇪🇺',  // European Union
    'GBP': '🇬🇧',  // United Kingdom
    'JPY': '🇯🇵',  // Japan
    'CNY': '🇨🇳',  // China
    'KRW': '🇰🇷',  // South Korea
    'THB': '🇹🇭',  // Thailand
    'SGD': '🇸🇬',  // Singapore
    'MYR': '🇲🇾',  // Malaysia
    'IDR': '🇮🇩',  // Indonesia
    'PHP': '🇵🇭',  // Philippines
    'AUD': '🇦🇺',  // Australia
    'CAD': '🇨🇦',  // Canada
    'CHF': '🇨🇭',  // Switzerland
    'INR': '🇮🇳',  // India
    'HKD': '🇭🇰',  // Hong Kong
    'TWD': '🇹🇼',  // Taiwan
    'BRL': '🇧🇷',  // Brazil
    'MXN': '🇲🇽',  // Mexico
    'RUB': '🇷🇺',  // Russia
    'ZAR': '🇿🇦',  // South Africa
    'EGP': '🇪🇬',  // Egypt
    'NGN': '🇳🇬',  // Nigeria
    'AED': '🇦🇪',  // UAE
    'SAR': '🇸🇦',  // Saudi Arabia
    'QAR': '🇶🇦',  // Qatar
    'KWD': '🇰🇼',  // Kuwait
    'NOK': '🇳🇴',  // Norway
    'SEK': '🇸🇪',  // Sweden
    'DKK': '🇩🇰',  // Denmark
    'PLN': '🇵🇱',  // Poland
    'CZK': '🇨🇿',  // Czech Republic
    'HUF': '🇭🇺',  // Hungary
    'NZD': '🇳🇿',  // New Zealand
    'CLP': '🇨🇱',  // Chile
    'COP': '🇨🇴',  // Colombia
    'PEN': '🇵🇪',  // Peru
    'ARS': '🇦🇷',  // Argentina
  };

  // Popular currencies for Vietnamese users (in priority order)
  static const List<String> popularCurrencies = [
    'VND',  // Always first for Vietnamese users
    'USD',
    'EUR', 
    'GBP',
    'JPY',
    'CNY',
    'KRW',
    'THB',
    'SGD',
    'MYR',
  ];

  /// Get flag emoji for currency code
  static String getFlag(String currencyCode) {
    return currencyFlags[currencyCode.toUpperCase()] ?? '🏳️';
  }

  /// Check if currency is popular
  static bool isPopular(String currencyCode) {
    return popularCurrencies.contains(currencyCode.toUpperCase());
  }

  /// Get display text for currency with flag
  static String getDisplayText(String code, String name, String symbol) {
    final flag = getFlag(code);
    return '$flag $name ($symbol)';
  }

  /// Sort currencies by priority: default currency, VND, popular currencies, then alphabetical
  static List<T> sortCurrenciesByPriority<T>(
    List<T> currencies,
    String Function(T) getCode,
    String? defaultCurrencyCode,
  ) {
    return List<T>.from(currencies)..sort((a, b) {
      final codeA = getCode(a).toUpperCase();
      final codeB = getCode(b).toUpperCase();
      
      // Default currency always first
      if (defaultCurrencyCode != null) {
        if (codeA == defaultCurrencyCode.toUpperCase()) return -1;
        if (codeB == defaultCurrencyCode.toUpperCase()) return 1;
      }
      
      // VND always second (unless it's the default)
      if (codeA == 'VND' && codeB != 'VND') return -1;
      if (codeB == 'VND' && codeA != 'VND') return 1;
      
      // Popular currencies come next
      final isPopularA = isPopular(codeA);
      final isPopularB = isPopular(codeB);
      
      if (isPopularA && !isPopularB) return -1;
      if (isPopularB && !isPopularA) return 1;
      
      // Within popular currencies, sort by popularCurrencies order
      if (isPopularA && isPopularB) {
        final indexA = popularCurrencies.indexOf(codeA);
        final indexB = popularCurrencies.indexOf(codeB);
        return indexA.compareTo(indexB);
      }
      
      // Alphabetical for others
      return codeA.compareTo(codeB);
    });
  }

  /// Filter currencies by search query
  static List<T> filterCurrencies<T>(
    List<T> currencies,
    String query,
    String Function(T) getCode,
    String Function(T) getName,
    String Function(T) getSymbol,
  ) {
    if (query.isEmpty) return currencies;
    
    final lowerQuery = query.toLowerCase();
    
    return currencies.where((currency) {
      final code = getCode(currency).toLowerCase();
      final name = getName(currency).toLowerCase();
      final symbol = getSymbol(currency).toLowerCase();
      
      return code.contains(lowerQuery) ||
             name.contains(lowerQuery) ||
             symbol.contains(lowerQuery);
    }).toList();
  }
} 