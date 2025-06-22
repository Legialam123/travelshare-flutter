// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:travel_share/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dob.text = picked.toIso8601String().split('T').first;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.register({
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text.trim(),
        'dob': _dob.text.trim(),
        'fullName': _fullName.text.trim(),
        'phoneNumber': _phone.text.trim(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Đăng ký thành công ! Vui lòng vào email của bạn để xác thực')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      String errorMessage = 'Lỗi không xác định';
      if (e is DioException) {
        if (e.response != null && e.response?.data != null) {
          // Nếu backend trả về JSON với trường 'message'
          errorMessage = e.response?.data['message'] ?? errorMessage;
        } else {
          errorMessage = e.message ?? errorMessage;
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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 12, top: 2),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat'),
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
                    color: Color(0xFF43A047),
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
                      'Đăng ký',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF22223B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _textField(_username, 'Tên đăng nhập', minLength: 6),
                    _textField(_email, 'Email', email: true),
                    _textField(_password, 'Mật khẩu',
                        obscure: true, minLength: 6),
                    _textField(_fullName, 'Họ và tên'),
                    _textField(_phone, 'Số điện thoại', phone: true),
                    TextFormField(
                      controller: _dob,
                      decoration: const InputDecoration(
                          labelText: 'Ngày sinh (yyyy-MM-dd)'),
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Chọn ngày sinh' : null,
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
                            onTap: _isLoading ? null : _submit,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 14),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.app_registration,
                                            color: Colors.white),
                                        SizedBox(width: 10),
                                        Text(
                                          'Đăng ký',
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
                              Navigator.pop(context);
                            },
                      child: const Text('Đã có tài khoản? Đăng nhập'),
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

  Widget _textField(TextEditingController c, String label,
      {bool obscure = false,
      bool email = false,
      bool phone = false,
      int minLength = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label),
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        validator: (value) {
          if (value == null || value.isEmpty) return 'Không được để trống';
          if (minLength > 1 && value.length < minLength)
            return 'Tối thiểu $minLength ký tự';
          if (email && !value.contains('@')) return 'Email không hợp lệ';
          if (phone && value.length != 10) return 'Số điện thoại phải 10 số';
          return null;
        },
      ),
    );
  }
}
