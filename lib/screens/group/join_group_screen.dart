import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../models/group.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({Key? key}) : super(key: key);

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _joinCodeController = TextEditingController();
  final _newNameController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _groupInfo;
  int? _selectedParticipantId;

  Future<void> _fetchJoinInfo() async {
    setState(() => _loading = true);
    try {
      final code = _joinCodeController.text.trim();
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
        SnackBar(content: Text('❌ $errorMessage')),
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
        const SnackBar(content: Text("Vui lòng chọn hoặc nhập tên")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xác nhận"),
        content: Text(
          participantId != null
              ? "Bạn có chắc muốn tham gia nhóm với tư cách là thành viên đã có?"
              : "Bạn có chắc muốn tham gia nhóm với tên '$name'?",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Huỷ")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Tham gia")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AuthService.dio.post('/group/join', data: {
        'joinCode': joinCode,
        if (participantId != null) 'participantId': participantId,
        if (participantId == null) 'participantName': name,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎉 Tham gia nhóm thành công!")),
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
        SnackBar(content: Text('❌ $errorMessage')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nhập mã tham gia")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _groupInfo == null
            ? Column(
                children: [
                  TextField(
                    controller: _joinCodeController,
                    decoration: const InputDecoration(
                      labelText: "Mã tham gia",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _fetchJoinInfo,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text("Xác nhận"),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("📍 Nhóm: ${_groupInfo!['groupName']}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    const Text("Chọn vai trò tham gia:"),
                    ...(_groupInfo!['participants'] as List).map((p) {
                      final id = p['id'];
                      final name = p['name'];
                      final linked = p['user'] != null;
                      return linked
                          ? ListTile(
                              leading: const Icon(Icons.lock),
                              title: Text(name),
                              subtitle: const Text("Đã được liên kết"),
                            )
                          : RadioListTile<int>(
                              value: id,
                              groupValue: _selectedParticipantId,
                              onChanged: (v) =>
                                  setState(() => _selectedParticipantId = v),
                              title: Text(name),
                              subtitle: const Text("Chưa liên kết"),
                            );
                    }),
                    const Divider(),
                    const Text("Hoặc nhập tên mới:"),
                    TextField(
                      controller: _newNameController,
                      decoration:
                          const InputDecoration(hintText: "Nhập tên của bạn"),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text("Tham gia"),
                      onPressed: _submitJoin,
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
