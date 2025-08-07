import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'currency_formatter.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final String currencyCode;
  
  CurrencyInputFormatter({required this.currencyCode});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Nếu text rỗng, allow
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final isInteger = CurrencyFormatter.isIntegerCurrency(currencyCode);
    
    if (!isInteger && currencyCode != 'VND') {
      // USD, EUR... allow numbers và 1 decimal point
      String cleanText = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
      
      // Validate decimal format
      List<String> parts = cleanText.split('.');
      if (parts.length > 2) {
        return oldValue; // Không cho phép nhiều hơn 1 dấu chấm
      }
      
      if (parts.length == 2 && parts[1].length > 2) {
        return oldValue; // Không cho phép nhiều hơn 2 chữ số sau dấu chấm
      }
      
      // 🔧 Preserve cursor position tương đối 
      int newCursorPosition = newValue.selection.baseOffset;
      
      // Adjust cursor if text was cleaned
      if (cleanText.length < newValue.text.length) {
        final removedChars = newValue.text.length - cleanText.length;
        newCursorPosition = (newValue.selection.baseOffset - removedChars).clamp(0, cleanText.length);
      }
      
      return TextEditingValue(
        text: cleanText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    } else {
      // VND, JPY, KRW... chỉ allow numbers (no formatting)
      String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
      
      if (digitsOnly.isEmpty && newValue.text.isNotEmpty) {
        return oldValue; // Reject invalid input
      }
      
      // 🔧 Preserve cursor position cho VND/integer currencies
      int newCursorPosition = newValue.selection.baseOffset;
      
      // Adjust cursor if non-digit characters were removed
      if (digitsOnly.length < newValue.text.length) {
        final removedChars = newValue.text.length - digitsOnly.length;
        newCursorPosition = (newValue.selection.baseOffset - removedChars).clamp(0, digitsOnly.length);
      }
      
      return TextEditingValue(
        text: digitsOnly,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    }
  }

  /// Get dynamic hint text based on currency
  static String getHintText(String currencyCode) {
    final isInteger = CurrencyFormatter.isIntegerCurrency(currencyCode);
    
    if (isInteger || currencyCode == 'VND') {
      // VND, JPY, KRW... show "0"
      return '0';
    } else {
      // USD, EUR... show "0.00"
      return '0.00';
    }
  }

  /// Prepare formatted text for editing (smart focus behavior)
  static String prepareForEdit(String formattedText, String currencyCode) {
    if (formattedText.isEmpty) return formattedText;
    
    final isInteger = CurrencyFormatter.isIntegerCurrency(currencyCode);
    
    if (currencyCode == 'VND') {
      // VND: Trở về raw number để edit dễ dàng (200.000 → 200000)
      return formattedText.replaceAll(RegExp(r'[^\d]'), '');
    } else if (isInteger) {
      // JPY, KRW: Trở về raw number (200,000 → 200000)
      return formattedText.replaceAll(RegExp(r'[^\d]'), '');
    } else {
      // USD, EUR: Giữ decimal context để edit (200,000.00 → 200000.00)
      String cleanText = formattedText.replaceAll(RegExp(r'[^\d.]'), '');
      
      // Nếu không có decimal point, thêm .00
      if (!cleanText.contains('.')) {
        cleanText += '.00';
      }
      
      return cleanText;
    }
  }

  /// Extract pure number for database submission (no currency formatting)
  static double? extractPureNumber(String text, String currencyCode) {
    if (text.isEmpty) return null;
    
    try {
      final isInteger = CurrencyFormatter.isIntegerCurrency(currencyCode);
      
      if (currencyCode == 'VND') {
        // VND: Remove dots and parse as integer
        String digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
        if (digitsOnly.isEmpty) return null;
        return double.parse(digitsOnly);
      } else if (isInteger) {
        // JPY, KRW: Remove commas and parse as integer
        String digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
        if (digitsOnly.isEmpty) return null;
        return double.parse(digitsOnly);
      } else {
        // USD, EUR: Remove commas but keep decimal point
        String cleanText = text.replaceAll(RegExp(r'[^\d.]'), '');
        if (cleanText.isEmpty) return null;
        return double.parse(cleanText);
      }
    } catch (e) {
      return null;
    }
  }

  /// Format số theo chuẩn Việt Nam với dấu chấm
  String _formatVietnamese(num value) {
    // Custom format để tránh conflict với decimal separator
    String numStr = value.round().toString();
    
    // Thêm dấu chấm từ phải sang trái
    String result = '';
    for (int i = 0; i < numStr.length; i++) {
      if (i > 0 && (numStr.length - i) % 3 == 0) {
        result += '.';
      }
      result += numStr[i];
    }
    
    return result;
  }

  /// Extract raw number từ formatted text
  static double? extractNumber(String formattedText) {
    if (formattedText.isEmpty) return null;
    
    // Extract chỉ các số, loại bỏ tất cả formatting (dấu chấm, phẩy, space...)
    String digitsOnly = formattedText.replaceAll(RegExp(r'[^\d.]'), '');
    if (digitsOnly.isEmpty) return null;
    
    return double.tryParse(digitsOnly);
  }

  /// Parse formatted input text về raw number
  static String? getRawValue(String formattedText) {
    final number = extractNumber(formattedText);
    return number?.toString();
  }

  /// Format a number theo currency (static method để dùng từ bên ngoài)
  static String formatCurrency(double value, String currencyCode) {
    final isInteger = CurrencyFormatter.isIntegerCurrency(currencyCode);
    
    if (currencyCode == 'VND') {
      // VND sử dụng dấu chấm theo chuẩn Việt Nam: 200.000
      return _formatVietnameseStatic(value.round());
    } else if (isInteger) {
      // JPY, KRW... không có phần thập phân: 200,000
      final formatter = NumberFormat('#,##0', 'en_US');
      return formatter.format(value.round());
    } else {
      // USD, EUR... có phần thập phân: 200,000.00
      final formatter = NumberFormat('#,##0.00', 'en_US');
      return formatter.format(value);
    }
  }

  /// Static version của Vietnamese formatter
  static String _formatVietnameseStatic(num value) {
    String numStr = value.round().toString();
    
    String result = '';
    for (int i = 0; i < numStr.length; i++) {
      if (i > 0 && (numStr.length - i) % 3 == 0) {
        result += '.';
      }
      result += numStr[i];
    }
    
    return result;
  }

  /// Format input value on focus lost
  static String formatOnBlur(String inputText, String currencyCode) {
    if (inputText.isEmpty) return inputText;
    
    try {
      final isInteger = CurrencyFormatter.isIntegerCurrency(currencyCode);
      
      if (!isInteger && currencyCode != 'VND') {
        // USD, EUR... parse as decimal
        double value = double.parse(inputText);
        return formatCurrency(value, currencyCode);
      } else {
        // VND, JPY, KRW... parse as integer
        double value = double.parse(inputText);
        return formatCurrency(value, currencyCode);
      }
    } catch (e) {
      return inputText; // Return original if parsing fails
    }
  }
} 