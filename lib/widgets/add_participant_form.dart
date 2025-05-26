import 'package:flutter/material.dart';
import 'package:travel_share/services/auth_service.dart';

class AddParticipantForm extends StatefulWidget {
  final int groupId;
  final VoidCallback? onSuccess;

  const AddParticipantForm({
    Key? key,
    required this.groupId,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<AddParticipantForm> createState() => _AddParticipantFormState();
}

class _AddParticipantFormState extends State<AddParticipantForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'MEMBER';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    try {
      final data = {
        "groupId": widget.groupId,
        "name": name,
        "role": _selectedRole,
        if (email.isNotEmpty) "email": email,
      };

      final response = await AuthService.dio.post(
        '/group/${widget.groupId}/participant',
        data: data,
      );

      if (!mounted) return;
      Navigator.pop(context); // Đóng form
      // Gọi callback để reload danh sách
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đã thêm thành viên')),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đã thêm thành viên')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi khi thêm: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Thêm thành viên mới",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Tên hiển thị"),
                validator: (value) => value == null || value.isEmpty
                    ? 'Không được bỏ trống'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email người dùng (tuỳ chọn)",
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: "Vai trò"),
                items: ['MEMBER', 'ADMIN']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedRole = value);
                },
              ),
              const SizedBox(height: 16),
              _isSubmitting
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submitForm,
                      child: const Text("Thêm thành viên"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
