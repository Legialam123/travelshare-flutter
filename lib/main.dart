import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'services/auth_service.dart' show AuthService, navigatorKey;
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load();
    await AuthService.init();
  } catch (e) {
    print('❌ Lỗi khi load .env hoặc khởi tạo Dio: $e');
  }

  // Kiểm tra token trước khi chạy app
  final token = await AuthService.getAccessToken();
  final refreshToken = await AuthService.getRefreshToken();

  bool isLoggedIn = false;

  if (token != null && token.isNotEmpty && !JwtDecoder.isExpired(token)) {
    // Token còn hạn → dùng luôn
    print('✅ Access token còn hạn');
    isLoggedIn = true;
  } else if (refreshToken != null && refreshToken.isNotEmpty) {
    // Token hết hạn → thử refresh
    try {
      final response = await AuthService.dio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      final result = response.data['result'];
      if (response.statusCode == 200 &&
          result != null &&
          result['token'] != null &&
          result['refreshToken'] != null) {
        await AuthService.saveTokens(
          result['token'],
          result['refreshToken'],
        );
        print('🔁 Đã refresh token thành công');
        isLoggedIn = true;
      } else {
        await AuthService.clearTokens();
        print('⚠️ Refresh token không hợp lệ – đã xoá token');
      }
    } catch (e) {
      print('❌ Lỗi khi refresh token: $e');
      await AuthService.clearTokens();
    }
  } else {
    await AuthService.clearTokens();
    print('⚠️ Không có token hợp lệ – đăng nhập lại');
  }

  // Chạy ứng dụng với điều kiện login status
  runApp(TravelShareApp(isLoggedIn: isLoggedIn, navigatorKey: navigatorKey));
}
