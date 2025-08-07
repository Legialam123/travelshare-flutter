import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/group.dart';
import '../../services/expense_service.dart';
import '../../services/settlement_service.dart';
import '../../services/auth_service.dart';
import '../../services/media_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/user.dart';
import '../settlement/suggested_settlements_screen.dart';
import '../../utils/icon_utils.dart';
import '../../utils/currency_formatter.dart';

class GroupStatisticsScreen extends StatefulWidget {
  final Group group;
  const GroupStatisticsScreen({Key? key, required this.group})
      : super(key: key);

  @override
  State<GroupStatisticsScreen> createState() => _GroupStatisticsScreenState();
}

class _GroupStatisticsScreenState extends State<GroupStatisticsScreen> {
  late NumberFormat currencyFormat;

  late Future<Map<String, dynamic>> _statisticsFuture;
  late Future<List<dynamic>> _balancesFuture;
  late Future<List<dynamic>> _settlementsFuture;
  late Future<User?> _userFuture;

  @override
  void initState() {
    super.initState();
    _setupCurrencyFormat();
    _loadData();
  }

  void _setupCurrencyFormat() {
    final defaultCurrency = widget.group.defaultCurrency;
    final isInteger = CurrencyFormatter.isIntegerCurrency(defaultCurrency);
    final symbol = CurrencyFormatter.getSymbol(defaultCurrency);

    currencyFormat = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: symbol,
      decimalDigits: isInteger ? 0 : 2,
    );
  }

  void _loadData() {
    _statisticsFuture =
        ExpenseService.fetchGroupExpenseStatistics(widget.group.id);
    _balancesFuture = SettlementService.fetchGroupBalances(widget.group.id);
    _settlementsFuture =
        SettlementService.fetchSettlementHistory(widget.group.id);
    _userFuture = AuthService.getCurrentUser();
  }

  String replaceBaseUrl(String? url) {
    if (url == null) return '';
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    return url.replaceFirst(
        RegExp(r'^https?://localhost:8080/TravelShare'), apiBaseUrl);
  }

  Future<String?> _loadAvatar(String? userId) async {
    if (userId == null) return null;
    final url = await MediaService.fetchUserAvatar(userId);
    return replaceBaseUrl(url);
  }

  @override
  Widget build(BuildContext context) {
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
              title: Text(
                'Thống kê: ${widget.group.name}',
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
              systemOverlayStyle: SystemUiOverlayStyle.light,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _loadData();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _loadData();
            });
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: FutureBuilder<List<dynamic>>(
              future: Future.wait([
                _statisticsFuture,
                _balancesFuture,
                _settlementsFuture,
                _userFuture.then(
                    (user) => user ?? User(id: '', username: '', email: '')),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(50),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('Lỗi tải dữ liệu: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loadData();
                            });
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }

                final results = snapshot.data!;

                // Safe type checking và fallback values
                Map<String, dynamic> statistics;
                List<dynamic> balances;
                List<dynamic> settlements;
                User currentUser;

                try {
                  // Kiểm tra và xử lý an toàn từng kết quả
                  if (results.length > 0 &&
                      results[0] is Map<String, dynamic>) {
                    statistics = results[0] as Map<String, dynamic>;
                  } else {
                    statistics = <String, dynamic>{};
                  }

                  if (results.length > 1 && results[1] is List) {
                    balances = results[1] as List<dynamic>;
                  } else {
                    balances = <dynamic>[];
                  }

                  if (results.length > 2 && results[2] is List) {
                    settlements = results[2] as List<dynamic>;
                  } else {
                    settlements = <dynamic>[];
                  }

                  if (results.length > 3 && results[3] is User) {
                    currentUser = results[3] as User;
                  } else {
                    currentUser = User(id: '', username: '', email: '');
                  }
                } catch (e) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('Lỗi xử lý dữ liệu: $e'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loadData();
                            });
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }

                // Xử lý dữ liệu thống kê
                final expenseStats = statistics is Map<String, dynamic> &&
                        statistics['result'] is Map<String, dynamic>
                    ? statistics['result'] as Map<String, dynamic>
                    : <String, dynamic>{};
                final totalExpense =
                    (expenseStats['totalExpense'] as num?)?.toDouble() ?? 0;
                final expenses = expenseStats['expenses'] is List
                    ? expenseStats['expenses'] as List
                    : <dynamic>[];

                // Thống kê settlement
                final completedSettlements = settlements.where((s) {
                  if (s is Map<String, dynamic>) {
                    return s['status']?.toString() == 'COMPLETED';
                  }
                  return false;
                }).length;
                final pendingSettlements = settlements.where((s) {
                  if (s is Map<String, dynamic>) {
                    return s['status']?.toString() == 'PENDING';
                  }
                  return false;
                }).length;

                // Tính toán số dư công nợ
                double totalDebt = 0;
                double totalCredit = 0;
                int membersWithDebt = 0;

                for (final balance in balances) {
                  if (balance is Map<String, dynamic>) {
                    final amount =
                        (balance['balance'] as num?)?.toDouble() ?? 0;
                    if (amount < 0) {
                      totalDebt += amount.abs();
                      membersWithDebt++;
                    } else if (amount > 0) {
                      totalCredit += amount;
                    }
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thống kê tổng quan
                    Row(
                      children: [
                        _statCard(
                          'Tổng chi tiêu',
                          currencyFormat.format(totalExpense),
                          Icons.paid,
                          Colors.blue.shade400,
                          bg: Colors.blue.shade50,
                          onTap: () => _showExpenseDetail(context, expenses),
                        ),
                        const SizedBox(width: 16),
                        _statCard(
                          'Thành viên',
                          '${widget.group.participants.length}',
                          Icons.group,
                          Colors.purple.shade400,
                          bg: Colors.purple.shade50,
                          onTap: () => _showMemberDetail(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _statCard(
                          'Lịch sử thanh toán',
                          '${settlements.length}',
                          Icons.receipt_long,
                          Colors.green.shade400,
                          bg: Colors.green.shade50,
                          onTap: () => _showGroupTransactionHistory(
                              context, settlements),
                        ),
                        const SizedBox(width: 16),
                        _statCard(
                          'Thanh toán chờ',
                          '$pendingSettlements',
                          Icons.pending,
                          Colors.orange.shade400,
                          bg: Colors.orange.shade50,
                          onTap: () => _showPendingSettlementsDetail(
                              context, settlements),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Phần công nợ nhóm
                    _buildDebtSection(balances, currentUser.id ?? ''),

                    const SizedBox(height: 28),

                    // Biểu đồ chi tiêu theo thành viên
                    _buildExpenseChart(expenses),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebtSection(List<dynamic> balances, String currentUserId) {
    if (balances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'Chưa có công nợ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tất cả chi phí đã được thanh toán đều',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Sắp xếp balances: âm trước (nợ), dương sau (có tiền)
    final sortedBalances = [...balances];
    sortedBalances.sort((a, b) {
      if (a is! Map<String, dynamic> || b is! Map<String, dynamic>) {
        return 0;
      }
      final balanceA = (a['balance'] as num?)?.toDouble() ?? 0;
      final balanceB = (b['balance'] as num?)?.toDouble() ?? 0;
      return balanceA.compareTo(balanceB);
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Công nợ nhóm',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _showAllBalancesDetail(context, balances, currentUserId);
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Xem tất cả'),
                ),
              ],
            ),
          ),

          // Danh sách số dư
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedBalances.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[200],
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final balance = sortedBalances[index];
              if (balance is! Map<String, dynamic>) {
                return const SizedBox.shrink();
              }
              final participantName =
                  balance['participantName']?.toString() ?? 'Thành viên';
              final amount = (balance['balance'] as num?)?.toDouble() ?? 0;
              final participantUserId =
                  balance['participantUserId']?.toString() ?? '';
              final isCurrentUser = participantUserId == currentUserId;

              final isDebt = amount < 0;
              final displayAmount = amount.abs();

              return FutureBuilder<String?>(
                future: _loadAvatar(participantUserId),
                builder: (context, snapshot) {
                  final avatar = snapshot.data;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: (avatar != null && avatar.isNotEmpty)
                              ? NetworkImage(avatar)
                              : const AssetImage(
                                      'assets/images/default_user_avatar.png')
                                  as ImageProvider,
                          backgroundColor: Colors.blue[100],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                participantName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              if (isCurrentUser)
                                Text(
                                  'Bạn',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isDebt ? '-' : amount > 0 ? '+' : ''}${currencyFormat.format(displayAmount)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDebt
                                    ? Colors.red
                                    : amount > 0
                                        ? Colors.green
                                        : Colors.grey,
                              ),
                            ),
                            Text(
                              isDebt
                                  ? 'Đang nợ'
                                  : amount > 0
                                      ? 'Được nợ'
                                      : 'Đã cân bằng',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // Footer với nút hành động
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SuggestedSettlementsScreen(
                            groupId: widget.group.id,
                            userOnly: true,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text('Công nợ của tôi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SuggestedSettlementsScreen(
                            groupId: widget.group.id,
                            userOnly: false,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.group, size: 18),
                    label: const Text('Tất cả gợi ý'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseChart(List<dynamic> expenses) {
    if (expenses.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text('Chưa có dữ liệu chi tiêu'),
        ),
      );
    }

    // Tính toán chi tiêu theo thành viên
    final Map<String, double> memberExpenses = {};
    final Map<String, Color> memberColors = {};
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    int colorIndex = 0;
    for (final expense in expenses) {
      if (expense is! Map<String, dynamic>) continue;

      // Sử dụng payer từ API mới
      final payerName =
          expense['payer']?['name']?.toString() ?? 'Không xác định';
      final amount = (expense['convertedAmount'] ?? expense['amount'] ?? 0 as num?)?.toDouble() ?? 0;
      memberExpenses[payerName] = (memberExpenses[payerName] ?? 0) + amount;

      if (!memberColors.containsKey(payerName)) {
        memberColors[payerName] = colors[colorIndex % colors.length];
        colorIndex++;
      }
    }

    final totalExpense = memberExpenses.values.fold(0.0, (a, b) => a + b);

    final pieData = memberExpenses.entries.map((entry) {
      final percent = totalExpense > 0 ? (entry.value / totalExpense * 100) : 0;
      return {
        'value': entry.value,
        'percent': percent,
        'color': memberColors[entry.key] ?? Colors.grey,
        'label': entry.key,
      };
    }).toList()
      ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Biểu đồ chi tiêu theo thành viên',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: PieChart(
                    PieChartData(
                      sections: pieData
                          .map((d) => PieChartSectionData(
                                value: (d['value'] as num).toDouble(),
                                color: d['color'] as Color,
                                radius: 54,
                                showTitle: true,
                                title:
                                    '${(d['percent'] as num).toStringAsFixed(0)}%',
                                titleStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                titlePositionPercentageOffset: 0.45,
                              ))
                          .toList(),
                      centerSpaceRadius: 38,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 0, 16),
                    child: ListView(
                      children: pieData
                          .map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: d['color'] as Color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d['label'] as String,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            currencyFormat.format(d['value']),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllBalancesDetail(
      BuildContext context, List<dynamic> balances, String currentUserId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        // Sắp xếp balances: âm trước (nợ), dương sau (được nợ)
        final sortedBalances = [...balances];
        sortedBalances.sort((a, b) {
          if (a is! Map<String, dynamic> || b is! Map<String, dynamic>) {
            return 0;
          }
          final balanceA = (a['balance'] as num?)?.toDouble() ?? 0;
          final balanceB = (b['balance'] as num?)?.toDouble() ?? 0;
          return balanceA.compareTo(balanceB);
        });

        // Tính toán thống kê
        double totalDebt = 0;
        double totalCredit = 0;
        int membersWithDebt = 0;
        int membersWithCredit = 0;

        for (final balance in sortedBalances) {
          if (balance is Map<String, dynamic>) {
            final amount = (balance['balance'] as num?)?.toDouble() ?? 0;
            if (amount < 0) {
              totalDebt += amount.abs();
              membersWithDebt++;
            } else if (amount > 0) {
              totalCredit += amount;
              membersWithCredit++;
            }
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Chi tiết công nợ nhóm',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Thống kê tổng hợp
              Row(
                children: [
                  // Card Tổng nợ
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade50, Colors.red.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.red.shade200, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.trending_down,
                                    color: Colors.red.shade700, size: 20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tổng nợ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currencyFormat.format(totalDebt),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$membersWithDebt người đang nợ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Card Tổng được nợ
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade50, Colors.green.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.green.shade200, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.trending_up,
                                    color: Colors.green.shade700, size: 20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tổng được nợ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currencyFormat.format(totalCredit),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$membersWithCredit người được nợ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Danh sách chi tiết
              SizedBox(
                height: 400,
                child: sortedBalances.isEmpty
                    ? const Center(child: Text('Không có dữ liệu công nợ.'))
                    : Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          itemCount: sortedBalances.length,
                          itemBuilder: (context, index) {
                            final balance = sortedBalances[index];
                            if (balance is! Map<String, dynamic>) {
                              return const SizedBox.shrink();
                            }

                            final participantName =
                                balance['participantName']?.toString() ??
                                    'Thành viên';
                            final amount =
                                (balance['balance'] as num?)?.toDouble() ?? 0;
                            final participantUserId =
                                balance['participantUserId']?.toString() ?? '';
                            final isCurrentUser =
                                participantUserId == currentUserId;

                            final isDebt = amount < 0;
                            final displayAmount = amount.abs();

                            return FutureBuilder<String?>(
                              future: _loadAvatar(participantUserId),
                              builder: (context, snapshot) {
                                final avatar = snapshot.data;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundImage: (avatar != null &&
                                                  avatar.isNotEmpty)
                                              ? NetworkImage(avatar)
                                              : const AssetImage(
                                                      'assets/images/default_user_avatar.png')
                                                  as ImageProvider,
                                          backgroundColor: Colors.blue[100],
                                        ),

                                        const SizedBox(width: 12),

                                        // Thông tin chính
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Tên
                                              Text(
                                                participantName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),

                                              const SizedBox(height: 4),

                                              // Trạng thái
                                              Text(
                                                isDebt
                                                    ? 'Đang nợ nhóm'
                                                    : amount > 0
                                                        ? 'Nhóm đang nợ'
                                                        : 'Đã thanh toán đều',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDebt
                                                      ? Colors.red.shade600
                                                      : amount > 0
                                                          ? Colors
                                                              .green.shade600
                                                          : Colors
                                                              .grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Số tiền và badge
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${isDebt ? '-' : amount > 0 ? '+' : ''}${currencyFormat.format(displayAmount)}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDebt
                                                    ? Colors.red
                                                    : amount > 0
                                                        ? Colors.green
                                                        : Colors.grey,
                                              ),
                                            ),
                                            if (isCurrentUser) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'Bạn',
                                                  style: TextStyle(
                                                    color: Colors.blue.shade700,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // Nút hành động
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SuggestedSettlementsScreen(
                        groupId: widget.group.id,
                        userOnly: false,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('Xem gợi ý thanh toán chung'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGroupTransactionHistory(
      BuildContext context, List<dynamic> settlements) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        String selectedFilter = 'Tất cả';
        String selectedStatus = 'Tất cả';
        final filters = [
          'Tất cả',
          'Hôm nay',
          'Tuần này',
          'Tháng này',
          'Năm nay',
          'Tuỳ chọn'
        ];
        final statusFilters = [
          'Tất cả',
          'Đã hoàn thành',
          'Đang chờ',
          'Thất bại'
        ];
        DateTime? startDate;
        DateTime? endDate;
        List filteredSettlements = settlements;
        double totalPaid = 0;
        double totalReceived = 0;

        void applyFilter() {
          DateTime now = DateTime.now();
          filteredSettlements = settlements;

          // Lọc theo trạng thái
          if (selectedStatus != 'Tất cả') {
            filteredSettlements = filteredSettlements.where((s) {
              if (s is! Map<String, dynamic>) return false;
              final status = s['status']?.toString() ?? '';
              if (selectedStatus == 'Đã hoàn thành')
                return status == 'COMPLETED';
              if (selectedStatus == 'Đang chờ') return status == 'PENDING';
              if (selectedStatus == 'Thất bại') return status == 'FAILED';
              return true;
            }).toList();
          }

          // Lọc theo thời gian
          if (selectedFilter == 'Hôm nay') {
            filteredSettlements = filteredSettlements
                .where((s) =>
                    s is Map<String, dynamic> &&
                    s['createdAt'] != null &&
                    DateTime.parse(s['createdAt']).day == now.day &&
                    DateTime.parse(s['createdAt']).month == now.month &&
                    DateTime.parse(s['createdAt']).year == now.year)
                .toList();
          } else if (selectedFilter == 'Tuần này') {
            DateTime monday = now.subtract(Duration(days: now.weekday - 1));
            filteredSettlements = filteredSettlements.where((s) {
              if (s is! Map<String, dynamic> || s['createdAt'] == null)
                return false;
              DateTime d = DateTime.parse(s['createdAt']);
              return d.isAfter(monday.subtract(const Duration(days: 1))) &&
                  d.isBefore(now.add(const Duration(days: 1)));
            }).toList();
          } else if (selectedFilter == 'Tháng này') {
            filteredSettlements = filteredSettlements.where((s) {
              if (s is! Map<String, dynamic> || s['createdAt'] == null)
                return false;
              DateTime d = DateTime.parse(s['createdAt']);
              return d.year == now.year && d.month == now.month;
            }).toList();
          } else if (selectedFilter == 'Năm nay') {
            filteredSettlements = filteredSettlements.where((s) {
              if (s is! Map<String, dynamic> || s['createdAt'] == null)
                return false;
              DateTime d = DateTime.parse(s['createdAt']);
              return d.year == now.year;
            }).toList();
          } else if (selectedFilter == 'Tuỳ chọn' &&
              startDate != null &&
              endDate != null) {
            filteredSettlements = filteredSettlements.where((s) {
              if (s is! Map<String, dynamic> || s['createdAt'] == null)
                return false;
              DateTime d = DateTime.parse(s['createdAt']);
              return !d.isBefore(startDate!) && !d.isAfter(endDate!);
            }).toList();
          }

          // Tính tổng tiền đã thanh toán/nhận (cho completed transactions)
          totalPaid = filteredSettlements
              .where((s) =>
                  s is Map<String, dynamic> && s['status'] == 'COMPLETED')
              .fold(
                  0.0, (a, b) => a + ((b['amount'] as num?)?.toDouble() ?? 0));
        }

        applyFilter();

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Lịch sử thanh toán nhóm',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lọc theo thời gian
                Row(
                  children: [
                    const Text('Thời gian: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedFilter,
                        isExpanded: true,
                        items: filters
                            .map((f) =>
                                DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedFilter = value;
                              applyFilter();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Lọc theo trạng thái
                Row(
                  children: [
                    const Text('Trạng thái: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: statusFilters
                            .map((f) =>
                                DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedStatus = value;
                              applyFilter();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                if (selectedFilter == 'Tuỳ chọn') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                startDate = picked;
                                applyFilter();
                              });
                            }
                          },
                          child: Text(startDate == null
                              ? 'Chọn từ ngày'
                              : '${startDate!.day}/${startDate!.month}/${startDate!.year}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: startDate ?? DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                endDate = picked;
                                applyFilter();
                              });
                            }
                          },
                          child: Text(endDate == null
                              ? 'Đến ngày'
                              : '${endDate!.day}/${endDate!.month}/${endDate!.year}'),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Thống kê tổng hợp
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng thanh toán:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                          Text(
                            '${filteredSettlements.length}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng tiền thanh toán:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            currencyFormat.format(totalPaid),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Danh sách giao dịch
                SizedBox(
                  height: 300,
                  child: filteredSettlements.isEmpty
                      ? const Center(child: Text('Không có thanh toán nào.'))
                      : Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            itemCount: filteredSettlements.length,
                            itemBuilder: (context, index) {
                              final settlement = filteredSettlements[index];
                              if (settlement is! Map<String, dynamic>) {
                                return const SizedBox.shrink();
                              }

                              final amount =
                                  (settlement['amount'] as num?)?.toDouble() ??
                                      0;
                              final status =
                                  settlement['status']?.toString() ?? '';
                              final fromName = settlement['fromParticipantName']
                                      ?.toString() ??
                                  'Không xác định';
                              final toName =
                                  settlement['toParticipantName']?.toString() ??
                                      'Không xác định';
                              final createdAt =
                                  settlement['createdAt']?.toString();
                              final settlementMethod =
                                  settlement['settlementMethod']?.toString();

                              Color statusColor = Colors.grey;
                              String statusText = status;
                              if (status == 'COMPLETED') {
                                statusColor = Colors.green;
                                statusText = 'Đã hoàn thành';
                              } else if (status == 'PENDING') {
                                statusColor = Colors.orange;
                                statusText = 'Đang chờ';
                              } else if (status == 'FAILED') {
                                statusColor = Colors.red;
                                statusText = 'Thất bại';
                              }

                              // Định nghĩa icon cho phương thức thanh toán
                              IconData paymentIcon = Icons.payment;
                              String paymentText = 'Không xác định';

                              if (settlementMethod != null) {
                                paymentText = settlementMethod;
                                switch (settlementMethod.toUpperCase()) {
                                  case 'CASH':
                                    paymentIcon = Icons.money;
                                    paymentText = 'Tiền mặt';
                                    break;
                                  case 'BANK_TRANSFER':
                                    paymentIcon = Icons.account_balance;
                                    paymentText = 'Chuyển khoản';
                                    break;
                                  case 'CREDIT_CARD':
                                    paymentIcon = Icons.credit_card;
                                    paymentText = 'Thẻ tín dụng';
                                    break;
                                  case 'DEBIT_CARD':
                                    paymentIcon = Icons.credit_card;
                                    paymentText = 'Thẻ ghi nợ';
                                    break;
                                  case 'E_WALLET':
                                    paymentIcon = Icons.wallet;
                                    paymentText = 'Ví điện tử';
                                    break;
                                  case 'PAYPAL':
                                    paymentIcon = Icons.payment;
                                    paymentText = 'PayPal';
                                    break;
                                  default:
                                    paymentIcon = Icons.payment;
                                    paymentText = settlementMethod;
                                }
                              }

                              String dateText = 'Không xác định';
                              if (createdAt != null) {
                                try {
                                  final date = DateTime.parse(createdAt);
                                  dateText =
                                      '${date.day}/${date.month}/${date.year}';
                                } catch (e) {
                                  dateText = 'Không xác định';
                                }
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        statusColor.withOpacity(0.2),
                                    child: Icon(
                                      status == 'COMPLETED'
                                          ? Icons.check_circle
                                          : status == 'PENDING'
                                              ? Icons.schedule
                                              : Icons.error,
                                      color: statusColor,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    '$fromName → $toName',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today,
                                              size: 14,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(dateText),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(paymentIcon,
                                              size: 14,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(paymentText),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            status == 'COMPLETED'
                                                ? Icons.check_circle_outline
                                                : status == 'PENDING'
                                                    ? Icons.schedule
                                                    : Icons.error_outline,
                                            size: 14,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    currencyFormat.format(amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExpenseDetail(BuildContext context, List<dynamic> expenses) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        String selectedFilter = 'Tất cả';
        String selectedCategory = 'Tất cả';
        String selectedPayer = 'Tất cả';
        final filters = [
          'Tất cả',
          'Hôm nay',
          'Tuần này',
          'Tháng này',
          'Năm nay',
          'Tuỳ chọn'
        ];
        DateTime? startDate;
        DateTime? endDate;
        List filteredExpenses = expenses;
        double filteredTotal = 0;

        // Lấy danh sách categories và payers từ expenses
        final categories = <String>{'Tất cả'};
        final payers = <String>{'Tất cả'};
        for (final expense in expenses) {
          if (expense is Map<String, dynamic>) {
            final categoryName = expense['category']?['name']?.toString();
            if (categoryName != null) categories.add(categoryName);

            final payerName = expense['payer']?['name']?.toString();
            if (payerName != null) payers.add(payerName);
          }
        }

        void applyFilter() {
          DateTime now = DateTime.now();
          filteredExpenses = expenses;

          // Lọc theo người thanh toán
          if (selectedPayer != 'Tất cả') {
            filteredExpenses = filteredExpenses
                .where((e) =>
                    e is Map<String, dynamic> &&
                    e['payer']?['name']?.toString() == selectedPayer)
                .toList();
          }

          // Lọc theo danh mục
          if (selectedCategory != 'Tất cả') {
            filteredExpenses = filteredExpenses
                .where((e) =>
                    e is Map<String, dynamic> &&
                    e['category']?['name']?.toString() == selectedCategory)
                .toList();
          }

          // Lọc theo thời gian
          if (selectedFilter == 'Hôm nay') {
            filteredExpenses = filteredExpenses
                .where((e) =>
                    e is Map<String, dynamic> &&
                    e['expenseDate'] ==
                        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}')
                .toList();
          } else if (selectedFilter == 'Tuần này') {
            DateTime monday = now.subtract(Duration(days: now.weekday - 1));
            filteredExpenses = filteredExpenses.where((e) {
              if (e is! Map<String, dynamic> || e['expenseDate'] == null)
                return false;
              DateTime d = DateTime.parse(e['expenseDate']);
              return d.isAfter(monday.subtract(const Duration(days: 1))) &&
                  d.isBefore(now.add(const Duration(days: 1)));
            }).toList();
          } else if (selectedFilter == 'Tháng này') {
            filteredExpenses = filteredExpenses.where((e) {
              if (e is! Map<String, dynamic> || e['expenseDate'] == null)
                return false;
              DateTime d = DateTime.parse(e['expenseDate']);
              return d.year == now.year && d.month == now.month;
            }).toList();
          } else if (selectedFilter == 'Năm nay') {
            filteredExpenses = filteredExpenses.where((e) {
              if (e is! Map<String, dynamic> || e['expenseDate'] == null)
                return false;
              DateTime d = DateTime.parse(e['expenseDate']);
              return d.year == now.year;
            }).toList();
          } else if (selectedFilter == 'Tuỳ chọn' &&
              startDate != null &&
              endDate != null) {
            filteredExpenses = filteredExpenses.where((e) {
              if (e is! Map<String, dynamic> || e['expenseDate'] == null)
                return false;
              DateTime d = DateTime.parse(e['expenseDate']);
              return !d.isBefore(startDate!) && !d.isAfter(endDate!);
            }).toList();
          }

          filteredTotal = filteredExpenses.fold(
              0.0,
              (a, b) =>
                  a +
                  ((b is Map<String, dynamic> ? b['amount'] as num? : null)
                          ?.toDouble() ??
                      0));
        }

        applyFilter();

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.paid,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Chi tiết chi tiêu nhóm',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lọc theo thời gian
                Row(
                  children: [
                    const Text('Thời gian: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedFilter,
                        isExpanded: true,
                        items: filters
                            .map((f) =>
                                DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedFilter = value;
                              applyFilter();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                if (selectedFilter == 'Tuỳ chọn') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                startDate = picked;
                                applyFilter();
                              });
                            }
                          },
                          child: Text(startDate == null
                              ? 'Chọn từ ngày'
                              : '${startDate!.day}/${startDate!.month}/${startDate!.year}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: startDate ?? DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                endDate = picked;
                                applyFilter();
                              });
                            }
                          },
                          child: Text(endDate == null
                              ? 'Đến ngày'
                              : '${endDate!.day}/${endDate!.month}/${endDate!.year}'),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Lọc theo danh mục
                Row(
                  children: [
                    const Text('Danh mục: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        items: categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedCategory = value;
                              applyFilter();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Lọc theo người thanh toán
                Row(
                  children: [
                    const Text('Người trả: ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedPayer,
                        isExpanded: true,
                        items: payers
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedPayer = value;
                              applyFilter();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Thống kê tổng hợp
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng chi tiêu:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          Text(
                            currencyFormat.format(filteredTotal),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Số khoản chi:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            '${filteredExpenses.length}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Danh sách chi tiêu
                SizedBox(
                  height: 300,
                  child: filteredExpenses.isEmpty
                      ? const Center(child: Text('Không có khoản chi nào.'))
                      : Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            itemCount: filteredExpenses.length,
                            itemBuilder: (context, index) {
                              final expense = filteredExpenses[index];
                              if (expense is! Map<String, dynamic>) {
                                return const SizedBox.shrink();
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Color(int.parse(
                                          '0xFF${expense['category']?['color']?.toString().substring(1) ?? '888888'}')),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      getIconDataFromCode(expense['category']
                                                  ?['iconCode']
                                              ?.toString() ??
                                          'receipt'),
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    expense['title']?.toString() ??
                                        'Không có tiêu đề',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${expense['category']?['name']?.toString() ?? 'Không có danh mục'}'),
                                      Text(
                                          'Người trả: ${expense['payer']?['name']?.toString() ?? 'Không xác định'}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                      Text(
                                          'Ngày: ${expense['expenseDate']?.toString() ?? 'Không xác định'}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        currencyFormat.format(
                                            ((expense['convertedAmount'] ?? expense['amount'] ?? 0) as num?)
                                                    ?.toDouble() ??
                                                0),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      Text(
                                        '${expense['participantCount'] ?? 0} người',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMemberDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.group,
                    color: Colors.purple.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Thành viên nhóm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Thống kê tổng hợp
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade50, Colors.purple.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${widget.group.participants.length}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
                        ),
                      ),
                      Text(
                        'Tổng thành viên',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.purple.shade300,
                  ),
                  Column(
                    children: [
                      Text(
                        '${widget.group.participants.where((p) => p.hasLinkedUser).length}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'Đang hoạt động',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.purple.shade300,
                  ),
                  Column(
                    children: [
                      Text(
                        '${widget.group.participants.where((p) => p.role == 'ADMIN').length}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      Text(
                        'Quản trị viên',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Danh sách thành viên
            SizedBox(
              height: 400,
              child: widget.group.participants.isEmpty
                  ? const Center(child: Text('Không có thành viên nào.'))
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        itemCount: widget.group.participants.length,
                        itemBuilder: (context, index) {
                          final participant = widget.group.participants[index];
                          final userId = participant.user?.id?.toString();

                          return FutureBuilder<String?>(
                            future: _loadAvatar(userId),
                            builder: (context, snapshot) {
                              final avatar = snapshot.data;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundImage: (avatar != null &&
                                            avatar.isNotEmpty)
                                        ? NetworkImage(avatar)
                                        : const AssetImage(
                                                'assets/images/default_user_avatar.png')
                                            as ImageProvider,
                                    backgroundColor: Colors.blue[100],
                                    child: (avatar == null || avatar.isEmpty) &&
                                            participant.user == null
                                        ? Text(
                                            participant.name.isNotEmpty
                                                ? participant.name[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    participant.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: participant.role == 'ADMIN'
                                                  ? Colors.blue.shade100
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              participant.role == 'ADMIN'
                                                  ? 'Quản trị viên'
                                                  : 'Thành viên',
                                              style: TextStyle(
                                                color:
                                                    participant.role == 'ADMIN'
                                                        ? Colors.blue.shade700
                                                        : Colors.grey.shade700,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (participant.user == null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Chưa tham gia',
                                                style: TextStyle(
                                                  color: Colors.orange.shade700,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: participant.hasLinkedUser
                                      ? Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.check_circle,
                                            color: Colors.green.shade700,
                                            size: 20,
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.pending,
                                            color: Colors.orange.shade700,
                                            size: 20,
                                          ),
                                        ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettlementHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SuggestedSettlementsScreen(
            groupId: widget.group.id, userOnly: false),
      ),
    );
  }

  void _showPendingSettlements(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SuggestedSettlementsScreen(
            groupId: widget.group.id, userOnly: false),
      ),
    );
  }

  void _showPendingSettlementsDetail(
      BuildContext context, List<dynamic> allSettlements) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        // Lọc chỉ lấy settlements đang chờ
        final pendingSettlements = allSettlements
            .where((s) =>
                s is Map<String, dynamic> &&
                s['status']?.toString() == 'PENDING')
            .toList();

        // Tính tổng tiền chờ thanh toán
        final totalPendingAmount = pendingSettlements.fold(
            0.0, (a, b) => a + ((b['amount'] as num?)?.toDouble() ?? 0));

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.pending,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Thanh toán chờ xử lý',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Thống kê tổng hợp
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade50, Colors.orange.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200, width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Số thanh toán chờ:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        Text(
                          '${pendingSettlements.length}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tổng tiền chờ:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        Text(
                          currencyFormat.format(totalPendingAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Danh sách giao dịch chờ
              SizedBox(
                height: 400,
                child: pendingSettlements.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 64, color: Colors.green[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'Tuyệt vời!',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Không có thanh toán nào đang chờ xử lý',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          itemCount: pendingSettlements.length,
                          itemBuilder: (context, index) {
                            final settlement = pendingSettlements[index];
                            if (settlement is! Map<String, dynamic>) {
                              return const SizedBox.shrink();
                            }

                            final amount =
                                (settlement['amount'] as num?)?.toDouble() ?? 0;
                            final fromName =
                                settlement['fromParticipantName']?.toString() ??
                                    'Không xác định';
                            final toName =
                                settlement['toParticipantName']?.toString() ??
                                    'Không xác định';
                            final createdAt =
                                settlement['createdAt']?.toString();
                            final description =
                                settlement['description']?.toString() ?? '';

                            String dateText = 'Không xác định';
                            String timeText = '';
                            if (createdAt != null) {
                              try {
                                final date = DateTime.parse(createdAt);
                                dateText =
                                    '${date.day}/${date.month}/${date.year}';
                                timeText =
                                    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                              } catch (e) {
                                dateText = 'Không xác định';
                              }
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header với trạng thái
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.schedule,
                                            color: Colors.orange.shade700,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Đang chờ xử lý',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          currencyFormat.format(amount),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Thông tin giao dịch
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$fromName → $toName',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // Mô tả
                                    if (description.isNotEmpty) ...[
                                      Text(
                                        description,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Thời gian
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today,
                                            size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$dateText ${timeText.isNotEmpty ? '• $timeText' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),

              // Footer actions
              if (pendingSettlements.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SuggestedSettlementsScreen(
                                groupId: widget.group.id,
                                userOnly: false,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Xem gợi ý thanh toán'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      {Color? bg, bool isFullWidth = false, VoidCallback? onTap}) {
    final card = GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        margin: const EdgeInsets.only(bottom: 0),
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
}
