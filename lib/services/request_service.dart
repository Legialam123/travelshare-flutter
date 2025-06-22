import 'package:dio/dio.dart';
import '../models/request.dart';
import 'auth_service.dart';

class RequestService {
  /// Lấy danh sách yêu cầu bạn nhận vào
  static Future<List<RequestModel>> fetchReceivedRequests() async {
    final response = await AuthService.dio.get('/request/my');
    final List data = response.data['result'];
    return data.map((e) => RequestModel.fromJson(e)).toList();
  }

  /// Lấy danh sách yêu cầu bạn đã gửi đi
  static Future<List<RequestModel>> fetchSentRequests() async {
    final response = await AuthService.dio.get('/request/sent');
    final List data = response.data['result'];
    return data.map((e) => RequestModel.fromJson(e)).toList();
  }

  /// Chấp nhận yêu cầu
  static Future<RequestModel> acceptRequest(int requestId) async {
    final response = await AuthService.dio.post('/request/$requestId/accept');
    return RequestModel.fromJson(response.data['result']);
  }

  /// Từ chối yêu cầu
  static Future<RequestModel> declineRequest(int requestId) async {
    final response = await AuthService.dio.post('/request/$requestId/decline');
    return RequestModel.fromJson(response.data['result']);
  }

  /// Hủy yêu cầu
  static Future<void> cancelRequest(int requestId) async {
    final response = await AuthService.dio.patch('/request/$requestId/cancel');
    if (response.statusCode != 200) {
      throw Exception('Hủy yêu cầu thất bại');
    }
  }

  /// Gửi yêu cầu xác nhận thanh toán (PAYMENT_CONFIRM)
  static Future<void> sendPaymentConfirm(int requestId) async {
    final response = await AuthService.dio.post('/request/$requestId/payment-confirm');
    if (response.statusCode != 200) {
      throw Exception('Gửi yêu cầu xác nhận thanh toán thất bại');
    }
  }

  /// Lấy link thanh toán VNPay cho PAYMENT_REQUEST
  static Future<String?> getVnPayUrl(int requestId) async {
    final response = await AuthService.dio.get('/request/$requestId/vnpay-url');
    if (response.statusCode == 200 && response.data['result'] != null) {
      return response.data['result']['paymentUrl'] as String?;
    }
    return null;
  }
}
