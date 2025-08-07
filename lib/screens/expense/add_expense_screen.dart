import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/group.dart';
import '../../../models/category.dart';
import '../../../models/currency.dart';
import '../../../services/auth_service.dart';
import '../../../services/category_service.dart';
import '../../../services/group_service.dart';
import '../../../services/currency_service.dart';
import '../../../utils/color_utils.dart';
import '../../../utils/icon_utils.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/currency_input_formatter.dart';
import '../../../widgets/currency_picker_modal.dart';
import 'package:intl/intl.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import '../../widgets/scan_receipt_dialog.dart';
import '../../widgets/review_ocr_dialog.dart';
import '../../services/chatgpt_ocr_service.dart';
import '../../models/receipt_data.dart';
import '../../widgets/amount_text_field.dart';
import '../../utils/amount_parser.dart';

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
  final _amountFocusNode = FocusNode();

  String? _selectedCategoryId;
  String _splitType = 'EQUAL';
  int? _selectedPayerId;
  DateTime _selectedDate = DateTime.now();
  List<XFile> _attachments = [];

  List<Map<String, dynamic>> _splits = [];
  List<Category> _categories = [];
  List<Currency> _currencies = [];
  Currency? _selectedCurrency;
  String? _groupDefaultCurrencyCode;
  bool _isLoading = true;

  // Thêm biến để track exchange rate
  double? _currentExchangeRate;
  bool _isLoadingExchangeRate = false;

  @override
  void initState() {
    super.initState();
    _setDefaultPayer();
    _splits = widget.participants?.map((p) {
          return {
            'participantId': p.id,
            'amount': '',
            'percentage': '',
          };
        }).toList() ??
        [];

    // Thêm listener cho amount controller để real-time update converted amount
    _amountController.addListener(() {
      if (_currentExchangeRate != null) {
        setState(() {}); // Trigger rebuild để update converted amount
      }
    });

    // AmountTextField tự xử lý format-on-blur, không cần listener

    _loadData();
  }

  /// Set default payer to current user
  void _setDefaultPayer() {
    if (widget.participants == null || widget.participants!.isEmpty) {
      _selectedPayerId = null;
      return;
    }

    // Try to find current user in participants
    if (widget.currentUserId != null) {
      final currentUserParticipant = widget.participants!.firstWhere(
        (p) => p.user?.id == widget.currentUserId,
        orElse: () => widget.participants!.first,
      );
      _selectedPayerId = currentUserParticipant.id;
      print(
          '🔧 Set default payer: ${currentUserParticipant.name} (current user)');
    } else {
      // Fallback to first participant
      _selectedPayerId = widget.participants!.first.id;
      print(
          '🔧 Set default payer: ${widget.participants!.first.name} (fallback)');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load categories và currencies
      final results = await Future.wait([
        CategoryService.fetchGroupExpenseCategories(widget.groupId),
        CurrencyService.fetchCurrencies(),
      ]);

      // Load group default currency separately
      await _loadGroupDefaultCurrency();

      final categories = results[0] as List<Category>;
      final currencies = results[1] as List<Currency>;

      setState(() {
        _categories = categories;
        _currencies = currencies;
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id.toString();
        }
        // Mặc định chọn currency của group hoặc VND nếu không có
        _selectedCurrency = _groupDefaultCurrencyCode != null
            ? currencies.firstWhere(
                (c) => c.code == _groupDefaultCurrencyCode,
                orElse: () => currencies.firstWhere((c) => c.code == 'VND',
                    orElse: () => currencies.first),
              )
            : currencies.firstWhere((c) => c.code == 'VND',
                orElse: () => currencies.first);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi khi tải dữ liệu: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroupDefaultCurrency() async {
    try {
      final group = await GroupService.getGroupById(widget.groupId);
      _groupDefaultCurrencyCode = group.defaultCurrency;
    } catch (e) {
      print('Warning: Could not load group default currency: $e');
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

  /// Quét hóa đơn OCR với ChatGPT AI và tự động điền form
  Future<void> _scanReceipt() async {
    try {
      // Step 1: Show scan dialog để chọn image
      final scanResult = await ScanReceiptHelper.showScanDialog(context);
      if (scanResult == null) return;

      // Lấy imageFile từ scan result
      final imageFile = scanResult['imageFile'] as XFile;

      // Show loading dialog với message tối ưu
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('🤖 Đang phân tích hóa đơn với AI...'),
              Text(
                'Quá trình sẽ diễn ra từ 3-5s',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );

      try {
        // Step 2: Process với ChatGPT OCR backend
        final receiptData =
            await ChatGptOcrService.processReceiptWithChatGPT(imageFile);

        // Close loading dialog
        if (mounted) Navigator.of(context).pop();

        // Step 3: Show review dialog với kết quả
        final reviewResult = await ReviewOCRHelper.showReviewDialog(
          context,
          receiptData,
          imageFile,
        );

        if (reviewResult == null) return;

        final finalData = reviewResult['receiptData'] as ReceiptData;
        final finalImageFile = reviewResult['imageFile'] as XFile;

        // Step 4: Apply data to form với category mapping
        await _applyOCRDataWithCategoryMapping(finalData, finalImageFile);
      } catch (e) {
        // Close loading dialog
        if (mounted) Navigator.of(context).pop();

        // Show error message với format mới
        if (mounted) {
          String errorText = e.toString();
          // Remove "Exception: " prefix nếu có
          if (errorText.startsWith('Exception: ')) {
            errorText = errorText.substring(11);
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorText),
              backgroundColor: Colors.red[700],
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Thử lại',
                textColor: Colors.white,
                onPressed: () => _scanReceipt(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error in _scanReceipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi quét hóa đơn: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Áp dụng dữ liệu OCR với category mapping từ ChatGPT
  Future<void> _applyOCRDataWithCategoryMapping(
      ReceiptData receiptData, XFile imageFile) async {
    setState(() {
      // Fill form fields
      if (receiptData.merchantName != null) {
        _titleController.text = receiptData.merchantName!;
      }

      if (receiptData.amount != null) {
        // Set formatted amount theo currency đã chọn
        if (_selectedCurrency != null) {
          final formattedValue = CurrencyInputFormatter.formatCurrency(
              receiptData.amount!, _selectedCurrency!.code);
          _amountController.text = formattedValue;
        } else {
          _amountController.text = receiptData.amount!.toString();
        }
      }

      if (receiptData.date != null) {
        _selectedDate = receiptData.date!;
      }

      if (receiptData.description != null &&
          receiptData.description!.isNotEmpty) {
        _descriptionController.text = receiptData.description!;
      }

      // Add image to attachments if space available
      if (_attachments.length < 5) {
        _attachments.add(imageFile);
      }
    });

    // Map category từ ChatGPT response
    if (receiptData.categoryName != null &&
        receiptData.categoryName!.isNotEmpty) {
      try {
        final categoryId = await ChatGptOcrService.getCategoryIdFromName(
          receiptData.categoryName!,
          widget.groupId,
        );

        if (categoryId != null) {
          setState(() {
            _selectedCategoryId = categoryId;
          });

          print(
              '✅ Auto-selected category: ${receiptData.categoryName} (ID: $categoryId)');
        }
      } catch (e) {
        print('⚠️ Could not map category "${receiptData.categoryName}": $e');
      }
    }

    // Note: Removed success message notification as requested
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
      final totalAmount = _selectedCurrency != null
          ? AmountParser.getPureDouble(
                  _amountController.text, _selectedCurrency!.code) ??
              0
          : CurrencyInputFormatter.extractNumber(_amountController.text) ?? 0;
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

    if (_selectedCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn loại tiền')),
      );
      return;
    }

    final data = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'amount': _selectedCurrency != null
          ? AmountParser.getPureDouble(
                  _amountController.text, _selectedCurrency!.code) ??
              0
          : CurrencyInputFormatter.extractNumber(_amountController.text) ?? 0,
      'category': int.parse(_selectedCategoryId!),
      'splitType': _splitType,
      'participantId': _selectedPayerId,
      'groupId': widget.groupId,
      'expenseDate': _selectedDate.toIso8601String(),
      'currency': _selectedCurrency!.code, // Gửi currency code thay vì cứng VND
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã tạo chi phí thành công!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi khi tạo expense: $e')),
      );
    }
  }

  /// Lấy tỷ giá exchange rate từ API
  Future<double?> _fetchExchangeRate(
      String fromCurrency, String toCurrency) async {
    if (fromCurrency == toCurrency) return 1.0;

    try {
      setState(() => _isLoadingExchangeRate = true);

      // Sử dụng API thực tế từ backend
      final response = await AuthService.dio.get(
        '/exchange/rate',
        queryParameters: {
          'from': fromCurrency,
          'to': toCurrency,
        },
      );

      // Parse response theo cấu trúc API của backend
      if (response.statusCode == 200 && response.data['result'] != null) {
        final result = response.data['result'];

        // Kiểm tra success flag
        if (result['success'] == true || result['isSuccess'] == true) {
          final rate = result['rate'] as double?;
          return rate;
        } else {
          // API trả về error
          final errorMessage = result['errorMessage'] ?? 'Unknown error';
          print('❌ API Exchange Rate Error: $errorMessage');
          return _getMockExchangeRate(fromCurrency, toCurrency);
        }
      } else {
        print('❌ API Response Error: ${response.statusCode}');
        return _getMockExchangeRate(fromCurrency, toCurrency);
      }
    } catch (e) {
      print('❌ Lỗi khi lấy tỷ giá: $e');
      // Fallback to mock rates nếu API fail
      return _getMockExchangeRate(fromCurrency, toCurrency);
    } finally {
      setState(() => _isLoadingExchangeRate = false);
    }
  }

  /// Mock exchange rates cho demo (thay thế bằng API thực)
  double? _getMockExchangeRate(String fromCurrency, String toCurrency) {
    print('🔄 Sử dụng mock exchange rate: $fromCurrency → $toCurrency');

    // Mock rates với USD làm base (cập nhật tỷ giá realistic hơn)
    final mockRates = {
      'USD': 1.0,
      'VND': 24500.0, // 1 USD = 24,500 VND
      'EUR': 0.92, // 1 USD = 0.92 EUR
      'GBP': 0.79, // 1 USD = 0.79 GBP
      'JPY': 149.0, // 1 USD = 149 JPY
      'CNY': 7.25, // 1 USD = 7.25 CNY
      'KRW': 1320.0, // 1 USD = 1,320 KRW
      'THB': 36.0, // 1 USD = 36 THB
      'SGD': 1.36, // 1 USD = 1.36 SGD
      'MYR': 4.68, // 1 USD = 4.68 MYR
      'IDR': 15600.0, // 1 USD = 15,600 IDR
      'PHP': 56.0, // 1 USD = 56 PHP
      'AUD': 1.53, // 1 USD = 1.53 AUD
      'CAD': 1.37, // 1 USD = 1.37 CAD
      'CHF': 0.89, // 1 USD = 0.89 CHF
    };

    final fromRate = mockRates[fromCurrency];
    final toRate = mockRates[toCurrency];

    if (fromRate != null && toRate != null) {
      final rate = toRate / fromRate;
      print('📊 Mock Rate: 1 $fromCurrency = $rate $toCurrency');
      return rate;
    }

    print('⚠️ Không tìm thấy mock rate cho $fromCurrency → $toCurrency');
    return null;
  }

  /// Load exchange rate khi currency thay đổi
  Future<void> _loadExchangeRateIfNeeded() async {
    if (_selectedCurrency != null &&
        _groupDefaultCurrencyCode != null &&
        _selectedCurrency!.code != _groupDefaultCurrencyCode) {
      print(
          '🔄 Loading exchange rate: ${_selectedCurrency!.code} → $_groupDefaultCurrencyCode');

      final rate = await _fetchExchangeRate(
          _selectedCurrency!.code, _groupDefaultCurrencyCode!);

      if (rate != null) {
        print(
            '✅ Exchange rate loaded: 1 ${_selectedCurrency!.code} = $rate $_groupDefaultCurrencyCode');
      } else {
        print('❌ Failed to load exchange rate');
      }

      setState(() => _currentExchangeRate = rate);
    } else {
      print('ℹ️ Same currency selected, no conversion needed');
      setState(() => _currentExchangeRate = null);
    }
  }

  /// Format converted amount để hiển thị
  String _getConvertedAmountText() {
    if (_currentExchangeRate == null || _amountController.text.isEmpty) {
      return '';
    }

    final amount = _selectedCurrency != null
        ? AmountParser.getPureDouble(
            _amountController.text, _selectedCurrency!.code)
        : CurrencyInputFormatter.extractNumber(_amountController.text);
    if (amount == null) return '';

    final convertedAmount = amount * _currentExchangeRate!;

    return '${CurrencyFormatter.formatMoney(amount, _selectedCurrency!.code)} → ${CurrencyFormatter.formatMoney(convertedAmount, _groupDefaultCurrencyCode!)}';
  }

  /// Show currency picker modal
  void _showCurrencyPicker(BuildContext context) async {
    final selected = await CurrencyPickerModal.showShortList(
      context: context,
      currencies: _currencies,
      selectedCurrency: _selectedCurrency,
      defaultCurrencyCode: _groupDefaultCurrencyCode,
    );

    if (selected != null) {
      // Re-format existing amount với currency mới
      final currentValue = _selectedCurrency != null
          ? AmountParser.getPureDouble(
              _amountController.text, _selectedCurrency!.code)
          : CurrencyInputFormatter.extractNumber(_amountController.text);

      setState(() => _selectedCurrency = selected);

      // Re-format amount với currency mới
      if (currentValue != null && currentValue > 0) {
        final formattedValue =
            CurrencyInputFormatter.formatCurrency(currentValue, selected.code);
        _amountController.text = formattedValue;
      }

      _loadExchangeRateIfNeeded(); // Load exchange rate khi currency thay đổi
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
        actions: [
          // OCR Scan Button in AppBar
          IconButton(
            onPressed: _scanReceipt,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Quét hóa đơn với ChatGPT AI',
            iconSize: 28,
          ),
          const SizedBox(width: 8),
        ],
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _selectedCurrency != null
                              ? AmountTextField(
                                  currencyCode: _selectedCurrency!.code,
                                  controller: _amountController,
                                  focusNode: _amountFocusNode,
                                  labelText: 'Số tiền',
                                  onChanged: (value) {
                                    // Trigger rebuild để update converted amount preview
                                    if (_currentExchangeRate != null) {
                                      setState(() {});
                                    }
                                  },
                                )
                              : TextFormField(
                                  controller: _amountController,
                                  focusNode: _amountFocusNode,
                                  decoration: const InputDecoration(
                                      labelText: 'Số tiền'),
                                  keyboardType: TextInputType.number,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Nhập số hợp lệ';
                                    }
                                    return null;
                                  },
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () => _showCurrencyPicker(context),
                            child: InputDecorator(
                              decoration:
                                  const InputDecoration(labelText: 'Tiền tệ'),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedCurrency != null
                                          ? _selectedCurrency!.code
                                          : 'Chọn tiền tệ',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_groupDefaultCurrencyCode != null &&
                                          _selectedCurrency?.code ==
                                              _groupDefaultCurrencyCode) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.green.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Mặc định',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Currency conversion info
                    if (_selectedCurrency != null &&
                        _groupDefaultCurrencyCode != null &&
                        _selectedCurrency!.code !=
                            _groupDefaultCurrencyCode) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.swap_horiz,
                                    size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Chuyển đổi tiền tệ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Số tiền sẽ được tự động quy đổi từ ${_selectedCurrency!.code} sang $_groupDefaultCurrencyCode (tiền tệ mặc định của nhóm)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                              ),
                            ),

                            // Exchange rate display
                            if (_isLoadingExchangeRate) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Đang tải tỷ giá...',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (_currentExchangeRate != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Tỷ giá: 1 ${_selectedCurrency!.code} = ${NumberFormat('#,##0.######').format(_currentExchangeRate)} $_groupDefaultCurrencyCode',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              // Converted amount preview
                              if (_amountController.text.isNotEmpty &&
                                  (_selectedCurrency != null
                                      ? AmountParser.getPureDouble(
                                              _amountController.text,
                                              _selectedCurrency!.code) !=
                                          null
                                      : CurrencyInputFormatter.extractNumber(
                                              _amountController.text) !=
                                          null)) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _getConvertedAmountText(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ] else ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 14, color: Colors.orange[600]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Không thể tải tỷ giá hiện tại (sử dụng tỷ giá ước tính)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[600],
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _splitType,
                      items: [
                        const DropdownMenuItem(
                            value: 'EQUAL', child: Text('Chia đều')),
                        const DropdownMenuItem(
                            value: 'AMOUNT', child: Text('Theo số tiền')),
                        const DropdownMenuItem(
                            value: 'PERCENTAGE', child: Text('Theo phần trăm')),
                      ],
                      onChanged: (v) => setState(() => _splitType = v!),
                      decoration:
                          const InputDecoration(labelText: 'Kiểu chia tiền'),
                    ),
                    const SizedBox(height: 12),
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

                    // Smart Receipt Scanner Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF667eea).withOpacity(0.1),
                            const Color(0xFF764ba2).withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF764ba2).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.smart_toy,
                                  color: Color(0xFF764ba2), size: 24),
                              SizedBox(width: 8),
                              Text(
                                'ChatGPT Vision AI',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF764ba2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sử dụng ChatGPT AI để tự động nhận diện và phân loại hóa đơn',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _scanReceipt,
                              icon: const Icon(Icons.smart_toy,
                                  color: Colors.white),
                              label: const Text(
                                'Quét hóa đơn với ChatGPT AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF764ba2),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                    const SizedBox(height: 12),
                    if (_attachments.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _attachments.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_attachments[index].path),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _attachments.removeAt(index)),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(Icons.close,
                                            size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Tạo chi phí',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
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
            top: 20,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
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
