import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';

/// Global key dùng để điều hướng toàn cục khi logout
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AuthService {
  static late Dio dio;
  static String? _tempAccessToken;
  static final FlutterSecureStorage storage = const FlutterSecureStorage();

  static Future<void> init() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('API_BASE_URL không được cấu hình trong file .env');
    }
    dio = Dio(BaseOptions(baseUrl: baseUrl));

    dio.interceptors.clear();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getAccessToken();
        final isAuthRoute = options.path.contains('/auth/login') ||
            options.path.contains('/auth/register') ||
            options.path.contains('/auth/refresh');

        if (!isAuthRoute && token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401) {
          final refreshToken = await storage.read(key: 'refreshToken');

          if (refreshToken != null) {
            try {
              final refreshResponse = await dio.post('/auth/refresh', data: {
                'refreshToken': refreshToken,
              });

              if (refreshResponse.statusCode == 200 &&
                  refreshResponse.data['result'] != null) {
                final newToken = refreshResponse.data['result']['token'];
                final newRefreshToken =
                    refreshResponse.data['result']['refreshToken'];

                await saveTokens(newToken, newRefreshToken);

                e.requestOptions.headers['Authorization'] = 'Bearer $newToken';

                try {
                  final cloneReq = await dio.fetch(e.requestOptions);
                  return handler.resolve(cloneReq);
                } catch (_) {
                  await _forceLogout(); // Nếu gửi lại request thất bại, logout
                  return handler.reject(e);
                }
              }
            } catch (_) {
              await _forceLogout(); // refresh token sai → logout
              return handler.reject(e);
            }
          }

          // Không có refreshToken → logout
          await _forceLogout();
          return handler.reject(e);
        }

        handler.next(e);
      },
    ));
  }

  /// ✅ Logout & điều hướng về màn login
  static Future<void> _forceLogout() async {
    await clearTokens();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  static Future<void> saveTokens(
      String accessToken, String refreshToken) async {
    await storage.write(key: 'accessToken', value: accessToken);
    await storage.write(key: 'refreshToken', value: refreshToken);
  }

  static Future<void> saveAccessToken(String token) async {
    _tempAccessToken = token;
  }

  static Future<void> clearTokens() async {
    _tempAccessToken = null;
    await storage.delete(key: 'accessToken');
    await storage.delete(key: 'refreshToken');
  }

  static Future<String?> getAccessToken() async {
    if (_tempAccessToken != null) {
      return _tempAccessToken;
    }
    return await storage.read(key: 'accessToken');
  }

  static Future<String?> getRefreshToken() async {
    return storage.read(key: 'refreshToken');
  }

  static Future<String?> getCurrentUsername() async {
    final token = await getAccessToken();
    if (token == null) return null;
    final decoded = JwtDecoder.decode(token);
    return decoded['sub'] ?? decoded['username'];
  }

  static Future<String?> getCurrentFullName() async {
    final token = await getAccessToken();
    if (token == null) return null;

    try {
      final response = await dio.get('/users/me');
      if (response.statusCode == 200 && response.data['result'] != null) {
        return response.data['result']['fullName'];
      }
    } catch (e) {
      print('Lỗi lấy full name: $e');
    }

    return null;
  }

  static Future<User?> getCurrentUser() async {
    final token = await getAccessToken();
    if (token == null) return null;

    try {
      final response = await dio.get('/users/me');
      if (response.statusCode == 200 && response.data['result'] != null) {
        return User.fromJson(response.data['result']);
      }
    } catch (e) {
      print('Lỗi getCurrentUser: $e');
    }

    return null;
  }

  static Future<void> register(Map<String, dynamic> data) async {
    final response = await dio.post('/users', data: data);
    if (response.statusCode != 200) {
      throw Exception('Lỗi đăng ký: ${response.data}');
    }
  }

  static Future<void> forgotPassword(String identifier) async {
    final response = await dio.post('/auth/forgot-password', data: {
      'identifier': identifier,
    });

    if (response.statusCode != 200) {
      throw Exception('Lỗi gửi email: ${response.data}');
    }
  }

  static Future<String?> getCurrentEmail() async {
    final token = await getAccessToken();
    if (token == null) return null;
    try {
      final response = await dio.get('/users/me');
      if (response.statusCode == 200 && response.data['result'] != null) {
        return response.data['result']['email'];
      }
    } catch (e) {
      print('Lỗi lấy email: $e');
    }
    return null;
  }

  static Future<bool> checkEmailExists(String email) async {
    final response =
        await dio.get('/users/check-email', queryParameters: {'email': email});
    if (response.statusCode == 200) {
      return response.data == true || response.data == 'true';
    }
    throw Exception('Lỗi kiểm tra email');
  }
}
