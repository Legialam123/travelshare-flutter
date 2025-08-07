import 'package:dio/dio.dart';
import '../services/auth_service.dart';
import '../models/expense_finalization.dart';

class ExpenseFinalizationService {
  static const String _baseEndpoint = '/expense-finalization';

  /// Khởi tạo tất toán chi phí cho nhóm
  static Future<ExpenseFinalization> initiateFinalization({
    required int groupId,
    required String description,
    int deadlineDays = 7,
  }) async {
    try {
      final response = await AuthService.dio.post(
        '$_baseEndpoint/initiate',
        data: {
          'groupId': groupId,
          'description': description,
          'deadlineDays': deadlineDays,
        },
      );

      if (response.statusCode == 200 && response.data['result'] != null) {
        return ExpenseFinalization.fromJson(response.data['result']);
      } else {
        print('⚠️ API trả về lỗi: ${response.statusCode}');
        throw Exception('Failed to initiate expense finalization: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi khởi tạo tất toán chi phí: $e');
      throw Exception('Error initiating expense finalization: $e');
    }
  }

  /// Lấy danh sách tất toán của nhóm
  static Future<List<ExpenseFinalization>> getGroupFinalizations(int groupId) async {
    try {
      final response = await AuthService.dio.get('$_baseEndpoint/group/$groupId');

      if (response.statusCode == 200 && response.data['result'] != null) {
        final List<dynamic> finalizationList = response.data['result'];
        return finalizationList
            .map((json) => ExpenseFinalization.fromJson(json))
            .toList();
      } else {
        print('⚠️ API trả về lỗi: ${response.statusCode}');
        throw Exception('Failed to get group finalizations: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi lấy danh sách tất toán nhóm: $e');
      throw Exception('Error getting group finalizations: $e');
    }
  }

  /// Lấy thông tin chi tiết của một tất toán
  static Future<ExpenseFinalization> getFinalization(int finalizationId) async {
    try {
      final response = await AuthService.dio.get('$_baseEndpoint/$finalizationId');

      if (response.statusCode == 200 && response.data['result'] != null) {
        return ExpenseFinalization.fromJson(response.data['result']);
      } else {
        print('⚠️ API trả về lỗi: ${response.statusCode}');
        throw Exception('Failed to get finalization: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi lấy chi tiết tất toán: $e');
      throw Exception('Error getting finalization: $e');
    }
  }

  /// Xử lý tất toán (kiểm tra và approve/reject)
  static Future<void> processFinalization(int finalizationId) async {
    try {
      final response = await AuthService.dio.post('$_baseEndpoint/$finalizationId/process');

      if (response.statusCode != 200) {
        print('⚠️ API trả về lỗi: ${response.statusCode}');
        throw Exception('Failed to process finalization: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi xử lý tất toán: $e');
      throw Exception('Error processing finalization: $e');
    }
  }

  /// Từ chối tất toán (dành cho admin)
  static Future<void> rejectFinalization(int finalizationId) async {
    try {
      final response = await AuthService.dio.post('$_baseEndpoint/$finalizationId/reject');

      if (response.statusCode != 200) {
        print('⚠️ API trả về lỗi: ${response.statusCode}');
        throw Exception('Failed to reject finalization: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi từ chối tất toán: $e');
      throw Exception('Error rejecting finalization: $e');
    }
  }

  /// Phê duyệt tất toán (dành cho admin)
  static Future<void> approveFinalization(int finalizationId) async {
    try {
      final response = await AuthService.dio.post('$_baseEndpoint/$finalizationId/approve');

      if (response.statusCode != 200) {
        print('⚠️ API trả về lỗi: ${response.statusCode}');
        throw Exception('Failed to approve finalization: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi khi phê duyệt tất toán: $e');
      throw Exception('Error approving finalization: $e');
    }
  }

  /// Helper methods for UI

  /// Kiểm tra xem user có thể khởi tạo tất toán không
  static bool canInitiateFinalization({
    required String currentUserId,
    required String groupCreatorId,
    required List<ExpenseFinalization> existingFinalizations,
  }) {
    // Chỉ trưởng nhóm mới có thể khởi tạo
    if (currentUserId != groupCreatorId) return false;

    // Không có tất toán PENDING nào
    return !existingFinalizations.any((f) => f.isPending);
  }

  /// Lấy tất toán PENDING hiện tại của nhóm (nếu có)
  static ExpenseFinalization? getCurrentPendingFinalization(
      List<ExpenseFinalization> finalizations) {
    try {
      return finalizations.firstWhere((f) => f.isPending);
    } catch (e) {
      return null;
    }
  }

  /// Kiểm tra xem còn bao lâu đến deadline
  static Duration getTimeUntilDeadline(ExpenseFinalization finalization) {
    return finalization.deadline.difference(DateTime.now());
  }

  /// Format thời gian còn lại đến deadline
  static String formatTimeUntilDeadline(ExpenseFinalization finalization) {
    final timeLeft = getTimeUntilDeadline(finalization);
    
    if (timeLeft.isNegative) {
      return 'Đã hết hạn';
    }

    final days = timeLeft.inDays;
    final hours = timeLeft.inHours % 24;
    final minutes = timeLeft.inMinutes % 60;

    if (days > 0) {
      return '$days ngày $hours giờ';
    } else if (hours > 0) {
      return '$hours giờ $minutes phút';
    } else {
      return '$minutes phút';
    }
  }

  /// Tính % progress của responses
  static double calculateResponseProgress(ExpenseFinalization finalization) {
    if (finalization.memberResponses.isEmpty) return 0.0;
    
    final totalResponses = finalization.memberResponses.length;
    final completedResponses = finalization.memberResponses
        .where((r) => r.requestStatus != 'PENDING')
        .length;
    
    return completedResponses / totalResponses;
  }

  /// Lấy icon phù hợp với status
  static String getStatusIcon(FinalizationStatus status) {
    switch (status) {
      case FinalizationStatus.pending:
        return '⏳';
      case FinalizationStatus.approved:
        return '✅';
      case FinalizationStatus.rejected:
        return '❌';
      case FinalizationStatus.expired:
        return '⏰';
    }
  }

  /// Lấy màu phù hợp với status
  static String getStatusColor(FinalizationStatus status) {
    switch (status) {
      case FinalizationStatus.pending:
        return '#FF9800'; // Orange
      case FinalizationStatus.approved:
        return '#4CAF50'; // Green
      case FinalizationStatus.rejected:
        return '#F44336'; // Red
      case FinalizationStatus.expired:
        return '#9E9E9E'; // Grey
    }
  }
}
