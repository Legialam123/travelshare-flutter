import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/settlement_service.dart';
import '../../services/group_detail_service.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
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

class _SuggestedSettlementsScreenState
    extends State<SuggestedSettlementsScreen> with WidgetsBindingObserver {
  late Future<List<dynamic>> _future;
  final _currencyFormat =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

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

  void _loadSuggestions() {
    _future = SettlementService.fetchSuggestedSettlements(
      widget.groupId,
      userOnly: widget.userOnly,
    );
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

  Future<void> _createPendingSettlement(Map<String, dynamic> s, String? method) async {
    final success = await SettlementService.createSettlement(
      groupId: s['groupId'],
      fromParticipantId: s['fromParticipantId'],
      toParticipantId: s['toParticipantId'],
      amount: s['amount'],
      currencyCode: s['currencyCode'],
      status: 'PENDING',
      settlementMethod: method,
      description: s['description'],
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '✅ Đã gửi yêu cầu thanh toán.' : '❌ Lỗi khi gửi yêu cầu'),
      ));
      if (success) setState(_loadSuggestions);
    }
  }

  Future<void> _confirmReceived(Map<String, dynamic> s) async {
    final success = await SettlementService.confirmSettlement(s['id']);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? '✅ Đã xác nhận đã nhận tiền.' : '❌ Lỗi khi xác nhận'),
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
            await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không lấy được link thanh toán VNPay.')));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi VNPay: $e')));
        }
      }
    } else {
      final success = await SettlementService.confirmSettlement(s['id']);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? '✅ Đã gửi xác nhận đã thanh toán.' : '❌ Lỗi khi xác nhận'),
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
                      await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sau khi thanh toán xong, vui lòng quay lại app và bấm làm mới để cập nhật trạng thái.'),
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Không lấy được link thanh toán VNPay.')),
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

  Future<Map<String, dynamic>> _getGroupAndRole(int groupId, String currentUserId) async {
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
      appBar: AppBar(
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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white),
                    tooltip: 'Lịch sử thanh toán',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettlementOverviewScreen(groupId: widget.groupId),
                        ),
                      );
                    },
                  ),
                ],
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
            return const Center(child: Text('Không có gợi ý thanh toán.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final s = suggestions[index] as Map<String, dynamic>;
                      final fromId = s['fromParticipantId'];
                      final toId = s['toParticipantId'];
                      final isYouOwe = myParticipantId != null && fromId == myParticipantId;
                      final isYouReceive = myParticipantId != null && toId == myParticipantId;
                      final isRelated = isYouOwe || isYouReceive;
                      // Logic hiển thị nút
                      List<Widget> buttons = [];
                      if (isAdmin) {
                        if (!isRelated) {
                          buttons = [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _confirmPayment(s),
                                child: const Text('Xác nhận \nthanh toán', textAlign: TextAlign.center),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showPaymentMethodSheet(s),
                                child: const Text('Yêu cầu \nthanh toán', textAlign: TextAlign.center),
                              ),
                            ),
                          ];
                        } else if (isYouOwe) {
                          buttons = [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _confirmPayment(s),
                                child: const Text('Xác nhận \nthanh toán', textAlign: TextAlign.center),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showPaymentMethodSheet(s),
                                child: const Text('Thanh toán', textAlign: TextAlign.center),
                              ),
                            ),
                          ];
                        } else if (isYouReceive) {
                          buttons = [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _confirmReceived(s),
                                child: const Text('Xác nhận \nthanh toán', textAlign: TextAlign.center),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _createPendingSettlement(s, null),
                                child: const Text('Yêu cầu \nthanh toán', textAlign: TextAlign.center),
                              ),
                            ),
                          ];
                        }
                      } else {
                        if (!isRelated) return const SizedBox.shrink();
                        if (isYouOwe) {
                          buttons = [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _confirmPayment(s),
                                child: const Text('Xác nhận \nthanh toán', textAlign: TextAlign.center),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showPaymentMethodSheet(s),
                                child: const Text('Thanh toán', textAlign: TextAlign.center),
                              ),
                            ),
                          ];
                        } else if (isYouReceive) {
                          buttons = [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _confirmReceived(s),
                                child: const Text('Xác nhận \nthanh toán', textAlign: TextAlign.center),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _createPendingSettlement(s, null),
                                child: const Text('Yêu cầu \nthanh toán', textAlign: TextAlign.center),
                              ),
                            ),
                          ];
                        }
                      }
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                              Text('${s['fromParticipantName']} → ${s['toParticipantName']}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                              Text('Số tiền: ${_currencyFormat.format(s['amount'])}'),
                      const SizedBox(height: 4),
                      Text(s['description'] ?? '',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                              Row(children: buttons),
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
}
