import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

import '../../models/user.dart';
import '../../models/category.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/media_service.dart';
import '../../services/group_detail_service.dart';
import '../../utils/color_utils.dart';
import '../../utils/icon_utils.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final int expenseId;

  const ExpenseDetailScreen({Key? key, required this.expenseId})
      : super(key: key);

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  late Future<Map<String, dynamic>?> _expenseFuture =
      ExpenseService.fetchExpenseDetail(widget.expenseId);
  User? _currentUser;
  Map<String, String?> participantAvatars = {};

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  List<Map<String, dynamic>> _attachments = [];

  List<XFile> _selectedImages = [];
  List<XFile> _confirmedImages = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCurrentUser();
  }

  Future<void> _loadData() async {
    final data = await ExpenseService.fetchExpenseDetail(widget.expenseId);
    if (data != null) {
      setState(() {
        _expenseFuture = Future.value(data);
        _attachments = (data['attachments'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCurrentUser();
    setState(() => _currentUser = user);
  }

  String replaceBaseUrl(String? url) {
    if (url == null) return '';
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    return url.replaceFirst(
        RegExp(r'^https?://localhost:8080/TravelShare'), apiBaseUrl);
  }

  Future<String?> _loadAvatar(String? userId) async {
    if (userId == null) return null;
    if (participantAvatars.containsKey(userId)) {
      return participantAvatars[userId];
    }
    final url = await MediaService.fetchUserAvatar(userId);
    final replacedUrl = replaceBaseUrl(url);
    setState(() {
      participantAvatars[userId] = replacedUrl;
    });
    return replacedUrl;
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

  void _showImagePreviewDialog(XFile image, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(
              child: Image.file(File(image.path), fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isUploading = true);
                try {
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
                  if (response.statusCode == 201 &&
                      response.data['result'] != null) {
                    setState(() {
                      _attachments.add(response.data['result']);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('🎉 Đã thêm ảnh thành công!')),
                    );
                    await _loadData(); // Load lại danh sách ảnh ngay sau khi upload
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi tải ảnh lên: $e')),
                  );
                } finally {
                  setState(() => _isUploading = false);
                }
                onConfirm();
              },
              child: const Text("✅ Sử dụng ảnh này và tải lên"),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
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
          if (response.statusCode == 201 && response.data['result'] != null) {
            setState(() {
              _attachments.add(response.data['result']);
            });
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🎉 Đã thêm ảnh minh chứng thành công!')),
        );
        await _loadData(); // Load lại danh sách ảnh ngay sau khi upload
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
            title: const Text('Chi tiết chi phí', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                onPressed: _isUploading ? null : _pickAndUploadMedia,
                icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
                tooltip: 'Chọn ảnh minh chứng',
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    final result = await Navigator.pushNamed(
                      context,
                      '/edit-expense',
                      arguments: widget.expenseId,
                    );

                    //Nếu sửa thành công thì reload lại dữ liệu
                    if (result == true) {
                      _loadData();
                      Navigator.pop(context, true);
                    }
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Xác nhận xoá'),
                        content:
                            const Text('Bạn có chắc chắn muốn xoá khoản chi này?'),
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
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('✏️ Sửa')),
                  const PopupMenuItem(value: 'delete', child: Text('🗑️ Xoá')),
                ],
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final payer = data['payer'];
          final expenseDate = data['expenseDate'] ?? '';
          final splits = data['splits'] as List<dynamic>? ?? [];
          final category = data['category'];

          return FutureBuilder<String?>(
            future: _loadAvatar(payer['user']?['id']),
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

                            // Date và Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
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
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _currencyFormat.format(data['amount']),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
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
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage: payerAvatar != null &&
                                  payerAvatar.isNotEmpty
                              ? NetworkImage(payerAvatar)
                              : const AssetImage(
                                      'assets/images/default_user_avatar.png')
                                  as ImageProvider,
                        ),
                        title: Text(
                          payer['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: _currentUser?.id == payer['user']?['id']
                            ? const Text(
                                'Bạn',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currencyFormat.format(data['amount']),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

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
                    ...splits.map((split) {
                      final participant = split['participant'];
                      final userId = participant['user']?['id'];
                      final isMe = _currentUser?.id == userId;
                      return FutureBuilder<String?>(
                        future: _loadAvatar(userId),
                        builder: (context, snapshot) {
                          final avatar = snapshot.data;
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundImage: avatar != null &&
                                        avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : const AssetImage(
                                            'assets/images/default_user_avatar.png')
                                        as ImageProvider,
                              ),
                              title: Text(
                                participant['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: isMe
                                  ? const Text(
                                      'Bạn',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  : null,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _currencyFormat.format(split['amount']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                    if (_attachments.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ảnh minh chứng',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1,
                                ),
                                itemCount: _attachments.length,
                                itemBuilder: (context, index) {
                                  final url = replaceBaseUrl(
                                      _attachments[index]['fileUrl']);
                                  return GestureDetector(
                                    onTap: () => _showImageViewer(
                                      context,
                                      _attachments
                                          .map((e) =>
                                              replaceBaseUrl(e['fileUrl']))
                                          .toList(),
                                      index,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          url,
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
                                              child: const Icon(
                                                Icons.error,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_selectedImages.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text("🖼️ Ảnh được chọn:",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedImages.map((img) {
                              final isConfirmed =
                                  _confirmedImages.contains(img);
                              return GestureDetector(
                                onLongPress: () =>
                                    _showImagePreviewDialog(img, () {
                                  setState(() {
                                    if (!_confirmedImages.contains(img)) {
                                      _confirmedImages.add(img);
                                    }
                                  });
                                }),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(File(img.path),
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover),
                                    ),
                                    if (isConfirmed)
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.check,
                                              size: 16, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
