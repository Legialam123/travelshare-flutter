import 'package:flutter/material.dart';
import '../models/group.dart';

class GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback? onTap;

  const GroupCard({super.key, required this.group, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundImage: group.avatarUrl != null
              ? group.avatarUrl!.startsWith('assets/')
                  ? AssetImage(group.avatarUrl!) as ImageProvider
                  : NetworkImage(group.avatarUrl!)
              : null,
          radius: 24,
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Người tạo: ${group.createdBy.fullName ?? 'Chưa rõ'}\n'
          'Ngày tạo: ${group.createdAt.toLocal().toString().split(' ').first}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group, size: 20),
            Text('${group.participants.length} người'),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
