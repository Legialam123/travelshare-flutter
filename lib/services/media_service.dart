import 'package:dio/dio.dart';
import 'auth_service.dart';

class MediaService {
  static Future<String?> fetchUserAvatar(String userId) async {
    try {
      final response = await AuthService.dio.get('/media/user/$userId');

      if (response.statusCode == 200) {
        final result = response.data['result'];
        if (result != null && result is List && result.isNotEmpty) {
          return result[0]['fileUrl'];
        }
      }
    } catch (e) {
      print('Lỗi khi load avatar: $e');
    }

    return null;
  }
}
