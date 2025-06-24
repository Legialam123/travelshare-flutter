import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

class UserStatisticsScreen extends StatelessWidget {
  const UserStatisticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock dữ liệu
    final totalExpense = 1250000;
    final groupCount = 4;
    final transactionCount = 18;
    final debt = 250000;
    final credit = 120000;

    // Dữ liệu mock cho biểu đồ
    final pieData = [
      PieChartSectionData(value: 40, color: Colors.blue, title: 'Ăn uống'),
      PieChartSectionData(value: 30, color: Colors.purple, title: 'Di chuyển'),
      PieChartSectionData(value: 20, color: Colors.orange, title: 'Khách sạn'),
      PieChartSectionData(value: 10, color: Colors.green, title: 'Khác'),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFCF8FF),
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
                'Thống kê cá nhân',
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
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lưới 2x2 cho 4 card
              Row(
                children: [
                  _statCard('Tổng chi tiêu', '$totalExpense đ', Icons.paid, Colors.blue.shade400, bg: Colors.blue.shade50),
                  const SizedBox(width: 16),
                  _statCard('Số nhóm', '$groupCount', Icons.group, Colors.purple.shade400, bg: Colors.purple.shade50),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statCard('Giao dịch', '$transactionCount', Icons.receipt_long, Colors.green.shade400, bg: Colors.green.shade50),
                  const SizedBox(width: 16),
                  _statCard('Còn nợ', '$debt đ', Icons.trending_down, Colors.red.shade400, bg: Colors.red.shade50),
                ],
              ),
              const SizedBox(height: 16),
              // Card full width
              _statCard('Được nhận', '$credit đ', Icons.trending_up, Colors.orange.shade400, bg: Colors.orange.shade50, isFullWidth: true),
              const SizedBox(height: 32),
              // Biểu đồ tròn
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    const Text('Phân bổ chi tiêu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 140,
                      child: PieChart(
                        PieChartData(
                          sections: pieData,
                          centerSpaceRadius: 32,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Chú thích
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      children: pieData.map((e) => _legend(e.color!, e.title!)).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {Color? bg, bool isFullWidth = false}) {
    final card = Container(
      width: isFullWidth ? double.infinity : null,
      margin: EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: bg ?? color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    if (isFullWidth) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: card,
      );
    } else {
      return Expanded(child: card);
    }
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
} 