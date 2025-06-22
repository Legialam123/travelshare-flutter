import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/settlement_service.dart';

class SettlementOverviewScreen extends StatelessWidget {
  final int groupId;
  const SettlementOverviewScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử thanh toán'),
      ),
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
                  title: Text('$from → $to'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Số tiền: ${currencyFormat.format(amount)}'),
                      if (desc.isNotEmpty) Text(desc, style: const TextStyle(color: Colors.grey)),
                      Text('Phương thức: $method'),
                      if (date.isNotEmpty) Text('Ngày: $date', style: const TextStyle(fontSize: 12)),
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
