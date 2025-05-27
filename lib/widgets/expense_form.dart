import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

class ExpenseForm extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final bool isEdit;
  final Future<void> Function(
      Map<String, dynamic> data, List<XFile> newAttachments) onSubmit;

  const ExpenseForm({
    Key? key,
    this.initialData,
    this.isEdit = false,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _dateFormatter = DateFormat('dd/MM/yyyy');
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedCategory;
  String _splitType = 'EQUAL';
  int? _selectedPayerId;
  DateTime _selectedDate = DateTime.now();

  List<XFile> _newAttachments = [];
  List<Map<String, dynamic>> _existingAttachments = [];
  List<Map<String, dynamic>> _splits = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _titleController.text = d['title'] ?? '';
      _descriptionController.text = d['description'] ?? '';
      _amountController.text = d['amount']?.toString() ?? '';
      _selectedCategory = d['category']?['id']?.toString();
      _splitType = d['splitType'] ?? 'EQUAL';
      _selectedPayerId = d['payer']?['id'];
      _selectedDate =
          DateTime.tryParse(d['expenseDate'] ?? '') ?? DateTime.now();
      _existingAttachments =
          List<Map<String, dynamic>>.from(d['attachments'] ?? []);
      _splits = List<Map<String, dynamic>>.from(
        (d['splits'] ?? []).map((s) => {
              'participantId': s['participant']['id'],
              'amount': s['amount']?.toString() ?? '',
              'percentage': s['percentage']?.toString() ?? '',
            }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Tên chi phí'),
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
              validator: (val) => val == null || double.tryParse(val) == null
                  ? 'Nhập số hợp lệ'
                  : null,
            ),
            const SizedBox(height: 12),
            Text('Ngày chi tiêu: ${_dateFormatter.format(_selectedDate)}'),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: const Text('Chọn ngày'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final images = await _picker.pickMultiImage();
                if (images.isNotEmpty) {
                  setState(() => _newAttachments.addAll(images));
                }
              },
              icon: const Icon(Icons.image),
              label: const Text('Chọn ảnh đính kèm'),
            ),
            if (_existingAttachments.isNotEmpty ||
                _newAttachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('📸 Ảnh minh chứng:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ..._existingAttachments.map((att) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              att['fileUrl'],
                              width: 115,
                              height: 108,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _existingAttachments.remove(att);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      )),
                  ..._newAttachments.map((f) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(f.path),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      )),
                ],
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final formData = {
                    'title': _titleController.text.trim(),
                    'description': _descriptionController.text.trim(),
                    'amount':
                        double.tryParse(_amountController.text.trim()) ?? 0,
                    'expenseDate': _selectedDate.toIso8601String(),
                    'splitType': _splitType,
                    'category': _selectedCategory,
                    'payerId': _selectedPayerId,
                    'splits': _splits,
                    'existingAttachments': _existingAttachments,
                  };
                  widget.onSubmit(formData, _newAttachments);
                }
              },
              child: Text(widget.isEdit ? 'Cập nhật' : 'Tạo chi phí'),
            ),
          ],
        ),
      ),
    );
  }
}
