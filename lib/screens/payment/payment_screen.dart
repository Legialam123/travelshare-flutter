import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../services/settlement_service.dart';
import '../../services/group_detail_service.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/color_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/request_service.dart';

// Hàm chung để lấy participantId của user hiện tại
Future<int?> _getCurrentUserParticipantId(
    int groupId, String currentUserId, Map<int, int?> participantIds) async {
  if (participantIds.containsKey(groupId)) {
    return participantIds[groupId];
  }

  try {
    final groupDetail = await GroupDetailService.fetchGroupDetail(groupId);
    final participants = groupDetail['participants'] as List<dynamic>;
    final participant = participants.firstWhere(
      (p) => p['user'] != null && p['user']['id'] == currentUserId,
      orElse: () => null,
    );
    final participantId = participant != null ? participant['id'] : null;
    participantIds[groupId] = participantId;
    return participantId;
  } catch (e) {
    participantIds[groupId] = null;
    return null;
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedGroupId;
  List<Group> _groups = [];
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await GroupService.fetchGroups();
    setState(() {
      _groups = groups;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            title: Row(
              children: [
                const Text(
                  'Thanh toán',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedGroupId,
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Colors.white, size: 20),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      dropdownColor: Colors.white,
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Tất cả nhóm',
                              style: TextStyle(
                                  color: Color(0xFF2C3E50),
                                  fontWeight: FontWeight.w500)),
                        ),
                        ..._groups.map((g) => DropdownMenuItem<int>(
                              value: g.id,
                              child: Text(g.name,
                                  style: const TextStyle(
                                      color: Color(0xFF2C3E50),
                                      fontWeight: FontWeight.w500)),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedGroupId = val;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
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
                  tabs: const [
                    Tab(child: Text('Thanh toán')),
                    Tab(child: Text('Lịch sử')),
                    Tab(child: Text('Đang chờ')),
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
          // Tab 1: Thanh toán
          _PaymentTabSuggestedSettlements(groupId: _selectedGroupId),
          // Tab 2: Lịch sử
          _PaymentTabHistory(groupId: _selectedGroupId),
          // Tab 3: Đang chờ
          _PaymentTabPending(groupId: _selectedGroupId),
        ],
      ),
    );
  }
}

class _PaymentTabSuggestedSettlements extends StatefulWidget {
  final int? groupId;
  const _PaymentTabSuggestedSettlements({Key? key, this.groupId})
      : super(key: key);

  @override
  State<_PaymentTabSuggestedSettlements> createState() =>
      _PaymentTabSuggestedSettlementsState();
}

class _PaymentTabSuggestedSettlementsState
    extends State<_PaymentTabSuggestedSettlements> with WidgetsBindingObserver {
  String? _currentUserId;
  Map<int, int?> _participantIds = {}; // groupId -> participantId
  Map<int, List<dynamic>> _groupPendingSettlements =
      {}; // groupId -> pending settlements
  Map<int, Color> _groupColors = {}; // groupId -> category color

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUserId();
    _loadPendingSettlementsForAllGroups();
    _loadGroupColors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Khi app được resume (quay lại từ VNPay), tải lại dữ liệu
      _loadPendingSettlementsForAllGroups();
    }
  }

  Future<void> _loadCurrentUserId() async {
    final user = await AuthService.getCurrentUser();
    setState(() {
      _currentUserId = user?.id;
    });
  }

  Future<void> _loadPendingSettlementsForAllGroups() async {
    try {
      final groups = await GroupService.fetchGroups();
      for (final group in groups) {
        final pendingSettlements =
            await SettlementService.fetchSettlementHistory(group.id);
        _groupPendingSettlements[group.id] = pendingSettlements
            .where((settlement) => settlement['status'] == 'PENDING')
            .toList();
      }
      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading pending settlements: $e');
    }
  }

  Future<void> _loadGroupColors() async {
    try {
      final groups = await GroupService.fetchGroups();
      final groupsByCategory = await GroupService.fetchGroupsByCategory();

      for (final group in groups) {
        Color categoryColor = const Color(0xFFFF9800); // Default orange

        // Tìm category của group này
        for (final entry in groupsByCategory.entries) {
          final category = entry.key;
          final groupsInCategory = entry.value;

          if (groupsInCategory.any((g) => g.id == group.id)) {
            if (category.color != null && category.color!.isNotEmpty) {
              categoryColor = HexColor.fromHex(category.color!);
            }
            break;
          }
        }

        _groupColors[group.id] = categoryColor;
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading group colors: $e');
      // Fallback: sử dụng màu orange cho tất cả
      final groups = await GroupService.fetchGroups();
      for (final group in groups) {
        _groupColors[group.id] = const Color(0xFFFF9800);
      }
      if (mounted) setState(() {});
    }
  }

  Color _getGroupColor(int groupId) {
    return _groupColors[groupId] ?? const Color(0xFFFF9800);
  }

  bool _hasPendingInGroup(int groupId, Map<String, dynamic> suggestion) {
    final pendingList = _groupPendingSettlements[groupId] ?? [];
    try {
      return pendingList.any((item) {
        if (item is! Map) return false;
        return item['fromParticipantId'] == suggestion['fromParticipantId'] &&
            item['toParticipantId'] == suggestion['toParticipantId'] &&
            item['amount'] == suggestion['amount'] &&
            item['currencyCode'] == suggestion['currencyCode'];
      });
    } catch (_) {
      return false;
    }
  }

  Future<int?> _getParticipantId(int groupId) async {
    return _getCurrentUserParticipantId(
        groupId, _currentUserId!, _participantIds);
  }

  Future<Map<String, dynamic>> _getGroupAndRole(
      int groupId, String currentUserId) async {
    final groupDetail = await GroupDetailService.fetchGroupDetail(groupId);
    final participants = groupDetail['participants'] as List<dynamic>;
    final participant = participants.firstWhere(
      (p) => p['user'] != null && p['user']['id'] == currentUserId,
      orElse: () => null,
    );
    final isAdmin = participant != null && participant['role'] == 'ADMIN';
    final myParticipantId = participant != null ? participant['id'] : null;
    return {
      'isAdmin': isAdmin,
      'participants': participants,
      'participant': participant,
      'myParticipantId': myParticipantId,
    };
  }

  Future<void> _confirmPayment(Map<String, dynamic> s) async {
    final success = await SettlementService.createSettlement(
      groupId: s['groupId'],
      fromParticipantId: s['fromParticipantId'],
      toParticipantId: s['toParticipantId'],
      amount: s['amount'],
      currencyCode: s['currencyCode'],
      status: 'COMPLETED',
      settlementMethod: 'CASH',
      description: s['description'],
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? '✅ Đã đánh dấu đã thanh toán.'
            : '❌ Lỗi khi xác nhận thanh toán'),
      ));

      if (success) {
        // Tải lại pending settlements và cập nhật UI
        await _loadPendingSettlementsForAllGroups();
        setState(() {});
      }
    }
  }

  Future<void> _createPendingSettlement(
      Map<String, dynamic> s, String? method) async {
    bool success = false;
    String message = '';
    if (method == 'CASH') {
      // Người nợ xác nhận đã thanh toán, gửi yêu cầu xác nhận cho người nhận
      success = await SettlementService.createSettlement(
        groupId: s['groupId'],
        fromParticipantId: s['fromParticipantId'],
        toParticipantId: s['toParticipantId'],
        amount: s['amount'],
        currencyCode: s['currencyCode'],
        status: 'PENDING',
        settlementMethod: method,
        description: s['description'],
      );
      message = success
          ? '✅ Đã gửi yêu cầu xác nhận thanh toán cho người nhận.'
          : '❌ Lỗi khi gửi yêu cầu';
    } else {
      // Người nhận gửi yêu cầu thanh toán cho người nợ
      success = await SettlementService.createSettlement(
        groupId: s['groupId'],
        fromParticipantId: s['fromParticipantId'],
        toParticipantId: s['toParticipantId'],
        amount: s['amount'],
        currencyCode: s['currencyCode'],
        status: 'PENDING',
        settlementMethod: method,
        description: s['description'],
      );
      message = success
          ? '✅ Đã gửi yêu cầu thanh toán đến người nợ.'
          : '❌ Lỗi khi gửi yêu cầu';
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
      ));
      if (success) {
        // Tải lại pending settlements và cập nhật UI
        await _loadPendingSettlementsForAllGroups();
        setState(() {});
      }
    }
  }

  Future<void> _confirmReceived(Map<String, dynamic> s) async {
    // Kiểm tra s['id'] trước khi gọi API
    if (s['id'] == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ Không thể xác nhận: thiếu thông tin settlement'),
        ));
      }
      return;
    }

    final success = await SettlementService.confirmSettlement(s['id']);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            success ? '✅ Đã xác nhận đã nhận tiền.' : '❌ Lỗi khi xác nhận'),
      ));
      if (success) {
        // Tải lại pending settlements và cập nhật UI
        await _loadPendingSettlementsForAllGroups();
        setState(() {});
      }
    }
  }

  Future<void> _showPaymentMethodSheet(Map<String, dynamic> s) async {
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
                await _createPendingSettlement(s, 'CASH');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('VNPay'),
              onTap: () async {
                Navigator.pop(context);
                await _handleVnPayPayment(s);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleVnPayPayment(Map<String, dynamic> s) async {
    try {
      final paymentUrl = await SettlementService.createVnPaySettlement(
        groupId: s['groupId'],
        fromParticipantId: s['fromParticipantId'],
        toParticipantId: s['toParticipantId'],
        amount: s['amount'],
        currencyCode: s['currencyCode'],
        description: s['description'],
      );
      if (paymentUrl != null) {
        if (context.mounted) {
          await launchUrl(Uri.parse(paymentUrl),
              mode: LaunchMode.externalApplication);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Không lấy được link thanh toán VNPay.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi VNPay: $e')),
        );
      }
    }
  }

  String _formatParticipantName(String name, String currentUserId) {
    if (name.contains(currentUserId)) {
      return name.replaceAll(currentUserId, 'Bạn');
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<dynamic>>(
      future: widget.groupId == null
          ? _fetchAllGroupsSuggested(context)
          : SettlementService.fetchSuggestedSettlements(widget.groupId!,
              userOnly: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) {
          return const Center(child: Text('Không có khoản cần thanh toán.'));
        }
        // Group by groupId
        final Map<int, List<Map<String, dynamic>>> groupMap = {};
        for (final s in suggestions) {
          final groupId = s['groupId'] as int?;
          if (groupId == null) continue;
          groupMap
              .putIfAbsent(groupId, () => [])
              .add(s as Map<String, dynamic>);
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: groupMap.entries.map((entry) {
            final groupId = entry.key;
            final groupSuggestions = entry.value;
            // Lấy groupName từ suggestion đầu tiên (tất cả đều cùng groupId nên groupName giống nhau)
            final groupName = groupSuggestions.isNotEmpty
                ? (groupSuggestions[0]['groupName'] ?? 'Nhóm')
                : 'Nhóm';
            final categoryColor = _getGroupColor(groupId);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: categoryColor.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: categoryColor.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    childrenPadding: const EdgeInsets.only(
                        top: 8, left: 8, right: 8, bottom: 12),
                    initiallyExpanded: true,
                    backgroundColor: categoryColor.withOpacity(0.05),
                    collapsedBackgroundColor: categoryColor.withOpacity(0.05),
                    iconColor: categoryColor.withOpacity(0.6),
                    collapsedIconColor: categoryColor.withOpacity(0.6),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Row(
                      children: [
                        // Group avatar with real image (like home_screen)
                        FutureBuilder<Group?>(
                          future: GroupService.getGroupById(groupId),
                          builder: (context, groupSnapshot) {
                            final group = groupSnapshot.data;
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    categoryColor,
                                    categoryColor.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: categoryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  child: group?.avatarUrl != null &&
                                          group!.avatarUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: group.avatarUrl!
                                                  .startsWith('assets/')
                                              ? Image.asset(
                                                  group.avatarUrl!,
                                                  width: 52,
                                                  height: 52,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.network(
                                                  group.avatarUrl!,
                                                  width: 52,
                                                  height: 52,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context,
                                                      child, loadingProgress) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Container(
                                                      color: categoryColor
                                                          .withOpacity(0.1),
                                                      child: Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                          color: categoryColor,
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color: categoryColor
                                                          .withOpacity(0.1),
                                                      child: Icon(
                                                        Icons.groups,
                                                        color: categoryColor,
                                                        size: 24,
                                                      ),
                                                    );
                                                  },
                                                ),
                                        )
                                      : Container(
                                          color: categoryColor.withOpacity(0.1),
                                          child: Icon(
                                            Icons.groups,
                                            color: categoryColor,
                                            size: 24,
                                          ),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                groupName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.payment_outlined,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${groupSuggestions.length} khoản cần thanh toán',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Loại bỏ hiển thị tổng tiền
                          ],
                        ),
                      ],
                    ),
                    children: groupSuggestions.map((s) {
                      return FutureBuilder<int?>(
                        future: _getParticipantId(s['groupId']),
                        builder: (context, participantSnapshot) {
                          if (!participantSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final myParticipantId = participantSnapshot.data;
                          final fromId = s['fromParticipantId'];
                          final toId = s['toParticipantId'];
                          final isYouOwe = myParticipantId != null &&
                              fromId == myParticipantId;
                          final isYouReceive = myParticipantId != null &&
                              toId == myParticipantId;

                          // Chỉ hiển thị nếu liên quan đến mình
                          if (!isYouOwe && !isYouReceive) {
                            return const SizedBox.shrink();
                          }

                          // Kiểm tra xem có pending settlement hay không
                          final hasPending = _hasPendingInGroup(groupId, s);

                          // Format tên hiển thị
                          String fromName = s['fromParticipantName'] ?? '';
                          String toName = s['toParticipantName'] ?? '';

                          if (isYouOwe) {
                            fromName = 'Bạn';
                          }
                          if (isYouReceive) {
                            toName = 'Bạn';
                          }

                          List<Widget> buttons = [];
                          if (isYouOwe) {
                            buttons = [
                              _buildStyledButton(
                                onTap: hasPending
                                    ? null
                                    : () => _createPendingSettlement(s, "CASH"),
                                icon: Icons.check_circle,
                                label: 'Xác nhận thanh toán',
                                colors: [
                                  Colors.green.shade600,
                                  Colors.green.shade700
                                ],
                                disabled: hasPending,
                              ),
                              _buildStyledButton(
                                onTap: hasPending
                                    ? null
                                    : () => _showPaymentMethodSheet(s),
                                icon: Icons.credit_card,
                                label: 'Thanh toán',
                                colors: [
                                  const Color(0xFF667eea),
                                  const Color(0xFF764ba2)
                                ],
                                disabled: hasPending,
                              ),
                            ];
                          } else if (isYouReceive) {
                            buttons = [
                              _buildStyledButton(
                                onTap: hasPending
                                    ? null
                                    : () => _confirmPayment(s),
                                icon: Icons.account_balance_wallet,
                                label: 'Xác nhận nhận tiền',
                                colors: [
                                  Colors.green.shade600,
                                  Colors.green.shade700
                                ],
                                disabled: hasPending,
                              ),
                              _buildStyledButton(
                                onTap: hasPending
                                    ? null
                                    : () => _createPendingSettlement(s, null),
                                icon: Icons.request_quote,
                                label: 'Yêu cầu thanh toán',
                                colors: [
                                  Colors.orange.shade600,
                                  Colors.orange.shade700
                                ],
                                disabled: hasPending,
                              ),
                            ];
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: categoryColor.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                                BoxShadow(
                                  color: categoryColor.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold),
                                            children: [
                                              TextSpan(
                                                  text: fromName,
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const TextSpan(text: ' nợ '),
                                              TextSpan(
                                                  text: toName,
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: categoryColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color:
                                                categoryColor.withOpacity(0.3),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          CurrencyFormatter.formatMoney(
                                              (s['amount'] as num?)
                                                      ?.toDouble() ??
                                                  0,
                                              s['currencyCode'] ?? 'VND'),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: categoryColor,
                                              fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (s['description'] != null &&
                                      s['description']
                                          .toString()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '📝 ${s['description']}',
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black),
                                    ),
                                  ],
                                  if (hasPending) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.orange.withOpacity(0.2),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: const Text(
                                        '⏳ Đã gửi yêu cầu thanh toán đang chờ xử lý',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: buttons,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStyledButton({
    required VoidCallback? onTap,
    required IconData icon,
    required String label,
    required List<Color> colors,
    bool disabled = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: disabled ? Colors.grey.shade300 : colors[0],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  disabled ? Colors.grey.shade400 : colors[0].withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: colors[0].withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: disabled ? Colors.grey.shade600 : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<List<dynamic>> _fetchAllGroupsSuggested(BuildContext context) async {
    final groups = await GroupService.fetchGroups();
    List<dynamic> all = [];
    for (final g in groups) {
      final list = await SettlementService.fetchSuggestedSettlements(g.id,
          userOnly: true);
      all.addAll(list);
    }
    return all;
  }
}

class _PaymentTabHistory extends StatefulWidget {
  final int? groupId;
  const _PaymentTabHistory({Key? key, this.groupId}) : super(key: key);

  @override
  State<_PaymentTabHistory> createState() => _PaymentTabHistoryState();
}

class _PaymentTabHistoryState extends State<_PaymentTabHistory> {
  String? _currentUserId;
  final Map<int, int?> _participantIds = {};
  Map<int, Color> _groupColors = {}; // groupId -> category color

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadGroupColors();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final user = await AuthService.getCurrentUser();
      setState(() {
        _currentUserId = user?.id;
      });
    } catch (e) {
      print('Error loading current user ID: $e');
    }
  }

  Future<void> _loadGroupColors() async {
    try {
      final groups = await GroupService.fetchGroups();
      final groupsByCategory = await GroupService.fetchGroupsByCategory();

      for (final group in groups) {
        Color categoryColor = const Color(0xFFFF9800); // Default orange

        // Tìm category của group này
        for (final entry in groupsByCategory.entries) {
          final category = entry.key;
          final groupsInCategory = entry.value;

          if (groupsInCategory.any((g) => g.id == group.id)) {
            if (category.color != null && category.color!.isNotEmpty) {
              categoryColor = HexColor.fromHex(category.color!);
            }
            break;
          }
        }

        _groupColors[group.id] = categoryColor;
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading group colors: $e');
      // Fallback: sử dụng màu orange cho tất cả
      final groups = await GroupService.fetchGroups();
      for (final group in groups) {
        _groupColors[group.id] = const Color(0xFFFF9800);
      }
      if (mounted) setState(() {});
    }
  }

  Color _getGroupColor(int groupId) {
    return _groupColors[groupId] ?? const Color(0xFFFF9800);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: widget.groupId == null
          ? _fetchAllGroupsHistory(context)
          : SettlementService.fetchSettlementHistory(widget.groupId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final settlements = (snapshot.data ?? [])
            .where((s) => s['status'] == 'COMPLETED' || s['status'] == 'FAILED')
            .toList();
        if (settlements.isEmpty) {
          return const Center(child: Text('Chưa có lịch sử thanh toán.'));
        }

        // Nhóm theo groupId
        final Map<int, List<Map<String, dynamic>>> groupedByGroup = {};

        for (final s in settlements) {
          final groupId = s['groupId'] as int?;
          if (groupId == null) continue;
          groupedByGroup
              .putIfAbsent(groupId, () => [])
              .add(s as Map<String, dynamic>);
        }

        // Sắp xếp các nhóm theo groupId
        final sortedGroupIds = groupedByGroup.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sortedGroupIds.length,
          itemBuilder: (context, index) {
            final groupId = sortedGroupIds[index];
            final groupSettlements = groupedByGroup[groupId]!;

            // Sắp xếp settlements trong nhóm theo thời gian mới nhất
            groupSettlements.sort((a, b) =>
                (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

            // Tính toán thống kê
            final completedSettlements = groupSettlements
                .where((s) => s['status'] == 'COMPLETED')
                .toList();
            final totalAmount = completedSettlements.fold<double>(
                0, (sum, s) => sum + ((s['amount'] as num).toDouble()));
            final currencyCode = groupSettlements.isNotEmpty
                ? (groupSettlements[0]['currencyCode'] ?? 'VND')
                : 'VND';

            return FutureBuilder<Group?>(
              future: GroupService.getGroupById(groupId),
              builder: (context, groupSnapshot) {
                final groupName = groupSnapshot.data?.name ?? 'Nhóm $groupId';
                final categoryColor = _getGroupColor(groupId);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: categoryColor.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: categoryColor.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        childrenPadding: const EdgeInsets.only(
                            top: 8, left: 8, right: 8, bottom: 12),
                        initiallyExpanded: true,
                        backgroundColor: categoryColor.withOpacity(0.05),
                        collapsedBackgroundColor:
                            categoryColor.withOpacity(0.05),
                        iconColor: categoryColor.withOpacity(0.6),
                        collapsedIconColor: categoryColor.withOpacity(0.6),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Row(
                          children: [
                            // Group avatar with real image (like home_screen)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    categoryColor,
                                    categoryColor.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: categoryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  child: groupSnapshot.data?.avatarUrl !=
                                              null &&
                                          groupSnapshot
                                              .data!.avatarUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: groupSnapshot.data!.avatarUrl!
                                                  .startsWith('assets/')
                                              ? Image.asset(
                                                  groupSnapshot
                                                      .data!.avatarUrl!,
                                                  width: 52,
                                                  height: 52,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.network(
                                                  groupSnapshot
                                                      .data!.avatarUrl!,
                                                  width: 52,
                                                  height: 52,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context,
                                                      child, loadingProgress) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Container(
                                                      color: categoryColor
                                                          .withOpacity(0.1),
                                                      child: Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                          color: categoryColor,
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color: categoryColor
                                                          .withOpacity(0.1),
                                                      child: Icon(
                                                        Icons.history,
                                                        color: categoryColor,
                                                        size: 24,
                                                      ),
                                                    );
                                                  },
                                                ),
                                        )
                                      : Container(
                                          color: categoryColor.withOpacity(0.1),
                                          child: Icon(
                                            Icons.history,
                                            color: categoryColor,
                                            size: 24,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groupName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${groupSettlements.length} giao dịch',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatMoney(
                                      totalAmount, currencyCode),
                                  style: TextStyle(
                                    color: categoryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tổng cộng',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        children: groupSettlements
                            .map((s) => _buildSettlementCard(s, context))
                            .toList(),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSettlementCard(Map<String, dynamic> s, BuildContext context) {
    String fromName = s['fromParticipantName'] ?? '';
    String toName = s['toParticipantName'] ?? '';
    final fromId = s['fromParticipantId'];
    final toId = s['toParticipantId'];
    final isCompleted = s['status'] == 'COMPLETED';
    final amount = (s['amount'] as num).toDouble();
    final currencyCode = s['currencyCode'] ?? 'VND';
    final description = s['description'];
    final createdAt = s['createdAt'] ?? '';
    final settlementMethod =
        s['settlementMethod'] ?? 'CASH'; // Lấy phương thức thanh toán

    return FutureBuilder<int?>(
      future: _getParticipantId(s['groupId']),
      builder: (context, participantSnapshot) {
        if (!participantSnapshot.hasData) return const SizedBox.shrink();

        final myParticipantId = participantSnapshot.data;
        final categoryColor = _getGroupColor(s['groupId']);

        // Hiển thị "Bạn" đúng vị trí
        if (fromId == myParticipantId) fromName = 'Bạn';
        if (toId == myParticipantId) toName = 'Bạn';

        // Xác định text và icon cho phương thức thanh toán
        String methodText = '';
        IconData methodIcon;
        Color methodColor;

        switch (settlementMethod.toUpperCase()) {
          case 'VNPAY':
            methodText = 'VNPay';
            methodIcon = Icons.payment;
            methodColor = Colors.blue;
            break;
          case 'CASH':
          default:
            methodText = 'Tiền mặt';
            methodIcon = Icons.money;
            methodColor = Colors.green;
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: categoryColor.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: categoryColor.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black),
                          children: [
                            TextSpan(
                                text: fromName,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const TextSpan(
                                text: ' đã thanh toán cho ',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: toName,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: categoryColor.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        CurrencyFormatter.formatMoney(amount, currencyCode),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                            fontSize: 16),
                      ),
                    ),
                  ],
                ),
                if (description != null &&
                    description.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '📝 $description',
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ],
                // Thêm thông tin phương thức thanh toán
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      methodIcon,
                      size: 14,
                      color: methodColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$methodText',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📅 ${_formatDateTime(createdAt)}',
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.withOpacity(0.08)
                            : Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCompleted
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        isCompleted ? 'Hoàn thành' : 'Thất bại',
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final settlementDate = DateTime(date.year, date.month, date.day);

      if (settlementDate == today) {
        return 'Hôm nay';
      } else if (settlementDate == yesterday) {
        return 'Hôm qua';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  Future<List<dynamic>> _fetchAllGroupsHistory(BuildContext context) async {
    final groups = await GroupService.fetchGroups();
    List<dynamic> all = [];
    for (final g in groups) {
      final list = await SettlementService.fetchSettlementHistory(g.id);
      all.addAll(list);
    }
    return all;
  }

  Future<int?> _getParticipantId(int groupId) async {
    if (_currentUserId == null) return null;
    return _getCurrentUserParticipantId(
        groupId, _currentUserId!, _participantIds);
  }
}

class _PaymentTabPending extends StatefulWidget {
  final int? groupId;
  const _PaymentTabPending({Key? key, this.groupId}) : super(key: key);

  @override
  State<_PaymentTabPending> createState() => _PaymentTabPendingState();
}

class _PaymentTabPendingState extends State<_PaymentTabPending>
    with WidgetsBindingObserver {
  Future<void> _showPaymentMethodSheet(Map<String, dynamic> r) async {
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
                Navigator.of(context).pop();
                await _handleCashPayment(r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('VNPay'),
              onTap: () async {
                Navigator.of(context).pop();
                await _handleVnPayPayment(r);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCashPayment(Map<String, dynamic> r) async {
    try {
      await RequestService.sendPaymentConfirm(r['id']);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã gửi yêu cầu xác nhận thanh toán (tiền mặt)!')));
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _handleVnPayPayment(Map<String, dynamic> r) async {
    try {
      final referenceId = r['referenceId'];
      if (referenceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thông tin thanh toán.')),
        );
        return;
      }
      final url = await SettlementService.createVnPaySettlement(
        settlementId: referenceId,
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

  String? _currentUserId;
  Map<int, Color> _groupColors = {}; // groupId -> category color

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUserId();
    _loadGroupColors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final user = await AuthService.getCurrentUser();
      setState(() {
        _currentUserId = user?.id;
      });
    } catch (e) {
      print('Error loading current user ID: $e');
    }
  }

  Future<void> _loadGroupColors() async {
    try {
      final groups = await GroupService.fetchGroups();
      final groupsByCategory = await GroupService.fetchGroupsByCategory();

      for (final group in groups) {
        Color categoryColor = const Color(0xFFFF9800); // Default orange

        // Tìm category của group này
        for (final entry in groupsByCategory.entries) {
          final category = entry.key;
          final groupsInCategory = entry.value;

          if (groupsInCategory.any((g) => g.id == group.id)) {
            if (category.color != null && category.color!.isNotEmpty) {
              categoryColor = HexColor.fromHex(category.color!);
            }
            break;
          }
        }

        _groupColors[group.id] = categoryColor;
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading group colors: $e');
      // Fallback: sử dụng màu orange cho tất cả
      final groups = await GroupService.fetchGroups();
      for (final group in groups) {
        _groupColors[group.id] = const Color(0xFFFF9800);
      }
      if (mounted) setState(() {});
    }
  }

  Color _getGroupColor(int groupId) {
    return _groupColors[groupId] ?? const Color(0xFFFF9800);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: widget.groupId == null
          ? _fetchAllGroupsPending(context)
          : _fetchGroupPendingRequests(widget.groupId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final requests = (snapshot.data ?? [])
            .where((r) =>
                r['type'] == 'PAYMENT_REQUEST' ||
                r['type'] == 'PAYMENT_CONFIRM')
            .toList();
        if (requests.isEmpty) {
          return const Center(child: Text('Không có yêu cầu nào đang chờ.'));
        }

        // Nhóm theo groupId
        final Map<int, List<Map<String, dynamic>>> groupedByGroup = {};
        for (final r in requests) {
          final groupId = r['groupId'] as int?;
          if (groupId == null) continue;
          groupedByGroup
              .putIfAbsent(groupId, () => [])
              .add(r as Map<String, dynamic>);
        }
        final sortedGroupIds = groupedByGroup.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sortedGroupIds.length,
          itemBuilder: (context, index) {
            final groupId = sortedGroupIds[index];
            final groupRequests = groupedByGroup[groupId]!;
            groupRequests.sort((a, b) =>
                (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
            return FutureBuilder<Group?>(
              future: GroupService.getGroupById(groupId),
              builder: (context, groupSnapshot) {
                final groupName = groupSnapshot.data?.name ?? 'Nhóm $groupId';
                final categoryColor = _getGroupColor(groupId);
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: categoryColor.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: categoryColor.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        childrenPadding: const EdgeInsets.only(
                            top: 8, left: 8, right: 8, bottom: 12),
                        initiallyExpanded: true,
                        backgroundColor: categoryColor.withOpacity(0.05),
                        collapsedBackgroundColor:
                            categoryColor.withOpacity(0.05),
                        iconColor: categoryColor.withOpacity(0.6),
                        collapsedIconColor: categoryColor.withOpacity(0.6),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    categoryColor,
                                    categoryColor.withOpacity(0.7)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: categoryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  child: groupSnapshot.data?.avatarUrl !=
                                              null &&
                                          groupSnapshot
                                              .data!.avatarUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: groupSnapshot.data!.avatarUrl!
                                                  .startsWith('assets/')
                                              ? Image.asset(
                                                  groupSnapshot
                                                      .data!.avatarUrl!,
                                                  width: 52,
                                                  height: 52,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.network(
                                                  groupSnapshot
                                                      .data!.avatarUrl!,
                                                  width: 52,
                                                  height: 52,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color: categoryColor
                                                          .withOpacity(0.1),
                                                      child: Icon(Icons.groups,
                                                          color: categoryColor,
                                                          size: 24),
                                                    );
                                                  },
                                                ),
                                        )
                                      : Container(
                                          color: categoryColor.withOpacity(0.1),
                                          child: Icon(Icons.groups,
                                              color: categoryColor, size: 24),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groupName,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2D3748)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${groupRequests.length} yêu cầu đang chờ',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        children: groupRequests
                            .map((r) => _buildRequestCardWithAction(r, context))
                            .toList(),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCardWithAction(
      Map<String, dynamic> r, BuildContext context) {
    final status = r['status'] ?? '';
    final type = r['type'] ?? '';
    final content = r['content'] ?? '';
    final createdAt = r['createdAt'] ?? '';
    final isCurrentUserSender = r['senderId'] == _currentUserId;
    final isCurrentUserReceiver = r['receiverId'] == _currentUserId;

    List<Widget> actionButtons = [];
    if (status == 'PENDING') {
      if (isCurrentUserSender) {
        if (type != 'PAYMENT_CONFIRM') {
          actionButtons = [
            Expanded(
              child: GestureDetector(
                onTap: () => _handleCancelRequest(r['id']),
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.shade600.withOpacity(0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade600.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Hủy yêu cầu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        }
      } else if (isCurrentUserReceiver) {
        if (type == 'PAYMENT_REQUEST') {
          // Từ chối + Thanh toán (hiển thị chọn phương thức thanh toán)
          actionButtons = [
            Expanded(
              child: GestureDetector(
                onTap: () => _handleDeclineRequest(r['id']),
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.shade600.withOpacity(0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade600.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Từ chối',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _showPaymentMethodSheet(r),
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.shade600.withOpacity(0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade600.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Thanh toán',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        } else if (type == 'PAYMENT_CONFIRM') {
          // Từ chối + Xác nhận
          actionButtons = [
            Expanded(
              child: GestureDetector(
                onTap: () => _handleDeclineRequest(r['id']),
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.shade600.withOpacity(0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade600.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Từ chối',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _handleAcceptRequest(r),
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade600,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.shade600.withOpacity(0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.shade600.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Xác nhận',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.isNotEmpty) ...[
              Text(
                '$content',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📅 ${_formatDateTime(createdAt)}',
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    '⏳ Đang chờ xử lý',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (actionButtons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: actionButtons,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  Future<void> _handleCancelRequest(int requestId) async {
    try {
      await RequestService.cancelRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy yêu cầu thành công')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _handleDeclineRequest(int requestId) async {
    try {
      await RequestService.declineRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã từ chối yêu cầu')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _handleAcceptRequest(Map<String, dynamic> request) async {
    try {
      await RequestService.acceptRequest(request['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chấp nhận yêu cầu')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<List<dynamic>> _fetchAllGroupsPending(BuildContext context) async {
    try {
      final allRequests = await RequestService.fetchReceivedRequestsWithFilter(
          direction: 'all');
      final pendingRequests =
          allRequests.where((r) => r.status == 'PENDING').toList();
      final List<Map<String, dynamic>> result = [];
      for (final req in pendingRequests) {
        result.add({
          'id': req.id,
          'type': req.type,
          'status': req.status,
          'content': req.content,
          'createdAt': req.createdAt.toIso8601String(),
          'senderId': req.senderId,
          'receiverId': req.receiverId,
          'senderName': req.senderName,
          'receiverName': req.receiverName,
          'referenceId': req.referenceId,
          'groupId': req.groupId,
        });
      }
      return result;
    } catch (e) {
      print('Error fetching all pending requests: $e');
      return [];
    }
  }

  Future<List<dynamic>> _fetchGroupPendingRequests(int groupId) async {
    try {
      final allRequests = await RequestService.fetchReceivedRequestsWithFilter(
          groupId: groupId.toString(), direction: 'all');
      final pendingRequests = allRequests
          .where((r) => r.status == 'PENDING' && r.groupId == groupId)
          .toList();
      final List<Map<String, dynamic>> result = [];
      for (final req in pendingRequests) {
        result.add({
          'id': req.id,
          'type': req.type,
          'status': req.status,
          'content': req.content,
          'createdAt': req.createdAt.toIso8601String(),
          'senderId': req.senderId,
          'receiverId': req.receiverId,
          'senderName': req.senderName,
          'receiverName': req.receiverName,
          'referenceId': req.referenceId,
          'groupId': req.groupId,
        });
      }
      return result;
    } catch (e) {
      print('Error fetching pending requests for group $groupId: $e');
      return [];
    }
  }
}
