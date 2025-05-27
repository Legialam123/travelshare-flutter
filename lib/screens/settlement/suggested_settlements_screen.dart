import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/settlement_service.dart';
import '../../services/group_detail_service.dart';
import 'package:flutter/services.dart';

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
    extends State<SuggestedSettlementsScreen> {
  late Future<List<dynamic>> _future;
  final _currencyFormat =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
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

  Future<void> _requestPayment(Map<String, dynamic> s) async {
    final success = await SettlementService.createSettlement(
      groupId: s['groupId'],
      fromParticipantId: s['fromParticipantId'],
      toParticipantId: s['toParticipantId'],
      amount: s['amount'],
      currencyCode: s['currencyCode'],
      status: 'PENDING',
      description: s['description'],
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            success ? '✅ Đã gửi yêu cầu thanh toán.' : '❌ Lỗi khi gửi yêu cầu'),
      ));

      if (success) {
        setState(() {
          _loadSuggestions();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              final from = s['fromParticipantName'] ?? 'Người A';
              final to = s['toParticipantName'] ?? 'Người B';
              final amount = _currencyFormat.format(s['amount']);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$from → $to',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Số tiền: $amount'),
                      const SizedBox(height: 4),
                      Text(s['description'] ?? '',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _confirmPayment(s),
                              child: const Text('Xác nhận thanh toán',
                                  textAlign: TextAlign.center),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _requestPayment(s),
                              child: const Text('Yêu cầu \nthanh toán',
                                  textAlign: TextAlign.center),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
