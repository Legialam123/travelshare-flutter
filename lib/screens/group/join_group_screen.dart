import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/auth_service.dart';
import 'package:flutter/services.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({Key? key}) : super(key: key);

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen>
    with TickerProviderStateMixin {
  final _joinCodeController = TextEditingController();
  final _newNameController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _groupInfo;
  int? _selectedParticipantId;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _newNameController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchJoinInfo() async {
    setState(() => _loading = true);
    try {
      final code = _joinCodeController.text.trim();
      if (code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Vui lòng nhập mã tham gia')),
        );
        setState(() => _loading = false);
        return;
      }

      final response = await AuthService.dio.get('/group/join-info/$code');
      setState(() {
        _groupInfo = response.data['result'];
      });
    } catch (e) {
      String errorMessage = 'Lỗi không xác định';
      if (e is DioException) {
        if (e.response != null && e.response?.data != null) {
          errorMessage = e.response?.data['message'] ?? errorMessage;
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitJoin() async {
    final joinCode = _joinCodeController.text.trim();
    final participantId = _selectedParticipantId;
    final name = _newNameController.text.trim();

    if (participantId == null && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Vui lòng chọn hoặc nhập tên"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.group_add,
                color: Color(0xFF667eea),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text("Xác nhận tham gia"),
          ],
        ),
        content: Text(
          participantId != null
              ? "Bạn có chắc muốn gửi yêu cầu tham gia nhóm với tư cách là thành viên đã có?"
              : "Bạn có chắc muốn gửi yêu cầu tham gia nhóm với tên '$name'?",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Huỷ",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.pop(context, true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "Gửi yêu cầu",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await AuthService.dio.post('/group/join', data: {
        'joinCode': joinCode,
        if (participantId != null) 'participantId': participantId,
        if (participantId == null) 'participantName': name,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.data['message'] ??
              "🎉 Đã gửi yêu cầu tham gia thành công!"),
          duration: const Duration(seconds: 4),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      String errorMessage = 'Lỗi không xác định';
      if (e is DioException) {
        if (e.response != null && e.response?.data != null) {
          errorMessage = e.response?.data['message'] ?? errorMessage;
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _groupInfo = null;
      _selectedParticipantId = null;
      _newNameController.clear();
    });
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
            title: const Text(
              'Tham gia nhóm',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
          ),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child:
                  _groupInfo == null ? _buildJoinCodeForm() : _buildGroupInfo(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinCodeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.group_add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nhập mã tham gia',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nhập mã tham gia nhóm để gửi yêu cầu đến admin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Join Code Input
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mã tham gia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _joinCodeController,
                decoration: InputDecoration(
                  hintText: "Nhập mã tham gia nhóm",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF667eea),
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.vpn_key,
                    color: Color(0xFF667eea),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 20),

              // Check Button
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _joinCodeController.text.trim().isEmpty
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          ),
                    color: _joinCodeController.text.trim().isEmpty
                        ? Colors.grey[300]
                        : null,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: _joinCodeController.text.trim().isEmpty
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF667eea).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap:
                          (_loading || _joinCodeController.text.trim().isEmpty)
                              ? null
                              : _fetchJoinInfo,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: _loading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Đang kiểm tra...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search,
                                    color:
                                        _joinCodeController.text.trim().isEmpty
                                            ? Colors.grey[500]
                                            : Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tìm nhóm',
                                    style: TextStyle(
                                      color: _joinCodeController.text
                                              .trim()
                                              .isEmpty
                                          ? Colors.grey[500]
                                          : Colors.white,
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
      ],
    );
  }

  Widget _buildGroupInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Group Info Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF667eea).withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.group,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhóm được tìm thấy',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _groupInfo!['groupName'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _resetForm,
                icon: const Icon(Icons.close, color: Colors.grey),
                tooltip: 'Nhập mã khác',
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Participants List
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn vai trò tham gia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chọn thành viên có sẵn hoặc tạo vai trò mới',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              // Existing participants
              ...(_groupInfo!['participants'] as List).map((p) {
                final id = p['id'];
                final name = p['name'];
                final hasUser = p['user'] != null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: hasUser ? Colors.grey[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedParticipantId == id
                          ? const Color(0xFF667eea)
                          : (hasUser ? Colors.grey[300]! : Colors.blue[200]!),
                      width: _selectedParticipantId == id ? 2 : 1,
                    ),
                  ),
                  child: hasUser
                      ? ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.lock,
                                color: Colors.grey, size: 20),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: const Text("Đã có người sử dụng"),
                          enabled: false,
                        )
                      : RadioListTile<int>(
                          value: id,
                          groupValue: _selectedParticipantId,
                          onChanged: (v) {
                            setState(() {
                              _selectedParticipantId = v;
                              _newNameController.clear();
                            });
                          },
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: const Text("Có thể tham gia"),
                          activeColor: const Color(0xFF667eea),
                        ),
                );
              }),

              const Divider(height: 32),

              // New participant option
              const Text(
                'Hoặc tạo vai trò mới',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newNameController,
                decoration: InputDecoration(
                  hintText: "Nhập tên của bạn",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF667eea),
                      width: 2,
                    ),
                  ),
                  prefixIcon: const Icon(
                    Icons.person,
                    color: Color(0xFF667eea),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _selectedParticipantId = null;
                    });
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Join Button
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: (_selectedParticipantId != null ||
                      _newNameController.text.trim().isNotEmpty)
                  ? const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    )
                  : null,
              color: (_selectedParticipantId != null ||
                      _newNameController.text.trim().isNotEmpty)
                  ? null
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(15),
              boxShadow: (_selectedParticipantId != null ||
                      _newNameController.text.trim().isNotEmpty)
                  ? [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: (_selectedParticipantId != null ||
                        _newNameController.text.trim().isNotEmpty)
                    ? _submitJoin
                    : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Gửi yêu cầu tham gia',
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

        const SizedBox(height: 40),
      ],
    );
  }
}
