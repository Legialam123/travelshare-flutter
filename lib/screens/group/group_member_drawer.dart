import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:travel_share/models/group.dart';

class GroupMemberDrawer extends StatelessWidget {
  final List<GroupParticipant> participants;
  final String currentUserId;
  final bool isAdmin;

  const GroupMemberDrawer({
    Key? key,
    required this.participants,
    required this.currentUserId,
    required this.isAdmin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thành viên nhóm"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: ListView.builder(
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final p = participants[index];
          final isCurrentUser = p.user?.id == currentUserId;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(p.name[0]),
            ),
            title: Text(p.name),
            subtitle: Text(p.role + (isCurrentUser ? " (Bạn)" : "")),
            onLongPress: isAdmin
                ? () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => _buildActionSheet(context, p),
                    );
                  }
                : null,
            trailing: !p.hasLinkedUser && isAdmin
                ? TextButton(
                    onPressed: () {
                      // TODO: Gửi lời mời liên kết user vào nhóm
                    },
                    child: const Text("Mời"),
                  )
                : null,
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add),
              label: const Text("Thêm thành viên"),
              onPressed: () {
                // TODO: Hiển thị form thêm thành viên mới
              },
            )
          : null,
    );
  }

  Widget _buildActionSheet(BuildContext context, GroupParticipant p) {
    return Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.admin_panel_settings),
          title: const Text("Đổi quyền"),
          onTap: () {
            // TODO: Gọi API updateRole
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.remove_circle_outline),
          title: const Text("Xoá khỏi nhóm"),
          onTap: () {
            // TODO: Gọi API removeParticipant
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
