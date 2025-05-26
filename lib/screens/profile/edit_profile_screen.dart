import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import 'package:flutter/services.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _dob;
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    setState(() {
      _user = user;
      _nameController.text = user?.fullName ?? '';
      _phoneController.text = user?.phoneNumber ?? '';
      _dob = user?.dob;
      _isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final userId = _user?.id;
      final response = await AuthService.dio.put('/users/$userId', data: {
        'fullName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'dob': _dob?.toIso8601String(),
      });

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thành công')),
        );
        Navigator.pop(context, true);
        setState(() => _isEditing = false);
        _loadUser(); // Reload thông tin mới
      } else {
        throw Exception('Update thất bại');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật: $e')),
      );
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _nameController.text = _user?.fullName ?? '';
      _phoneController.text = _user?.phoneNumber ?? '';
      _dob = _user?.dob;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh sửa' : 'Thông tin cá nhân', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
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
        actions: [
          if (!_isLoading)
            _isEditing
                ? Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check),
                        tooltip: 'Lưu thay đổi',
                        onPressed: _saveChanges,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Huỷ bỏ',
                        onPressed: _cancelEditing,
                      ),
                    ],
                  )
                : IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Chỉnh sửa',
                    onPressed: () => setState(() => _isEditing = true),
                  )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Họ tên",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _isEditing
                        ? TextFormField(
                            controller: _nameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Không được để trống';
                              }
                              if (RegExp(r'\d').hasMatch(value)) {
                                return 'Họ tên không được chứa số';
                              }
                              return null;
                            },
                          )
                        : Text(_user?.fullName ?? '',
                            style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 24),
                    const Text("Email",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_user?.email ?? '',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 24),
                    const Text("Số điện thoại",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _isEditing
                        ? TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return null; // Cho phép trống nếu muốn
                              }
                              if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                                return 'Số điện thoại phải đúng 10 chữ số';
                              }
                              return null;
                            },
                          )
                        : Text(_user?.phoneNumber ?? 'Chưa có',
                            style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 24),
                    const Text("Ngày sinh",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _isEditing
                        ? InkWell(
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _dob ?? DateTime(2000),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  _dob = pickedDate;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.all(12),
                              ),
                              child: Text(
                                _dob != null
                                    ? "${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}"
                                    : 'Chọn ngày sinh',
                              ),
                            ),
                          )
                        : Text(
                            _dob != null
                                ? "${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}"
                                : 'Chưa có',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
