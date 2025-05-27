import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await AuthService.dio.post(
        '/auth/login',
        data: {
          'username': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Timeout: Không nhận được phản hồi từ server');
      });

      final data = response.data;
      if (response.statusCode == 200 &&
          data['result'] != null &&
          data['result']['authenticated'] == true) {
        final token = data['result']['token'];
        final refreshToken = data['result']['refreshToken'];

        if (_rememberMe) {
          await AuthService.saveTokens(token, refreshToken);
        } else {
          await AuthService.saveAccessToken(token);
        }

        // ✅ Gọi loginSuccess từ AuthProvider
        if (context.mounted) {
          Provider.of<AuthProvider>(context, listen: false).loginSuccess();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng nhập thành công!')),
          );

          Navigator.pushReplacementNamed(context,
              '/main-navigation'); // Chuyển tới MainNavigation sau khi login
        }
      } else {
        final message = data['message'] ?? 'Đăng nhập thất bại!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      String errorMessage = 'Lỗi kết nối hoặc đăng nhập!';

      if (e is DioException && e.response != null) {
        final statusCode = e.response?.statusCode;
        final serverMessage = e.response?.data['message'];

        if (statusCode == 401) {
          errorMessage = 'Sai tên đăng nhập hoặc mật khẩu!';
        } else if (serverMessage != null) {
          errorMessage = serverMessage.toString();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $errorMessage')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 12, top: 2),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
              children: [
                TextSpan(
                  text: 'i',
                  style: TextStyle(
                    color: Color(0xFF764ba2),
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Color(0xFF764ba2).withOpacity(0.18),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                TextSpan(
                  text: 'Share',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    letterSpacing: 1.2,
                  ),
                ),
                TextSpan(
                  text: 'Money',
                  style: TextStyle(
                    color: Color(0xFF43A047), // xanh lá
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                    const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22223B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Vui lòng nhập tên đăng nhập'
                      : null,
                ),
                    const SizedBox(height: 18),
                TextFormField(
                  controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                  obscureText: true,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Vui lòng nhập mật khẩu'
                      : null,
                ),
                    const SizedBox(height: 18),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) =>
                          setState(() => _rememberMe = value ?? false),
                    ),
                    const Text('Ghi nhớ tôi'),
                  ],
                ),
                const SizedBox(height: 24),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF667eea).withOpacity(0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: _isLoading ? null : _login,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.login, color: Colors.white),
                                        SizedBox(width: 10),
                                        Text(
                                          'Đăng nhập',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                  ),
                ),
                    const SizedBox(height: 24),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                  child: const Text('Bạn chưa có tài khoản? Đăng ký'),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          );
                        },
                  child: const Text('Quên mật khẩu?'),
                ),
              ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
