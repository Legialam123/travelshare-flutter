import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:dio/dio.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _identifierController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await AuthService.forgotPassword(_identifierController.text.trim());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi link đặt lại mật khẩu tới email của bạn!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      String errorMessage = 'Lỗi không xác định';
      if (e is DioException) {
        if (e.response != null && e.response?.data != null) {
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
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _identifierController,
                  decoration: const InputDecoration(
                      labelText: 'Email hoặc tên đăng nhập'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Vui lòng nhập email hoặc tên đăng nhập'
                      : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendResetLink,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Gửi link đặt lại mật khẩu'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
