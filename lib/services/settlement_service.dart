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
    String settlementMethod = 'CASH',
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
        'settlementMethod': settlementMethod,
        if (description != null) 'description': description,
      });
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Không thể tạo thanh toán: $e');
    }
  }
}
