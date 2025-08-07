import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/settlement_service.dart';
import '../../utils/currency_formatter.dart';

class SettlementOverviewScreen extends StatelessWidget {
  final int groupId;
  const SettlementOverviewScreen({Key? key, required this.groupId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            title: const Text(
              'Lịch sử thanh toán',
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
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.white,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFFCF8FF),
      body: FutureBuilder<List<dynamic>>(
        future: SettlementService.fetchSettlementHistory(groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          final settlements = snapshot.data ?? [];
          if (settlements.isEmpty) {
            return const Center(child: Text('Chưa có lịch sử thanh toán.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: settlements.length,
            itemBuilder: (context, index) {
              final s = settlements[index] as Map<String, dynamic>;
              final status = s['status'] ?? '';
              final method = s['settlementMethod'] ?? '';
              final amount = s['amount'] ?? 0;
              final desc = s['description'] ?? '';
              final from = s['fromParticipantName'] ?? '';
              final to = s['toParticipantName'] ?? '';
              final date = s['createdAt'] ?? '';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: Icon(
                    status == 'COMPLETED' ? Icons.check_circle : Icons.cancel,
                    color: status == 'COMPLETED' ? Colors.green : Colors.red,
                  ),
                  title: Text('$from → $to',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Số tiền: ${CurrencyFormatter.formatMoney((amount as num).toDouble(), s['currencyCode'] ?? 'VND')}',
                          style: const TextStyle(color: Colors.black)),
                      if (desc.isNotEmpty)
                        Text(desc, style: const TextStyle(color: Colors.black)),
                      Text('Phương thức: $method',
                          style: const TextStyle(color: Colors.black)),
                      if (date.isNotEmpty)
                        Text('Ngày: $date',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black)),
                    ],
                  ),
                  trailing: Text(
                    status == 'COMPLETED' ? 'Hoàn thành' : 'Thất bại',
                    style: TextStyle(
                      color: status == 'COMPLETED' ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
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
