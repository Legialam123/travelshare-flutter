// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:travel_share/services/auth_service.dart';
import 'package:dio/dio.dart';

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
      appBar: AppBar(title: const Text('Đăng ký')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _textField(_username, 'Tên đăng nhập', minLength: 6),
              _textField(_email, 'Email', email: true),
              _textField(_password, 'Mật khẩu', obscure: true, minLength: 6),
              _textField(_fullName, 'Họ và tên'),
              _textField(_phone, 'Số điện thoại', phone: true),
              TextFormField(
                controller: _dob,
                decoration:
                    const InputDecoration(labelText: 'Ngày sinh (yyyy-MM-dd)'),
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Chọn ngày sinh' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Đăng ký'),
                ),
              ),
            ],
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
