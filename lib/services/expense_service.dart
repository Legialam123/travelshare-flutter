import 'package:dio/dio.dart';
import '../services/auth_service.dart';
import '../models/expense.dart';

class ExpenseService {
  /// Lấy chi tiết một khoản chi cụ thể - trả về Expense object
  static Future<Expense?> fetchExpenseDetail(int expenseId) async {
    try {
      final response = await AuthService.dio.get('/expense/$expenseId');
      if (response.statusCode == 200 && response.data['result'] != null) {
        return Expense.fromJson(response.data['result']);
      } else {
        print('⚠️ API trả về lỗi: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi lấy chi tiết chi phí: $e');
    }
    return null;
  }

  /// Lấy thống kê chi tiêu cá nhân với multi-currency support
  static Future<UserExpenseSummary?> fetchUserExpenseSummary({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    int? groupId,
    int? categoryId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate.toIso8601String().split('T')[0];
      if (endDate != null) queryParams['endDate'] = endDate.toIso8601String().split('T')[0];
      if (groupId != null) queryParams['groupId'] = groupId;
      if (categoryId != null) queryParams['categoryId'] = categoryId;

      final response = await AuthService.dio.get(
        '/expense/user/$userId',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200 && response.data['result'] != null) {
        return UserExpenseSummary.fromJson(response.data['result']);
      } else {
        print('⚠️ API trả về lỗi: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi lấy thống kê chi tiêu cá nhân: $e');
    }
    return null;
  }

  /// Lấy chi tiết expense dạng Map (backward compatibility)
  static Future<Map<String, dynamic>?> fetchExpenseDetailMap(int expenseId) async {
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

  /// Xoá một khoản chi
  static Future<bool> deleteExpense(int expenseId) async {
    try {
      final response = await AuthService.dio.delete('/expense/$expenseId');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Lỗi khi xoá chi phí: $e');
      return false;
    }
  }

  /// Cập nhật khoản chi
  static Future<Expense?> updateExpense(int expenseId, Map<String, dynamic> data) async {
    try {
      final response = await AuthService.dio.put('/expense/$expenseId', data: data);
      if (response.statusCode == 200 && response.data['result'] != null) {
        return Expense.fromJson(response.data['result']);
      }
    } catch (e) {
      print('❌ Lỗi khi cập nhật chi phí: $e');
    }
    return null;
  }

  /// Tạo expense mới
  static Future<Expense?> createExpense(Map<String, dynamic> data) async {
    try {
      final response = await AuthService.dio.post('/expense', data: data);
      if (response.statusCode == 200 && response.data['result'] != null) {
        return Expense.fromJson(response.data['result']);
      }
    } catch (e) {
      print('❌ Lỗi khi tạo chi phí: $e');
    }
    return null;
  }

  /// Lấy thống kê chi tiêu cá nhân (legacy - Map format)
  @deprecated
  static Future<Map<String, dynamic>?> fetchUserExpenseStatistics(String userId) async {
    try {
      final response = await AuthService.dio.get('/expense/user/$userId');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      } else {
        print('⚠️ API trả về lỗi: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi lấy thống kê cá nhân: $e');
    }
    return null;
  }

  /// Lấy danh sách expenses của nhóm với Expense models
  static Future<List<Expense>> fetchGroupExpenses(int groupId) async {
    try {
      final response = await AuthService.dio.get('/expense/group/$groupId');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['result'] is List) {
          final expenseList = data['result'] as List<dynamic>;
          return expenseList.map((e) => Expense.fromJson(e)).toList();
        }
        return [];
      } else {
        throw Exception('API trả về lỗi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Nhóm chưa có expense nào
        return [];
      }
      throw Exception('Lỗi mạng: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải danh sách chi tiêu: $e');
    }
  }

  /// Lấy danh sách chi tiết tất cả expenses của nhóm (legacy - dynamic format)
  static Future<List<dynamic>> fetchGroupExpensesMap(int groupId) async {
    try {
      final response = await AuthService.dio.get('/expense/group/$groupId');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['result'] is List) {
          return data['result'] as List<dynamic>;
        }
        return [];
      } else {
        throw Exception('API trả về lỗi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Nhóm chưa có expense nào
        return [];
      }
      throw Exception('Lỗi mạng: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải danh sách chi tiêu: $e');
    }
  }

  /// Lấy thống kê chi tiêu của nhóm (legacy - Map format)
  static Future<Map<String, dynamic>> fetchGroupExpenseStatistics(int groupId) async {
    try {
      final response = await AuthService.dio.get('/expense/group/$groupId');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['result'] is List) {
          final expenses = data['result'] as List<dynamic>;
          final totalExpense = expenses.fold<double>(0, (sum, expense) {
            return sum + (((expense['convertedAmount'] ?? expense['amount'] ?? 0) as num?)?.toDouble() ?? 0);
          });
          return {
            'result': {
              'totalExpense': totalExpense,
              'expenses': expenses,
            }
          };
        }
        return data;
      } else {
        throw Exception('API trả về lỗi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Nhóm chưa có expense nào
        return {
          'result': {
            'totalExpense': 0,
            'expenses': [],
          }
        };
      }
      throw Exception('Lỗi mạng: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải thống kê nhóm: $e');
    }
  }
}
