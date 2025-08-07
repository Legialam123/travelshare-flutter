import 'receipt_data.dart';

class ChatGptOcrResponse {
  final int code;
  final String? message;
  final ChatGptOcrResult? result;

  ChatGptOcrResponse({
    required this.code,
    this.message,
    this.result,
  });

  factory ChatGptOcrResponse.fromJson(Map<String, dynamic> json) {
    return ChatGptOcrResponse(
      code: json['code'] ?? 0,
      message: json['message'],
      result: json['result'] != null
          ? ChatGptOcrResult.fromJson(json['result'])
          : null,
    );
  }
}

class ChatGptOcrResult {
  final String? merchantName;
  final double? amount;
  final String? date; // "2016-07-22 20:53:11"
  final String? description;
  final String? categoryName;
  
  // Note: Backend đã bỏ confidence, originalText và currency để tối ưu response
  final String? confidence; // Deprecated - for backward compatibility
  final String? originalText; // Deprecated - for backward compatibility

  ChatGptOcrResult({
    this.merchantName,
    this.amount,
    this.date,
    this.description,
    this.categoryName,
    this.confidence,
    this.originalText,
  });

  factory ChatGptOcrResult.fromJson(Map<String, dynamic> json) {
    return ChatGptOcrResult(
      merchantName: json['merchantName'],
      amount: json['amount']?.toDouble(),
      date: json['date'],
      description: json['description'],
      categoryName: json['categoryName'],
      confidence: json['confidence'] ?? 'high', // Default confidence
      originalText: json['originalText'] ?? '', // Default empty
    );
  }

  // Convert to ReceiptData format để tương thích với UI hiện tại
  ReceiptData toReceiptData() {
    DateTime? parsedDate;
    if (date != null) {
      try {
        parsedDate = DateTime.parse(date!);
      } catch (e) {
        print('Error parsing date: $date');
      }
    }

    return ReceiptData(
      merchantName: merchantName,
      amount: amount,
      date: parsedDate,
      description: description ?? merchantName ?? 'Chi tiêu từ hóa đơn',
      rawText: originalText ?? 'Dữ liệu từ OCR tối ưu', // Fallback text
      categoryName: categoryName, // Category từ AI
    );
  }

  @override
  String toString() {
    return 'ChatGptOcrResult(merchant: $merchantName, amount: $amount, category: $categoryName)';
  }
}
