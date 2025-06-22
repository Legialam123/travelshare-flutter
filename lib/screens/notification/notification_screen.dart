import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
// TODO: Thay thế bằng model và service thực tế của bạn
import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../services/group_service.dart';
import '../../models/group.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  NotificationScreenState createState() => NotificationScreenState();
}

class NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isFiltering = false; // loading overlay khi lọc

  // Filter state
  DateTimeRange? _selectedDateRange;
  String? _selectedGroup;
  String? _selectedType;
  List<GroupSummary> _userGroups = [];

  @override
  void initState() {
    super.initState();
    _loadGroupsAndNotifications();
  }

  Future<void> _loadGroupsAndNotifications() async {
    setState(() => _isLoading = true);
    try {
      // Lấy danh sách group user tham gia
      final groups = await GroupService.fetchGroups();
      _userGroups = groups.map((g) => GroupSummary(id: g.id, name: g.name)).toList();
      await _fetchNotifications();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải nhóm: $e')),
      );
    }
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isFiltering = true;
    });
    try {
      final notifications = await NotificationService.getMyNotifications(
        groupId: _selectedGroup,
        type: _selectedType,
        dateRange: _selectedDateRange,
      );
      setState(() {
        _notifications = notifications;
        _isLoading = false;
        _isFiltering = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isFiltering = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải thông báo: $e')),
      );
    }
  }

  void _showFilterSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _FilterSheet(
        initialDateRange: _selectedDateRange,
        initialGroup: _selectedGroup,
        initialType: _selectedType,
        groups: _userGroups,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedDateRange = result['dateRange'];
        _selectedGroup = result['group'];
        _selectedType = result['type'];
      });
      _fetchNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
                  'Thông báo',
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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    tooltip: 'Lọc thông báo',
                    onPressed: _showFilterSheet,
                  ),
                ],
              ),
            ),
          ),
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              // Hiển thị filter đang áp dụng
              if (_selectedGroup != null || _selectedType != null || _selectedDateRange != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildActiveFilterBar(),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _notifications.isEmpty
                        ? const Center(child: Text('Không có thông báo nào.'))
                        : RefreshIndicator(
                            onRefresh: _fetchNotifications,
                            child: _buildGroupedNotificationList(),
                          ),
              ),
            ],
          ),
        ),
        // Loading overlay khi đang lọc
        if (_isFiltering)
          Container(
            color: Colors.black.withOpacity(0.15),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'EXPENSE_CREATED':
        return Icons.attach_money_rounded;
      case 'GROUP_UPDATED':
        return Icons.group_rounded;
      case 'MEMBER_JOINED':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'EXPENSE_CREATED':
        return Colors.green;
      case 'GROUP_UPDATED':
        return Colors.purple;
      case 'MEMBER_JOINED':
        return Colors.blue;
      default:
        return Colors.deepPurple;
    }
  }

  void _navigateToDetail(NotificationModel noti) {
    // Điều hướng dựa vào type và referenceId
    if (noti.type == 'EXPENSE_CREATED' && noti.referenceId != null) {
      Navigator.pushNamed(context, '/expense_detail', arguments: noti.referenceId);
    } else if (noti.type == 'GROUP_UPDATED' && noti.referenceId != null) {
      Navigator.pushNamed(context, '/group_detail', arguments: noti.referenceId);
    }
    // Có thể mở rộng thêm các loại khác nếu cần
  }

  Widget _buildActiveFilterBar() {
    List<String> filters = [];
    if (_selectedGroup != null) {
      final group = _userGroups.firstWhereOrNull((g) => g.id.toString() == _selectedGroup);
      if (group != null) filters.add('Nhóm: ${group.name}');
    }
    if (_selectedType != null) {
      String typeLabel = _selectedType == 'EXPENSE_CREATED'
          ? 'Tạo khoản chi'
          : _selectedType == 'GROUP_UPDATED'
              ? 'Cập nhật nhóm'
              : _selectedType == 'MEMBER_JOINED'
                  ? 'Thành viên mới'
                  : _selectedType!;
      filters.add('Loại: $typeLabel');
    }
    if (_selectedDateRange != null) {
      filters.add('Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, color: Color(0xFF667eea), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              filters.join('  |  '),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_selectedGroup != null || _selectedType != null || _selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
              tooltip: 'Xoá filter',
              onPressed: () {
                setState(() {
                  _selectedGroup = null;
                  _selectedType = null;
                  _selectedDateRange = null;
                });
                _fetchNotifications();
              },
            ),
        ],
      ),
    );
  }

  Widget buildNotificationCard(NotificationModel noti) {
    final iconData = _getIconForType(noti.type);
    final iconColor = _getColorForType(noti.type);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _navigateToDetail(noti),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [iconColor.withOpacity(0.8), iconColor.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(iconData, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              // Nội dung
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noti.content,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (noti.group != null)
                      Text('Nhóm: ${noti.group.name}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    if (noti.createdBy != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                noti.createdBy.fullName,
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm').format(noti.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 8),
      child: Text(
        date,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF667eea),
        ),
      ),
    );
  }

  Widget _buildGroupedNotificationList() {
    final Map<String, List<NotificationModel>> grouped = {};
    for (final noti in _notifications) {
      final dateStr = DateFormat('dd/MM/yyyy').format(noti.createdAt);
      grouped.putIfAbsent(dateStr, () => []).add(noti);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => DateFormat('dd/MM/yyyy').parse(b).compareTo(DateFormat('dd/MM/yyyy').parse(a)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sortedKeys.fold<int>(0, (prev, key) => prev + 1 + grouped[key]!.length),
      itemBuilder: (context, index) {
        int runningIndex = 0;
        for (final date in sortedKeys) {
          // Header
          if (index == runningIndex) {
            return buildDateHeader(date);
          }
          runningIndex++;
          final notis = grouped[date]!;
          if (index < runningIndex + notis.length) {
            final noti = notis[index - runningIndex];
            return buildNotificationCard(noti);
          }
          runningIndex += notis.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Thêm hàm public để reload từ ngoài
  Future<void> reloadNotifications() async {
    await _loadGroupsAndNotifications();
  }
}

// Widget filter bottom sheet
class _FilterSheet extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final String? initialGroup;
  final String? initialType;
  final List<GroupSummary> groups;
  const _FilterSheet({this.initialDateRange, this.initialGroup, this.initialType, required this.groups});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTimeRange? _dateRange;
  String? _group;
  String? _type;

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialDateRange;
    _group = widget.initialGroup;
    _type = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bộ lọc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          // Chọn ngày
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_dateRange == null
                ? 'Chọn khoảng ngày'
                : '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}'),
            trailing: const Icon(Icons.date_range),
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2022),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _dateRange,
              );
              if (picked != null) setState(() => _dateRange = picked);
            },
          ),
          const SizedBox(height: 8),
          // Chọn group động
          DropdownButtonFormField<String>(
            value: _group,
            decoration: const InputDecoration(labelText: 'Nhóm'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tất cả nhóm')),
              ...widget.groups.map((g) => DropdownMenuItem(value: g.id.toString(), child: Text(g.name))),
            ],
            onChanged: (g) => setState(() => _group = g),
          ),
          const SizedBox(height: 8),
          // Chọn loại thông báo
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Loại thông báo'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tất cả loại')),
              DropdownMenuItem(value: 'EXPENSE_CREATED', child: Text('Tạo khoản chi')),
              DropdownMenuItem(value: 'GROUP_UPDATED', child: Text('Cập nhật nhóm')),
              DropdownMenuItem(value: 'MEMBER_JOINED', child: Text('Thành viên mới')),
            ],
            onChanged: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _dateRange = null;
                    _group = null;
                    _type = null;
                  });
                },
                child: const Text('Đặt lại'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'dateRange': _dateRange,
                    'group': _group,
                    'type': _type,
                  });
                },
                child: const Text('Áp dụng'),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 