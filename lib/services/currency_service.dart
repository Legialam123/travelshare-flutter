import 'package:dio/dio.dart';
import '../models/currency.dart';
import 'auth_service.dart';

class CurrencyService {
  static Future<List<Currency>> fetchCurrencies() async {
    try {
      final response =
          await AuthService.dio.get('/currency'); // cập nhật endpoint nếu khác
      if (response.statusCode == 200 && response.data['result'] != null) {
        final List<dynamic> list = response.data['result'];
        return list.map((e) => Currency.fromJson(e)).toList();
      } else {
        throw Exception('Không thể lấy danh sách tiền tệ');
      }
    } catch (e) {
      throw Exception('Lỗi khi gọi API tiền tệ: $e');
    }
  }
}
