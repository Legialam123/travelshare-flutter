import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;

  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;

  // Kiểm tra trạng thái đăng nhập khi khởi chạy app
  Future<void> checkLoginStatus() async {
    final token = await AuthService.getAccessToken();
    if (token != null) {
      _isLoggedIn = true;
      await _fetchCurrentUser();
    } else {
      _isLoggedIn = false;
    }
    notifyListeners();
  }

  // Đánh dấu đăng nhập thành công (ví dụ sau login hoặc refresh token)
  Future<void> loginSuccess() async {
    _isLoggedIn = true;
    await _fetchCurrentUser();
    notifyListeners();
  }

  // Đăng xuất người dùng: gọi API logout, xoá token, điều hướng về Login
  Future<void> logout(BuildContext context) async {
    final accessToken = await AuthService.getAccessToken();
    final refreshToken = await AuthService.getRefreshToken();

    try {
      if (accessToken != null && refreshToken != null) {
        await AuthService.dio.post('/auth/logout', data: {
          'token': accessToken,
          'refreshToken': refreshToken,
        });
      }
    } catch (e) {
      print('❌ Lỗi gọi API logout: $e');
    }

    await AuthService.clearTokens();
    _isLoggedIn = false;
    _currentUser = null;
    notifyListeners();

    // Điều hướng về màn hình đăng nhập, xoá toàn bộ navigation stack
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // Lấy thông tin người dùng hiện tại
  Future<void> _fetchCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
      }
    } catch (e) {
      print('❌ Lỗi khi lấy thông tin người dùng: $e');
    }
  }

  // Cập nhật user thủ công nếu cần
  void setUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }
}
