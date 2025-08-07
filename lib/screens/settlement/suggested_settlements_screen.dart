import 'package:flutter/material.dart';
import '../../services/settlement_service.dart';
import '../../services/group_detail_service.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../utils/currency_formatter.dart';
import '../../screens/settlement/settlement_overview_screen.dart';

class SuggestedSettlementsScreen extends StatefulWidget {
  final int groupId;
  final bool userOnly;

  const SuggestedSettlementsScreen({
    Key? key,
    required this.groupId,
    this.userOnly = false,
  }) : super(key: key);

  @override
  State<SuggestedSettlementsScreen> createState() =>
      _SuggestedSettlementsScreenState();
}

class _SuggestedSettlementsScreenState extends State<SuggestedSettlementsScreen>
    with WidgetsBindingObserver {
  late Future<List<dynamic>> _future;
  List<dynamic> _pendingSettlements = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSuggestions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  void _loadSuggestions() async {
    _future = SettlementService.fetchSuggestedSettlements(
      widget.groupId,
      userOnly: widget.userOnly,
    );
    // Load pending settlements song song
    final history =
        await SettlementService.fetchSettlementHistory(widget.groupId);
    setState(() {
      _pendingSettlements = history
          .where((item) => item is Map && item['status'] == 'PENDING')
          .toList();
    });
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
        setState(() {
          _loadSuggestions();
        });
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
      if (success) setState(_loadSuggestions);
    }
  }

  Future<void> _confirmReceived(Map<String, dynamic> s) async {
    final success = await SettlementService.confirmSettlement(s['id']);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            success ? '✅ Đã xác nhận đã nhận tiền.' : '❌ Lỗi khi xác nhận'),
      ));
      if (success) setState(_loadSuggestions);
    }
  }

  Future<void> _handlePay(Map<String, dynamic> s) async {
    if (s['settlementMethod'] == 'VNPAY') {
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Không lấy được link thanh toán VNPay.')));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Lỗi VNPay: $e')));
        }
      }
    } else {
      final success = await SettlementService.confirmSettlement(s['id']);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? '✅ Đã gửi xác nhận đã thanh toán.'
              : '❌ Lỗi khi xác nhận'),
        ));
        if (success) setState(_loadSuggestions);
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
                try {
                  final paymentUrl =
                      await SettlementService.createVnPaySettlement(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Sau khi thanh toán xong, vui lòng quay lại app và bấm làm mới để cập nhật trạng thái.'),
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Không lấy được link thanh toán VNPay.')),
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
              },
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: AuthService.getCurrentUser(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!userSnapshot.hasData || userSnapshot.data == null) {
          return const Center(child: Text('Không xác định người dùng.'));
        }
        final currentUser = userSnapshot.data!;
        if (currentUser.id == null) {
          return const Center(child: Text('Không xác định người dùng.'));
        }
        final currentUserId = currentUser.id!;
        return FutureBuilder<Map<String, dynamic>>(
          future: _getGroupAndRole(widget.groupId, currentUserId),
          builder: (context, groupSnapshot) {
            if (!groupSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final isAdmin = groupSnapshot.data!['isAdmin'] as bool;
            final myParticipantId = groupSnapshot.data!['myParticipantId'];
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
                    title: Text(
                      widget.userOnly
                          ? 'Gợi ý thanh toán của bạn'
                          : 'Tất cả gợi ý thanh toán',
                      style: const TextStyle(
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
                      statusBarColor: Colors.white,
                      statusBarIconBrightness: Brightness.dark,
                      statusBarBrightness: Brightness.light,
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.history, color: Colors.white),
                        tooltip: 'Lịch sử thanh toán',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettlementOverviewScreen(
                                  groupId: widget.groupId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              body: FutureBuilder<List<dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Lỗi: ${snapshot.error}'));
                  }
                  final suggestions = snapshot.data ?? [];
                  if (suggestions.isEmpty) {
                    return const Center(
                        child: Text('Không có gợi ý thanh toán.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final s = suggestions[index] as Map<String, dynamic>;
                      // Khai báo các biến dùng xuyên suốt itemBuilder
                      final fromUser = s['fromParticipantUser'];
                      final toUser = s['toParticipantUser'];
                      final fromId = s['fromParticipantId'];
                      final toId = s['toParticipantId'];
                      final isFromLinked = fromUser != null;
                      final isToLinked = toUser != null;
                      final isYouOwe =
                          myParticipantId != null && fromId == myParticipantId;
                      final isYouReceive =
                          myParticipantId != null && toId == myParticipantId;
                      // ...các biến này đã được khai báo ở trên nếu cần...
                      if (!isFromLinked && isYouReceive) {
                        // Chỉ hiển thị nút xác nhận nhận tiền, căn phải
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${s['fromParticipantName']} → ${s['toParticipantName']}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                    'Số tiền: ${CurrencyFormatter.formatMoney((s['amount'] as num).toDouble(), s['currencyCode'] ?? 'VND')}'),
                                const SizedBox(height: 4),
                                Text("Mô tả: ${s['description'] ?? ''}",
                                    style:
                                        const TextStyle(color: Colors.black)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _buildStyledButton(
                                      onTap: () => _confirmPayment(s),
                                      icon: Icons.account_balance_wallet,
                                      label: 'Xác nhận\nnhận tiền',
                                      colors: [
                                        Colors.green.shade600,
                                        Colors.green.shade700
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      // Nếu 1 trong 2 participant chưa liên kết user, ẩn nút thao tác
                      if (!isFromLinked || !isToLinked) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: const Color(0xFFF8F6FF),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${s['fromParticipantName']} → ${s['toParticipantName']}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                    'Số tiền: ${CurrencyFormatter.formatMoney((s['amount'] as num).toDouble(), s['currencyCode'] ?? 'VND')}',
                                    style:
                                        const TextStyle(color: Colors.black)),
                                const SizedBox(height: 4),
                                Text("Mô tả: ${s['description'] ?? ''}",
                                    style:
                                        const TextStyle(color: Colors.black)),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.info_outline,
                                          color: Color(0xFFFF9800), size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Người nhận chưa liên kết tài khoản. Vui lòng thanh toán trực tiếp và nhắc họ liên kết tài khoản để xác nhận.',
                                          style: const TextStyle(
                                            color: Color(0xFFB26A00),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.justify,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      // ...phần còn lại giữ nguyên...
                      final isRelated = isYouOwe || isYouReceive;
                      // Logic hiển thị nút
                      List<Widget> buttons = [];
                      // Check for duplicate PENDING settlement for this pair (dựa vào _pendingSettlements)
                      bool hasPending = false;
                      try {
                        hasPending = _pendingSettlements.any((item) {
                          if (item is! Map) return false;
                          return item['fromParticipantId'] ==
                                  s['fromParticipantId'] &&
                              item['toParticipantId'] == s['toParticipantId'] &&
                              item['amount'] == s['amount'] &&
                              item['currencyCode'] == s['currencyCode'];
                        });
                      } catch (_) {
                        hasPending = false;
                      }
                      if (isAdmin) {
                        if (!isRelated) {
                          buttons = [
                            _buildStyledButton(
                              onTap: () => _createPendingSettlement(s, 'CASH'),
                              icon: Icons.check_circle,
                              label: 'Xác nhận\nthanh toán',
                              colors: [
                                Colors.green.shade600,
                                Colors.green.shade700
                              ],
                              disabled: hasPending,
                            ),
                            _buildStyledButton(
                              onTap: () => _showPaymentMethodSheet(s),
                              icon: Icons.payment,
                              label: 'Yêu cầu\nthanh toán',
                              colors: [
                                Colors.blue.shade600,
                                Colors.blue.shade700
                              ],
                              disabled: hasPending,
                            ),
                          ];
                        } else if (isYouOwe) {
                          buttons = [
                            _buildStyledButton(
                              onTap: () => _createPendingSettlement(s, 'CASH'),
                              icon: Icons.check_circle,
                              label: 'Xác nhận\nthanh toán',
                              colors: [
                                Colors.green.shade600,
                                Colors.green.shade700
                              ],
                              disabled: hasPending,
                            ),
                            _buildStyledButton(
                              onTap: () => _showPaymentMethodSheet(s),
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
                              onTap: () => _confirmPayment(s),
                              icon: Icons.account_balance_wallet,
                              label: 'Xác nhận\nnhận tiền',
                              colors: [
                                Colors.green.shade600,
                                Colors.green.shade700
                              ],
                              disabled: hasPending,
                            ),
                            _buildStyledButton(
                              onTap: () => _createPendingSettlement(s, null),
                              icon: Icons.request_quote,
                              label: 'Yêu cầu\nthanh toán',
                              colors: [
                                Colors.orange.shade600,
                                Colors.orange.shade700
                              ],
                              disabled: hasPending,
                            ),
                          ];
                        }
                      } else {
                        // Luôn hiển thị item, chỉ hiển thị nút thao tác nếu là người nợ hoặc người nhận
                        if (isYouOwe) {
                          buttons = [
                            _buildStyledButton(
                              onTap: () => _createPendingSettlement(s, 'CASH'),
                              icon: Icons.check_circle,
                              label: 'Xác nhận\nthanh toán',
                              colors: [
                                Colors.green.shade600,
                                Colors.green.shade700
                              ],
                              disabled: hasPending,
                            ),
                            _buildStyledButton(
                              onTap: () => _showPaymentMethodSheet(s),
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
                              onTap: () => _confirmPayment(s),
                              icon: Icons.account_balance_wallet,
                              label: 'Xác nhận\nnhận tiền',
                              colors: [
                                Colors.green.shade600,
                                Colors.green.shade700
                              ],
                              disabled: hasPending,
                            ),
                            _buildStyledButton(
                              onTap: () => _createPendingSettlement(s, null),
                              icon: Icons.request_quote,
                              label: 'Yêu cầu\nthanh toán',
                              colors: [
                                Colors.orange.shade600,
                                Colors.orange.shade700
                              ],
                              disabled: hasPending,
                            ),
                          ];
                        } else {
                          buttons = [];
                        }
                      }
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${s['fromParticipantName']} → ${s['toParticipantName']}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                  'Số tiền: ${CurrencyFormatter.formatMoney((s['amount'] as num).toDouble(), s['currencyCode'] ?? 'VND')}'),
                              const SizedBox(height: 4),
                              Text("Mô tả: ${s['description'] ?? ''}",
                                  style: const TextStyle(color: Colors.black)),
                              const SizedBox(height: 12),
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
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStyledButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required List<Color> colors,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Container(
        width: 145,
        height: 45,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: disabled ? null : onTap,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
