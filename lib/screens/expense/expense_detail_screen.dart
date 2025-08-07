import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/media_service.dart';
import '../../utils/color_utils.dart';
import '../../utils/icon_utils.dart';
import '../../utils/currency_formatter.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final int expenseId;

  const ExpenseDetailScreen({Key? key, required this.expenseId})
      : super(key: key);

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late Future<Map<String, dynamic>?> _expenseFuture =
      ExpenseService.fetchExpenseDetailMap(widget.expenseId);
  User? _currentUser;
  String _currencyCode =
      'VND'; // Default fallback - will be updated to group currency

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  List<XFile> _selectedImages = [];
  List<XFile> _confirmedImages = [];

  // Track avatar loading errors
  final Set<String> _avatarErrors = <String>{};

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCurrentUser();
  }

  Future<void> _loadData() async {
    final expense =
        await ExpenseService.fetchExpenseDetailMap(widget.expenseId);
    if (expense != null) {
      setState(() {
        _expenseFuture = Future.value(expense);
        // Extract currency - use group default currency for display
        _currencyCode = expense['group']?['defaultCurrency'] ?? 'VND';
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCurrentUser();
    setState(() => _currentUser = user);
  }

  String replaceBaseUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    if (apiBaseUrl.isEmpty)
      return url; // Nếu không có API_BASE_URL, return original URL
    return url.replaceFirst(
        RegExp(r'^https?://localhost:8080/TravelShare'), apiBaseUrl);
  }

  Future<String?> _loadAvatar(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      final url = await MediaService.fetchUserAvatar(userId);
      final processedUrl = replaceBaseUrl(url);
      return _isValidUrl(processedUrl) ? processedUrl : null;
    } catch (e) {
      print('❌ Lỗi load avatar: $e');
      return null;
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
      case '.gif':
        return MediaType('image', 'gif');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  void _showImageViewer(
      BuildContext context, List<String> images, int initialIndex) {
    PageController controller = PageController(initialPage: initialIndex);
    showDialog(
      context: context,
      builder: (_) {
        int currentIndex = initialIndex;
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: images.length,
                  onPageChanged: (index) =>
                      setState(() => currentIndex = index),
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      child: Center(
                        child:
                            Image.network(images[index], fit: BoxFit.contain),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  child: Text(
                    '${currentIndex + 1}/${images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _pickAndUploadMedia() async {
    final pickedImages = await _picker.pickMultiImage();
    if (pickedImages != null && pickedImages.isNotEmpty) {
      setState(() {
        _isUploading = true;
      });
      try {
        for (final image in pickedImages) {
          final fileName = path.basename(image.path);
          final formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              image.path,
              filename: fileName,
              contentType: _getMediaType(image.path),
            ),
            'description': 'expense_attachment',
          });
          final response = await AuthService.dio.post(
            '/media/expense/${widget.expenseId}',
            data: formData,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🎉 Đã thêm ảnh minh chứng thành công!')),
        );
        await _loadData(); // Load lại data sau khi upload
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải ảnh lên: $e')),
        );
      } finally {
        setState(() {
          _selectedImages.clear();
          _confirmedImages.clear();
          _isUploading = false;
        });
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
            title: const Text('Chi tiết chi phí',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                onPressed: _isUploading ? null : _pickAndUploadMedia,
                icon:
                    const Icon(Icons.add_photo_alternate, color: Colors.white),
                tooltip: 'Chọn ảnh minh chứng',
              ),
              FutureBuilder<Map<String, dynamic>?>(
                future: _expenseFuture,
                builder: (context, snapshot) {
                  final isLocked = snapshot.hasData ? _isExpenseLocked(snapshot.data!) : false;
                  
                  return PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        if (isLocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🔒 Không thể sửa chi phí đã khóa')),
                          );
                          return;
                        }
                        final result = await Navigator.pushNamed(
                          context,
                          '/edit-expense',
                          arguments: widget.expenseId,
                        );

                        if (result == true) {
                          _loadData();
                          Navigator.pop(context, true);
                        }
                      } else if (value == 'delete') {
                        if (isLocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🔒 Không thể xóa chi phí đã khóa')),
                          );
                          return;
                        }
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Xác nhận xoá'),
                            content: const Text(
                                'Bạn có chắc chắn muốn xoá khoản chi này?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Không'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Xoá'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          try {
                            await AuthService.dio
                                .delete('/expense/${widget.expenseId}');
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi khi xoá: $e')),
                            );
                          }
                        }
                      } else if (value == 'lock_info') {
                        _showLockInfoModal(snapshot.data!);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit', 
                        enabled: !isLocked,
                        child: Text(
                          '✏️ Sửa',
                          style: TextStyle(
                            color: isLocked ? Colors.grey : null,
                          ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete', 
                        enabled: !isLocked,
                        child: Text(
                          '🗑️ Xoá',
                          style: TextStyle(
                            color: isLocked ? Colors.grey : null,
                          ),
                        ),
                      ),
                      if (isLocked)
                        const PopupMenuItem(
                          value: 'lock_info',
                          child: Text('ℹ️ Thông tin khóa'),
                        ),
                    ],
                  );
                },
              ),
            ],
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.white,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _expenseFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadData(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Không tìm thấy chi phí'),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final payer = data['payer'];
          final expenseDate = data['expenseDate'] ?? '';
          final splits = data['splits'] as List<dynamic>? ?? [];
          final category = data['category'];
          final attachments = data['attachments'] as List<dynamic>? ?? [];

          // Extract currency and conversion info
          final originalCurrencyData = data['originalCurrency'];
          final convertedCurrencyData = data['convertedCurrency'];
          final group = data['group'];
          final groupDefaultCurrency = group?['defaultCurrency'] ?? 'VND';
          final originalAmount = data['originalAmount'];
          final convertedAmount = data['convertedAmount']; 
          final exchangeRate = data['exchangeRate'];
          final isMultiCurrency = data['isMultiCurrency'] ?? false;
          // Use convertedAmount for group context, fallback to originalAmount, then 0
          final displayAmount = (convertedAmount ?? originalAmount ?? 0).toDouble();

          // Check if currency conversion occurred
          final hasConversion = isMultiCurrency || 
              (originalCurrencyData != null && 
               convertedCurrencyData != null &&
               originalCurrencyData['code'] != convertedCurrencyData['code']);

          final payerUser = payer['user'];
          return FutureBuilder<String?>(
            future: _loadAvatar(payerUser?['id']),
            builder: (context, payerSnapshot) {
              final payerAvatar = payerSnapshot.data;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card với thông tin chính
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              data['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Category
                            if (category != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: HexColor.fromHex(
                                          category['color'] ?? '#2196F3')
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: HexColor.fromHex(
                                            category['color'] ?? '#2196F3')
                                        .withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (category['iconCode'] != null)
                                      Icon(
                                        getIconDataFromCode(
                                            category['iconCode']),
                                        color: HexColor.fromHex(
                                            category['color'] ?? '#2196F3'),
                                        size: 16,
                                      ),
                                    if (category['iconCode'] != null)
                                      const SizedBox(width: 6),
                                    Text(
                                      category['name'] ?? 'Không có danh mục',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: HexColor.fromHex(
                                            category['color'] ?? '#2196F3'),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 12),

                            // Date và Amount - Timeline Style
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      expenseDate,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500, // Màu xám đồng bộ
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),

                                // 🔒 Lock status (if expense is locked)
                                if (_isExpenseLocked(data))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.lock,
                                          size: 16,
                                          color: Colors.orange[600], // Màu vàng cam
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Đã khóa',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey, // Màu xám đồng bộ
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 16),

                                // Timeline Style Layout
                                if (hasConversion) ...[
                                  // Timeline conversion display
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          HexColor.fromHex(category?['color'] ??
                                                  '#2196F3')
                                              .withOpacity(0.05),
                                          Colors.blue.withOpacity(0.08),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: HexColor.fromHex(
                                                category?['color'] ?? '#2196F3')
                                            .withOpacity(0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        // Timeline header
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: HexColor.fromHex(
                                                        category?['color'] ??
                                                            '#2196F3')
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.timeline,
                                                    size: 14,
                                                    color: HexColor.fromHex(
                                                        category?['color'] ??
                                                            '#2196F3'),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Chuyển đổi tiền tệ',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: HexColor.fromHex(
                                                          category?['color'] ??
                                                              '#2196F3'),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 16),

                                        // Timeline flow - Horizontal layout with result
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Original amount section
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 10,
                                                        height: 10,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: HexColor
                                                              .fromHex(category?[
                                                                      'color'] ??
                                                                  '#2196F3'),
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: HexColor.fromHex(
                                                                      category?[
                                                                              'color'] ??
                                                                          '#2196F3')
                                                                  .withOpacity(
                                                                      0.3),
                                                              blurRadius: 4,
                                                              spreadRadius: 1,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Gốc',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Text(
                                                      _formatCurrency(
                                                          originalAmount,
                                                          originalCurrencyData),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: HexColor.fromHex(
                                                            category?[
                                                                    'color'] ??
                                                                '#2196F3'),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Arrow section
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                height: 40,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    // Background line
                                                    Container(
                                                      height: 2,
                                                      margin: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8),
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                          colors: [
                                                            HexColor.fromHex(
                                                                    category?[
                                                                            'color'] ??
                                                                        '#2196F3')
                                                                .withOpacity(
                                                                    0.3),
                                                            Colors.green
                                                                .withOpacity(
                                                                    0.3),
                                                          ],
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(1),
                                                      ),
                                                    ),
                                                    // Arrow icon with background
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              6),
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                          colors: [
                                                            HexColor.fromHex(
                                                                category?[
                                                                        'color'] ??
                                                                    '#2196F3'),
                                                            Colors.green,
                                                          ],
                                                          begin: Alignment
                                                              .centerLeft,
                                                          end: Alignment
                                                              .centerRight,
                                                        ),
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: HexColor.fromHex(
                                                                    category?[
                                                                            'color'] ??
                                                                        '#2196F3')
                                                                .withOpacity(
                                                                    0.3),
                                                            blurRadius: 6,
                                                            spreadRadius: 1,
                                                          ),
                                                        ],
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Result amount section
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Kết quả',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        width: 10,
                                                        height: 10,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.green,
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .green
                                                                  .withOpacity(
                                                                      0.3),
                                                              blurRadius: 4,
                                                              spreadRadius: 1,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: Text(
                                                      CurrencyFormatter
                                                          .formatMoney(displayAmount,
                                                              groupDefaultCurrency),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 16),

                                        // Exchange rate info
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color:
                                                  Colors.grey.withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.flash_on,
                                                size: 16,
                                                color: Colors.orange[600],
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  '1 ${originalCurrencyData?['code']} = ${CurrencyFormatter.formatExchangeRate(exchangeRate)} ${groupDefaultCurrency}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // No conversion - simple amount display
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: HexColor.fromHex(
                                                category?['color'] ?? '#2196F3')
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        CurrencyFormatter.formatMoney(
                                            displayAmount, _currencyCode),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: HexColor.fromHex(
                                              category?['color'] ?? '#2196F3'),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Thanh toán bởi section
                    const Text(
                      'Thanh toán bởi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _getPayerAvatarImage(payerAvatar),
                          onBackgroundImageError: (exception, stackTrace) {
                            print('❌ Lỗi load avatar: $exception');
                            setState(() {
                              _avatarErrors.add('payer');
                            });
                          },
                          child: _getPayerAvatarChild(payerAvatar, 'payer'),
                        ),
                        title: Text(
                          payer['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          'Thành viên nhóm',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Phân chia chi phí section
                    const Text(
                      'Phân chia chi phí',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...splits.map((split) => _buildSplitItem(split)).toList(),

                    const SizedBox(height: 20),

                    // Ảnh minh chứng section
                    if (attachments.isNotEmpty) ...[
                      const Text(
                        'Ảnh minh chứng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAttachmentsGrid(attachments),
                    ],

                    // Upload indicator
                    if (_isUploading) ...[
                      const SizedBox(height: 20),
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Đang tải ảnh...'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSplitItem(dynamic split) {
    final participant = split['participant'];
    final userId = participant['user']?['id'];
    return FutureBuilder<String?>(
      future: _loadAvatar(userId),
      builder: (context, avatarSnapshot) {
        final avatarUrl = avatarSnapshot.data;
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              backgroundImage: _getParticipantAvatarImage(avatarUrl),
              onBackgroundImageError: (exception, stackTrace) {
                print('❌ Lỗi load avatar: $exception');
                setState(() {
                  _avatarErrors.add(
                      'participant_${participant['user']?['id'] ?? 'unknown'}');
                });
              },
              child: _getParticipantAvatarChild(avatarUrl,
                  'participant_${participant['user']?['id'] ?? 'unknown'}'),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    participant['name'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (split['isPayer'] == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Người thanh toán',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '${(split['percentage'] ?? 0).toStringAsFixed(1)}% của tổng chi phí',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: Text(
              CurrencyFormatter.formatMoney(
                  ((split['amount'] ?? 0) as num).toDouble(), _currencyCode),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentsGrid(List<dynamic> attachments) {
    // Filter out attachments với URL không hợp lệ
    final validAttachments = attachments.where((attachment) {
      final fileUrl = attachment['fileUrl'];
      return fileUrl != null && fileUrl.toString().isNotEmpty;
    }).toList();

    if (validAttachments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text(
            'Không có ảnh minh chứng hợp lệ',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: validAttachments.length,
      itemBuilder: (context, index) {
        final attachment = validAttachments[index];
        final fileUrl = attachment['fileUrl']?.toString() ?? '';
        final imageUrl = replaceBaseUrl(fileUrl);

        // Validate URL trước khi sử dụng
        if (imageUrl.isEmpty || !_isValidUrl(imageUrl)) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey),
                  SizedBox(height: 4),
                  Text(
                    'URL không hợp lệ',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            final validImageUrls = validAttachments
                .map((a) => replaceBaseUrl(a['fileUrl']?.toString() ?? ''))
                .where((url) => url.isNotEmpty && _isValidUrl(url))
                .toList();

            if (validImageUrls.isNotEmpty) {
              final actualIndex = validImageUrls.indexOf(imageUrl);
              _showImageViewer(
                  context, validImageUrls, actualIndex >= 0 ? actualIndex : 0);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('❌ Lỗi load ảnh: $error, URL: $imageUrl');
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 20),
                        SizedBox(height: 4),
                        Text(
                          'Lỗi tải ảnh',
                          style: TextStyle(fontSize: 10, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  String _formatCurrency(dynamic amount, Map<String, dynamic>? currency) {
    if (amount == null || currency == null) return '';

    final currencyCode = currency['code'] ?? 'VND';
    final amountValue = amount is num ? amount.toDouble() : 0.0;

    return CurrencyFormatter.formatMoney(amountValue, currencyCode);
  }

  // 🔒 Helper method to check if expense is locked
  bool _isExpenseLocked(Map<String, dynamic> expenseData) {
    return expenseData['isLocked'] == true;
  }

  // 🔒 Show lock information modal
  void _showLockInfoModal(Map<String, dynamic> expenseData) {
    final lockedAt = expenseData['lockedAt'];
    final finalizationId = expenseData['lockedByFinalizationId'];
    
    String formattedLockTime = 'Không rõ';
    if (lockedAt != null) {
      try {
        final lockDate = DateTime.parse(lockedAt);
        formattedLockTime = DateFormat('dd/MM/yyyy HH:mm').format(lockDate);
      } catch (e) {
        print('Error parsing lock date: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Icon(
                  Icons.lock,
                  color: Colors.orange[600], // Màu vàng cam
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'THÔNG TIN KHÓA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Lock info items
            _buildLockInfoItem(
              icon: Icons.timeline,
              title: 'Đợt tất toán',
              value: finalizationId != null ? '#$finalizationId' : 'Không rõ',
            ),
            
            const SizedBox(height: 12),
            
            _buildLockInfoItem(
              icon: Icons.schedule,
              title: 'Thời gian khóa',
              value: formattedLockTime,
            ),
            
            const SizedBox(height: 12),
            
            _buildLockInfoItem(
              icon: Icons.info_outline,
              title: 'Lý do',
              value: 'Tất toán chi phí nhóm',
            ),

            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build lock info items
  Widget _buildLockInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ImageProvider _getPayerAvatarImage(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return NetworkImage(avatarUrl);
    } else {
      return const AssetImage('assets/images/default_user_avatar.png');
    }
  }

  Widget? _getPayerAvatarChild(String? avatarUrl, String role) {
    // Hiển thị fallback icon nếu có lỗi load avatar
    if (_avatarErrors.contains(role)) {
      return Icon(Icons.person, color: Colors.grey[600], size: 28);
    }
    return null;
  }

  ImageProvider _getParticipantAvatarImage(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return NetworkImage(avatarUrl);
    } else {
      return const AssetImage('assets/images/default_user_avatar.png');
    }
  }

  Widget? _getParticipantAvatarChild(String? avatarUrl, String role) {
    // Hiển thị fallback icon nếu có lỗi load avatar
    if (_avatarErrors.contains(role)) {
      return Icon(Icons.person, color: Colors.grey[600], size: 20);
    }
    return null;
  }
}

// Custom painter for dashed line in timeline
class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  DashedLinePainter({
    required this.color,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
