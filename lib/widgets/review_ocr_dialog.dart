import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/receipt_data.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class ReviewOCRDialog extends StatefulWidget {
  final ReceiptData receiptData;
  final XFile imageFile;

  const ReviewOCRDialog({
    Key? key,
    required this.receiptData,
    required this.imageFile,
  }) : super(key: key);

  @override
  State<ReviewOCRDialog> createState() => _ReviewOCRDialogState();
}

class _ReviewOCRDialogState extends State<ReviewOCRDialog> {
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(
      text: widget.receiptData.merchantName ?? '',
    );
    _amountController = TextEditingController(
      text: widget.receiptData.amount?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.receiptData.description ?? '',
    );
    _selectedDate = widget.receiptData.date ?? DateTime.now();
    
    // Tìm selected category nếu có categoryId trong receiptData
    if (widget.receiptData.categoryId != null) {
      _selectedCategory = null; // Sẽ được set sau khi load categories
    }
    
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final categories = await CategoryService.fetchExpenseCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
        
        // Tìm selected category theo priorites:
        // 1. Nếu có categoryId từ OCR
        if (widget.receiptData.categoryId != null) {
          try {
            _selectedCategory = _categories.firstWhere(
              (cat) => cat.id == widget.receiptData.categoryId,
            );
          } catch (e) {
            _selectedCategory = null;
          }
        }
        
        // 2. Nếu chưa có và có categoryName từ OCR, match theo tên
        if (_selectedCategory == null && widget.receiptData.categoryName != null) {
          _selectedCategory = _findCategoryByName(widget.receiptData.categoryName!);
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      print('Lỗi khi tải categories: $e');
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kiểm tra thông tin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Xem lại và chỉnh sửa nếu cần',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Padding để tránh chồng lấp với nút X
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Nút X positioned ở góc trên bên phải
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Receipt Image Preview
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(widget.imageFile.path),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ảnh hóa đơn đã quét',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nhấn để xem chi tiết',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _showImagePreview,
                          icon: Icon(Icons.zoom_in, color: Colors.grey[600]),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Form Fields
                    _buildFormField(
                      label: 'Tên chi phí',
                      controller: _merchantController,
                      icon: Icons.store,
                      hint: 'Nhập tên chi phí',
                    ),

                    const SizedBox(height: 16),

                    _buildAmountField(),

                    const SizedBox(height: 16),

                    _buildDateField(),

                    const SizedBox(height: 16),

                    _buildCategoryField(),

                    const SizedBox(height: 16),

                    _buildFormField(
                      label: 'Mô tả (tùy chọn)',
                      controller: _descriptionController,
                      icon: Icons.description,
                      hint: 'Mô tả chi phí',
                      maxLines: 2,
                    ),

                    const SizedBox(height: 24),

                    // OCR Raw Text (Expandable)
                    if (widget.receiptData.rawText.isNotEmpty)
                      _buildRawTextSection(),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _applyData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Áp dụng',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_money, size: 20, color: Color(0xFF667eea)),
            const SizedBox(width: 8),
            const Text(
              'Số tiền',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Nhập số tiền',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF667eea)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF667eea)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF667eea)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: Color(0xFF667eea)),
            SizedBox(width: 8),
            Text(
              'Ngày giao dịch',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.category, size: 20, color: Color(0xFF667eea)),
            SizedBox(width: 8),
            Text(
              'Danh mục',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isLoadingCategories
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Đang tải danh mục...'),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<Category>(
                    value: _selectedCategory,
                    hint: const Text('Chọn danh mục'),
                    isExpanded: true,
                    items: _categories.map((Category category) {
                      return DropdownMenuItem<Category>(
                        value: category,
                        child: Row(
                          children: [
                            // Icon cho category nếu có
                            if (category.iconCode != null)
                              Icon(
                                _getIconFromCode(category.iconCode!),
                                size: 20,
                                color: _getColorFromCode(category.color),
                              )
                            else
                              Icon(
                                Icons.category,
                                size: 20,
                                color: _getColorFromCode(category.color),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (category.description.isNotEmpty)
                                    Text(
                                      category.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (Category? newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRawTextSection() {
    return ExpansionTile(
      title: const Text(
        'Văn bản gốc đã quét',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('Nhấn để xem toàn bộ text'),
      leading: const Icon(Icons.text_fields, color: Color(0xFF667eea)),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.receiptData.rawText,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showImagePreview() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: InteractiveViewer(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(widget.imageFile.path),
                    fit: BoxFit.contain,
                  ),
                ),
                // Nút X positioned trên ảnh
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tìm category theo tên với fuzzy matching
  Category? _findCategoryByName(String categoryName) {
    print('🔍 Looking for category: $categoryName');
    
    // Tìm exact match first
    Category? exactMatch;
    try {
      exactMatch = _categories.firstWhere((cat) => cat.name == categoryName);
    } catch (e) {
      exactMatch = null;
    }
    
    if (exactMatch != null) {
      print('✅ Found exact category match: ${exactMatch.name}');
      return exactMatch;
    }
    
    // Fuzzy matching
    final lowerCategoryName = categoryName.toLowerCase();
    
    for (final category in _categories) {
      final lowerCatName = category.name.toLowerCase();
      
      if (lowerCatName.contains('ăn') && lowerCategoryName.contains('ăn')) {
        print('✅ Fuzzy match for Ăn uống: ${category.name}');
        return category;
      }
      if (lowerCatName.contains('phương tiện') && 
          (lowerCategoryName.contains('phương tiện') || lowerCategoryName.contains('di chuyển'))) {
        print('✅ Fuzzy match for Phương tiện: ${category.name}');
        return category;
      }
      if (lowerCatName.contains('lưu trú') && 
          (lowerCategoryName.contains('lưu trú') || lowerCategoryName.contains('khách sạn'))) {
        print('✅ Fuzzy match for Lưu trú: ${category.name}');
        return category;
      }
      if (lowerCatName.contains('mua sắm') && lowerCategoryName.contains('mua sắm')) {
        print('✅ Fuzzy match for Mua sắm: ${category.name}');
        return category;
      }
      if (lowerCatName.contains('giải trí') && lowerCategoryName.contains('giải trí')) {
        print('✅ Fuzzy match for Giải trí: ${category.name}');
        return category;
      }
    }
    
    print('⚠️ No category match found for: $categoryName');
    return null;
  }

  // Helper methods for category display
  IconData _getIconFromCode(String iconCode) {
    // Map iconCode string to IconData
    switch (iconCode.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'flight':
        return Icons.flight;
      case 'hotel':
        return Icons.hotel;
      case 'local_taxi':
        return Icons.local_taxi;
      case 'entertainment':
        return Icons.theaters;
      case 'health':
        return Icons.local_hospital;
      case 'education':
        return Icons.school;
      case 'sports':
        return Icons.sports;
      default:
        return Icons.category;
    }
  }

  Color _getColorFromCode(String? colorCode) {
    if (colorCode == null) return const Color(0xFF667eea);
    
    // Parse color từ hex string
    try {
      if (colorCode.startsWith('#')) {
        return Color(int.parse(colorCode.substring(1), radix: 16) + 0xFF000000);
      } else {
        return Color(int.parse(colorCode, radix: 16) + 0xFF000000);
      }
    } catch (e) {
      return const Color(0xFF667eea);
    }
  }

  void _applyData() {
    // Validate required fields
    if (_merchantController.text.trim().isEmpty) {
      _showError('Vui lòng nhập tên chi phí');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('Vui lòng nhập số tiền hợp lệ');
      return;
    }

    if (_selectedCategory == null) {
      _showError('Vui lòng chọn danh mục');
      return;
    }

    // Create updated receipt data
    final updatedData = ReceiptData(
      merchantName: _merchantController.text.trim(),
      amount: amount,
      date: _selectedDate,
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      rawText: widget.receiptData.rawText,
      categoryId: _selectedCategory!.id,
      categoryName: _selectedCategory!.name,
    );

    // Return the data
    Navigator.of(context).pop({
      'receiptData': updatedData,
      'imageFile': widget.imageFile,
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Helper class để show review dialog
class ReviewOCRHelper {
  static Future<Map<String, dynamic>?> showReviewDialog(
    BuildContext context,
    ReceiptData receiptData,
    XFile imageFile,
  ) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReviewOCRDialog(
        receiptData: receiptData,
        imageFile: imageFile,
      ),
    );
  }
} 