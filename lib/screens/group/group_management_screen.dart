import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travel_share/models/group.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../../services/auth_service.dart';
import '../../widgets/add_participant_form.dart';
import '../../services/group_service.dart';
import '../../widgets/edit_group_form.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../utils/color_utils.dart';
import '../../utils/icon_utils.dart';
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
            title: const Text("Quản lý nhóm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.white,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  if (value == 'edit') {
                    _showEditGroupModal(context);
                  } else if (value == 'leave') {
                    final lastAdmin = _isLastAdmin();
                    if (lastAdmin) {
                      // ❌ Nếu là Admin cuối cùng thì không cho rời
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('❌ Bạn là Admin cuối cùng, không thể rời nhóm!'),
                        ),
                      );
                      return;
                    }

                    // ✅ Nếu còn Admin khác -> xác nhận rời
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Xác nhận rời khỏi nhóm'),
                        content:
                            const Text('Bạn có chắc chắn muốn rời khỏi nhóm này?'),
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
                        await AuthService.dio.delete('/group/${group.id}/leave');
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('🎉 Đã rời khỏi nhóm thành công!')),
                        );
                        Navigator.pop(context); // Đóng GroupManagementScreen
                        Navigator.pop(context,
                            true); // Đóng GroupDetailScreen (về HomeScreen)
                      } catch (e) {
                        String errorMessage = 'Lỗi không xác định khi rời nhóm';
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
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: group.avatarUrl != null &&
                                    group.avatarUrl!.startsWith('http')
                                ? NetworkImage(group.avatarUrl!)
                                : AssetImage(group.avatarUrl!) as ImageProvider,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        group.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Hiển thị danh mục
                                if (group.category != null)
                                  Row(
                                    children: [
                                      Icon(
                                        getIconDataFromCode(
                                            group.category!.iconCode),
                                        size: 18,
                                        color: HexColor.fromHex(
                                            group.category!.color ?? '#000000'),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        group.category!.name,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.monetization_on,
                                        size: 18, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${group.budgetLimit ?? 0} ${group.defaultCurrency}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 18, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(group.createdAt),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.isAdmin) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.vpn_key,
                                  size: 20, color: Colors.deepPurple),
                              const SizedBox(width: 8),
                              Text(
                                "Mã tham gia: ",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[700]),
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
                        ),
                      ],
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
                  ...group.participants.map((p) {
                    final isCurrentUser =
                        p.user?.id.toString() == widget.currentUserId;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text(p.name[0]),
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                            "${p.role}${isCurrentUser ? ' (Bạn)' : ''} - ${p.status}"),
                        trailing: p.user == null && widget.isAdmin
                            ? TextButton(
                                onPressed: () =>
                                    _showInviteDialog(context, p.id),
                                child: const Text("📧 Mời"))
                            : null,
                        onLongPress: widget.isAdmin
                            ? () => _showActions(context, p)
                            : null,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
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
                    content: Text(response.data['message'] ?? 'Đã gửi lời mời'),
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
          Navigator.pop(context, true);
        },
      ),
    );
  }

  void _showActions(BuildContext context, GroupParticipant participant) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
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
            ListTile(
              leading:
                  const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const Text('Xoá khỏi nhóm',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context); // đóng modal
                await _removeParticipant(participant);
              },
            ),
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
                  subtitle: Text(category.description ?? ''),
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
}
