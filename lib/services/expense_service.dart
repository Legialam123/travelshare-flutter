import 'package:dio/dio.dart';
import '../services/auth_service.dart';

class ExpenseService {
  /// Lấy chi tiết một khoản chi cụ thể
  static Future<Map<String, dynamic>?> fetchExpenseDetail(int expenseId) async {
    try {
      final response = await AuthService.dio.get('/expense/$expenseId');
      if (response.statusCode == 200 && response.data['result'] != null) {
        return response.data['result'] as Map<String, dynamic>;
      } else {
        print('⚠️ API trả về lỗi: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi lấy chi tiết chi phí: $e');
    }
    return null;
  }

  /// (Tuỳ chọn) Xoá một khoản chi
  static Future<bool> deleteExpense(int expenseId) async {
    try {
      final response = await AuthService.dio.delete('/expense/$expenseId');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Lỗi khi xoá chi phí: $e');
      return false;
    }
  }

  /// (Tuỳ chọn) Cập nhật khoản chi
  static Future<bool> updateExpense(
      int expenseId, Map<String, dynamic> data) async {
    try {
      final response =
          await AuthService.dio.put('/expense/$expenseId', data: data);
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Lỗi khi cập nhật chi phí: $e');
      return false;
    }
  }
}
