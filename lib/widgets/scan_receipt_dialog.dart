import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';


class ScanReceiptDialog extends StatefulWidget {
  const ScanReceiptDialog({Key? key}) : super(key: key);

  @override
  State<ScanReceiptDialog> createState() => _ScanReceiptDialogState();
}

class _ScanReceiptDialogState extends State<ScanReceiptDialog> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String? _processingStatus;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.document_scanner, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quét hóa đơn',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Chụp ảnh hoặc chọn từ thư viện',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Padding để tránh chồng lấp với nút X
                    const SizedBox(width: 48),
                  ],
                ),
            
            const SizedBox(height: 24),
            
            if (_isProcessing) ...[
              // Processing State
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _processingStatus ?? 'Đang xử lý...',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Action Buttons
              _buildActionButton(
                icon: Icons.camera_alt,
                title: 'Chụp ảnh',
                subtitle: 'Mở camera để chụp hóa đơn',
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              
              const SizedBox(height: 16),
              
              _buildActionButton(
                icon: Icons.photo_library,
                title: 'Chọn từ thư viện',
                subtitle: 'Chọn ảnh hóa đơn có sẵn',
                gradient: const LinearGradient(
                  colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                ),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              
              const SizedBox(height: 24),
              
              // Tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, 
                             size: 20, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Mẹo để quét chính xác',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Chụp ảnh rõ nét, không bị mờ\n'
                      '• Đảm bảo ánh sáng đủ\n'
                      '• Hóa đơn phẳng, không bị nhăn\n'
                      '• Chụp toàn bộ hóa đơn',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      // Nút X positioned ở góc trên bên phải
      Positioned(
        top: 8,
        right: 8,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
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
);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                                      Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Check permissions
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (status.isDenied) {
          _showError('Cần quyền truy cập camera để chụp ảnh');
          return;
        }
      }

      setState(() {
        _isProcessing = true;
        _processingStatus = source == ImageSource.camera 
            ? 'Đang mở camera...' 
            : 'Đang mở thư viện ảnh...';
      });

      // Pick image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Process OCR
      await _processImage(pickedFile);
      
    } catch (e) {
      print('❌ Error picking image: $e');
      _showError('Lỗi khi chọn ảnh: $e');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    try {
      setState(() {
        _processingStatus = 'Đang chuẩn bị ảnh...';
      });

      // Small delay để user thấy processing status
      await Future.delayed(const Duration(milliseconds: 500));

      // Return imageFile for ChatGPT OCR processing
      if (mounted) {
        Navigator.of(context).pop({
          'imageFile': imageFile,
        });
      }

    } catch (e) {
      print('❌ Error processing image: $e');
      _showError('Lỗi khi xử lý ảnh: $e');
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

// Helper function để show dialog
class ScanReceiptHelper {
  static Future<Map<String, dynamic>?> showScanDialog(BuildContext context) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ScanReceiptDialog(),
    );
  }
} 