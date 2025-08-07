import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../models/chatgpt_ocr_response.dart';
import '../services/auth_service.dart';
import '../services/category_service.dart';
import '../models/receipt_data.dart';

class ChatGptOcrService {
  /// Xác định MediaType dựa trên file extension
  static MediaType _getMediaType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.gif':
        return MediaType('image', 'gif');
      case '.webp':
        return MediaType('image', 'webp');
      case '.bmp':
        return MediaType('image', 'bmp');
      default:
        // Default to JPEG if unknown
        return MediaType('image', 'jpeg');
    }
  }

  /// Xử lý OCR sử dụng ChatGPT backend (với optimization và caching)
  static Future<ReceiptData> processReceiptWithChatGPT(XFile imageFile) async {
    try {
      // Xác định MediaType dựa trên file extension
      final mediaType = _getMediaType(imageFile.path);

      // Basic validation (backend sẽ handle chi tiết)
      final file = File(imageFile.path);
      if (!await file.exists()) {
        throw Exception('File không tồn tại: ${imageFile.path}');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File rỗng');
      }

      print('📤 Uploading file: ${imageFile.name} (${(fileSize / 1024).toStringAsFixed(1)}KB)');

      // Tạo FormData với image file
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.name,
          contentType: mediaType,
        ),
      });

      // Call API using centralized AuthService.dio (auto-handles auth token)
      // Backend đã có optimization và caching, timeout có thể ngắn hơn
      final response = await AuthService.dio.post(
        '/ai/ocr/process-receipt',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          receiveTimeout: const Duration(seconds: 45), // Tăng để xử lý optimization
          sendTimeout: const Duration(seconds: 15),    // Upload timeout
        ),
      );

      // Parse response
      final ocrResponse = ChatGptOcrResponse.fromJson(response.data);

      if (ocrResponse.code == 1000 && ocrResponse.result != null) {
        // Create enhanced ReceiptData với category info
        final receiptData = ocrResponse.result!.toReceiptData();
        
        print('✅ OCR thành công: ${ocrResponse.result!.merchantName} - ${ocrResponse.result!.amount}');
        return receiptData;
      } else {
        // Xử lý error codes từ backend
        String errorMessage;
        switch (ocrResponse.code) {
          case 1002:
            errorMessage = 'File không được để trống';
            break;
          case 1003:
            errorMessage = ocrResponse.message ?? 'File không hợp lệ (định dạng hoặc kích thước)';
            break;
          case 1004:
            errorMessage = 'Không thể xử lý OCR. Vui lòng thử lại.';
            break;
          case 1005:
            errorMessage = 'File quá lớn (tối đa 5MB). Vui lòng chọn file nhỏ hơn.';
            break;
          default:
            errorMessage = ocrResponse.message ?? 'Lỗi không xác định';
        }
        throw Exception(errorMessage);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('⏱️ Timeout: OCR đang bận, vui lòng thử lại sau.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('🌐 Không thể kết nối đến server. Kiểm tra kết nối mạng.');
      } else if (e.response?.statusCode == 413) {
        throw Exception('📁 File quá lớn. Vui lòng chọn file nhỏ hơn 5MB.');
      } else {
        throw Exception('❌ Lỗi server: ${e.response?.statusCode ?? 'Unknown'}');
      }
    } catch (e) {
      print('❌ OCR Error: $e');
      throw Exception('Không thể xử lý hóa đơn với AI: $e');
    }
  }

  /// Lấy category ID từ category name
  static Future<String?> getCategoryIdFromName(
      String categoryName, int groupId) async {
    try {
      final categories =
          await CategoryService.fetchGroupExpenseCategories(groupId);

      // Tìm exact match first
      final exactMatch =
          categories.where((cat) => cat.name == categoryName).firstOrNull;

      if (exactMatch != null) {
        return exactMatch.id.toString();
      }

      // Fuzzy matching
      final lowerCategoryName = categoryName.toLowerCase();

      for (final category in categories) {
        final lowerCatName = category.name.toLowerCase();

        if (lowerCatName.contains('ăn') && lowerCategoryName.contains('ăn')) {
          return category.id.toString();
        }
        if (lowerCatName.contains('phương tiện') &&
            (lowerCategoryName.contains('phương tiện') ||
                lowerCategoryName.contains('di chuyển'))) {
          return category.id.toString();
        }
        if (lowerCatName.contains('lưu trú') &&
            (lowerCategoryName.contains('lưu trú') ||
                lowerCategoryName.contains('khách sạn'))) {
          return category.id.toString();
        }
        if (lowerCatName.contains('mua sắm') &&
            lowerCategoryName.contains('mua sắm')) {
          return category.id.toString();
        }
        if (lowerCatName.contains('giải trí') &&
            lowerCategoryName.contains('giải trí')) {
          return category.id.toString();
        }
      }

      // Default fallback - find "Khác" or first category
      final defaultCategory = categories
              .where((cat) => cat.name.toLowerCase().contains('khác'))
              .firstOrNull ??
          categories.firstOrNull;

      if (defaultCategory != null) {
        return defaultCategory.id.toString();
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Test connection đến backend
  static Future<bool> testConnection() async {
    try {
      final response = await AuthService.dio.get(
        '/ai/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
