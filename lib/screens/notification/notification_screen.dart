import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../models/notification.dart';
import '../../models/request.dart';
import '../../models/user.dart';
import '../../services/notification_service.dart';
import '../../services/request_service.dart';
import '../../services/group_service.dart';
import '../../services/settlement_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../expense_finalization_screen.dart';
import '../../models/group.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  NotificationScreenState createState() => NotificationScreenState();
}

class NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Notification state
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isFiltering = false;
  DateTimeRange? _selectedDateRange;
  String? _selectedGroup;
  String? _selectedType;
  List<GroupSummary> _userGroups = [];

  // Request state
  List<RequestModel> _allRequests = [];
  bool _isRequestLoading = true;
  bool _isRequestFiltering = false;
  DateTimeRange? _selectedRequestDateRange;
  String? _selectedRequestGroup;
  String? _selectedRequestType;
  String _requestDirection = 'all'; // Thêm biến thiếu
  Map<int, bool> _cancelLoading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadGroupsAndNotifications();
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // Không cần reload data khi chuyển tab vì filter đã tách biệt
    // Mỗi tab sẽ giữ filter state riêng
  }

  Future<void> _loadGroupsAndNotifications() async {
    setState(() => _isLoading = true);
    try {
      final groups = await GroupService.fetchGroups();
      _userGroups =
          groups.map((g) => GroupSummary(id: g.id, name: g.name)).toList();
      await _fetchNotifications();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải nhóm: $e')),
      );
    }
  }

  void _loadRequests() async {
    setState(() {
      _isRequestLoading = true;
    });
    try {
      final requests = await RequestService.fetchReceivedRequestsWithFilter(
        groupId: _selectedRequestGroup,
        type: _selectedRequestType,
        dateRange: _selectedRequestDateRange,
        direction: _requestDirection,
      );
      setState(() {
        _allRequests = requests;
        _isRequestLoading = false;
      });
    } catch (e) {
      setState(() {
        _isRequestLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải yêu cầu: $e')),
      );
    }
  }

  Future<void> _fetchRequestsWithFilter() async {
    setState(() {
      _isRequestFiltering = true;
    });
    try {
      final requests = await RequestService.fetchReceivedRequestsWithFilter(
        groupId: _selectedRequestGroup,
        type: _selectedRequestType,
        dateRange: _selectedRequestDateRange,
        direction: _requestDirection,
      );
      setState(() {
        _allRequests = requests;
        _isRequestFiltering = false;
      });
    } catch (e) {
      setState(() {
        _isRequestFiltering = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải yêu cầu: $e')),
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
        initialDateRange: _tabController.index == 0
            ? _selectedDateRange
            : _selectedRequestDateRange,
        initialGroup:
            _tabController.index == 0 ? _selectedGroup : _selectedRequestGroup,
        initialType:
            _tabController.index == 0 ? _selectedType : _selectedRequestType,
        initialDirection: _tabController.index == 1 ? _requestDirection : null,
        groups: _userGroups,
        isRequestTab: _tabController.index == 1,
      ),
    );
    if (result != null) {
      if (_tabController.index == 0) {
        setState(() {
          _selectedDateRange = result['dateRange'];
          _selectedGroup = result['group'];
          _selectedType = result['type'];
        });
        _fetchNotifications();
      } else {
        setState(() {
          _selectedRequestDateRange = result['dateRange'];
          _selectedRequestGroup = result['group'];
          _selectedRequestType = result['type'];
          if (result.containsKey('direction')) {
            _requestDirection = result['direction'] ?? 'all';
          }
        });
        _fetchRequestsWithFilter();
      }
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

  // Request handling methods
  Future<void> _handleCancel(int requestId) async {
    setState(() {
      _cancelLoading[requestId] = true;
    });
    try {
      await RequestService.cancelRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy yêu cầu thành công')));
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      setState(() {
        _cancelLoading[requestId] = false;
      });
    }
  }

  void _handleAccept(int requestId) async {
    try {
      await RequestService.acceptRequest(requestId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã chấp nhận yêu cầu!')));
      _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _handleDecline(int requestId) async {
    try {
      await RequestService.declineRequest(requestId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã từ chối yêu cầu!')));
      _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _showPaymentMethodSheet(RequestModel req) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.money),
              title: const Text('Tiền mặt'),
              onTap: () async {
                Navigator.pop(context);
                await _handleCashPayment(req);
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('VNPay'),
              onTap: () async {
                Navigator.pop(context);
                await _handleVnPayPayment(req);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCashPayment(RequestModel req) async {
    try {
      await RequestService.sendPaymentConfirm(req.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã gửi yêu cầu xác nhận thanh toán (tiền mặt)!')));
      _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _handleVnPayPayment(RequestModel req) async {
    try {
      if (req.referenceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thông tin thanh toán.')),
        );
        return;
      }
      final url = await SettlementService.createVnPaySettlement(
        settlementId: req.referenceId,
      );
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lấy được link VNPay.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight + 48),
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
                  'Thông báo và yêu cầu',
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
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF667eea),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF667eea),
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14),
                      tabs: [
                        Tab(
                            child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('Thông báo'))),
                        Tab(
                            child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('Yêu cầu'))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          backgroundColor: Colors.grey[50],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationsTab(),
              _buildRequestsTab(),
            ],
          ),
        ),
        // Loading overlay khi đang lọc
        if (_isFiltering || _isRequestFiltering)
          Container(
            color: Colors.black.withOpacity(0.15),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationsTab() {
    return Column(
      children: [
        // Hiển thị filter đang áp dụng
        if (_selectedGroup != null ||
            _selectedType != null ||
            _selectedDateRange != null)
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
    );
  }

  Widget _buildRequestsTab() {
    return Column(
      children: [
        // Hiển thị filter đang áp dụng cho request
        if (_selectedRequestGroup != null ||
            _selectedRequestType != null ||
            _selectedRequestDateRange != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildActiveRequestFilterBar(),
          ),
        Expanded(
          child: _isRequestLoading
              ? const Center(child: CircularProgressIndicator())
              : _allRequests.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Không có yêu cầu nào',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Thử thay đổi bộ lọc để xem thêm yêu cầu',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchRequestsWithFilter,
                      child: _buildGroupedRequestList(_allRequests),
                    ),
        ),
      ],
    );
  }

  // Notification methods (giữ nguyên từ file cũ)
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
    if (noti.type == 'EXPENSE_CREATED' && noti.referenceId != null) {
      Navigator.pushNamed(context, '/expense_detail',
          arguments: noti.referenceId);
    } else if (noti.type == 'GROUP_UPDATED' && noti.referenceId != null) {
      Navigator.pushNamed(context, '/group_detail',
          arguments: noti.referenceId);
    }
  }

  Widget _buildActiveFilterBar() {
    List<String> filters = [];
    if (_selectedGroup != null) {
      final group = _userGroups
          .firstWhereOrNull((g) => g.id.toString() == _selectedGroup);
      if (group != null) filters.add('Nhóm: ${group.name}');
    }
    if (_selectedType != null) {
      String typeLabel = _selectedType == 'EXPENSE_CREATED'
          ? 'Tạo khoản chi'
          : _selectedType == 'GROUP_UPDATED'
              ? 'Cập nhật nhóm'
              : _selectedType == 'MEMBER_JOINED'
                  ? 'Thành viên mới'
                  : _selectedType == 'JOIN_GROUP_INVITE'
                      ? 'Mời vào nhóm'
                      : _selectedType == 'JOIN_GROUP_REQUEST'
                          ? 'Yêu cầu tham gia'
                          : _selectedType == 'PAYMENT_REQUEST'
                              ? 'Yêu cầu thanh toán'
                              : _selectedType == 'PAYMENT_CONFIRM'
                                  ? 'Xác nhận thanh toán'
                                  : _selectedType!;
      filters.add('Loại: $typeLabel');
    }
    if (_selectedDateRange != null) {
      filters.add(
          'Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}');
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
          if (_selectedGroup != null ||
              _selectedType != null ||
              _selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
              tooltip: 'Xoá filter',
              onPressed: () {
                setState(() {
                  _selectedGroup = null;
                  _selectedType = null;
                  _selectedDateRange = null;
                });
                if (_tabController.index == 0) {
                  _fetchNotifications();
                } else {
                  _fetchRequestsWithFilter();
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActiveRequestFilterBar() {
    List<String> filters = [];
    if (_selectedRequestGroup != null) {
      final group = _userGroups
          .firstWhereOrNull((g) => g.id.toString() == _selectedRequestGroup);
      if (group != null) filters.add('Nhóm: ${group.name}');
    }
    if (_selectedRequestType != null) {
      String typeLabel = _selectedRequestType == 'JOIN_GROUP_INVITE'
          ? 'Mời vào nhóm'
          : _selectedRequestType == 'JOIN_GROUP_REQUEST'
              ? 'Yêu cầu tham gia'
              : _selectedRequestType == 'PAYMENT_REQUEST'
                  ? 'Yêu cầu thanh toán'
                  : _selectedRequestType == 'PAYMENT_CONFIRM'
                      ? 'Xác nhận thanh toán'
                      : _selectedRequestType == 'EXPENSE_FINALIZATION'
                          ? 'Xác nhận tất toán'
                          : _selectedRequestType!;
      filters.add('Loại: $typeLabel');
    }
    if (_selectedRequestDateRange != null) {
      filters.add(
          'Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedRequestDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedRequestDateRange!.end)}');
    }
    // Thêm hiển thị direction filter
    if (_requestDirection != 'all') {
      String directionLabel =
          _requestDirection == 'sent' ? 'Gửi đi' : 'Nhận vào';
      filters.add('Phân loại: $directionLabel');
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
          if (_selectedRequestGroup != null ||
              _selectedRequestType != null ||
              _selectedRequestDateRange != null ||
              _requestDirection != 'all')
            IconButton(
              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
              tooltip: 'Xoá filter',
              onPressed: () {
                setState(() {
                  _selectedRequestGroup = null;
                  _selectedRequestType = null;
                  _selectedRequestDateRange = null;
                  _requestDirection = 'all';
                });
                _fetchRequestsWithFilter();
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
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withOpacity(0.8),
                      iconColor.withOpacity(0.5)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(iconData, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noti.content,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: null,
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 4),
                    Text('Nhóm: ${noti.group.name}',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[700])),
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              noti.createdBy.fullName,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
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
      ..sort((a, b) => DateFormat('dd/MM/yyyy')
          .parse(b)
          .compareTo(DateFormat('dd/MM/yyyy').parse(a)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sortedKeys.fold<int>(
          0, (prev, key) => prev + 1 + grouped[key]!.length),
      itemBuilder: (context, index) {
        int runningIndex = 0;
        for (final date in sortedKeys) {
          if (index == runningIndex) {
            return buildDateHeader(date);
          }
          runningIndex++;
          final notis = grouped[date]!
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  // Request methods (từ request_screen)
  Widget buildRequestActionButtons(RequestModel req, {required bool isSent}) {
    if (req.status != 'PENDING') return const SizedBox.shrink();

    final ButtonStyle declineStyle = OutlinedButton.styleFrom(
      backgroundColor: Colors.red.shade50,
      foregroundColor: Colors.red,
      side: BorderSide(color: Colors.red.shade400, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    );
    final ButtonStyle acceptStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.green.shade500,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      elevation: 0,
    );
    final ButtonStyle cancelStyle = OutlinedButton.styleFrom(
      backgroundColor: Colors.orange.shade50,
      foregroundColor: Colors.orange.shade700,
      side: BorderSide(color: Colors.orange.shade400, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    );

    List<Widget> buttons = [];

    if (isSent) {
      // Đối với requests mà user đã gửi đi - chỉ có nút "Hủy yêu cầu"
      buttons = [
        Expanded(
          child: OutlinedButton(
            style: cancelStyle,
            onPressed: _cancelLoading[req.id] == true
                ? null
                : () => _handleCancel(req.id),
            child: _cancelLoading[req.id] == true
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Hủy yêu cầu'),
          ),
        ),
      ];
    } else {
      // Đối với requests mà user nhận vào - có nút Accept/Decline
      if (req.type == 'JOIN_GROUP_INVITE' || req.type == 'JOIN_GROUP_REQUEST') {
        buttons = [
          Expanded(
            child: OutlinedButton(
              style: declineStyle,
              onPressed: () => _handleDecline(req.id),
              child: const Text('Từ chối'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: acceptStyle,
              onPressed: () => _handleAccept(req.id),
              child: const Text('Đồng ý'),
            ),
          ),
        ];
      } else if (req.type == 'PAYMENT_REQUEST') {
        buttons = [
          Expanded(
            child: OutlinedButton(
              style: declineStyle,
              onPressed: () => _handleDecline(req.id),
              child: const Text('Từ chối'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: acceptStyle,
              onPressed: () => _showPaymentMethodSheet(req),
              child: const Text('Thanh toán'),
            ),
          ),
        ];
      } else if (req.type == 'PAYMENT_CONFIRM') {
        buttons = [
          Expanded(
            child: OutlinedButton(
              style: declineStyle,
              onPressed: () => _handleDecline(req.id),
              child: const Text('Từ chối'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: acceptStyle,
              onPressed: () => _handleAccept(req.id),
              child: const Text('Xác nhận'),
            ),
          ),
        ];
      } else if (req.type == 'EXPENSE_FINALIZATION') {
        buttons = [
          Expanded(
            child: OutlinedButton(
              style: declineStyle,
              onPressed: () => _handleDecline(req.id),
              child: const Text('Từ chối'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: acceptStyle,
              onPressed: () => _handleAccept(req.id),
              child: const Text('Đồng ý'),
            ),
          ),
        ];
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(children: buttons),
    );
  }

  void _navigateToRequestDetail(RequestModel req) async {
    if (req.type == 'EXPENSE_FINALIZATION' && req.groupId != null) {
      try {
        // Loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Fetch group detail để có Group object
        final groupDetail = await GroupService.getGroupById(req.groupId!);
        
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
          
          // Navigate to ExpenseFinalizationScreen giống như từ GroupManagementScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpenseFinalizationScreen(
                group: groupDetail,
              ),
            ),
          );
        }
      } catch (e) {
        // Close loading dialog
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tải thông tin nhóm: $e')),
          );
        }
      }
    }
    // Add more navigation cases for other request types if needed
  }

  Widget buildRequestCard(RequestModel req, {required bool isSent}) {
    IconData iconData;
    Color iconColor;
    switch (req.type) {
      case 'SETTLEMENT':
        iconData = Icons.payments_rounded;
        iconColor = Colors.teal;
        break;
      case 'INVITE':
      case 'JOIN_GROUP_INVITE':
        iconData = Icons.group_add_rounded;
        iconColor = Colors.blue;
        break;
      case 'JOIN_GROUP_REQUEST':
        iconData = Icons.person_add_rounded;
        iconColor = Colors.green;
        break;
      case 'PAYMENT_REQUEST':
        iconData = Icons.payment_rounded;
        iconColor = Colors.orange;
        break;
      case 'PAYMENT_CONFIRM':
        iconData = Icons.verified_rounded;
        iconColor = Colors.purple;
        break;
      case 'EXPENSE_FINALIZATION':
        iconData = Icons.lock_clock_rounded;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.request_page_rounded;
        iconColor = Colors.deepPurple;
    }

    return Card(
      color: Colors.white,
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _navigateToRequestDetail(req),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        iconColor.withOpacity(0.8),
                        iconColor.withOpacity(0.5)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(iconData, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        req.content,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Trạng thái: ${req.status}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '${req.createdAt.hour.toString().padLeft(2, '0')}:${req.createdAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Loại: ${isSent ? 'Gửi đi' : 'Nhận vào'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSent ? Colors.blue : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
            buildRequestActionButtons(req, isSent: isSent),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedRequestList(List<RequestModel> requests) {
    final Map<String, List<RequestModel>> grouped = {};
    for (final req in requests) {
      final dateStr =
          '${req.createdAt.day.toString().padLeft(2, '0')}/${req.createdAt.month.toString().padLeft(2, '0')}/${req.createdAt.year}';
      grouped.putIfAbsent(dateStr, () => []).add(req);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => DateTime.parse(
              '${b.split('/')[2]}-${b.split('/')[1]}-${b.split('/')[0]}')
          .compareTo(DateTime.parse(
              '${a.split('/')[2]}-${a.split('/')[1]}-${a.split('/')[0]}')));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sortedKeys.fold<int>(
          0, (prev, key) => prev + 1 + grouped[key]!.length),
      itemBuilder: (context, index) {
        int runningIndex = 0;
        for (final date in sortedKeys) {
          if (index == runningIndex) {
            return buildDateHeader(date);
          }
          runningIndex++;
          final reqs = grouped[date]!
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (index < runningIndex + reqs.length) {
            final req = reqs[index - runningIndex];

            // Xác định isSent dựa trên direction filter thay vì so sánh senderId
            bool isSent;
            if (_requestDirection == 'sent') {
              isSent = true;
            } else if (_requestDirection == 'received') {
              isSent = false;
            } else {
              // Chỉ khi direction = 'all' thì mới cần so sánh senderId
              return FutureBuilder<User?>(
                future: AuthService.getCurrentUser(),
                builder: (context, snapshot) {
                  final currentUser = snapshot.data;
                  final currentUserId = currentUser?.id?.trim();
                  final requestSenderId = req.senderId.trim();
                  final isSent = currentUserId != null &&
                      currentUserId.isNotEmpty &&
                      requestSenderId == currentUserId;

                  return buildRequestCard(req, isSent: isSent);
                },
              );
            }

            return buildRequestCard(req, isSent: isSent);
          }
          runningIndex += reqs.length;
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

// Widget filter bottom sheet (cập nhật để hỗ trợ cả notification và request)
class _FilterSheet extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final String? initialGroup;
  final String? initialType;
  final List<GroupSummary> groups;
  final bool isRequestTab;
  final String? initialDirection;
  const _FilterSheet({
    this.initialDateRange,
    this.initialGroup,
    this.initialType,
    required this.groups,
    required this.isRequestTab,
    this.initialDirection,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTimeRange? _dateRange;
  String? _group;
  String? _type;
  String _direction = 'all';

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialDateRange;
    _group = widget.initialGroup;
    _type = widget.initialType;
    // Map lại nếu initialDirection không hợp lệ
    if (widget.initialDirection == 'sent' ||
        widget.initialDirection == 'received' ||
        widget.initialDirection == 'all') {
      _direction = widget.initialDirection!;
    } else if (widget.initialDirection == 'INCOMING') {
      _direction = 'received';
    } else if (widget.initialDirection == 'OUTGOING') {
      _direction = 'sent';
    } else {
      _direction = 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isRequestTab ? 'Bộ lọc yêu cầu' : 'Bộ lọc thông báo',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
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
          DropdownButtonFormField<String>(
            value: _group,
            decoration: const InputDecoration(labelText: 'Nhóm'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tất cả nhóm')),
              ...widget.groups.map((g) => DropdownMenuItem(
                  value: g.id.toString(), child: Text(g.name))),
            ],
            onChanged: (g) => setState(() => _group = g),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: InputDecoration(
              labelText:
                  widget.isRequestTab ? 'Loại yêu cầu' : 'Loại thông báo',
            ),
            items: widget.isRequestTab
                ? [
                    const DropdownMenuItem(
                        value: null, child: Text('Tất cả loại')),
                    DropdownMenuItem(
                        value: 'JOIN_GROUP_INVITE',
                        child: Text('Mời vào nhóm')),
                    DropdownMenuItem(
                        value: 'JOIN_GROUP_REQUEST',
                        child: Text('Yêu cầu tham gia')),
                    DropdownMenuItem(
                        value: 'PAYMENT_REQUEST',
                        child: Text('Yêu cầu thanh toán')),
                    DropdownMenuItem(
                        value: 'PAYMENT_CONFIRM',
                        child: Text('Xác nhận thanh toán')),
                    DropdownMenuItem(
                        value: 'EXPENSE_FINALIZATION',
                        child: Text('Xác nhận tất toán')),
                  ]
                : [
                    const DropdownMenuItem(
                        value: null, child: Text('Tất cả loại')),
                    DropdownMenuItem(
                        value: 'EXPENSE_CREATED', child: Text('Tạo khoản chi')),
                    DropdownMenuItem(
                        value: 'GROUP_UPDATED', child: Text('Cập nhật nhóm')),
                    DropdownMenuItem(
                        value: 'MEMBER_JOINED', child: Text('Thành viên mới')),
                  ],
            onChanged: (t) => setState(() => _type = t),
          ),
          if (widget.isRequestTab) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _direction,
              decoration: const InputDecoration(labelText: 'Phân loại yêu cầu'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                DropdownMenuItem(value: 'sent', child: Text('Đã gửi')),
                DropdownMenuItem(value: 'received', child: Text('Nhận vào')),
              ],
              onChanged: (val) => setState(() => _direction = val ?? 'all'),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Nút Đặt lại
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      setState(() {
                        _dateRange = null;
                        _group = null;
                        _type = null;
                        if (widget.isRequestTab) _direction = 'all';
                      });
                    },
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                      child: Text(
                        'Đặt lại',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Nút Áp dụng
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      Navigator.pop(context, {
                        'dateRange': _dateRange,
                        'group': _group,
                        'type': _type,
                        if (widget.isRequestTab) 'direction': _direction,
                      });
                    },
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                      child: Text(
                        'Áp dụng',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
