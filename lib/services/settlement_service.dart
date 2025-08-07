import 'package:dio/dio.dart';
import '../services/auth_service.dart';

class SettlementService {
  /// Lấy danh sách suggested settlements cho một nhóm
  static Future<List<dynamic>> fetchSuggestedSettlements(
    int groupId, {
    bool userOnly = false,
  }) async {
    try {
      final response = await AuthService.dio.get(
        '/settlement/group/$groupId/suggested',
        queryParameters: {
          'userOnly': userOnly,
        },
      );
      return response.data['result'] as List;
    } catch (e) {
      throw Exception('Không thể tải thanh toán đề xuất: $e');
    }
  }

  /// Tạo thanh toán (xác nhận đã thanh toán hoặc yêu cầu thanh toán)
  static Future<bool> createSettlement({
    required int groupId,
    required int fromParticipantId,
    required int toParticipantId,
    required double amount,
    required String currencyCode,
    required String status,
    String? settlementMethod,
    String? description,
  }) async {
    try {
      final response = await AuthService.dio.post('/settlement', data: {
        'groupId': groupId,
        'fromParticipantId': fromParticipantId,
        'toParticipantId': toParticipantId,
        'amount': amount,
        'currencyCode': currencyCode,
        'status': status,
        if (settlementMethod != null) 'settlementMethod': settlementMethod,
        if (description != null) 'description': description,
      });
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Không thể tạo thanh toán: $e');
    }
  }

  /// Tạo settlement và lấy link thanh toán VNPay
  static Future<String?> createVnPaySettlement({
    int? settlementId,
    int? groupId,
    int? fromParticipantId,
    int? toParticipantId,
    double? amount,
    String? currencyCode,
    String? description,
    String? settlementMethod,
    String? status,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (settlementId != null) {
        data['settlementId'] = settlementId;
      } else {
        data['groupId'] = groupId;
        data['fromParticipantId'] = fromParticipantId;
        data['toParticipantId'] = toParticipantId;
        data['amount'] = amount;
        data['currencyCode'] = currencyCode;
        data['settlementMethod'] = settlementMethod ?? 'VNPAY';
        if (description != null) data['description'] = description;
        if (status != null) data['status'] = status;
      }
      final response = await AuthService.dio.post('/vnpay/create', data: data);
      if (response.statusCode == 200 && response.data['result'] != null) {
        return response.data['result']['paymentUrl'] as String?;
      }
      return null;
    } catch (e) {
      throw Exception('Không thể tạo thanh toán VNPay: $e');
    }
  }

  /// Lấy danh sách settlements của một user
  static Future<List<dynamic>> fetchUserSettlements(String userId) async {
    final response = await AuthService.dio.get('/settlement/user/$userId');
    if (response.statusCode == 200 && response.data['result'] != null) {
      return response.data['result'] as List;
    } else {
      throw Exception('Không thể tải danh sách giao dịch của user');
    }
  }

  /// Xác nhận settlement (chuyển sang COMPLETED)
  static Future<bool> confirmSettlement(int settlementId) async {
    try {
      final response = await AuthService.dio
          .patch('/settlement/$settlementId/confirm', data: {
        'status': 'COMPLETED',
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Lấy lịch sử thanh toán (COMPLETED/FAILED/PENDING) cho một nhóm
  static Future<List<dynamic>> fetchSettlementHistory(int groupId) async {
    try {
      final response = await AuthService.dio.get(
        '/settlement/group/$groupId',
      );
      return response.data['result'] as List;
    } catch (e) {
      throw Exception('Không thể tải lịch sử thanh toán: $e');
    }
  }

  /// Lấy số dư của user theo từng nhóm
  static Future<List<dynamic>> fetchUserBalancesByGroup(String userId) async {
    final response =
        await AuthService.dio.get('/settlement/user/$userId/groups');
    if (response.statusCode == 200 && response.data['result'] != null) {
      return response.data['result'] as List;
    } else {
      throw Exception('Không thể tải số dư các nhóm của user');
    }
  }

  /// Lấy số dư của tất cả thành viên trong một nhóm
  static Future<List<dynamic>> fetchGroupBalances(int groupId) async {
    try {
      final response = await AuthService.dio.get('/settlement/group/$groupId/balances');
      if (response.statusCode == 200 && response.data['result'] != null) {
        return response.data['result'] as List;
      } else {
        throw Exception('API trả về lỗi: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Nhóm chưa có balance nào
        return [];
      }
      throw Exception('Lỗi mạng: ${e.message}');
    } catch (e) {
      throw Exception('Không thể tải số dư nhóm: $e');
    }
  }
}
