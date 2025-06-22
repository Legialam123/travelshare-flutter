import 'package:flutter/material.dart';
import '../../models/request.dart';
import '../../services/request_service.dart';
import '../../screens/settlement/settlement_overview_screen.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/settlement_service.dart';

class RequestScreen extends StatefulWidget {
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        child: AppBar(
        title: const Text(
          'Yêu cầu',
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Color(0xFF667eea),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF667eea),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Đã gửi'))),
                Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Nhận vào'))),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Lịch sử\nthanh toán',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SentRequestsTab(),
          _ReceivedRequestsTab(),
          _SettlementHistoryTab(),
        ],
      ),
    );
  }
}

class _SentRequestsTab extends StatefulWidget {
  @override
  State<_SentRequestsTab> createState() => _SentRequestsTabState();
}

class _SentRequestsTabState extends State<_SentRequestsTab> {
  late Future<List<RequestModel>> _futureSent;
  Map<int, bool> _cancelLoading = {};

  @override
  void initState() {
    super.initState();
    _futureSent = RequestService.fetchSentRequests();
  }

  Future<void> _handleCancel(int requestId) async {
    setState(() {
      _cancelLoading[requestId] = true;
    });
    try {
      await RequestService.cancelRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy yêu cầu thành công')));
        setState(() {
          _futureSent = RequestService.fetchSentRequests();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      setState(() {
        _cancelLoading[requestId] = false;
      });
    }
  }

  Widget buildRequestActionButtons(RequestModel req) {
    if (req.status == 'PENDING_CONFIRM') return const SizedBox.shrink();
    return const SizedBox.shrink();
  }

  Widget buildRequestCard(RequestModel req, {bool isSent = true, bool isLoading = false, void Function()? onAccept, void Function()? onDecline}) {
    IconData iconData;
    Color iconColor;
    switch (req.type) {
      case 'SETTLEMENT':
        iconData = Icons.payments_rounded;
        iconColor = Colors.teal;
        break;
      case 'INVITE':
        iconData = Icons.group_add_rounded;
        iconColor = Colors.blue;
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
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: (isSent && req.status == 'PENDING')
                ? () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Xác nhận hủy yêu cầu'),
                        content: const Text('Bạn có chắc chắn muốn hủy yêu cầu này?'),
                        actions: [
                          TextButton(
                            child: const Text('Đóng'),
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                          TextButton(
                            child: const Text('Hủy yêu cầu', style: TextStyle(color: Colors.red)),
                            onPressed: () => Navigator.pop(ctx, true),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _handleCancel(req.id);
                    }
                  }
                : null,
            child: Stack(
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
                            colors: [iconColor.withOpacity(0.8), iconColor.withOpacity(0.5)],
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSent && req.status == 'PENDING')
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(Icons.chevron_right, color: Colors.grey, size: 28),
                    ),
                  ),
              ],
            ),
          ),
          buildRequestActionButtons(req),
        ],
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

  Widget _buildGroupedRequestList(List<RequestModel> requests, {bool isSent = true, bool isLoading = false, void Function(RequestModel req)? onAccept, void Function(RequestModel req)? onDecline}) {
    final Map<String, List<RequestModel>> grouped = {};
    for (final req in requests) {
      final dateStr = '${req.createdAt.day.toString().padLeft(2, '0')}/${req.createdAt.month.toString().padLeft(2, '0')}/${req.createdAt.year}';
      grouped.putIfAbsent(dateStr, () => []).add(req);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => DateTime.parse('${b.split('/')[2]}-${b.split('/')[1]}-${b.split('/')[0]}').compareTo(DateTime.parse('${a.split('/')[2]}-${a.split('/')[1]}-${a.split('/')[0]}')));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sortedKeys.fold<int>(0, (prev, key) => prev + 1 + grouped[key]!.length),
      itemBuilder: (context, index) {
        int runningIndex = 0;
        for (final date in sortedKeys) {
          if (index == runningIndex) {
            return buildDateHeader(date);
          }
          runningIndex++;
          final reqs = grouped[date]!..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (index < runningIndex + reqs.length) {
            final req = reqs[index - runningIndex];
            return buildRequestCard(
              req,
              isSent: isSent,
              isLoading: isLoading,
              onAccept: onAccept != null ? () => onAccept(req) : null,
              onDecline: onDecline != null ? () => onDecline(req) : null,
            );
          }
          runningIndex += reqs.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RequestModel>>(
      future: _futureSent,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: [38;5;5m${snapshot.error}[0m'));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(child: Text('Không có yêu cầu nào đã gửi.'));
        }
        return _buildGroupedRequestList(requests, isSent: true);
      },
    );
  }
}

class _ReceivedRequestsTab extends StatefulWidget {
  @override
  State<_ReceivedRequestsTab> createState() => _ReceivedRequestsTabState();
}

class _ReceivedRequestsTabState extends State<_ReceivedRequestsTab> with WidgetsBindingObserver {
  late Future<List<RequestModel>> _futureReceived;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  void _load() {
    setState(() {
      _futureReceived = RequestService.fetchReceivedRequests();
    });
  }

  void _handleAccept(int requestId) async {
    setState(() => _isLoading = true);
    try {
      await RequestService.acceptRequest(requestId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chấp nhận yêu cầu!')));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleDecline(int requestId) async {
    setState(() => _isLoading = true);
    try {
      await RequestService.declineRequest(requestId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã từ chối yêu cầu!')));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget buildRequestActionButtons(RequestModel req) {
    if (req.status == 'PENDING_CONFIRM') return const SizedBox.shrink();
    if (req.status != 'PENDING') return const SizedBox.shrink();
    List<Widget> buttons = [];
    final ButtonStyle declineStyle = OutlinedButton.styleFrom(
      backgroundColor: Colors.red.shade50,
      foregroundColor: Colors.red,
      side: BorderSide(color: Colors.red.shade400, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    );
    final ButtonStyle payStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.green.shade500,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      elevation: 0,
    );
    if (req.type == 'PAYMENT_REQUEST') {
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
            style: payStyle,
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
            style: payStyle,
            onPressed: () => _handleAccept(req.id),
            child: const Text('Xác nhận'),
          ),
        ),
      ];
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(children: buttons),
    );
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
    setState(() => _isLoading = true);
    try {
      // Gọi API gửi PAYMENT_CONFIRM
      await RequestService.sendPaymentConfirm(req.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu xác nhận thanh toán (tiền mặt)!')));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVnPayPayment(RequestModel req) async {
    setState(() => _isLoading = true);
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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget buildRequestCard(RequestModel req) {
    IconData iconData;
    Color iconColor;
    switch (req.type) {
      case 'SETTLEMENT':
        iconData = Icons.payments_rounded;
        iconColor = Colors.teal;
        break;
      case 'INVITE':
        iconData = Icons.group_add_rounded;
        iconColor = Colors.blue;
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
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: (req.status == 'PENDING')
                ? () async {
                    final action = await showModalBottomSheet<String>(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.check, color: Colors.green),
                              title: const Text('Chấp nhận'),
                              onTap: () => Navigator.pop(ctx, 'accept'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.close, color: Colors.red),
                              title: const Text('Từ chối'),
                              onTap: () => Navigator.pop(ctx, 'decline'),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (action == 'accept') {
                      _handleAccept(req.id);
                    } else if (action == 'decline') {
                      _handleDecline(req.id);
                    }
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          req.content,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          buildRequestActionButtons(req),
        ],
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

  Widget _buildGroupedRequestList(List<RequestModel> requests) {
    final Map<String, List<RequestModel>> grouped = {};
    for (final req in requests) {
      final dateStr = '${req.createdAt.day.toString().padLeft(2, '0')}/${req.createdAt.month.toString().padLeft(2, '0')}/${req.createdAt.year}';
      grouped.putIfAbsent(dateStr, () => []).add(req);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => DateTime.parse('${b.split('/')[2]}-${b.split('/')[1]}-${b.split('/')[0]}').compareTo(DateTime.parse('${a.split('/')[2]}-${a.split('/')[1]}-${a.split('/')[0]}')));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sortedKeys.fold<int>(0, (prev, key) => prev + 1 + grouped[key]!.length),
      itemBuilder: (context, index) {
        int runningIndex = 0;
        for (final date in sortedKeys) {
          if (index == runningIndex) {
            return buildDateHeader(date);
          }
          runningIndex++;
          final reqs = grouped[date]!..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (index < runningIndex + reqs.length) {
            final req = reqs[index - runningIndex];
            return buildRequestCard(req);
          }
          runningIndex += reqs.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<RequestModel>>(
          future: _futureReceived,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            }
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return const Center(child: Text('Không có yêu cầu nào nhận vào.'));
            }
            return _buildGroupedRequestList(requests);
          },
        ),
        if (_isLoading)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _SettlementHistoryTab extends StatefulWidget {
  @override
  State<_SettlementHistoryTab> createState() => _SettlementHistoryTabState();
}

class _SettlementHistoryTabState extends State<_SettlementHistoryTab> {
  int? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Group>>(
      future: GroupService.fetchGroups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        final groups = snapshot.data ?? [];
        if (groups.isEmpty) {
          return const Center(child: Text('Bạn chưa tham gia nhóm nào.'));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<int>(
                value: _selectedGroupId,
                decoration: const InputDecoration(
                  labelText: 'Chọn nhóm',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: groups.map((g) => DropdownMenuItem<int>(
                  value: g.id,
                  child: Text(g.name),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedGroupId = val;
                  });
                },
              ),
            ),
            if (_selectedGroupId != null)
              Expanded(child: SettlementOverviewScreen(groupId: _selectedGroupId!)),
          ],
        );
      },
    );
  }
} 