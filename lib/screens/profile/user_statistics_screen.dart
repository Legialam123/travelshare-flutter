import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../services/expense_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/category_service.dart';
import '../../models/category.dart';
import '../../services/group_service.dart';
import '../../models/group.dart';
import '../../services/settlement_service.dart';
import '../../utils/icon_utils.dart';
import '../../utils/currency_formatter.dart';
import '../../models/expense.dart'; // For UserExpenseSummary

class UserStatisticsScreen extends StatefulWidget {
  const UserStatisticsScreen({Key? key}) : super(key: key);

  @override
  State<UserStatisticsScreen> createState() => _UserStatisticsScreenState();
}

class _UserStatisticsScreenState extends State<UserStatisticsScreen> {
  // 🎯 Simplified state management
  UserExpenseSummary? _summary;
  List<Category> _categories = [];
  List<Group> _userGroups = [];
  List<dynamic> _userSettlements = [];
  List<dynamic> _userBalances = [];

  // 🎯 Currency selector - simplified
  String _selectedCurrency = 'VND';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  /// Load all data in parallel for better performance
  Future<void> _loadAllData() async {
      setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) throw Exception('User not found');

      // 🎯 Load all data in parallel
      final results = await Future.wait([
        ExpenseService.fetchUserExpenseSummary(userId: user.id!),
        CategoryService.fetchExpenseCategories(),
        GroupService.fetchGroups(),
        SettlementService.fetchUserSettlements(user.id!),
        SettlementService.fetchUserBalancesByGroup(user.id!),
      ]);

      if (mounted) {
      setState(() {
          _summary = results[0] as UserExpenseSummary?;
          _categories = results[1] as List<Category>;
          _userGroups = results[2] as List<Group>;
          _userSettlements = results[3] as List<dynamic>;
          _userBalances = results[4] as List<dynamic>;

          // Auto-select primary currency if available
          if (_summary != null && _summary!.primaryCurrency != null) {
            _selectedCurrency = _summary!.primaryCurrency!;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Get available currencies from summary
  List<String> get _availableCurrencies {
    return _summary?.usedCurrencies ?? ['VND'];
  }

  /// Get currency flag emoji for display
  String _getCurrencyFlag(String currencyCode) {
    const currencyFlags = {
      'VND': '🇻🇳',
      'USD': '🇺🇸',
      'EUR': '🇪🇺',
      'GBP': '🇬🇧',
      'JPY': '🇯🇵',
      'KRW': '🇰🇷',
      'CNY': '🇨🇳',
      'THB': '🇹🇭',
      'SGD': '🇸🇬',
      'AUD': '🇦🇺',
      'CAD': '🇨🇦',
      'CHF': '🇨🇭',
      'SEK': '🇸🇪',
      'NOK': '🇳🇴',
      'DKK': '🇩🇰',
      'PLN': '🇵🇱',
      'MYR': '🇲🇾',
      'IDR': '🇮🇩',
      'PHP': '🇵🇭',
    };
    return currencyFlags[currencyCode] ?? '💰';
  }

  /// Filter expenses by selected currency
  List<Expense> get _filteredExpenses {
    if (_summary == null) return [];
    return _summary!.expenses
        .where((expense) => expense.originalCurrency.code == _selectedCurrency)
        .toList();
  }

  /// Get total amount for selected currency
  double get _selectedCurrencyTotal {
    return _summary?.totalsByOriginalCurrency[_selectedCurrency] ?? 0.0;
  }

  /// Get balance total for selected currency
  double get _selectedCurrencyBalance {
    final filteredBalances = _getFilteredBalances();
    return filteredBalances.fold(
        0.0,
        (sum, balance) =>
            sum + ((balance['balance'] as num?)?.toDouble() ?? 0.0));
  }

  /// Calculate category amounts for pie chart
  Map<int, double> get _categoryAmounts {
    final Map<int, double> categoryAmountMap = {};

    // Initialize all categories with 0
    for (final cat in _categories) {
      categoryAmountMap[cat.id] = 0;
    }

    // Sum amounts by category for selected currency
    for (final expense in _filteredExpenses) {
      final catId = expense.category?.id;
      if (catId != null) {
        categoryAmountMap[catId] =
            (categoryAmountMap[catId] ?? 0) + expense.originalAmount;
      }
    }

    return categoryAmountMap;
  }

  /// Generate pie chart data
  List<Map<String, dynamic>> get _pieChartData {
    final categoryAmounts = _categoryAmounts;
    final totalForPie = categoryAmounts.values.fold(0.0, (a, b) => a + b);

    if (totalForPie <= 0) return [];

    final List<Map<String, dynamic>> pieData = [];
    const colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.deepOrange,
      Colors.lime,
    ];

    int colorIndex = 0;
    for (final cat in _categories) {
      final amount = categoryAmounts[cat.id] ?? 0;
      if (amount > 0) {
        final percent = (amount / totalForPie) * 100;
        // Only show categories with >= 1%
        if (percent >= 1.0) {
          pieData.add({
            'label': cat.name,
            'value': amount,
            'percent': percent,
            'color': colors[colorIndex % colors.length],
            'category': cat,
          });
          colorIndex++;
        }
      }
    }

    // Sort by value descending
    pieData
        .sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    return pieData;
  }

  /// Filter balances by selected currency
  List<dynamic> _getFilteredBalances() {
    return _userBalances
        .where((balance) =>
            balance['currencyCode']?.toString() == _selectedCurrency ||
            balance['currencyCode'] == null) // Include null currency as VND
        .toList();
  }

  /// Filter settlements by selected currency
  List<dynamic> _getFilteredSettlements() {
    if (_selectedCurrency == null) return _userSettlements;

    return _userSettlements
        .where((settlement) =>
            settlement['currencyCode']?.toString() == _selectedCurrency ||
            settlement['currencyCode'] == null) // Include null currency as VND
        .toList();
  }

  /// Filter groups by selected currency
  List<Group> get _filteredGroups {
    return _userGroups
        .where((group) => group.defaultCurrency == _selectedCurrency)
        .toList();
  }

  /// Format multi-currency display for totals (simplified)
  String _formatMultiCurrencyDisplay(Map<String, double> currencyTotals) {
    if (currencyTotals.isEmpty) return '0';

    final sortedEntries = currencyTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedEntries.length == 1) {
      final entry = sortedEntries.first;
      return CurrencyFormatter.formatMoney(entry.value, entry.key);
    }

    final primaryEntry = sortedEntries.first;
    final primaryText =
        CurrencyFormatter.formatMoney(primaryEntry.value, primaryEntry.key);

    if (sortedEntries.length == 2) {
      final secondEntry = sortedEntries[1];
      final secondText =
          CurrencyFormatter.formatMoney(secondEntry.value, secondEntry.key);
      return '$primaryText + $secondText';
    }

    return '$primaryText + ${sortedEntries.length - 1} khác';
  }

  void _showTotalExpenseDetail(BuildContext context, UserExpenseSummary summary,
      List<Expense> filteredExpenses) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => _ExpenseDetailModal(
        summary: summary,
        filteredExpenses: filteredExpenses,
        selectedCurrency: _selectedCurrency,
        categories: _categories,
        getCurrencyFlag: _getCurrencyFlag,
      ),
    );
  }

  void _showGroupListBottomSheet(BuildContext context, List<Group> groups) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => _GroupListModal(
        groups: groups,
        getCurrencyFlag: _getCurrencyFlag,
        selectedCurrency: _selectedCurrency,
      ),
    );
  }

  void _showTransactionListBottomSheet(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => _TransactionListModal(
        userSettlements: _userSettlements,
        userGroups: _userGroups,
        currentUserId: user.id!,
        formatMultiCurrencyDisplay: _formatMultiCurrencyDisplay,
      ),
    );
  }

  void _showBalanceBottomSheet(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => _BalanceModal(
        userId: user.id!,
        selectedCurrency: _selectedCurrency,
        getCurrencyFlag: _getCurrencyFlag,
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      {Color? bg,
      bool isFullWidth = false,
      VoidCallback? onTap,
      String? subtitle}) {
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
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: color.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadAllData,
                ),
              ],
            ),
          ),
        ),
        backgroundColor: const Color(0xFFFCF8FF),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                            size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                        const Text(
                          'Có lỗi xảy ra',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loadAllData,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAllData,
                    child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                          // Currency Selector
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.currency_exchange,
                                    color: Colors.blue.shade700),
                                const SizedBox(width: 12),
                                const Text(
                                  'Tiền tệ:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCurrency,
                                      isExpanded: true,
                                      items:
                                          _availableCurrencies.map((currency) {
                                        return DropdownMenuItem(
                                          value: currency,
                                          child: Row(
                                            children: [
                                              Text(
                                                _getCurrencyFlag(currency),
                                                style: const TextStyle(
                                                    fontSize: 18),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                currency,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            _selectedCurrency = newValue;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Main Statistics Grid
                    Row(
                      children: [
                        _statCard(
                            'Tổng chi tiêu',
                            CurrencyFormatter.formatMoney(
                                    _selectedCurrencyTotal, _selectedCurrency),
                            Icons.paid,
                                Colors.blue,
                            onTap: () => _showTotalExpenseDetail(
                                    context, _summary!, _filteredExpenses),
                                subtitle: 'Nhấn để xem chi tiết',
                              ),
                        const SizedBox(width: 16),
                              _statCard(
                                'Số nhóm',
                                '${_filteredGroups.length}',
                                Icons.group,
                                Colors.purple,
                                onTap: () => _showGroupListBottomSheet(
                                    context, _filteredGroups),
                                subtitle: 'Theo tiền tệ đã chọn',
                              ),
                            ],
                          ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        _statCard(
                            'Lịch sử thanh toán',
                                '${_userSettlements.length}',
                            Icons.receipt_long,
                                Colors.green,
                            onTap: () =>
                                    _showTransactionListBottomSheet(context),
                                subtitle: 'Nhấn để xem chi tiết',
                              ),
                        const SizedBox(width: 16),
                        _statCard(
                                'Số dư hiện tại',
                            CurrencyFormatter.formatMoney(
                                    _selectedCurrencyBalance,
                                    _selectedCurrency),
                            Icons.account_balance_wallet,
                                Colors.amber,
                                onTap: () => _showBalanceBottomSheet(context),
                                subtitle: 'Nhấn để xem chi tiết',
                              ),
                            ],
                          ),

                    const SizedBox(height: 28),

                          // Expense Category Breakdown
                    Container(
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
                            child: _pieChartData.isEmpty
                                ? Center(
                      child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.pie_chart_outline,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Chưa có dữ liệu chi tiêu',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Hãy thêm chi tiêu để xem phân tích theo danh mục',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                        children: [
                          const SizedBox(height: 18),
                                      Center(
                            child: Text(
                                          'Phân tích chi tiêu theo danh mục',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
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
                                                  sections: _pieChartData
                                                      .map((d) =>
                                                          PieChartSectionData(
                                                            value: (d['value']
                                                                    as num)
                                                    .toDouble(),
                                                            color: d['color']
                                                                as Color,
                                                radius: 54,
                                                showTitle: true,
                                                title:
                                                    '${(d['percent'] as num).toStringAsFixed(0)}%',
                                                            titleStyle:
                                                                const TextStyle(
                                                    fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                titlePositionPercentageOffset:
                                                    0.45,
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
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                        24, 16, 0, 16),
                                    child: ListView(
                                                  children: _pieChartData
                                          .map((d) => Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                    bottom: 10),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 16,
                                                      height: 16,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: d[
                                                                            'color']
                                                                        as Color,
                                                                    shape: BoxShape
                                                                        .circle,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 8),
                                                    Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                            d['label']
                                                                as String,
                                                                        style: const TextStyle(
                                                                    fontSize:
                                                                                14,
                                                                            fontWeight:
                                                                                FontWeight.w500),
                                                                      ),
                                                                      Text(
                                                                        CurrencyFormatter.formatMoney(
                                                                            d['value'],
                                                                            _selectedCurrency),
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.grey[600]),
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
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

// 🎯 Separated modals for better code organization

class _ExpenseDetailModal extends StatefulWidget {
  final UserExpenseSummary summary;
  final List<Expense> filteredExpenses;
  final String selectedCurrency;
  final List<Category> categories;
  final String Function(String) getCurrencyFlag;

  const _ExpenseDetailModal({
    required this.summary,
    required this.filteredExpenses,
    required this.selectedCurrency,
    required this.categories,
    required this.getCurrencyFlag,
  });

  @override
  State<_ExpenseDetailModal> createState() => _ExpenseDetailModalState();
}

class _ExpenseDetailModalState extends State<_ExpenseDetailModal> {
        String selectedFilter = 'Tất cả';
        String selectedCategory = 'Tất cả';
  DateTime? startDate;
  DateTime? endDate;

        final filters = [
          'Tất cả',
          'Hôm nay',
          'Tuần này',
          'Tháng này',
          'Năm nay',
          'Tuỳ chọn'
        ];

  List<Expense> get filteredExpensesList {
    List<Expense> result = widget.filteredExpenses;
              DateTime now = DateTime.now();

    // Filter by category
              if (selectedCategory != 'Tất cả') {
      final cat = widget.categories.firstWhere(
                    (c) => c.name == selectedCategory,
        orElse: () =>
            Category(id: -1, name: '', description: '', type: 'EXPENSE'),
      );
                if (cat.id != -1) {
        result = result.where((e) => e.category?.id == cat.id).toList();
      }
    }

    // Filter by time
    switch (selectedFilter) {
      case 'Hôm nay':
        final today = DateTime(now.year, now.month, now.day);
        result = result
                    .where((e) =>
                e.expenseDate.year == today.year &&
                e.expenseDate.month == today.month &&
                e.expenseDate.day == today.day)
                    .toList();
        break;
      case 'Tuần này':
                DateTime monday = now.subtract(Duration(days: now.weekday - 1));
        result = result
            .where((e) =>
                e.expenseDate
                    .isAfter(monday.subtract(const Duration(days: 1))) &&
                e.expenseDate.isBefore(now.add(const Duration(days: 1))))
            .toList();
        break;
      case 'Tháng này':
        result = result
            .where((e) =>
                e.expenseDate.year == now.year &&
                e.expenseDate.month == now.month)
            .toList();
        break;
      case 'Năm nay':
        result = result.where((e) => e.expenseDate.year == now.year).toList();
        break;
      case 'Tuỳ chọn':
        if (startDate != null && endDate != null) {
          result = result
              .where((e) =>
                  !e.expenseDate.isBefore(startDate!) &&
                  !e.expenseDate.isAfter(endDate!))
              .toList();
        }
        break;
    }

    return result;
  }

  double get filteredTotal {
    return filteredExpensesList.fold(0.0, (sum, e) => sum + e.originalAmount);
  }

  @override
  Widget build(BuildContext context) {
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
          _buildHeader(),
          const SizedBox(height: 16),
          _buildFilters(),
          const SizedBox(height: 16),
          _buildSummary(),
          const SizedBox(height: 16),
          _buildExpenseList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                            'Chi tiết chi tiêu cá nhân',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    widget.getCurrencyFlag(widget.selectedCurrency),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.selectedCurrency,
                            style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
                    Row(
                      children: [
            const Text('Thời gian: ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: selectedFilter,
                          items: filters
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (value) {
                if (value != null) setState(() => selectedFilter = value);
                          },
                        ),
                      ],
                    ),
                    if (selectedFilter == 'Tuỳ chọn') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                  child: _buildDatePicker(
                      'Từ ngày', startDate, (date) => startDate = date)),
                          const SizedBox(width: 8),
                          Expanded(
                  child: _buildDatePicker(
                      'Đến ngày', endDate, (date) => endDate = date)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
            const Text('Danh mục: ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(
                                  value: 'Tất cả', child: Text('Tất cả')),
                  ...widget.categories.map((c) =>
                      DropdownMenuItem(value: c.name, child: Text(c.name))),
                            ],
                            onChanged: (value) {
                  if (value != null) setState(() => selectedCategory = value);
                            },
                          ),
                        ),
                      ],
                    ),
      ],
    );
  }

  Widget _buildDatePicker(
      String label, DateTime? date, Function(DateTime) onDateSelected) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => onDateSelected(picked));
        }
      },
      child:
          Text(date == null ? label : '${date.day}/${date.month}/${date.year}'),
    );
  }

  Widget _buildSummary() {
    return Container(
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
                                CurrencyFormatter.formatMoney(
                    filteredTotal, widget.selectedCurrency),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Số khoản chi:',
                style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                              ),
                              Text(
                '${filteredExpensesList.length}',
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
    );
  }

  Widget _buildExpenseList() {
    return SizedBox(
                      height: 200,
      child: filteredExpensesList.isEmpty
                          ? const Center(child: Text('Không có khoản chi nào.'))
                          : Scrollbar(
                              thumbVisibility: true,
                              child: ListView.builder(
                itemCount: filteredExpensesList.length,
                                itemBuilder: (context, index) {
                  final e = filteredExpensesList[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Color(int.parse(
                              '0xFF${e.category?.color?.substring(1) ?? '888888'}')),
                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                          getIconDataFromCode(
                              e.category?.iconCode?.toString() ?? 'receipt'),
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                        e.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                          Text('${e.category?.name ?? 'Không có danh mục'}'),
                                          Text(
                            'Ngày: ${e.formattedDate}',
                                              style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                                        ],
                                      ),
                                      trailing: Text(
                                        CurrencyFormatter.formatMoney(
                            e.originalAmount, e.originalCurrency.code),
                                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      isThreeLine: true,
                                    ),
                                  );
                                },
              ),
            ),
    );
  }
}

class _GroupListModal extends StatelessWidget {
  final List<Group> groups;
  final String Function(String) getCurrencyFlag;
  final String selectedCurrency;

  const _GroupListModal({
    required this.groups,
    required this.getCurrencyFlag,
    required this.selectedCurrency,
  });

  @override
  Widget build(BuildContext context) {
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nhóm sử dụng ${getCurrencyFlag(selectedCurrency)} $selectedCurrency',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tổng cộng: ${groups.length} nhóm',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.purple.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (groups.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'Không có nhóm nào',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bạn chưa tham gia nhóm nào sử dụng tiền tệ ${getCurrencyFlag(selectedCurrency)} $selectedCurrency',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 320,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final g = groups[index];
                    final currentUser =
                        Provider.of<AuthProvider>(context, listen: false)
                            .currentUser;
                    final userParticipant = g.participants.firstWhere(
                      (p) => p.user?.id == currentUser?.id,
                      orElse: () => g.participants.first,
                    );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: CircleAvatar(
                          backgroundImage: const AssetImage(
                              'assets/images/default_group_avatar.png'),
                              backgroundColor: Colors.grey[200],
                            ),
                            title: Text(g.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Vai trò: ${userParticipant.role}'),
                                Text('Thành viên: ${g.participants.length}'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.purple.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    getCurrencyFlag(g.defaultCurrency),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    g.defaultCurrency,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple.shade700),
                                  ),
                                ],
                              ),
                            ),
                                  Text(
                                      'Ngày tạo: ${g.createdAt.day}/${g.createdAt.month}/${g.createdAt.year}',
                              style: const TextStyle(fontSize: 12),
                            ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}

class _TransactionListModal extends StatefulWidget {
  final List<dynamic> userSettlements;
  final List<Group> userGroups;
  final String currentUserId;
  final String Function(Map<String, double>) formatMultiCurrencyDisplay;

  const _TransactionListModal({
    required this.userSettlements,
    required this.userGroups,
    required this.currentUserId,
    required this.formatMultiCurrencyDisplay,
  });

  @override
  State<_TransactionListModal> createState() => _TransactionListModalState();
}

class _TransactionListModalState extends State<_TransactionListModal> {
        String selectedFilter = 'Tất cả';
        String selectedStatus = 'Tất cả';
  DateTime? startDate;
  DateTime? endDate;

        final filters = [
          'Tất cả',
          'Hôm nay',
          'Tuần này',
          'Tháng này',
          'Năm nay',
          'Tuỳ chọn'
        ];
  final statusFilters = ['Tất cả', 'Đã hoàn thành', 'Đang chờ', 'Thất bại'];

  Set<int> get myParticipantIds {
    final Set<int> ids = <int>{};
    for (final g in widget.userGroups) {
      for (final p in g.participants) {
        if (p.user?.id == widget.currentUserId) {
          ids.add(p.id);
        }
      }
    }
    return ids;
  }

  List<dynamic> get filteredSettlements {
    List<dynamic> result = widget.userSettlements;
          DateTime now = DateTime.now();

    // Filter by status
          if (selectedStatus != 'Tất cả') {
      result = result.where((s) {
              final status = s['status'] ?? '';
        switch (selectedStatus) {
          case 'Đã hoàn thành':
                return status == 'COMPLETED';
          case 'Đang chờ':
            return status == 'PENDING';
          case 'Thất bại':
            return status == 'FAILED';
          default:
              return true;
        }
            }).toList();
          }

    // Filter by time
    switch (selectedFilter) {
      case 'Hôm nay':
        result = result
                .where((s) =>
                    s['createdAt'] != null &&
                    DateTime.parse(s['createdAt']).day == now.day &&
                    DateTime.parse(s['createdAt']).month == now.month &&
                    DateTime.parse(s['createdAt']).year == now.year)
                .toList();
        break;
      case 'Tuần này':
            DateTime monday = now.subtract(Duration(days: now.weekday - 1));
        result = result.where((s) {
              DateTime d = DateTime.parse(s['createdAt']);
              return d.isAfter(monday.subtract(const Duration(days: 1))) &&
                  d.isBefore(now.add(const Duration(days: 1)));
            }).toList();
        break;
      case 'Tháng này':
        result = result.where((s) {
              DateTime d = DateTime.parse(s['createdAt']);
              return d.year == now.year && d.month == now.month;
            }).toList();
        break;
      case 'Năm nay':
        result = result.where((s) {
              DateTime d = DateTime.parse(s['createdAt']);
              return d.year == now.year;
            }).toList();
        break;
      case 'Tuỳ chọn':
        if (startDate != null && endDate != null) {
          result = result.where((s) {
              DateTime d = DateTime.parse(s['createdAt']);
            return !d.isBefore(startDate!) && !d.isAfter(endDate!);
            }).toList();
          }
        break;
    }

    return result;
  }

  Map<String, double> get totalPaidByCurrency {
    final Map<String, double> totals = {};
    final paidSettlements = filteredSettlements.where((s) =>
                  myParticipantIds.contains(s['fromParticipantId']) &&
        s['status'] == 'COMPLETED');

    for (final s in paidSettlements) {
      final amount = (s['amount'] as num).toDouble();
      final currency = s['currencyCode']?.toString() ?? 'VND';
      totals[currency] = (totals[currency] ?? 0.0) + amount;
    }

    return totals;
  }

  Map<String, double> get totalReceivedByCurrency {
    final Map<String, double> totals = {};
    final receivedSettlements = filteredSettlements.where((s) =>
                  myParticipantIds.contains(s['toParticipantId']) &&
        s['status'] == 'COMPLETED');

    for (final s in receivedSettlements) {
      final amount = (s['amount'] as num).toDouble();
      final currency = s['currencyCode']?.toString() ?? 'VND';
      totals[currency] = (totals[currency] ?? 0.0) + amount;
    }

    return totals;
  }

  @override
  Widget build(BuildContext context) {
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
          _buildHeader(),
          const SizedBox(height: 16),
          _buildFilters(),
          const SizedBox(height: 16),
          _buildSummary(),
          const SizedBox(height: 16),
          _buildTransactionList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
                      'Lịch sử thanh toán cá nhân',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
              Row(
                children: [
            const Text('Thời gian: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: selectedFilter,
                    items: filters
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) {
                if (value != null) setState(() => selectedFilter = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
            const Text('Trạng thái: ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: selectedStatus,
                    items: statusFilters
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (value) {
                if (value != null) setState(() => selectedStatus = value);
                    },
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
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
                          'Đã thanh toán:',
                style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                        ),
                        Text(
                widget.formatMultiCurrencyDisplay(totalPaidByCurrency),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đã nhận:',
                style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                        ),
                        Text(
                widget.formatMultiCurrencyDisplay(totalReceivedByCurrency),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _buildTransactionList() {
    return SizedBox(
                height: 240,
                child: filteredSettlements.isEmpty
                    ? const Center(child: Text('Không có thanh toán nào.'))
                    : Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          itemCount: filteredSettlements.length,
                          itemBuilder: (context, index) {
                            final s = filteredSettlements[index];
                  Color statusColor = Colors.grey;
                  switch (s['status']) {
                    case 'COMPLETED':
                      statusColor = Colors.green;
                      break;
                    case 'FAILED':
                      statusColor = Colors.red;
                      break;
                    case 'PENDING':
                      statusColor = Colors.orange;
                      break;
                  }

                            return ListTile(
                              title: Text(
                      'Số tiền: ${CurrencyFormatter.formatMoney((s['amount'] as num).toDouble(), s['currencyCode']?.toString() ?? 'VND')}',
                    ),
                              subtitle: Text(
                                  '${s['fromParticipantName']} → ${s['toParticipantName']}'),
                    trailing: Text(
                      s['status'] ?? '',
                                  style: TextStyle(
                          fontWeight: FontWeight.bold, color: statusColor),
                    ),
                            );
                          },
                        ),
            ),
    );
  }
}

class _BalanceModal extends StatelessWidget {
  final String userId;
  final String selectedCurrency;
  final String Function(String) getCurrencyFlag;

  const _BalanceModal({
    required this.userId,
    required this.selectedCurrency,
    required this.getCurrencyFlag,
  });

  @override
  Widget build(BuildContext context) {
        return FutureBuilder<List<dynamic>>(
      future: SettlementService.fetchUserBalancesByGroup(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final balances = snapshot.data ?? [];
        final filteredBalances = balances
            .where((balance) =>
                (balance['currencyCode']?.toString() ?? 'VND') ==
                selectedCurrency)
            .toList();

        final selectedCurrencyBalance = filteredBalances.fold(
            0.0,
            (sum, balance) =>
                sum + ((balance['balance'] as num?)?.toDouble() ?? 0.0));

        final totalBalanceText = CurrencyFormatter.formatMoney(
            selectedCurrencyBalance, selectedCurrency);

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
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSummary(totalBalanceText),
              const SizedBox(height: 16),
              _buildBalanceList(filteredBalances),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: Colors.amber.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Số dư với các nhóm',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    ],
    );
  }

  Widget _buildSummary(String totalBalanceText) {
    return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade50, Colors.amber.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tổng số dư:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        Text(
            totalBalanceText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
            textAlign: TextAlign.right,
                        ),
                      ],
                    ),
    );
  }

  Widget _buildBalanceList(List<dynamic> filteredBalances) {
    return SizedBox(
                    height: 300,
      child: filteredBalances.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                const Text(
                                  'Không có số dư',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                  Text(
                    'Bạn chưa có số dư với tiền tệ ${getCurrencyFlag(selectedCurrency)} $selectedCurrency',
                    style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            child: ListView.builder(
                itemCount: filteredBalances.length,
                              itemBuilder: (context, index) {
                  final balance = filteredBalances[index];
                  final amount = (balance['balance'] as num?)?.toDouble() ?? 0;
                                final groupName =
                      balance['groupName']?.toString() ?? 'Nhóm không xác định';
                  final currencyCode =
                      balance['currencyCode']?.toString() ?? 'VND';
                                final isDebt = amount < 0;
                                final displayAmount = amount.abs();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.group,
                                            color: Colors.amber.shade700,
                                            size: 24,
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
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                isDebt
                                                    ? 'Bạn đang nợ nhóm'
                                                    : amount > 0
                                                        ? 'Nhóm đang nợ bạn'
                                                        : 'Đã thanh toán đều',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.amber.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                '${isDebt ? '-' : amount > 0 ? '+' : ''}${CurrencyFormatter.formatMoney(displayAmount, currencyCode)}',
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
                                            const SizedBox(height: 2),
                                            Text(
                                currencyCode,
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
    );
  }
}
