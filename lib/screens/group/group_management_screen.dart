import 'package:flutter/material.dart';
import 'package:travel_share/models/group.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/auth_service.dart';
import '../../widgets/add_participant_form.dart';
import '../../services/group_service.dart';
import '../../widgets/edit_group_form.dart';
import '../../services/category_service.dart';
import '../../services/media_service.dart';
import '../../utils/color_utils.dart';
import '../../utils/icon_utils.dart';
import '../expense_finalization_screen.dart';
import 'package:flutter/services.dart';

class GroupManagementScreen extends StatefulWidget {
  final Group group;
  final String currentUserId;
  final bool isAdmin;

  const GroupManagementScreen({
    Key? key,
    required this.group,
    required this.currentUserId,
    required this.isAdmin,
  }) : super(key: key);

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late Group group;
  bool _isLoading = false;
  bool _wasUpdated = false;

  @override
  void initState() {
    super.initState();
    group = widget.group;
  }

  Future<void> _reloadGroup() async {
    final updatedGroup = await GroupService.getGroupById(group.id);
    setState(() {
      group = updatedGroup;
    });
  }

  String replaceBaseUrl(String? url) {
    if (url == null) return '';
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    return url.replaceFirst(
        RegExp(r'^https?://localhost:8080/TravelShare'), apiBaseUrl);
  }

  Future<String?> _loadAvatar(String? userId) async {
    if (userId == null) return null;
    final url = await MediaService.fetchUserAvatar(userId);
    return replaceBaseUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    // Sắp xếp danh sách thành viên: admin lên đầu, trong mỗi nhóm sắp xếp theo tên
    final sortedParticipants = [
      ...group.participants.where((p) => p.role == 'ADMIN').toList()
        ..sort((a, b) => a.name.compareTo(b.name)),
      ...group.participants.where((p) => p.role != 'ADMIN').toList()
        ..sort((a, b) => a.name.compareTo(b.name)),
    ];

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _wasUpdated);
        return false;
      },
      child: Scaffold(
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
              title: const Text("Quản lý nhóm",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.white,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context, _wasUpdated);
                },
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEditGroupModal(context);
                    } else if (value == 'finalization') {
                      // Navigate to Expense Finalization Screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpenseFinalizationScreen(
                            group: group,
                          ),
                        ),
                      );
                    } else if (value == 'leave') {
                      final lastAdmin = _isLastAdmin();
                      if (lastAdmin) {
                        // ❌ Nếu là Admin cuối cùng thì không cho rời
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '❌ Bạn là Admin cuối cùng, không thể rời nhóm!'),
                          ),
                        );
                        return;
                      }

                      // ✅ Nếu còn Admin khác -> xác nhận rời
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Xác nhận rời khỏi nhóm'),
                          content: const Text(
                              'Bạn có chắc chắn muốn rời khỏi nhóm này?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Huỷ'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text('Rời đi'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await AuthService.dio
                              .delete('/group/${group.id}/leave');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('🎉 Đã rời khỏi nhóm thành công!')),
                          );
                          Navigator.pop(context); // Đóng GroupManagementScreen
                          Navigator.pop(context,
                              true); // Đóng GroupDetailScreen (về HomeScreen)
                        } catch (e) {
                          String errorMessage =
                              'Lỗi không xác định khi rời nhóm';
                          if (e is DioException && e.response?.data != null) {
                            errorMessage =
                                e.response?.data['message'] ?? errorMessage;
                          }
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ $errorMessage')),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('✏️ Sửa thông tin nhóm'),
                    ),
                    if (widget.isAdmin)
                      const PopupMenuItem(
                        value: 'finalization',
                        child: Text('🔒 Tất toán chi phí'),
                      ),
                    const PopupMenuItem(
                      value: 'leave',
                      child: Text('🚪 Rời khỏi nhóm'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // PHẦN A - Thông tin nhóm
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage: group.avatarUrl != null &&
                                      group.avatarUrl!.startsWith('http')
                                  ? NetworkImage(group.avatarUrl!)
                                  : AssetImage(group.avatarUrl!)
                                      as ImageProvider,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tên nhóm
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Tên nhóm : ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black, // màu đen cũ
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          group.name,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Roboto',
                                            color: Color(
                                                0xFF5F27CD), // màu nổi bật
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Danh mục
                                  if (group.category != null)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Danh mục : ',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black, // màu đen cũ
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: HexColor.fromHex(
                                                group.category!.color ??
                                                    '#FFD6E0'),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                getIconDataFromCode(
                                                    group.category!.iconCode),
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                group.category!.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: 'Roboto',
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 10),
                                  // Tiền tệ
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Tiền tệ      : ',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black, // màu đen cũ
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        group.defaultCurrency,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Roboto',
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Ngày tạo
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Ngày tạo   : ',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black, // màu đen cũ
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(group.createdAt),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Roboto',
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (widget.isAdmin) ...[
                                    Row(
                                      children: [
                                        Text(
                                          "Mã tham gia: ",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black, // màu đen cũ
                                          ),
                                        ),
                                        Text(
                                          group.joinCode,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepPurple),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // PHẦN B - Danh sách thành viên
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Thành viên",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        if (widget.isAdmin)
                          ElevatedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => AddParticipantForm(
                                  groupId: group.id,
                                  onSuccess: _reloadGroup,
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text("Thêm"),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...sortedParticipants.map((p) {
                      final isCurrentUser =
                          p.user?.id.toString() == widget.currentUserId;
                      final userId = p.user?.id?.toString();
                      return FutureBuilder<String?>(
                        future: _loadAvatar(userId),
                        builder: (context, snapshot) {
                          final avatar = snapshot.data;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundImage: (avatar != null &&
                                        avatar.isNotEmpty)
                                    ? NetworkImage(avatar)
                                    : const AssetImage(
                                            'assets/images/default_user_avatar.png')
                                        as ImageProvider,
                                backgroundColor: Colors.blue[100],
                              ),
                              title: Text(p.name),
                              subtitle: Text(
                                  "${p.role == 'ADMIN' ? 'Trưởng nhóm' : 'Thành viên'}${isCurrentUser ? ' (Bạn)' : ''} - ${p.displayStatus}"),
                              trailing: isCurrentUser
                                  ? const Icon(Icons.chevron_right)
                                  : (!p.hasLinkedUser && widget.isAdmin
                                      ? TextButton(
                                          onPressed: () =>
                                              _showInviteDialog(context, p.id),
                                          child: const Text("📧 Mời"))
                                      : null),
                              onTap: () => _showUserProfileModal(context, p, isCurrentUser, avatar),
                              onLongPress: widget.isAdmin || isCurrentUser
                                  ? () => _showActions(context, p,
                                      isCurrentUser: isCurrentUser)
                                  : null,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, int participantId) {
    final TextEditingController _emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mời người dùng'),
        content: TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Nhập email người dùng'),
        ),
        actions: [
          TextButton(
            child: const Text('Huỷ'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Mời'),
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isEmpty) return;

              Navigator.pop(context); // đóng dialog
              try {
                final response = await AuthService.dio.post(
                  '/group/invite',
                  data: {
                    'participantId': participantId,
                    'email': email,
                  },
                );

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(response.data['message'] ??
                        'Đã gửi mã tham gia qua email'),
                    backgroundColor: Colors.black,
                    duration: const Duration(seconds: 4),
                  ),
                );

                _reloadGroup(); // làm mới danh sách thành viên
              } catch (e) {
                String errorMessage = '❌ Lỗi không xác định khi mời';
                if (e is DioException && e.response?.data != null) {
                  final data = e.response?.data;
                  errorMessage = data['message'] ?? errorMessage;
                }

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errorMessage)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditGroupModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditGroupForm(
        group: group,
        onUpdated: () async {
          final updatedGroup = await GroupService.getGroupById(group.id);
          setState(() {
            group = updatedGroup;
          });
          _wasUpdated = true;
          if (context.mounted) {
            Navigator.pop(context, true);
          }
        },
      ),
    );
  }

  void _showActions(BuildContext context, GroupParticipant participant,
      {bool isCurrentUser = false}) {
    final isCurrentUserAdmin = isCurrentUser && participant.role == 'ADMIN';
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (isCurrentUser)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Đổi tên hiển thị'),
                onTap: () {
                  Navigator.pop(context);
                  _showChangeNameDialog(context, participant);
                },
              ),
            if (widget.isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(participant.role == 'ADMIN'
                    ? 'Chuyển thành MEMBER'
                    : 'Chuyển thành ADMIN'),
                onTap: () async {
                  Navigator.pop(context); // đóng modal
                  await _changeRole(participant);
                },
              ),
              if (!isCurrentUserAdmin)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  title: const Text('Xoá khỏi nhóm',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context); // đóng modal
                    await _removeParticipant(participant);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isLastAdmin() {
    int adminCount = 0;
    bool isCurrentUserAdmin = false;

    for (var participant in group.participants) {
      if (participant.role == 'ADMIN') {
        adminCount++;
        if (participant.user?.id == widget.currentUserId) {
          isCurrentUserAdmin = true;
        }
      }
    }

    return isCurrentUserAdmin && adminCount <= 1;
  }

  Future<void> _changeRole(GroupParticipant participant) async {
    try {
      final newRole = participant.role == 'ADMIN' ? 'MEMBER' : 'ADMIN';
      await AuthService.dio.put(
          '/group/${group.id}/participant/${participant.id}/update_role',
          data: {
            'newRole': newRole,
            'groupId': group.id,
            'participantId': participant.id
          });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã đổi quyền thành công!')),
      );
      await _reloadGroup();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi đổi quyền: $e')),
      );
    }
  }

  Future<void> _removeParticipant(GroupParticipant participant) async {
    try {
      await AuthService.dio
          .delete('/group/${group.id}/participant/${participant.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xoá thành viên khỏi nhóm')),
      );
      await _reloadGroup();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi xóa thành viên: $e')),
      );
    }
  }

  // Hiển thị dialog chọn danh mục
  void _showChangeCategoryDialog(BuildContext context, Group group) async {
    setState(() => _isLoading = true);

    try {
      // Lấy danh sách danh mục GROUP từ server
      final categories = await CategoryService.fetchGroupCategories();

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Hiển thị dialog chọn danh mục
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chọn danh mục'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = group.category?.id == category.id;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        HexColor.fromHex(category.color ?? '#000000'),
                    child: Icon(
                      getIconDataFromCode(category.iconCode),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(category.name),
                  subtitle: Text(category.description),
                  selected: isSelected,
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () async {
                    // Cập nhật danh mục cho nhóm
                    try {
                      Navigator.pop(context); // Đóng dialog trước
                      setState(() => _isLoading = true);

                      await GroupService.updateGroupCategory(
                          group.id, category.id);

                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                          _reloadGroup(); // Tải lại dữ liệu nhóm
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Đã cập nhật danh mục nhóm')),
                        );
                      }
                    } catch (e) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi: $e')),
                      );
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải danh mục: $e')),
      );
    }
  }

  void _showUserProfileModal(BuildContext context, GroupParticipant participant, bool isCurrentUser, String? avatarUrl) {
    // Không hiện modal nếu là bản thân hoặc participant chưa liên kết user
    if (isCurrentUser || participant.user == null) {
      return;
    }



    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => UserProfileModal(
        userSummary: participant.user!,
        participantName: participant.name,
        participantRole: participant.role,
        participantAvatarUrl: avatarUrl,
      ),
    );
  }

  void _showChangeNameDialog(
      BuildContext context, GroupParticipant participant) {
    final controller = TextEditingController(text: participant.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đổi tên hiển thị'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Tên mới'),
        ),
        actions: [
          TextButton(
            child: const Text('Huỷ'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Lưu'),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(context);
              try {
                await AuthService.dio.put(
                  '/group/${group.id}/participant/${participant.id}/update_name',
                  data: {
                    'groupId': group.id,
                    'participantId': participant.id,
                    'newName': newName,
                  },
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã đổi tên thành công!')),
                );
                await _reloadGroup();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Lỗi đổi tên: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// Widget hiển thị thông tin user thực tế
class UserProfileModal extends StatelessWidget {
  final UserSummaryResponse userSummary;
  final String participantName;
  final String participantRole;
  final String? participantAvatarUrl;

  const UserProfileModal({
    Key? key,
    required this.userSummary,
    required this.participantName,
    required this.participantRole,
    this.participantAvatarUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header compact với avatar và tên
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: (participantAvatarUrl != null && participantAvatarUrl!.isNotEmpty)
                    ? NetworkImage(participantAvatarUrl!)
                    : const AssetImage('assets/images/default_user_avatar.png')
                        as ImageProvider,
                backgroundColor: Colors.blue[100],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userSummary.fullName ?? 'Không có tên',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$participantName (${participantRole == 'ADMIN' ? 'Trưởng nhóm' : 'Thành viên'})',
                      style: TextStyle(
                        fontSize: 13,
                        color: participantRole == 'ADMIN' ? Colors.orange.shade600 : Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Thông tin liên hệ compact
          Column(
            children: [
              // Email
              if (userSummary.email != null && userSummary.email!.isNotEmpty)
                _buildCompactInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: userSummary.email!,
                  iconColor: Colors.red.shade400,
                ),
              
              // Số điện thoại
              if (userSummary.phoneNumber != null && userSummary.phoneNumber!.isNotEmpty)
                _buildCompactInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Số điện thoại',
                  value: userSummary.phoneNumber!,
                  iconColor: Colors.green.shade400,
                ),

              // Ngày sinh
              if (userSummary.dob != null)
                _buildCompactInfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Ngày sinh',
                  value: DateFormat('dd/MM/yyyy').format(userSummary.dob!),
                  iconColor: Colors.purple.shade400,
                ),
            ],
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }



  Widget _buildCompactInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
