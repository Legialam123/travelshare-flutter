import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/group.dart';
import '../../../models/category.dart';
import '../../../services/auth_service.dart';
import '../../../services/category_service.dart';
import '../../../utils/color_utils.dart';
import '../../../utils/icon_utils.dart';
import 'package:intl/intl.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

class AddExpenseScreen extends StatefulWidget {
  final int groupId;
  final List<GroupParticipant>? participants;
  final String? currentUserId;

  const AddExpenseScreen({
    Key? key,
    required this.groupId,
    this.participants,
    this.currentUserId,
  }) : super(key: key);

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedCategoryId;
  String _splitType = 'EQUAL';
  int? _selectedPayerId;
  DateTime _selectedDate = DateTime.now();
  List<XFile> _attachments = [];

  List<Map<String, dynamic>> _splits = [];
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedPayerId = widget.participants?.first.id;
    _splits = widget.participants?.map((p) {
          return {
            'participantId': p.id,
            'amount': '',
            'percentage': '',
          };
        }).toList() ??
        [];
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories =
          await CategoryService.fetchGroupExpenseCategories(widget.groupId);
      setState(() {
        _categories = categories;
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id.toString();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi khi tải danh mục: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAttachments() async {
    if (_attachments.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ được chọn tối đa 5 ảnh.')),
      );
      return;
    }
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        final remain = 5 - _attachments.length;
        _attachments.addAll(images.take(remain));
      });
    }
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedIcon = 'category'; // Mã icon mặc định
    String selectedColor = '#2196F3'; // Màu mặc định

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Thêm danh mục mới"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Tên danh mục"),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: "Mô tả"),
              ),
              const SizedBox(height: 16),
              /*Row(
                children: [
                  CircleAvatar(
                    backgroundColor: HexColor.fromHex(selectedColor),
                    child: Icon(Icons.category, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text("Icon và màu mặc định")
                ],
              )*/
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Huỷ"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();
              if (name.isEmpty) return;

              try {
                final data = {
                  'name': name,
                  'description': description,
                  'iconCode': selectedIcon,
                  'color': selectedColor,
                };

                final newCategory =
                    await CategoryService.createExpenseCategoryForGroup(
                        widget.groupId, data);
                setState(() {
                  _categories.add(newCategory);
                  _selectedCategoryId = newCategory.id.toString();
                });

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Đã thêm danh mục mới')),
                  );
                }
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Lỗi khi tạo danh mục: $e')),
                );
              }
            },
            child: const Text("Thêm"),
          ),
        ],
      ),
    );
  }

  MediaType _getMediaType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.gif':
        return MediaType('image', 'gif');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  int _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  Future<void> _selectExpenseDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Validate the selected payer
    if (_splitType == 'AMOUNT') {
      final totalSplitAmount = _splits.fold<double>(
        0,
        (sum, s) => sum + (double.tryParse(s['amount'] ?? '0') ?? 0),
      );
      final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0;
      if (totalSplitAmount.toStringAsFixed(2) !=
          totalAmount.toStringAsFixed(2)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tổng tiền chia không khớp với số tiền.')),
        );
        return;
      }
    }

    if (_splitType == 'PERCENTAGE') {
      final totalPercentage = _splits.fold<double>(
        0,
        (sum, s) => sum + (double.tryParse(s['percentage'] ?? '0') ?? 0),
      );
      if (totalPercentage.toStringAsFixed(2) != '100.00') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tổng phần trăm chia phải bằng 100%.')),
        );
        return;
      }
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục')),
      );
      return;
    }

    final data = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'amount': double.parse(_amountController.text.trim()),
      'category': int.parse(_selectedCategoryId!),
      'splitType': _splitType,
      'participantId': _selectedPayerId,
      'groupId': widget.groupId,
      'expenseDate': _selectedDate.toIso8601String(),
      'currency': 'VND',
      'splits': _splitType == 'EQUAL'
          ? null
          : _splits.map((s) {
              final id = s['participantId'];
              return {
                'participantId': id,
                if (_splitType == 'AMOUNT')
                  'amount': double.tryParse(s['amount'] ?? '0') ?? 0,
                if (_splitType == 'PERCENTAGE')
                  'percentage': double.tryParse(s['percentage'] ?? '0') ?? 0,
              };
            }).toList(),
    };

    try {
      final res = await AuthService.dio.post('/expense', data: data);
      final expenseId = res.data['result']['id'];

      if (_attachments.isNotEmpty) {
        for (var file in _attachments) {
          final formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              file.path,
              filename: file.name,
              contentType: _getMediaType(file.path),
            ),
            'description': 'expense_attachment',
          });
          await AuthService.dio
              .post('/media/expense/$expenseId', data: formData);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tạo expense: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm chi phí mới',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration:
                          const InputDecoration(labelText: 'Tên chi phí'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Không để trống' : null,
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                    ),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Số tiền'),
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          val == null || double.tryParse(val) == null
                              ? 'Nhập số hợp lệ'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      readOnly: true,
                      controller: TextEditingController(
                          text: DateFormat('dd/MM/yyyy').format(_selectedDate)),
                      decoration:
                          const InputDecoration(labelText: 'Ngày chi tiêu'),
                      onTap: _selectExpenseDate,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Danh mục'),
                      items: [
                        ..._categories.map((c) => DropdownMenuItem(
                              value: c.id.toString(),
                              child: Row(
                                children: [
                                  if (c.iconCode != null)
                                    Icon(
                                      getIconDataFromCode(c.iconCode),
                                      color: HexColor.fromHex(
                                          c.color ?? '#000000'),
                                      size: 20,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            )),
                        const DropdownMenuItem<String>(
                          value: '__add_new__',
                          child: Row(
                            children: [
                              Icon(Icons.add, color: Colors.deepPurple),
                              SizedBox(width: 6),
                              Text('Thêm danh mục mới'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == '__add_new__') {
                          _showAddCategoryDialog(context);
                        } else {
                          setState(() => _selectedCategoryId = value);
                        }
                      },
                      validator: (value) =>
                          value == null ? 'Vui lòng chọn danh mục' : null,
                    ),
                    DropdownButtonFormField<String>(
                      value: _splitType,
                      items: ['EQUAL', 'AMOUNT', 'PERCENTAGE']
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _splitType = v!),
                      decoration:
                          const InputDecoration(labelText: 'Kiểu chia tiền'),
                    ),
                    DropdownButtonFormField<int>(
                      value: _selectedPayerId,
                      items: widget.participants
                              ?.map((p) => DropdownMenuItem(
                                  value: p.id, child: Text(p.name)))
                              .toList() ??
                          [],
                      onChanged: (v) => setState(() => _selectedPayerId = v),
                      decoration:
                          const InputDecoration(labelText: 'Người thanh toán'),
                    ),
                    const SizedBox(height: 12),
                    if (_splitType != 'EQUAL')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _splits.map((s) {
                          final participant = widget.participants
                              ?.firstWhere((p) => p.id == s['participantId']);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: _splitType == 'AMOUNT'
                                    ? 'Số tiền (${participant?.name})'
                                    : 'Phần trăm (${participant?.name})',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setState(() {
                                if (_splitType == 'AMOUNT') {
                                  s['amount'] = v;
                                } else {
                                  s['percentage'] = v;
                                }
                              }),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _attachments.length >= 5 ? null : _pickAttachments,
                      child: Container(
                        width: double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Color(0xFF764ba2).withOpacity(0.12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: Color(0xFF764ba2), size: 26),
                            const SizedBox(width: 8),
                            Text(
                              'Thêm ảnh minh chứng',
                              style: TextStyle(
                                  color: Color(0xFF764ba2),
                                  fontWeight: FontWeight.w600),
                            ),
                            if (_attachments.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  '(${_attachments.length}/5)',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _attachments.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final file = _attachments[index];
                          return Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => _ImagePreviewDialog(
                                      attachments: _attachments,
                                      initialPage: index,
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(file.path),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(
                                        () => _attachments.removeAt(index));
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
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
                              color: const Color(0xFF667eea).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: _submit,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text(
                                    'Xác nhận',
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
                  ],
                ),
              ),
            ),
    );
  }
}

class _ImagePreviewDialog extends StatefulWidget {
  final List<XFile> attachments;
  final int initialPage;
  const _ImagePreviewDialog(
      {required this.attachments, required this.initialPage});
  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  late PageController _controller;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _controller = PageController(initialPage: widget.initialPage);
    _controller.addListener(() {
      final page = _controller.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.attachments.length,
            itemBuilder: (context, pageIndex) {
              return Center(
                child: InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(widget.attachments[pageIndex].path)),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 32,
            right: 32,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentPage + 1}/${widget.attachments.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
