import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  User? _user;
  String _userId = '';
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  Timer? _countdownTimer; // 🎯 Add timer for countdown

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    if (_animationController != null) {
      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
      );
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
          parent: _animationController!, curve: Curves.easeOutCubic));
    }

    _loadUser();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _countdownTimer
        ?.cancel(); // 🎯 Cancel timer to prevent setState after dispose
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getCurrentUser();
    setState(() {
      _user = user;
      _userId = user?.id ?? '';
      _isLoading = false;
    });
    _animationController?.forward();
  }

  String getAvatarUrl(String? url) {
    if (url == null) return '';
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    return url.replaceFirst('http://localhost:8080/TravelShare', apiBaseUrl);
  }

  Future<void> _confirmDeleteAccount() async {
    try {
      final url = "/users/$_userId";

      await AuthService.dio.delete(url);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Tài khoản đã được xoá")),
        );

        // Xoá token và điều hướng về login
        _onLogout();
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Xoá thất bại: ${e.toString()}")),
      );
    }
  }

  Future<void> _updateAvatar() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final fileName = path.basename(pickedFile.path);
    final fileExt = path.extension(fileName).toLowerCase();
    final mediaType = {
          '.jpg': MediaType('image', 'jpeg'),
          '.jpeg': MediaType('image', 'jpeg'),
          '.png': MediaType('image', 'png'),
          '.gif': MediaType('image', 'gif'),
        }[fileExt] ??
        MediaType('application', 'octet-stream');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        pickedFile.path,
        filename: fileName,
        contentType: mediaType,
      ),
      'description': 'avatar',
    });

    try {
      final response =
          await AuthService.dio.post('/media/user', data: formData);
      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật ảnh đại diện thành công')),
        );
        _loadUser(); // reload avatar mới
      } else {
        throw Exception('Upload thất bại');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật avatar: $e')),
      );
    }
  }

  void _onChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  void _onDeleteAccount() async {
    int countdown = 5;
    bool confirmEnabled = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 🎯 Start countdown timer only once
            if (_countdownTimer == null && countdown > 0) {
              _countdownTimer =
                  Timer.periodic(const Duration(seconds: 1), (timer) {
                if (countdown > 0) {
                  setDialogState(() => countdown--);
                } else {
                  setDialogState(() => confirmEnabled = true);
                  timer.cancel();
                  _countdownTimer = null;
                }
              });
            }

            return AlertDialog(
              title: const Text("Xác nhận xoá tài khoản"),
              content: Text(
                  "Bạn chắc chắn muốn xoá tài khoản? Điều này không thể hoàn tác.\n\n"
                  "Nút xác nhận sẽ bật sau ${countdown > 0 ? countdown : 0} giây."),
              actions: [
                TextButton(
                  onPressed: () {
                    _countdownTimer?.cancel(); // 🎯 Cancel timer when canceling
                    _countdownTimer = null;
                    Navigator.pop(context);
                  },
                  child: const Text("Huỷ"),
                ),
                ElevatedButton(
                  onPressed: confirmEnabled
                      ? () async {
                          _countdownTimer
                              ?.cancel(); // 🎯 Cancel timer before closing
                          _countdownTimer = null;
                          Navigator.pop(context); // đóng dialog
                          await _confirmDeleteAccount(); // gọi API
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Xác nhận xoá"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onLogout() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // 🎯 Remove back button
        toolbarHeight: 0, // 🎯 Hide AppBar completely
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('Không thể tải thông tin người dùng'))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 40), // 🎯 More top spacing

                        // 🎯 Profile Header - No Card
                        _fadeAnimation != null && _slideAnimation != null
                            ? FadeTransition(
                                opacity: _fadeAnimation!,
                                child: SlideTransition(
                                  position: _slideAnimation!,
                                  child: Column(
                                    children: [
                                      // 🎯 Avatar with edit overlay
                                      Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF667eea),
                                                width: 4,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: CircleAvatar(
                                              radius: 50,
                                              backgroundImage: _user!
                                                          .avatarUrl !=
                                                      null
                                                  ? NetworkImage(getAvatarUrl(
                                                      _user!.avatarUrl))
                                                  : const AssetImage(
                                                          'assets/images/default_user_avatar.png')
                                                      as ImageProvider,
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: GestureDetector(
                                              onTap: _updateAvatar,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF667eea),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: Colors.white,
                                                      width: 3),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.2),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.camera_alt,
                                                  size: 20,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // 🎯 User Info
                                      Text(
                                        _user!.fullName ?? 'Chưa có tên',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D3748),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF667eea)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _user!.email ?? '',
                                          style: const TextStyle(
                                            color: Color(0xFF667eea),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  // 🎯 Avatar with edit overlay
                                  Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF667eea),
                                            width: 4,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundImage: _user!.avatarUrl !=
                                                  null
                                              ? NetworkImage(getAvatarUrl(
                                                  _user!.avatarUrl))
                                              : const AssetImage(
                                                      'assets/images/default_user_avatar.png')
                                                  as ImageProvider,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: _updateAvatar,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF667eea),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 3),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // 🎯 User Info
                                  Text(
                                    _user!.fullName ?? 'Chưa có tên',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF667eea)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _user!.email ?? '',
                                      style: const TextStyle(
                                        color: Color(0xFF667eea),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                        const SizedBox(height: 40),

                        // 🎯 Menu Items - No Card Container
                        _buildMenuTile(
                          icon: Icons.person_outline,
                          title: 'Thông tin cá nhân',
                          subtitle: 'Chỉnh sửa hồ sơ của bạn',
                          color: const Color(0xFF4299E1),
                          onTap: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen()),
                            );
                            if (updated == true) {
                              _loadUser();
                            }
                          },
                        ),

                        _buildMenuTile(
                          icon: Icons.lock_outline,
                          title: 'Đổi mật khẩu',
                          subtitle: 'Cập nhật mật khẩu bảo mật',
                          color: const Color(0xFF48BB78),
                          onTap: _onChangePassword,
                        ),

                        _buildMenuTile(
                          icon: Icons.delete_forever_outlined,
                          title: 'Xoá tài khoản',
                          subtitle: 'Xoá vĩnh viễn tài khoản này',
                          color: const Color(0xFFE53E3E),
                          onTap: _onDeleteAccount,
                        ),

                        const SizedBox(height: 20),

                        // 🎯 Logout Button
                        Container(
                          width: double.infinity,
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
                              onTap: _onLogout,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.logout, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text(
                                      'Đăng xuất',
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

                        const SizedBox(height: 40), // Bottom spacing
                      ],
                    ),
                  ),
                ),
    );
  }

  // 🎯 Custom Menu Tile Widget
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
