import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../../models/group.dart';
import '../../services/auth_service.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../utils/icon_utils.dart';
import '../../utils/color_utils.dart';

class EditGroupForm extends StatefulWidget {
  final Group group;
  final VoidCallback? onUpdated;

  const EditGroupForm({Key? key, required this.group, this.onUpdated})
      : super(key: key);

  @override
  State<EditGroupForm> createState() => _EditGroupFormState();
}

class _EditGroupFormState extends State<EditGroupForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedCurrency;
  XFile? _pickedImage;
  List<Category> _categories = [];
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _selectedCurrency = widget.group.defaultCurrency;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await CategoryService.fetchGroupCategories();
      for (var cat in cats) {}
      setState(() {
        _categories = cats;
        if (widget.group.categoryId != null && cats.isNotEmpty) {
          _selectedCategory = cats.firstWhere(
            (c) => c.id == widget.group.categoryId,
            orElse: () => cats.first,
          );
        } else if (cats.isNotEmpty) {
          _selectedCategory = cats.first;
        } else {
          _selectedCategory = null;
        }
      });
    } catch (e) {
      // Có thể show lỗi hoặc để trống danh mục
      print('Error loading categories: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool fromCamera) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (image != null) {
      setState(() => _pickedImage = image);
    }
  }

  MediaType _getMediaType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  void _showImageSourceMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Chụp từ camera'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadAvatar() async {
    if (_pickedImage == null) return;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        _pickedImage!.path,
        filename: _pickedImage!.name,
        contentType: _getMediaType(_pickedImage!.path),
      ),
      'description': 'avatar',
    });

    await AuthService.dio
        .post('/media/group/${widget.group.id}', data: formData);
  }

  Future<void> _updateGroupInfo() async {
    final data = {
      'name': _nameController.text.trim(),
      'categoryId': _selectedCategory?.id,
    };
    await AuthService.dio.put('/group/${widget.group.id}', data: data);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Sửa thông tin nhóm",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: _pickedImage != null
                          ? FileImage(File(_pickedImage!.path))
                          : (widget.group.avatarUrl != null &&
                                  widget.group.avatarUrl!.startsWith('http'))
                              ? NetworkImage(widget.group.avatarUrl!)
                              : AssetImage(widget.group.avatarUrl!)
                                  as ImageProvider,
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: GestureDetector(
                      onTap: () {
                        _showImageSourceMenu(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                        ),
                        child: const Icon(Icons.edit,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Tên nhóm"),
                validator: (value) => value == null || value.isEmpty
                    ? 'Không được để trống'
                    : null,
              ),
              const SizedBox(height: 8),
              // Đã loại bỏ trường chỉnh sửa tiền tệ
              const SizedBox(height: 8),
              DropdownButtonFormField<Category>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: "Danh mục nhóm"),
                items: _categories.isNotEmpty
                    ? _categories
                        .map((c) => DropdownMenuItem<Category>(
                              value: c,
                              child: Row(
                                children: [
                                  Icon(
                                    getIconDataFromCode(c.iconCode),
                                    size: 24,
                                    color:
                                        c.color != null && c.color!.isNotEmpty
                                            ? getColorFromHex(c.color!)
                                            : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            ))
                        .toList()
                    : [
                        const DropdownMenuItem<Category>(
                          value: null,
                          child: Text('Không có danh mục'),
                        ),
                      ],
                onChanged: _categories.isNotEmpty
                    ? (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    : null,
                validator: (value) =>
                    value == null ? 'Vui lòng chọn danh mục' : null,
                disabledHint: const Text('Không có danh mục'),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () async {
                        if (_formKey.currentState?.validate() ?? false) {
                          await _uploadAvatar();
                          await _updateGroupInfo();

                          if (widget.onUpdated != null) {
                            widget.onUpdated!();
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "✅ Chỉnh sửa thông tin nhóm thành công"),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              Navigator.pop(context);
                            }
                          }
                        }
                      },
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Lưu thay đổi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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
            ],
          ),
        ),
      ),
    );
  }
}
