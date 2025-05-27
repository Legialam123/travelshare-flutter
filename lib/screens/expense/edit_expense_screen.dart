import 'dart:io';
import 'dart:async'; // 🔧 Thêm import cho Timer
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../services/auth_service.dart';
import '../../../services/category_service.dart';
import '../../../models/category.dart';
import '../../../utils/color_utils.dart';
import '../../../utils/icon_utils.dart';
import 'package:flutter/services.dart';

int? _groupId;

// Hàm replaceBaseUrl dùng chung cho mọi class trong file
String replaceBaseUrl(String? url) {
  if (url == null) return '';
  final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
  return url.replaceFirst(
      RegExp(r'^https?://localhost:8080/TravelShare'), apiBaseUrl);
}

class EditExpenseScreen extends StatefulWidget {
  final int expenseId;
  const EditExpenseScreen({Key? key, required this.expenseId})
      : super(key: key);

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _participants = [];
  List<Category> _categories = [];
  List<Map<String, dynamic>> _splits = [];

  // 🎯 Smart split management
  Map<int, Map<String, dynamic>> _originalSplitData = {};
  Map<int, Map<String, dynamic>> _currentSplitData = {};
  bool _hasUserModifications = false;

  // 🔧 Smart Auto-Recalculation
  Timer? _amountRecalculationTimer;
  double _lastProcessedAmount = 0.0;

  // 🎯 Backup original ratios để restore khi cần
  List<double> _originalRatios = [];
  bool _hasOriginalRatios = false;

  String? _selectedCategoryId;
  int? _selectedPayerId;
  String _splitType = 'EQUAL';

  List<Map<String, dynamic>> _existingAttachments = [];
  List<XFile> _newAttachments = [];

  @override
  void initState() {
    super.initState();
    _loadExpenseData();
  }

  Future<void> _loadParticipants() async {
    if (_groupId == null) return;
    try {
      final res = await AuthService.dio.get('/group/$_groupId');
      final group = res.data['result'];

      _participants =
          List<Map<String, dynamic>>.from(group['participants'] ?? []);

      setState(() {}); // Cập nhật lại giao diện sau khi load participants
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi tải người tham gia: $e')));
    }
  }

  Future<void> _loadExpenseData() async {
    try {
      final res = await AuthService.dio.get('/expense/${widget.expenseId}');
      final result = res.data['result'];

      _groupId = result['group']['id'];
      _titleController.text = result['title'] ?? '';
      _descriptionController.text = result['description'] ?? '';
      _amountController.text = (result['amount'] ?? '').toString();
      _selectedDate = DateTime.parse(result['expenseDate']);
      _selectedPayerId = result['payer']['id'];
      _splitType = result['splitType'] ?? 'EQUAL';
      _existingAttachments =
          List<Map<String, dynamic>>.from(result['attachments'] ?? []);
      _participants = List<Map<String, dynamic>>.from(
          result['group']['participants'] ?? []);
      _splits = List<Map<String, dynamic>>.from(result['splits'] ?? []);

      setState(() => _loading = false);
      await _loadCategories();
      _selectedCategoryId = result['category']['id'].toString();

      // 🎯 Smart split management
      _originalSplitData = {};
      _currentSplitData = {};
      for (var i = 0; i < _splits.length; i++) {
        _originalSplitData[i] = Map.from(_splits[i]);
        _currentSplitData[i] = Map.from(_splits[i]);
      }

      // 🔧 Initialize last processed amount
      _lastProcessedAmount = double.tryParse(_amountController.text) ?? 0.0;

      _backupOriginalRatios();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      Navigator.pop(context);
    }
  }

  Future<void> _loadCategories() async {
    if (_groupId == null) return;

    try {
      final categories =
          await CategoryService.fetchGroupExpenseCategories(_groupId!);

      setState(() {
        _categories = categories;

        if (_selectedCategoryId != null) {
          final categoryExists =
              _categories.any((c) => c.id.toString() == _selectedCategoryId);
          if (!categoryExists && _categories.isNotEmpty) {
            _selectedCategoryId = _categories.first.id.toString();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi khi tải danh mục: $e')),
        );
      }
    }
  }

  Future<void> _selectExpenseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_splitType == 'AMOUNT') {
      final total = _splits.fold(0.0, (sum, s) => sum + (s['amount'] ?? 0));
      if (total.toStringAsFixed(2) !=
          double.parse(_amountController.text).toStringAsFixed(2)) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tổng số tiền chia không khớp.')));
        return;
      }
    }
    if (_splitType == 'PERCENTAGE') {
      final total = _splits.fold(0.0, (sum, s) => sum + (s['percentage'] ?? 0));
      if (total.toStringAsFixed(2) != '100.00') {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tổng phần trăm phải bằng 100%.')));
        return;
      }
    }

    try {
      if (_newAttachments.isNotEmpty) {
        for (final img in _newAttachments) {
          final formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              img.path,
              filename: path.basename(img.path),
              contentType: _getMediaType(img.path),
            ),
            'description': 'expense_attachment',
          });

          final res = await AuthService.dio.post(
            '/media/expense/${widget.expenseId}',
            data: formData,
          );

          if (res.statusCode == 201 && res.data['result'] != null) {
            final uploaded = res.data['result'];
            setState(() {
              _existingAttachments.add({
                'id': uploaded['id'],
                'fileUrl': uploaded['fileUrl'] ?? '',
              });
            });
          }
        }
      }

      // 🎯 2. Build lại danh sách attachmentIds
      final attachmentIds =
          _existingAttachments.map((e) => e['id'] as int).toList();

      // 🎯 3. Chuẩn bị data gửi update
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'amount': double.parse(_amountController.text.trim()),
        'participantId': _selectedPayerId,
        'category': int.parse(_selectedCategoryId!),
        'expenseDate': _selectedDate.toIso8601String(),
        'splitType': _splitType,
        'splits': _splitType == 'EQUAL'
            ? _splits
                .map((s) => {
                      'participantId': s['participant']['id'],
                      // Không cần gửi amount/percentage vì backend sẽ tự tính cho EQUAL
                    })
                .toList()
            : _splits
                .map((s) => {
                      'participantId': s['participant']['id'],
                      if (_splitType == 'AMOUNT') 'amount': s['amount'],
                      if (_splitType == 'PERCENTAGE')
                        'percentage': s['percentage'],
                    })
                .toList(),
        'attachmentIds': attachmentIds,
      };

      // 🔍 DEBUG LOGGING - Log thông tin submit
      print('=== EXPENSE UPDATE SUBMIT DEBUG ===');
      print('Split Type: $_splitType');
      print('Amount: ${_amountController.text}');
      print('Last Processed Amount: $_lastProcessedAmount');
      print('Has User Modifications: $_hasUserModifications');
      print('Splits Data sent to backend:');
      if (data['splits'] == null) {
        print('  → NULL (EQUAL mode)');
      } else {
        print('  → ${data['splits']}');
      }
      print('Full data object:');
      print('  Title: ${data['title']}');
      print('  Amount: ${data['amount']}');
      print('  SplitType: ${data['splitType']}');
      print('  ParticipantId: ${data['participantId']}');
      print('  Category: ${data['category']}');
      print('  AttachmentIds: ${data['attachmentIds']}');
      print('Current _splits state:');
      for (int i = 0; i < _splits.length; i++) {
        final split = _splits[i];
        print(
            '  Split $i: Participant=${split['participant']['name']}, Amount=${split['amount']}, Percentage=${split['percentage']}');
      }
      print('================================');

      // 🎯 4. Gửi request update
      await AuthService.dio.put('/expense/${widget.expenseId}', data: data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Cập nhật khoản chi thành công!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi cập nhật: $e')));
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
                        _groupId!, data);
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

  double _calculateTotalPercentage() {
    if (_splitType != 'PERCENTAGE') return 0.0;

    return _splits.fold(0.0, (sum, split) {
      return sum + (split['percentage'] ?? 0);
    });
  }

  double _calculateTotalAmount() {
    if (_splitType != 'AMOUNT') return 0.0;

    return _splits.fold(0.0, (sum, split) {
      return sum + (split['amount'] ?? 0);
    });
  }

  Color _getValidationColor() {
    if (_splitType == 'PERCENTAGE') {
      final total = _calculateTotalPercentage();
      if ((total - 100.0).abs() < 0.1) return Colors.green;
      return Colors.red;
    } else if (_splitType == 'AMOUNT') {
      final total = _calculateTotalAmount();
      final expected = double.tryParse(_amountController.text) ?? 0;
      if ((total - expected).abs() < 0.01) return Colors.green;
      return Colors.red;
    }
    return Colors.blue;
  }

  // 🎯 Smart Split Type Conversion
  void _convertSplitType(String newSplitType) {
    if (_splitType == newSplitType) return;

    final currentAmount = double.tryParse(_amountController.text) ?? 0.0;

    // 🔍 DEBUG LOGGING - Log split type conversion
    print('=== SPLIT TYPE CONVERSION DEBUG ===');
    print('Converting from: $_splitType → $newSplitType');
    print('Current Amount: $currentAmount');
    print('Splits BEFORE conversion:');
    for (int i = 0; i < _splits.length; i++) {
      final split = _splits[i];
      print(
          '  Split $i: ${split['participant']['name']} - Amount: ${split['amount']}, Percentage: ${split['percentage']}');
    }

    setState(() {
      final oldSplitType = _splitType;
      _splitType = newSplitType;

      for (int i = 0; i < _splits.length; i++) {
        final split = _splits[i];

        switch (newSplitType) {
          case 'EQUAL':
            // 🔧 EQUAL mode chỉ là display mode, không thay đổi underlying ratios
            // Data sẽ được tính equal trong UI rendering, không cần modify splits ở đây
            break;

          case 'AMOUNT':
            // Nếu chuyển từ PERCENTAGE, convert từ percentage hiện tại
            if (oldSplitType == 'PERCENTAGE') {
              final currentPercentage =
                  split['percentage'] ?? 0.0; // 🔧 Fallback cho null
              final totalAmount = double.tryParse(_amountController.text) ?? 0;
              split['amount'] = (currentPercentage / 100.0) * totalAmount;
            } else if (oldSplitType == 'EQUAL') {
              // 🔧 Chuyển từ EQUAL → Restore original ratios
              _restoreOriginalRatios();
              break; // Exit loop vì _restoreOriginalRatios đã xử lý tất cả splits
            }
            // Nếu từ EQUAL, sử dụng amount đã có (đã được backend tính)
            // split['amount'] đã có sẵn, không cần thay đổi
            break;

          case 'PERCENTAGE':
            // Nếu chuyển từ AMOUNT, convert từ amount hiện tại
            if (oldSplitType == 'AMOUNT') {
              final currentAmount =
                  split['amount'] ?? 0.0; // 🔧 Fallback cho null
              final totalAmount = double.tryParse(_amountController.text) ?? 0;
              if (totalAmount > 0) {
                split['percentage'] = (currentAmount / totalAmount) * 100.0;
              }
            } else if (oldSplitType == 'EQUAL') {
              // 🔧 Chuyển từ EQUAL → Restore original ratios
              _restoreOriginalRatios();
              break; // Exit loop vì _restoreOriginalRatios đã xử lý tất cả splits
            }
            // Nếu từ EQUAL, sử dụng percentage đã có (đã được backend tính)
            // split['percentage'] đã có sẵn, không cần thay đổi
            break;
        }

        // Cập nhật current data
        _currentSplitData[i] = Map.from(split);
      }

      // 🔧 Đồng bộ _lastProcessedAmount với current amount
      _lastProcessedAmount = double.tryParse(_amountController.text) ?? 0.0;
    });

    // 🔍 DEBUG LOGGING - Log after conversion
    print('Splits AFTER conversion:');
    for (int i = 0; i < _splits.length; i++) {
      final split = _splits[i];
      print(
          '  Split $i: ${split['participant']['name']} - Amount: ${split['amount']}, Percentage: ${split['percentage']}');
    }
    print('==============================');
  }

  // 🎯 Check if current values are different from original
  bool _hasModifications() {
    for (int i = 0; i < _splits.length; i++) {
      final current = _currentSplitData[i];
      final original = _originalSplitData[i];

      if (current == null || original == null) continue;

      if (_splitType == 'AMOUNT') {
        if ((current['amount'] ?? 0).toStringAsFixed(0) !=
            (original['amount'] ?? 0).toStringAsFixed(0)) {
          return true;
        }
      } else if (_splitType == 'PERCENTAGE') {
        if ((current['percentage'] ?? 0).toStringAsFixed(1) !=
            (original['percentage'] ?? 0).toStringAsFixed(1)) {
          return true;
        }
      }
    }
    return false;
  }

  // 🎯 Smart Auto-Recalculation System
  void _onAmountFieldChanged(String value) {
    // Cancel previous timer để avoid excessive calculations
    _amountRecalculationTimer?.cancel();

    // Debounce để smooth performance
    _amountRecalculationTimer = Timer(Duration(milliseconds: 500), () {
      _performSmartRecalculation(value);
    });
  }

  void _performSmartRecalculation(String amountText) {
    final newAmount = double.tryParse(amountText);
    if (newAmount == null || newAmount <= 0) {
      return; // Invalid input, don't recalculate
    }

    // Skip nếu amount không thực sự thay đổi
    if ((newAmount - _lastProcessedAmount).abs() < 0.01) {
      return;
    }

    // 🔍 DEBUG LOGGING - Log auto-recalculation
    print('=== AUTO-RECALCULATION DEBUG ===');
    print('Split Type: $_splitType');
    print('Old Amount: $_lastProcessedAmount');
    print('New Amount: $newAmount');
    print('Splits BEFORE recalculation:');
    for (int i = 0; i < _splits.length; i++) {
      final split = _splits[i];
      print(
          '  Split $i: ${split['participant']['name']} - Amount: ${split['amount']}, Percentage: ${split['percentage']}');
    }

    _lastProcessedAmount = newAmount;

    setState(() {
      switch (_splitType) {
        case 'EQUAL':
          _handleEqualModeRecalculation(newAmount);
          break;
        case 'AMOUNT':
          _handleAmountModeRecalculation(newAmount);
          break;
        case 'PERCENTAGE':
          _handlePercentageModeRecalculation(newAmount);
          break;
      }

      _updateCurrentSplitData();
      _hasUserModifications = true;
    });

    // 🔍 DEBUG LOGGING - Log after recalculation
    print('Splits AFTER recalculation:');
    for (int i = 0; i < _splits.length; i++) {
      final split = _splits[i];
      print(
          '  Split $i: ${split['participant']['name']} - Amount: ${split['amount']}, Percentage: ${split['percentage']}');
    }
    print('==============================');
  }

  void _handleEqualModeRecalculation(double newAmount) {
    if (_splits.isEmpty) return;

    final equalAmount = newAmount / _splits.length;
    final equalPercentage = 100.0 / _splits.length;

    for (var split in _splits) {
      split['amount'] = equalAmount;
      split['percentage'] = equalPercentage;
    }
  }

  void _handleAmountModeRecalculation(double newAmount) {
    if (_splits.isEmpty) return;

    // Tính tổng amount hiện tại
    double currentTotal =
        _splits.fold(0.0, (sum, split) => sum + (split['amount'] ?? 0.0));

    if (currentTotal == 0) {
      // Fallback: không có reference → chia đều
      _handleEqualModeRecalculation(newAmount);
      return;
    }

    // Preserve ratios, scale to new amount
    for (var split in _splits) {
      double currentAmount = split['amount'] ?? 0.0;
      double ratio = currentAmount / currentTotal;

      // Apply ratio to new total
      split['amount'] = ratio * newAmount;
      split['percentage'] = ratio * 100.0;
    }

    // Fix rounding errors
    _applyRoundingFix(newAmount);
  }

  void _handlePercentageModeRecalculation(double newAmount) {
    // Percentages stay the same, chỉ recalculate amounts
    for (var split in _splits) {
      double percentage = split['percentage'] ?? 0.0;
      split['amount'] = (percentage / 100.0) * newAmount;
    }
  }

  void _applyRoundingFix(double targetAmount) {
    if (_splits.isEmpty) return;

    // Calculate total after all calculations
    double totalCalculated =
        _splits.fold(0.0, (sum, split) => sum + (split['amount'] ?? 0.0));

    // If there's rounding difference, adjust largest split
    double difference = targetAmount - totalCalculated;
    if (difference.abs() > 0.01) {
      // Find split with largest amount
      var largestSplit = _splits.reduce(
          (a, b) => (a['amount'] ?? 0.0) > (b['amount'] ?? 0.0) ? a : b);

      largestSplit['amount'] = (largestSplit['amount'] ?? 0.0) + difference;

      // Recalculate percentage for adjusted split
      final totalAmount = double.tryParse(_amountController.text) ?? 0;
      if (totalAmount > 0) {
        largestSplit['percentage'] =
            ((largestSplit['amount'] ?? 0.0) / totalAmount) * 100.0;
      }
    }
  }

  void _updateCurrentSplitData() {
    for (int i = 0; i < _splits.length; i++) {
      _currentSplitData[i] = Map.from(_splits[i]);
    }
  }

  void _backupOriginalRatios() {
    if (_splits.isEmpty) return;

    _originalRatios.clear();
    double totalAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (totalAmount > 0) {
      for (var split in _splits) {
        double amount = split['amount'] ?? 0.0;
        double ratio = amount / totalAmount;
        _originalRatios.add(ratio);
      }
      _hasOriginalRatios = true;
    }
  }

  void _restoreOriginalRatios() {
    if (!_hasOriginalRatios || _originalRatios.length != _splits.length) return;

    double currentAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (currentAmount <= 0) return;

    for (int i = 0; i < _splits.length; i++) {
      if (i < _originalRatios.length) {
        double ratio = _originalRatios[i];
        _splits[i]['amount'] = ratio * currentAmount;
        _splits[i]['percentage'] = ratio * 100.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            title: const Text('Sửa chi phí', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.white,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          ),
        ),
      ),
      body: _loading
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
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Không được để trống' : null,
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                    ),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số tiền'),
                      validator: (v) => v == null || double.tryParse(v) == null
                          ? 'Nhập số hợp lệ'
                          : null,
                      onChanged: _onAmountFieldChanged,
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
                    DropdownButtonFormField<int>(
                      value: _selectedPayerId,
                      items: _participants.map((participant) {
                        return DropdownMenuItem<int>(
                          value: participant['id'],
                          child: Text(
                            participant['name'] ?? 'Không có tên',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPayerId = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Người thanh toán',
                        hintText: 'Chọn người thanh toán',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: _splitType,
                      items: [
                        DropdownMenuItem(
                          value: 'EQUAL',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.balance, color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Text('Chia đều'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'AMOUNT',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attach_money,
                                  color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Text('Theo số tiền'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'PERCENTAGE',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pie_chart,
                                  color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Text('Theo phần trăm'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) => _convertSplitType(v!),
                      decoration:
                          const InputDecoration(labelText: 'Kiểu chia tiền'),
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
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
                      decoration: const InputDecoration(labelText: 'Danh mục'),
                    ),
                    const SizedBox(height: 16),
                    if (_splitType == 'EQUAL' && _splits.isNotEmpty) ...[
                      // 🎯 EQUAL mode display
                      Text(
                        'Phân chia chi phí (Chia đều):',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: Column(
                          children: [
                            ..._splits.map((split) {
                              final participant = split['participant'];
                              final totalAmount =
                                  double.tryParse(_amountController.text) ?? 0;
                              final equalAmount = totalAmount > 0
                                  ? totalAmount / _splits.length
                                  : 0;
                              final equalPercentage = 100.0 / _splits.length;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      participant['name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '${NumberFormat('#,##0', 'vi_VN').format(equalAmount)} ₫ (${equalPercentage.toStringAsFixed(1)}%)',
                                      style: TextStyle(color: Colors.blue[700]),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tổng:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${NumberFormat('#,##0', 'vi_VN').format(double.tryParse(_amountController.text) ?? 0)} ₫ (100.0%)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_splitType != 'EQUAL' && _splits.isNotEmpty) ...[
                      Text(
                        'Phân chia chi phí (${_splitType == 'AMOUNT' ? 'Số tiền' : 'Phần trăm'}):',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._splits.map((split) {
                        final participant = split['participant'];

                        // 🎯 Sử dụng giá trị đúng cho từng split type
                        double? currentValue;
                        if (_splitType == 'AMOUNT') {
                          currentValue = split['amount'];
                        } else if (_splitType == 'PERCENTAGE') {
                          currentValue = split['percentage'];
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextFormField(
                            key: ValueKey(
                                'split_${_splitType}_${split['participant']['id']}'),
                            initialValue: currentValue?.toStringAsFixed(
                                    _splitType == 'PERCENTAGE' ? 1 : 0) ??
                                '0',
                            decoration: InputDecoration(
                              labelText:
                                  '${participant['name']} (${_splitType == 'AMOUNT' ? 'VND' : '%'})',
                              border: const OutlineInputBorder(),
                              hintText: _splitType == 'AMOUNT' ? '0' : '0.0',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (value) {
                              setState(() {
                                final index = _splits.indexOf(split);
                                if (_splitType == 'AMOUNT') {
                                  split['amount'] = double.tryParse(value) ?? 0;
                                  // Tính lại percentage
                                  final totalAmount =
                                      double.tryParse(_amountController.text) ??
                                          0;
                                  if (totalAmount > 0) {
                                    split['percentage'] =
                                        (split['amount'] / totalAmount) * 100;
                                  }
                                } else if (_splitType == 'PERCENTAGE') {
                                  split['percentage'] =
                                      double.tryParse(value) ?? 0;
                                  // Tính lại amount
                                  final totalAmount =
                                      double.tryParse(_amountController.text) ??
                                          0;
                                  split['amount'] =
                                      (split['percentage'] / 100.0) *
                                          totalAmount;
                                }

                                // Cập nhật current data
                                _currentSplitData[index] = Map.from(split);
                                _hasUserModifications = true;

                                // 🔧 Update backup ratios để preserve user changes
                                _backupOriginalRatios();
                              });
                            },
                            validator: (value) {
                              final numValue = double.tryParse(value ?? '');
                              if (numValue == null || numValue < 0) {
                                return 'Nhập số hợp lệ';
                              }
                              if (_splitType == 'PERCENTAGE' &&
                                  numValue > 100) {
                                return 'Phần trăm không được vượt quá 100%';
                              }
                              return null;
                            },
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      if (_splitType == 'PERCENTAGE')
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getValidationColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _getValidationColor(), width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                  _getValidationColor() == Colors.green
                                      ? Icons.check_circle
                                      : Icons.warning,
                                  color: _getValidationColor(),
                                  size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tổng: ${_calculateTotalPercentage().toStringAsFixed(1)}% ${_getValidationColor() == Colors.green ? '✓' : '(cần bằng 100%)'}',
                                  style: TextStyle(
                                    color: _getValidationColor(),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_splitType == 'AMOUNT')
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getValidationColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _getValidationColor(), width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                  _getValidationColor() == Colors.green
                                      ? Icons.check_circle
                                      : Icons.warning,
                                  color: _getValidationColor(),
                                  size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tổng: ${NumberFormat('#,##0', 'vi_VN').format(_calculateTotalAmount())} ₫ ${_getValidationColor() == Colors.green ? '✓' : '(cần bằng ${NumberFormat('#,##0', 'vi_VN').format(double.tryParse(_amountController.text) ?? 0)} ₫)'}',
                                  style: TextStyle(
                                    color: _getValidationColor(),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Ảnh minh chứng',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_existingAttachments.isEmpty &&
                              _newAttachments.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                    style: BorderStyle.solid),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.image_outlined,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Chưa có ảnh minh chứng',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                              itemCount: _existingAttachments.length +
                                  _newAttachments.length,
                              itemBuilder: (context, index) {
                                if (index < _existingAttachments.length) {
                                  // Existing attachments
                                  final att = _existingAttachments[index];
                                  return GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => _ImagePreviewDialog(
                                          attachments: _existingAttachments,
                                          initialPage: index,
                                          isNetwork: true,
                                        ),
                                      );
                                    },
                                    child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.network(
                                            replaceBaseUrl(att['fileUrl']),
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return Container(
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2),
                                                ),
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[200],
                                                child: Icon(Icons.broken_image,
                                                    color: Colors.grey[400]),
                                              );
                                            },
                                          ),
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: GestureDetector(
                                              onTap: () => setState(() =>
                                                  _existingAttachments
                                                      .remove(att)),
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: Colors.red
                                                      .withOpacity(0.9),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.2),
                                                      blurRadius: 3,
                                                      offset:
                                                          const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  // New attachments
                                  final file = _newAttachments[index - _existingAttachments.length];
                                  return GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => _ImagePreviewDialog(
                                          attachments: _newAttachments,
                                          initialPage: index - _existingAttachments.length,
                                          isNetwork: false,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.file(
                                              File(file.path),
                                              fit: BoxFit.cover,
                                            ),
                                            Positioned(
                                              top: 0,
                                              right: 0,
                                              child: GestureDetector(
                                                onTap: () => setState(() =>
                                                    _newAttachments.remove(file)),
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withOpacity(0.9),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        blurRadius: 3,
                                                        offset:
                                                            const Offset(0, 1),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 16,
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
                              },
                            ),
                        ],
                      ),
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
                              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text(
                                    'Lưu thay đổi',
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

  @override
  void dispose() {
    _amountRecalculationTimer?.cancel(); // 🔧 Cleanup timer
    super.dispose();
  }
}

class _ImagePreviewDialog extends StatefulWidget {
  final List<dynamic> attachments;
  final int initialPage;
  final bool isNetwork;
  const _ImagePreviewDialog({required this.attachments, required this.initialPage, this.isNetwork = false});
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
                    child: widget.isNetwork
                        ? Image.network(
                            replaceBaseUrl(widget.attachments[pageIndex]['fileUrl']),
                            fit: BoxFit.contain,
                          )
                        : Image.file(
                            File(widget.attachments[pageIndex].path),
                            fit: BoxFit.contain,
                          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentPage + 1}/${widget.attachments.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
