import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import '../../services/auth_service.dart';
import 'package:flutter/services.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _passwordMatchError;

  void _checkPasswordMatch(String _) {
    setState(() {
      if (_confirmPasswordController.text != _newPasswordController.text) {
        _passwordMatchError = "❌ Mật khẩu xác nhận không khớp";
      } else {
        _passwordMatchError = null;
      }
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = await AuthService.getCurrentUser();
      final userId = user?.id;
      final data = {
        "oldPassword": _oldPasswordController.text.trim(),
        "newPassword": _newPasswordController.text.trim(),
      };

      final url = "/users/$userId";

      await AuthService.dio.put(url, data: data);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Đổi mật khẩu thành công")),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      String message = "Lỗi không xác định";

      if (e.response != null && e.response!.data is Map) {
        message = e.response!.data["message"] ?? message;
      } else if (e.message != null) {
        message = e.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $message")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Đổi mật khẩu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Mật khẩu cũ
              TextFormField(
                controller: _oldPasswordController,
                obscureText: _obscureOld,
                decoration: InputDecoration(
                  labelText: "Mật khẩu hiện tại",
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureOld ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureOld = !_obscureOld),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? "Vui lòng nhập mật khẩu hiện tại"
                    : null,
              ),

              const SizedBox(height: 16),

              // Mật khẩu mới
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: "Mật khẩu mới",
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (value) => value == null || value.length < 6
                    ? "Mật khẩu phải ít nhất 6 ký tự"
                    : null,
                onChanged: _checkPasswordMatch,
              ),

              const SizedBox(height: 16),

              // Xác nhận mật khẩu mới
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: "Xác nhận mật khẩu",
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                onChanged: _checkPasswordMatch,
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return "Mật khẩu xác nhận không khớp";
                  }
                  return null;
                },
              ),

              if (_passwordMatchError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _passwordMatchError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _submit,
                child: const Text("Xác nhận"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
