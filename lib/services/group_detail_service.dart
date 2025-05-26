import 'package:dio/dio.dart';
import '../services/auth_service.dart';

class GroupDetailService {
  static Future<Map<String, dynamic>> fetchGroupDetail(int groupId) async {
    final response = await AuthService.dio.get('/group/$groupId');
    return response.data['result'];
  }

  static Future<List<dynamic>> fetchExpenses(int groupId) async {
    final response = await AuthService.dio.get('/expense/group/$groupId');
    return response.data['result'] ?? [];
  }

  static Future<List<dynamic>> fetchSettlements(int groupId) async {
    final response =
        await AuthService.dio.get('/settlement/group/$groupId/suggested');
    return response.data['result'] ?? [];
  }

  static Future<List<dynamic>> fetchBalances(int groupId) async {
    final response =
        await AuthService.dio.get('/settlement/group/$groupId/balances');
    return response.data['result'] ?? [];
  }

  static Future<List<dynamic>> fetchPhotos(int groupId) async {
    final response = await AuthService.dio.get(
      '/media/group/$groupId',
      queryParameters: {'type': 'IMAGE'},
    );
    return response.data['result'] ?? [];
  }

  static Future<void> deleteMedia(int mediaId) async {
    await AuthService.dio.delete('/media/$mediaId');
  }
}
