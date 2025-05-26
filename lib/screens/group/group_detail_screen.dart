import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../../models/group.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../services/group_detail_service.dart';
import '../../providers/auth_provider.dart';
import '../expense/add_expense_screen.dart';
import '../../models/user.dart';
import '../expense/expense_detail_screen.dart';
import '../group/group_management_screen.dart';
import '../../utils/color_utils.dart';
import 'package:flutter/services.dart';

// 🎯 Helper class for category grouping
class CategoryGroup {
  final Map<String, dynamic> category;
  final List<dynamic> expenses;
  final double totalAmount;
  bool isExpanded;

  CategoryGroup({
    required this.category,
    required this.expenses,
    required this.totalAmount,
    this.isExpanded = true,
  });
}

class GroupDetailScreen extends StatefulWidget {
  final int groupId;
  final String? groupName;

  const GroupDetailScreen({
    Key? key,
    required this.groupId,
    this.groupName,
  }) : super(key: key);

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  late Future<List<dynamic>> _expensesFuture;
  late Future<List<dynamic>> _balancesFuture;
  late Future<List<dynamic>> _photosFuture;
  late Future<User?> _userFuture;
  bool _groupWasUpdated = false;
  Group? _group;
  late Future<Group> _groupFuture;

  // 🎯 Photo management features
  String _photoFilter = 'all'; // 'all', 'mine'
  String _photoSort = 'newest'; // 'newest', 'oldest', 'uploader'
  bool _isSelectionMode = false;
  Set<int> _selectedPhotos = {};
  bool _isDownloading = false;

  // 🎯 Expense category grouping features
  bool _isGroupedByCategory = true;
  String _expenseSort = 'newest'; // 'newest', 'oldest', 'amount', 'category'
  Map<String, bool> _categoryExpansionState = {};

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  Map<String, String> _userNameCache = {}; // Cache tên người dùng

  // 🎯 Safe color parsing helper
  Color _safeColorFromHex(String? hexColor) {
    try {
      return HexColor.fromHex(hexColor ?? '#2196F3');
    } catch (e) {
      return Colors.blue; // Default color if parsing fails
    }
  }

  // 🎯 Helper methods for expense category grouping
  List<CategoryGroup> _groupExpensesByCategory(List<dynamic> expenses) {
    // Group expenses by category
    Map<String, List<dynamic>> categoryMap = {};

    for (var expense in expenses) {
      final category = expense['category'];
      final categoryId = category?['id']?.toString() ?? 'unknown';

      if (!categoryMap.containsKey(categoryId)) {
        categoryMap[categoryId] = [];
      }
      categoryMap[categoryId]!.add(expense);
    }

    // Convert to CategoryGroup objects with totals
    List<CategoryGroup> categoryGroups = [];

    categoryMap.forEach((categoryId, expenseList) {
      final category = expenseList.first['category'] ??
          {
            'id': categoryId,
            'name': 'Không xác định',
            'iconCode': 'help_outline',
            'color': '#9E9E9E'
          };

      final totalAmount = expenseList.fold<double>(0.0, (sum, expense) {
        final amount = expense['amount'];
        if (amount is num) return sum + amount.toDouble();
        if (amount is String) {
          final parsed = double.tryParse(amount);
          return sum + (parsed ?? 0.0);
        }
        return sum;
      });

      // Sort expenses within category
      expenseList.sort((a, b) {
        switch (_expenseSort) {
          case 'newest':
            final dateA =
                DateTime.tryParse(a['expenseDate'] ?? '') ?? DateTime.now();
            final dateB =
                DateTime.tryParse(b['expenseDate'] ?? '') ?? DateTime.now();
            return dateB.compareTo(dateA);
          case 'oldest':
            final dateA =
                DateTime.tryParse(a['expenseDate'] ?? '') ?? DateTime.now();
            final dateB =
                DateTime.tryParse(b['expenseDate'] ?? '') ?? DateTime.now();
            return dateA.compareTo(dateB);
          case 'amount':
            final amountA = _getExpenseAmount(a);
            final amountB = _getExpenseAmount(b);
            return amountB.compareTo(amountA);
          default:
            return 0;
        }
      });

      categoryGroups.add(CategoryGroup(
        category: category,
        expenses: expenseList,
        totalAmount: totalAmount,
        isExpanded: _categoryExpansionState[categoryId] ?? true,
      ));
    });

    // Sort category groups by total amount (highest first)
    categoryGroups.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return categoryGroups;
  }

  double _getExpenseAmount(dynamic expense) {
    final amount = expense['amount'];
    if (amount is num) return amount.toDouble();
    if (amount is String) {
      final parsed = double.tryParse(amount);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  List<dynamic> _getSortedExpenses(List<dynamic> expenses) {
    List<dynamic> sortedExpenses = List.from(expenses);

    sortedExpenses.sort((a, b) {
      switch (_expenseSort) {
        case 'newest':
          final dateA =
              DateTime.tryParse(a['expenseDate'] ?? '') ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['expenseDate'] ?? '') ?? DateTime.now();
          return dateB.compareTo(dateA);
        case 'oldest':
          final dateA =
              DateTime.tryParse(a['expenseDate'] ?? '') ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['expenseDate'] ?? '') ?? DateTime.now();
          return dateA.compareTo(dateB);
        case 'amount':
          final amountA = _getExpenseAmount(a);
          final amountB = _getExpenseAmount(b);
          return amountB.compareTo(amountA);
        case 'category':
          final categoryA = a['category']?['name'] ?? '';
          final categoryB = b['category']?['name'] ?? '';
          return categoryA.compareTo(categoryB);
        default:
          return 0;
      }
    });

    return sortedExpenses;
  }

  IconData _getCategoryIcon(String? iconCode) {
    if (iconCode == null || iconCode.isEmpty) return Icons.help_outline;

    // Map common icon codes to Flutter icons
    switch (iconCode.toLowerCase()) {
      case 'directions_car':
      case 'car':
        return Icons.directions_car;
      case 'restaurant_menu':
      case 'restaurant':
        return Icons.restaurant_menu;
      case 'hotel':
      case 'bed':
        return Icons.hotel;
      case 'shopping_bag':
      case 'shopping':
        return Icons.shopping_bag;
      case 'local_activity':
      case 'activity':
        return Icons.local_activity;
      case 'flight':
      case 'airplane':
        return Icons.flight;
      case 'train':
        return Icons.train;
      case 'local_hospital':
      case 'medical':
        return Icons.local_hospital;
      case 'school':
      case 'education':
        return Icons.school;
      case 'sports_soccer':
      case 'sports':
        return Icons.sports_soccer;
      case 'celebration':
      case 'party':
        return Icons.celebration;
      case 'work':
      case 'business':
        return Icons.work;
      case 'travel_explore':
      case 'explore':
        return Icons.travel_explore;
      case 'home':
        return Icons.home;
      default:
        return Icons.help_outline;
    }
  }

  void _showExpenseFilterSortDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hiển thị và sắp xếp chi phí',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Display mode section
            const Text('Hiển thị:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Nhóm theo danh mục'),
                    value: true,
                    groupValue: _isGroupedByCategory,
                    onChanged: (value) {
                      setState(() => _isGroupedByCategory = value!);
                      Navigator.pop(context);
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Danh sách'),
                    value: false,
                    groupValue: _isGroupedByCategory,
                    onChanged: (value) {
                      setState(() => _isGroupedByCategory = value!);
                      Navigator.pop(context);
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sort section
            const Text('Sắp xếp:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Mới nhất'),
              leading: Radio<String>(
                value: 'newest',
                groupValue: _expenseSort,
                onChanged: (value) {
                  setState(() => _expenseSort = value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Cũ nhất'),
              leading: Radio<String>(
                value: 'oldest',
                groupValue: _expenseSort,
                onChanged: (value) {
                  setState(() => _expenseSort = value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Số tiền'),
              leading: Radio<String>(
                value: 'amount',
                groupValue: _expenseSort,
                onChanged: (value) {
                  setState(() => _expenseSort = value!);
                  Navigator.pop(context);
                },
              ),
            ),
            if (!_isGroupedByCategory)
              ListTile(
                title: const Text('Danh mục'),
                leading: Radio<String>(
                  value: 'category',
                  groupValue: _expenseSort,
                  onChanged: (value) {
                    setState(() => _expenseSort = value!);
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🎯 Build grouped expenses list by category
  Widget _buildGroupedExpensesList(List<dynamic> expenses) {
    final categoryGroups = _groupExpensesByCategory(expenses);

    if (categoryGroups.isEmpty) {
      return const Center(child: Text('Chưa có chi phí nào.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          0, 12, 0, 100), // 🎯 Bottom padding for FAB, no horizontal padding
      itemCount: categoryGroups.length,
      itemBuilder: (context, index) {
        final categoryGroup = categoryGroups[index];
        final category = categoryGroup.category;
        final categoryId = category['id']?.toString() ?? 'unknown';
        final isExpanded = categoryGroup.isExpanded;

        return Container(
          margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _safeColorFromHex(category['color']).withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: _safeColorFromHex(category['color']).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // 🎯 Category header
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  onTap: () {
                    setState(() {
                      _categoryExpansionState[categoryId] = !isExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _safeColorFromHex(category['color'])
                              .withOpacity(0.08),
                          _safeColorFromHex(category['color'])
                              .withOpacity(0.03),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _safeColorFromHex(category['color']),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _safeColorFromHex(category['color'])
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getCategoryIcon(category['iconCode']),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category['name'] ?? 'Không xác định',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.group_outlined,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${categoryGroup.expenses.length} chi phí',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _currencyFormat
                                          .format(categoryGroup.totalAmount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: _safeColorFromHex(
                                            category['color']),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                    ),
                                    Text(
                                      '${((categoryGroup.totalAmount / expenses.fold<double>(0.0, (sum, e) => sum + _getExpenseAmount(e))) * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: _safeColorFromHex(category['color']),
                                  size: 28,
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

              // 🎯 Expenses in category (collapsible)
              if (isExpanded) ...[
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _safeColorFromHex(category['color']).withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...categoryGroup.expenses.asMap().entries.map<Widget>((entry) {
                  final expenseIndex = entry.key;
                  final expense = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: expenseIndex == categoryGroup.expenses.length - 1
                          ? 16
                          : 8,
                    ),
                    child: _buildExpenseListTile(expense, showCategory: false),
                  );
                }).toList(),
              ],
            ],
          ),
        );
      },
    );
  }

  // 🎯 Build flat expenses list
  Widget _buildFlatExpensesList(List<dynamic> expenses) {
    final sortedExpenses = _getSortedExpenses(expenses);

    if (sortedExpenses.isEmpty) {
      return const Center(child: Text('Chưa có chi phí nào.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          12, 12, 12, 100), // 🎯 Bottom padding for FAB
      itemCount: sortedExpenses.length,
      itemBuilder: (context, index) {
        return _buildExpenseListTile(sortedExpenses[index], showCategory: true);
      },
    );
  }

  // 🎯 Build individual expense list tile
  Widget _buildExpenseListTile(dynamic expense, {bool showCategory = true}) {
    final dateStr = expense['expenseDate'];
    final formattedDate = dateStr != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr))
        : 'Chưa rõ ngày';

    final category = expense['category'];
    // 🎯 Use category color for amount, fallback to green if no category
    final amountColor =
        category != null ? _safeColorFromHex(category['color']) : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (category != null
                  ? _safeColorFromHex(category['color'])
                  : Colors.grey)
              .withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          if (category != null)
            BoxShadow(
              color: _safeColorFromHex(category['color']).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExpenseDetailScreen(expenseId: expense['id']),
              ),
            );
            if (result == true) {
              setState(() {
                _expensesFuture =
                    GroupDetailService.fetchExpenses(widget.groupId);
                _reloadBalances();
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Category icon with gradient (only show if showCategory is true)
                if (showCategory && category != null)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          _safeColorFromHex(category['color']),
                          _safeColorFromHex(category['color']).withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _safeColorFromHex(category['color'])
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40,
                        height: 40,
                        color: _safeColorFromHex(category['color'])
                            .withOpacity(0.1),
                        child: Icon(
                          _getCategoryIcon(category['iconCode']),
                          color: _safeColorFromHex(category['color']),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                if (showCategory && category != null) const SizedBox(width: 16),

                // Expense info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Amount row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expense['title'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currencyFormat.format(expense['amount']),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: amountColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Paid by ${expense['payer']?['name'] ?? '...'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (showCategory && category != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _safeColorFromHex(category['color'])
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                category['name'] ?? '',
                                style: TextStyle(
                                  color: _safeColorFromHex(category['color']),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow icon only
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Cập nhật lại UI khi đổi tab
    });
    _expensesFuture = GroupDetailService.fetchExpenses(widget.groupId);
    _balancesFuture = GroupDetailService.fetchBalances(widget.groupId);
    _photosFuture = GroupDetailService.fetchPhotos(widget.groupId);
    _userFuture = AuthService.getCurrentUser();
    _loadGroupData();
  }

  void _loadGroupData() {
    _groupFuture = GroupService.getGroupById(widget.groupId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expensesFuture = GroupDetailService.fetchExpenses(widget.groupId);
    _selectedPhotos.clear(); // 🎯 Clear photo selections
    super.dispose();
  }

  Future<void> _loadGroupDetail() async {
    try {
      final groupDetail =
          await GroupDetailService.fetchGroupDetail(widget.groupId);
      setState(() {
        _group = Group.fromJson(groupDetail);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Không thể tải chi tiết nhóm: $e')),
      );
    }
  }

  Future<void> _reloadBalances() async {
    setState(() {
      _balancesFuture = GroupDetailService.fetchBalances(widget.groupId);
    });
  }

  Future<void> _reloadExpenses() async {
    setState(() {
      _expensesFuture = GroupDetailService.fetchExpenses(widget.groupId);
    });
  }

  Future<void> _reloadMedia() async {
    setState(() {
      _photosFuture = GroupDetailService.fetchPhotos(widget.groupId);
    });
  }

  String replaceBaseUrl(String? url) {
    if (url == null) return '';
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    return url.replaceFirst(
        RegExp(r'^https?://localhost:8080/TravelShare'), apiBaseUrl);
  }

  MediaType _getMediaType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.gif':
        return MediaType('image', 'gif');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  Future<void> _pickAndUploadMedia({
    required bool fromCamera,
    required bool isImage,
  }) async {
    setState(() => _isUploading = true);
    try {
      List<XFile> files = [];

      // Nếu chọn từ camera
      if (fromCamera) {
        final XFile? file = isImage
            ? await _picker.pickImage(source: ImageSource.camera)
            : await _picker.pickVideo(source: ImageSource.camera);
        if (file != null) files = [file];
      }
      // Nếu chọn từ thư viện ảnh hoặc video
      else {
        if (isImage) {
          files = await _picker.pickMultiImage(); // Chọn nhiều ảnh từ thư viện
        } else {
          final XFile? file =
              await _picker.pickVideo(source: ImageSource.gallery);
          if (file != null) files = [file];
        }
      }

      // Nếu có ảnh hoặc video được chọn, tiến hành tải lên
      for (final file in files) {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path,
              filename: file.name, contentType: _getMediaType(file.path)),
          if ('description' == null) 'description': 'group_media',
          'description': file.name,
        });

        // Thực hiện upload ảnh hoặc video
        await AuthService.dio
            .post('/media/group/${widget.groupId}', data: formData);
      }

      // Sau khi upload thành công, làm mới danh sách ảnh
      await _reloadMedia();
    } catch (e) {
      // Nếu xảy ra lỗi trong quá trình tải lên, hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload thất bại: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // 🎯 Photo Management Methods

  Map<String, String> _createUserNameMap(Group group) {
    final Map<String, String> userMap = {};
    for (final participant in group.participants) {
      if (participant.user?.id != null && participant.name != null) {
        userMap[participant.user!.id!] = participant.name!;
      }
    }
    return userMap;
  }

  String _getUserName(dynamic uploadedBy) {
    if (uploadedBy == null) return 'Không rõ';

    String? userId;

    // Nếu uploadedBy là Map (object có id và name)
    if (uploadedBy is Map<String, dynamic>) {
      userId = uploadedBy['id']?.toString();
    }
    // Nếu uploadedBy là String (user_id trực tiếp)
    else if (uploadedBy is String) {
      userId = uploadedBy;
    }
    // Nếu là type khác, convert thành String
    else {
      userId = uploadedBy.toString();
    }

    if (userId == null || userId.isEmpty) return 'Không rõ';

    return _userNameCache[userId] ?? 'Không rõ';
  }

  String _extractUserId(dynamic uploadedBy) {
    if (uploadedBy == null) return '';

    if (uploadedBy is Map<String, dynamic>) {
      return uploadedBy['id']?.toString() ?? '';
    } else if (uploadedBy is String) {
      return uploadedBy;
    } else {
      return uploadedBy.toString();
    }
  }

  List<dynamic> _getFilteredAndSortedPhotos(
      List<dynamic> photos, String? currentUserId, Group group) {
    _userNameCache = _createUserNameMap(group);

    List<dynamic> filteredPhotos = List.from(photos);

    // Apply filter
    if (_photoFilter == 'mine' && currentUserId != null) {
      filteredPhotos = filteredPhotos.where((photo) {
        final uploaderId = _extractUserId(photo['uploadedBy']);
        return uploaderId == currentUserId;
      }).toList();
    }

    // Apply sort
    switch (_photoSort) {
      case 'newest':
        filteredPhotos.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['uploadedAt'] ?? '') ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['uploadedAt'] ?? '') ?? DateTime.now();
          return dateB.compareTo(dateA);
        });
        break;
      case 'oldest':
        filteredPhotos.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['uploadedAt'] ?? '') ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['uploadedAt'] ?? '') ?? DateTime.now();
          return dateA.compareTo(dateB);
        });
        break;
      case 'uploader':
        filteredPhotos.sort((a, b) {
          final nameA = _getUserName(a['uploadedBy']);
          final nameB = _getUserName(b['uploadedBy']);
          return nameA.compareTo(nameB);
        });
        break;
    }

    return filteredPhotos;
  }

  bool _canDeletePhoto(dynamic photo, String? currentUserId, bool isAdmin) {
    if (isAdmin) return true; // Admin có thể xóa tất cả
    final uploaderId = _extractUserId(photo['uploadedBy']);
    return uploaderId.isNotEmpty &&
        uploaderId == currentUserId; // Chỉ được xóa ảnh của mình
  }

  Future<void> _downloadPhoto(String url, String filename,
      [BuildContext? dialogContext]) async {
    setState(() => _isDownloading = true);
    try {
      // For Android 13+ (API 33+), we don't need storage permission for saving to gallery
      // For older versions, we still need to request permission
      bool hasPermission = true;

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt < 33) {
          // For Android 12 and below, request storage permission
          final permission = await Permission.storage.request();
          hasPermission = permission.isGranted;

          if (!hasPermission) {
            // Try requesting photos permission as fallback
            final photosPermission = await Permission.photos.request();
            hasPermission = photosPermission.isGranted;
          }
        }
      }

      if (!hasPermission) {
        final contextToUse = dialogContext ?? context;
        ScaffoldMessenger.of(contextToUse).showSnackBar(
          const SnackBar(content: Text('Cần quyền truy cập để lưu ảnh')),
        );
        return;
      }

      // Download file
      final response = await Dio().get(
        replaceBaseUrl(url),
        options: Options(responseType: ResponseType.bytes),
      );

      // Save to gallery using image_gallery_saver
      final result = await ImageGallerySaver.saveImage(
        response.data,
        name: filename.replaceAll('.jpg', ''),
        quality: 100,
      );

      final contextToUse = dialogContext ?? context;
      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(contextToUse).showSnackBar(
          const SnackBar(content: Text('✅ Đã lưu ảnh vào thư viện')),
        );
      } else {
        ScaffoldMessenger.of(contextToUse).showSnackBar(
          const SnackBar(content: Text('❌ Lỗi khi lưu ảnh')),
        );
      }
    } catch (e) {
      final contextToUse = dialogContext ?? context;
      ScaffoldMessenger.of(contextToUse).showSnackBar(
        SnackBar(content: Text('❌ Lỗi tải ảnh: $e')),
      );
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  Future<void> _sharePhoto(String url) async {
    try {
      await Share.share(
        replaceBaseUrl(url),
        subject: 'Ảnh từ TravelShare',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi chia sẻ: $e')),
      );
    }
  }

  void _showPhotoInfo(dynamic photo) {
    final uploadedBy = _getUserName(photo['uploadedBy']);
    final uploadedAt = photo['uploadedAt'] != null
        ? DateFormat('dd/MM/yyyy HH:mm')
            .format(DateTime.parse(photo['uploadedAt']))
        : 'Không rõ';

    // Format file size properly
    String formatFileSize(dynamic fileSize) {
      if (fileSize == null) return 'Không rõ';

      double size;
      if (fileSize is String) {
        size = double.tryParse(fileSize) ?? 0;
      } else if (fileSize is num) {
        size = fileSize.toDouble();
      } else {
        return 'Không rõ';
      }

      if (size == 0) return 'Không rõ';

      // Convert bytes to appropriate unit
      if (size < 1024) {
        return '${size.toInt()} B';
      } else if (size < 1024 * 1024) {
        return '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    final fileSize = formatFileSize(photo['fileSize']);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin ảnh',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Người tải: $uploadedBy'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Thời gian: $uploadedAt'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.storage, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Kích thước: $fileSize'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedPhotos.clear();
      }
    });
  }

  void _selectAllPhotos(List<dynamic> photos) {
    setState(() {
      _selectedPhotos.addAll(photos.map((p) => p['id'] as int));
    });
  }

  void _deselectAllPhotos() {
    setState(() {
      _selectedPhotos.clear();
    });
  }

  Future<void> _bulkDeletePhotos() async {
    if (_selectedPhotos.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ảnh đã chọn?'),
        content: Text(
            'Bạn có chắc chắn muốn xóa ${_selectedPhotos.length} ảnh đã chọn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final photoId in _selectedPhotos) {
          await GroupDetailService.deleteMedia(photoId);
        }
        setState(() {
          _selectedPhotos.clear();
          _isSelectionMode = false;
        });
        await _reloadMedia();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã xóa ảnh thành công')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi xóa ảnh: $e')),
        );
      }
    }
  }

  Future<void> _bulkDownloadPhotos(List<dynamic> photos) async {
    if (_selectedPhotos.isEmpty) return;

    setState(() => _isDownloading = true);
    try {
      // For Android 13+ (API 33+), we don't need storage permission for saving to gallery
      // For older versions, we still need to request permission
      bool hasPermission = true;

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt < 33) {
          // For Android 12 and below, request storage permission
          final permission = await Permission.storage.request();
          hasPermission = permission.isGranted;

          if (!hasPermission) {
            // Try requesting photos permission as fallback
            final photosPermission = await Permission.photos.request();
            hasPermission = photosPermission.isGranted;
          }
        }
      }

      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần quyền truy cập để lưu ảnh')),
        );
        return;
      }

      int downloaded = 0;
      for (final photoId in _selectedPhotos) {
        final photo = photos.firstWhere((p) => p['id'] == photoId);

        try {
          // Download file
          final response = await Dio().get(
            replaceBaseUrl(photo['fileUrl']),
            options: Options(responseType: ResponseType.bytes),
          );

          // Save to gallery
          final result = await ImageGallerySaver.saveImage(
            response.data,
            name: 'image_$photoId',
            quality: 100,
          );

          if (result['isSuccess'] == true) {
            downloaded++;
          }
        } catch (e) {
          print('Error downloading photo $photoId: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Đã tải $downloaded ảnh')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi tải ảnh: $e')),
      );
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  void _showFilterSortDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lọc và sắp xếp ảnh',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Filter section
            const Text('Bộ lọc:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Tất cả ảnh'),
                    value: 'all',
                    groupValue: _photoFilter,
                    onChanged: (value) {
                      setState(() => _photoFilter = value!);
                      Navigator.pop(context);
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Ảnh của tôi'),
                    value: 'mine',
                    groupValue: _photoFilter,
                    onChanged: (value) {
                      setState(() => _photoFilter = value!);
                      Navigator.pop(context);
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sort section
            const Text('Sắp xếp:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Mới nhất'),
              leading: Radio<String>(
                value: 'newest',
                groupValue: _photoSort,
                onChanged: (value) {
                  setState(() => _photoSort = value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Cũ nhất'),
              leading: Radio<String>(
                value: 'oldest',
                groupValue: _photoSort,
                onChanged: (value) {
                  setState(() => _photoSort = value!);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Theo người tải'),
              leading: Radio<String>(
                value: 'uploader',
                groupValue: _photoSort,
                onChanged: (value) {
                  setState(() => _photoSort = value!);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pop(context, _groupWasUpdated); //Trả kết quả về HomeScreen
        }
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize:
              const Size.fromHeight(kToolbarHeight + 48), // 48 cho TabBar
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: AppBar(
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.white, // hoặc màu nền bạn muốn
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
              title: widget.groupName != null
                  ? Text(widget.groupName!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20))
                  : FutureBuilder<Group>(
                      future: _groupFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text('Chi tiết nhóm',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20));
                        } else if (snapshot.hasData) {
                          return Text(snapshot.data!.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20));
                        } else {
                          return const Text('Chi tiết nhóm',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20));
                        }
                      },
                    ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Quản lý nhóm',
                  onPressed: () async {
                    try {
                      final groupDetail =
                          await GroupDetailService.fetchGroupDetail(
                              widget.groupId);
                      final group = Group.fromJson(groupDetail);
                      final userInfo = await AuthService.getCurrentUser();
                      if (!context.mounted || userInfo == null) return;

                      final isAdmin = group.participants.any(
                        (p) => p.user?.id == userInfo.id && p.role == 'ADMIN',
                      );
                      final updated = await Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => GroupManagementScreen(
                            group: group,
                            currentUserId: userInfo.id!,
                            isAdmin: isAdmin,
                          ),
                          transitionsBuilder: (_, animation, __, child) {
                            final tween = Tween(
                                    begin: const Offset(1, 0), end: Offset.zero)
                                .chain(CurveTween(curve: Curves.easeInOut));
                            return SlideTransition(
                              position: animation.drive(tween),
                              child: child,
                            );
                          },
                        ),
                      );

                      if (updated == true) {
                        await _loadGroupDetail();
                        _groupWasUpdated = true; // ✅ Ghi nhận có thay đổi
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("❌ Không thể mở quản lý nhóm: $e")),
                      );
                    }
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.deepPurple,
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: Colors.deepPurple,
                    tabs: const [
                      Tab(text: 'Expenses'),
                      Tab(text: 'Balances'),
                      Tab(text: 'Photos'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        backgroundColor: Colors.grey[50],
        body: FutureBuilder<Group>(
          future: _groupFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            } else if (!snapshot.hasData) {
              return const Center(child: Text('Không tìm thấy thông tin nhóm'));
            }

            final group = snapshot.data!;

            return TabBarView(
              controller: _tabController,
              children: [
                // Expenses Tab
                FutureBuilder<List<dynamic>>(
                  future: _expensesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        _isUploading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Lỗi: ${snapshot.error}'));
                    }

                    final expenses = snapshot.data ?? [];
                    if (expenses.isEmpty) {
                      return const Center(child: Text('Chưa có chi phí nào.'));
                    }

                    final totalExpenses = expenses.fold<num>(
                      0,
                      (sum, e) {
                        final amount = e['amount'];
                        if (amount is num) return sum + amount;
                        if (amount is String) {
                          final parsed = double.tryParse(amount);
                          return parsed != null ? sum + parsed : sum;
                        }
                        return sum;
                      },
                    );

                    // Lấy currentUserId từ AuthProvider
                    final currentUserId =
                        Provider.of<AuthProvider>(context, listen: false)
                            .currentUser
                            ?.id;

                    final myExpenses = expenses.where((e) {
                      final payerUserId = e['payer']?['user']?['id'];
                      return payerUserId != null &&
                          payerUserId == currentUserId;
                    }).fold<num>(0, (sum, e) {
                      final amount = e['amount'];

                      if (amount is num) return sum + amount;

                      if (amount is String) {
                        final parsed = double.tryParse(amount);
                        return parsed != null ? sum + parsed : sum;
                      }
                      return sum;
                    });

                    return Column(
                      children: [
                        // 🎯 Header with stats and controls
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Stats row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(children: [
                                    const Text('Chi phí của tôi',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(_currencyFormat.format(myExpenses),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                            fontSize: 16)),
                                  ]),
                                  Column(children: [
                                    const Text('Tổng chi phí',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(_currencyFormat.format(totalExpenses),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                            fontSize: 16)),
                                  ]),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Controls row
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _showExpenseFilterSortDialog,
                                    icon: const Icon(Icons.tune, size: 18),
                                    label: Text(
                                      _isGroupedByCategory
                                          ? 'Nhóm danh mục'
                                          : 'Danh sách',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${expenses.length} chi phí',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 🎯 Expenses list - grouped or flat
                        Expanded(
                          child: _isGroupedByCategory
                              ? _buildGroupedExpensesList(expenses)
                              : _buildFlatExpensesList(expenses),
                        ),
                      ],
                    );
                  },
                ),

                // Balances Tab
                FutureBuilder<List<dynamic>>(
                  future: _balancesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Lỗi: ${snapshot.error}'));
                    }

                    final balances = snapshot.data ?? [];
                    if (balances.isEmpty) {
                      return const Center(
                          child: Text('Không có dữ liệu số dư.'));
                    }

                    return FutureBuilder<User?>(
                      future: _userFuture,
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final User? user = userSnapshot.data;
                        final currentUserId = user?.id;
                        double totalOwed = 0;
                        double totalReceivable = 0;

                        for (var b in balances) {
                          if (b['participantUserId'] == currentUserId) {
                            double value = (b['balance'] ?? 0).toDouble();
                            if (value < 0) totalOwed += value.abs();
                            if (value > 0) totalReceivable += value;
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: Card(
                                child: ListTile(
                                  title:
                                      const Text('Xem tất cả gợi ý thanh toán'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/suggested-settlements',
                                      arguments: {
                                        'groupId': widget.groupId,
                                        'userOnly': false,
                                      },
                                    ).then((_) => _reloadBalances());
                                  },
                                ),
                              ),
                            ),
                            if (totalOwed > 0 || totalReceivable > 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: Card(
                                  color: Colors.grey[50],
                                  child: ListTile(
                                    leading: Icon(
                                      totalOwed > 0
                                          ? Icons.money_off
                                          : Icons.attach_money,
                                      color: totalOwed > 0
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    title: Text(
                                      totalOwed > 0
                                          ? 'Bạn đang nợ người khác ${_currencyFormat.format(totalOwed)}'
                                          : 'Người khác đang nợ bạn ${_currencyFormat.format(totalReceivable)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/suggested-settlements',
                                        arguments: {
                                          'groupId': widget.groupId,
                                          'userOnly': true,
                                        },
                                      ).then((_) => _reloadBalances());
                                    },
                                  ),
                                ),
                              ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Text(
                                'Số dư hiện tại giữa các thành viên:',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: balances.length,
                                itemBuilder: (context, index) {
                                  final b = balances[index];
                                  final name =
                                      b['participantName'] ?? 'Người dùng';
                                  final balance = b['balance'] ?? 0.0;
                                  final currency = b['currencyCode'] ?? '';
                                  final avatarUrl = b['avatar'];
                                  final isMe =
                                      b['participantUserId'] == currentUserId;

                                  final isPositive = balance >= 0;
                                  final formattedAmount =
                                      _currencyFormat.format(balance.abs());

                                  return Card(
                                    color: isPositive
                                        ? Colors.green[50]
                                        : Colors.red[50],
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: avatarUrl != null &&
                                                avatarUrl.isNotEmpty
                                            ? NetworkImage(avatarUrl)
                                            : const AssetImage(
                                                    'assets/images/default_user_avatar.png')
                                                as ImageProvider,
                                      ),
                                      title: Text(name),
                                      subtitle: isMe
                                          ? const Text('Bạn',
                                              style: TextStyle(
                                                  fontStyle: FontStyle.italic))
                                          : const SizedBox.shrink(),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${isPositive ? '+' : '-'}$formattedAmount',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isPositive
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                // Photos Tab
                FutureBuilder<List<dynamic>>(
                  future: _photosFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        _isUploading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Lỗi: ${snapshot.error}'));
                    }

                    final allPhotos = snapshot.data ?? [];

                    return FutureBuilder<User?>(
                      future: _userFuture,
                      builder: (context, userSnapshot) {
                        final currentUser = userSnapshot.data;
                        final currentUserId = currentUser?.id;

                        // Get admin status
                        bool isAdmin = false;
                        if (group.participants.isNotEmpty &&
                            currentUserId != null) {
                          isAdmin = group.participants.any(
                            (p) =>
                                p.user?.id == currentUserId &&
                                p.role == 'ADMIN',
                          );
                        }

                        // Apply filtering and sorting
                        final filteredPhotos = _getFilteredAndSortedPhotos(
                            allPhotos, currentUserId, group);

                        if (allPhotos.isEmpty) {
                          return const Center(child: Text('Chưa có hình ảnh.'));
                        }

                        return Column(
                          children: [
                            // 🎯 Header with filter/sort and selection controls
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                border: Border(
                                    bottom:
                                        BorderSide(color: Colors.grey[300]!)),
                              ),
                              child: Row(
                                children: [
                                  // Filter/Sort button
                                  OutlinedButton.icon(
                                    onPressed: _showFilterSortDialog,
                                    icon: const Icon(Icons.tune, size: 18),
                                    label: Text(
                                      _photoFilter == 'mine'
                                          ? 'Ảnh của tôi'
                                          : 'Tất cả ảnh',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),

                                  const Spacer(),

                                  // Selection mode toggle
                                  if (!_isSelectionMode)
                                    IconButton(
                                      onPressed: _toggleSelectionMode,
                                      icon:
                                          const Icon(Icons.checklist, size: 20),
                                      tooltip: 'Chọn nhiều',
                                    )
                                  else ...[
                                    // Selection mode controls
                                    Flexible(
                                      child: TextButton(
                                        onPressed: () =>
                                            _selectAllPhotos(filteredPhotos),
                                        child: const Text('Tất cả',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                    ),
                                    Flexible(
                                      child: TextButton(
                                        onPressed: _deselectAllPhotos,
                                        child: const Text('Bỏ chọn',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _toggleSelectionMode,
                                      icon: const Icon(Icons.close, size: 20),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // 🎯 Bulk actions bar (only in selection mode)
                            if (_isSelectionMode && _selectedPhotos.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  border: Border(
                                      bottom:
                                          BorderSide(color: Colors.blue[200]!)),
                                ),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${_selectedPhotos.length} ảnh đã chọn',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_isDownloading)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    else
                                      Flexible(
                                        child: TextButton.icon(
                                          onPressed: () => _bulkDownloadPhotos(
                                              filteredPhotos),
                                          icon: const Icon(Icons.download,
                                              size: 16),
                                          label: const Text('Tải',
                                              style: TextStyle(fontSize: 11)),
                                        ),
                                      ),
                                    Flexible(
                                      child: TextButton.icon(
                                        onPressed: _bulkDeletePhotos,
                                        icon: const Icon(Icons.delete,
                                            size: 16, color: Colors.red),
                                        label: const Text('Xóa',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.red)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // 🎯 Photos Grid
                            Expanded(
                              child: filteredPhotos.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.photo_library_outlined,
                                              size: 64,
                                              color: Colors.grey[400]),
                                          const SizedBox(height: 16),
                                          Text(
                                            _photoFilter == 'mine'
                                                ? 'Bạn chưa tải ảnh nào'
                                                : 'Chưa có hình ảnh',
                                            style: TextStyle(
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    )
                                  : GridView.builder(
                                      padding: const EdgeInsets.all(12),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                      ),
                                      itemCount: filteredPhotos.length,
                                      itemBuilder: (context, index) {
                                        final photo = filteredPhotos[index];
                                        final photoId = photo['id'] as int;
                                        final isSelected =
                                            _selectedPhotos.contains(photoId);
                                        final canDelete = _canDeletePhoto(
                                            photo, currentUserId, isAdmin);
                                        final uploaderName =
                                            _getUserName(photo['uploadedBy']);

                                        return GestureDetector(
                                          onLongPress: () {
                                            if (_isSelectionMode) return;
                                            _showPhotoInfo(photo);
                                          },
                                          onTap: () {
                                            if (_isSelectionMode) {
                                              setState(() {
                                                if (isSelected) {
                                                  _selectedPhotos
                                                      .remove(photoId);
                                                } else {
                                                  _selectedPhotos.add(photoId);
                                                }
                                              });
                                              return;
                                            }

                                            // Full screen view
                                            int currentIndex = index;
                                            final controller = PageController(
                                                initialPage: currentIndex);

                                            showDialog(
                                              context: context,
                                              builder: (_) {
                                                return StatefulBuilder(
                                                  builder:
                                                      (context, setState) =>
                                                          Scaffold(
                                                    backgroundColor:
                                                        Colors.black,
                                                    body: Stack(
                                                      children: [
                                                        PageView.builder(
                                                          controller:
                                                              controller,
                                                          itemCount:
                                                              filteredPhotos
                                                                  .length,
                                                          onPageChanged: (i) {
                                                            setState(() =>
                                                                currentIndex =
                                                                    i);
                                                          },
                                                          itemBuilder:
                                                              (context, i) {
                                                            final currentPhoto =
                                                                filteredPhotos[
                                                                    i];
                                                            return Center(
                                                              child:
                                                                  Image.network(
                                                                replaceBaseUrl(
                                                                    currentPhoto[
                                                                        'fileUrl']),
                                                                fit: BoxFit
                                                                    .contain,
                                                              ),
                                                            );
                                                          },
                                                        ),

                                                        // Top overlay with info and close
                                                        Positioned(
                                                          top: 40,
                                                          left: 20,
                                                          right: 20,
                                                          child: Row(
                                                            children: [
                                                              Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    '${currentIndex + 1}/${filteredPhotos.length}',
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          16,
                                                                      fontStyle:
                                                                          FontStyle
                                                                              .italic,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'Bởi: ${_getUserName(filteredPhotos[currentIndex]['uploadedBy'])}',
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white70,
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const Spacer(),
                                                              IconButton(
                                                                icon: const Icon(
                                                                    Icons.close,
                                                                    color: Colors
                                                                        .white,
                                                                    size: 28),
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(),
                                                              ),
                                                            ],
                                                          ),
                                                        ),

                                                        // Bottom overlay with actions
                                                        Positioned(
                                                          bottom: 40,
                                                          left: 20,
                                                          right: 20,
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceEvenly,
                                                            children: [
                                                              // Download button
                                                              Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .black54,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              25),
                                                                ),
                                                                child:
                                                                    IconButton(
                                                                  onPressed: _isDownloading
                                                                      ? null
                                                                      : () => _downloadPhoto(
                                                                          filteredPhotos[currentIndex]
                                                                              [
                                                                              'fileUrl'],
                                                                          'image_${filteredPhotos[currentIndex]['id']}.jpg',
                                                                          context),
                                                                  icon: _isDownloading
                                                                      ? const SizedBox(
                                                                          width:
                                                                              20,
                                                                          height:
                                                                              20,
                                                                          child: CircularProgressIndicator(
                                                                              color: Colors.white,
                                                                              strokeWidth: 2),
                                                                        )
                                                                      : const Icon(Icons.download, color: Colors.white),
                                                                ),
                                                              ),

                                                              // Share button
                                                              Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .black54,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              25),
                                                                ),
                                                                child:
                                                                    IconButton(
                                                                  onPressed: () =>
                                                                      _sharePhoto(
                                                                          filteredPhotos[currentIndex]
                                                                              [
                                                                              'fileUrl']),
                                                                  icon: const Icon(
                                                                      Icons
                                                                          .share,
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                              ),

                                                              // Info button
                                                              Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .black54,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              25),
                                                                ),
                                                                child:
                                                                    IconButton(
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop();
                                                                    _showPhotoInfo(
                                                                        filteredPhotos[
                                                                            currentIndex]);
                                                                  },
                                                                  icon: const Icon(
                                                                      Icons
                                                                          .info_outline,
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                              ),

                                                              // Delete button (only if can delete)
                                                              if (_canDeletePhoto(
                                                                  filteredPhotos[
                                                                      currentIndex],
                                                                  currentUserId,
                                                                  isAdmin))
                                                                Container(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .red
                                                                        .withOpacity(
                                                                            0.7),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            25),
                                                                  ),
                                                                  child:
                                                                      IconButton(
                                                                    onPressed:
                                                                        () async {
                                                                      final confirmed =
                                                                          await showDialog<
                                                                              bool>(
                                                                        context:
                                                                            context,
                                                                        builder:
                                                                            (ctx) =>
                                                                                AlertDialog(
                                                                          title:
                                                                              const Text('Xoá ảnh?'),
                                                                          content:
                                                                              const Text('Bạn có chắc chắn muốn xoá ảnh này?'),
                                                                          actions: [
                                                                            TextButton(
                                                                              onPressed: () => Navigator.pop(ctx, false),
                                                                              child: const Text('Huỷ'),
                                                                            ),
                                                                            TextButton(
                                                                              onPressed: () => Navigator.pop(ctx, true),
                                                                              child: const Text('Xoá', style: TextStyle(color: Colors.red)),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      );
                                                                      if (confirmed ==
                                                                          true) {
                                                                        Navigator.of(context)
                                                                            .pop();
                                                                        await GroupDetailService.deleteMedia(filteredPhotos[currentIndex]
                                                                            [
                                                                            'id']);
                                                                        await _reloadMedia();
                                                                      }
                                                                    },
                                                                    icon: const Icon(
                                                                        Icons
                                                                            .delete,
                                                                        color: Colors
                                                                            .white),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                          child: Stack(
                                            children: [
                                              // Photo container
                                              Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: _isSelectionMode &&
                                                          isSelected
                                                      ? Border.all(
                                                          color: Colors.blue,
                                                          width: 3)
                                                      : null,
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    replaceBaseUrl(
                                                        photo['fileUrl']),
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                  ),
                                                ),
                                              ),

                                              // Selection checkbox
                                              if (_isSelectionMode)
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? Colors.blue
                                                          : Colors.white,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? Colors.blue
                                                            : Colors.grey,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(2),
                                                    child: isSelected
                                                        ? const Icon(
                                                            Icons.check,
                                                            color: Colors.white,
                                                            size: 16)
                                                        : const SizedBox(
                                                            width: 16,
                                                            height: 16),
                                                  ),
                                                ),

                                              // Uploader indicator (bottom left)
                                              if (!_isSelectionMode &&
                                                  uploaderName.isNotEmpty)
                                                Positioned(
                                                  bottom: 4,
                                                  left: 4,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black54,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          currentUserId !=
                                                                      null &&
                                                                  photo['uploadedBy']
                                                                          ?[
                                                                          'id'] ==
                                                                      currentUserId
                                                              ? Icons.person
                                                              : Icons
                                                                  .person_outline,
                                                          color: Colors.white,
                                                          size: 12,
                                                        ),
                                                        const SizedBox(
                                                            width: 2),
                                                        Text(
                                                          uploaderName.length >
                                                                  8
                                                              ? '${uploaderName.substring(0, 8)}..'
                                                              : uploaderName,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                )
              ],
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _tabController.index == 0
            ? Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22), // 🎯 More rounded
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF667eea), // Blue-purple
                      Color(0xFF764ba2), // Purple
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(22), // 🎯 Match container radius
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(22), // 🎯 Match container radius
                    onTap: () async {
                      final groupDetail =
                          await GroupDetailService.fetchGroupDetail(
                              widget.groupId);
                      final participantsJson =
                          groupDetail['participants'] as List<dynamic>? ?? [];
                      final participants = participantsJson
                          .map((p) => GroupParticipant.fromJson(p))
                          .toList();
                      final userInfo = await AuthService.getCurrentUser();
                      if (!mounted || userInfo == null || userInfo.id == null)
                        return;

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(
                            groupId: widget.groupId,
                            participants: participants,
                            currentUserId: userInfo.id!,
                          ),
                        ),
                      );

                      if (result == true) {
                        _reloadExpenses();
                        _reloadBalances();
                      }
                    },
                    child: Container(
                      width: 62, // 🎯 Updated size
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            22), // 🎯 Match container radius
                        border: Border.all(
                          color: Colors.white
                              .withOpacity(0.3), // 🎯 Slightly more visible
                          width: 1.5, // 🎯 Slightly thicker border
                        ),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 30, // 🎯 Updated icon size
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              )
            : _tabController.index == 2
                ? Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(22), // 🎯 More rounded
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF667eea), // Blue-purple
                          Color(0xFF764ba2), // Purple
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(
                          22), // 🎯 Match container radius
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                            22), // 🎯 Match container radius
                        onTap: () {
                          _pickAndUploadMedia(fromCamera: false, isImage: true);
                        },
                        child: Container(
                          width: 62, // 🎯 Updated size
                          height: 62,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                22), // 🎯 Match container radius
                            border: Border.all(
                              color: Colors.white
                                  .withOpacity(0.3), // 🎯 Slightly more visible
                              width: 1.5, // 🎯 Slightly thicker border
                            ),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_rounded,
                            size: 26, // 🎯 Updated icon size
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
      ),
    );
  }
}
