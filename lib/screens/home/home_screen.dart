import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../group/create_group_screen.dart';
import '../group/group_detail_screen.dart';
import '../../models/group.dart';
import '../../models/category.dart';
import '../../services/group_service.dart';
import '../../services/auth_service.dart';
import '../../services/category_service.dart';
import '../group/join_group_screen.dart';
import '../../models/user.dart';
import '../../utils/color_utils.dart';
import '../../utils/icon_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late Future<Map<Category, List<Group>>> _groupsByCategoryFuture;
  User? _currentUser;
  Category? _selectedCategory;
  bool _isLoading = false;
  List<Group> _allGroups = [];

  // 🎯 New: Category expansion state management
  Map<int, bool> _categoryExpansionState = {};
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Khởi tạo giá trị mặc định để tránh lỗi LateInitializationError
    _groupsByCategoryFuture = Future.value({});

    // 🎯 Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));

    _loadCurrentUser();
    _loadGroupsByCategory();
    _animationController!.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCurrentUser();
    setState(() => _currentUser = user);
  }

  void _loadGroupsByCategory() {
    setState(() => _isLoading = true);

    // Đầu tiên, lấy tất cả nhóm bình thường
    GroupService.fetchGroups().then((groups) {
      // Bất kể kết quả lấy nhóm theo danh mục có lỗi hay không,
      // chúng ta vẫn hiển thị tất cả các nhóm
      setState(() {
        _allGroups = groups;
        _isLoading = false;
      });

      // Sau đó, thử lấy nhóm theo danh mục (có thể có lỗi)
      GroupService.fetchGroupsByCategory().then((groupsByCategory) {
        setState(() {
          _groupsByCategoryFuture = Future.value(groupsByCategory);
          _isLoading = false;
        });
      }).catchError((error) {
        // Nếu có lỗi, tạo một map đơn giản với một danh mục giả
        print('Lỗi khi lấy nhóm theo danh mục: $error');
        setState(() {
          _groupsByCategoryFuture = Future.value({
            Category(
                id: 0,
                name: 'Tất cả nhóm',
                description: '',
                type: 'GROUP',
                isSystemCategory: true): _allGroups,
          });
          _isLoading = false;
        });
      });
    }).catchError((error) {
      print('Lỗi khi lấy danh sách nhóm: $error');
      setState(() {
        _allGroups = [];
        _isLoading = false;
        _groupsByCategoryFuture = Future.value({});
      });
    });
  }

  bool isAdminOfGroup(Group group, String currentUserId) {
    for (final participant in group.participants) {
      if (participant.user != null &&
          participant.user?.id == currentUserId &&
          participant.role == 'ADMIN') {
        return true;
      }
    }
    return false;
  }

  void checkCurrentUserRoleInGroup(Group group, String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) {
      print('⚠️ currentUserId rỗng hoặc chưa load được!');
      return;
    }

    for (final participant in group.participants) {
      if (participant.user != null) {
        print(
            '🔍 Đang kiểm tra participant: ${participant.user?.id}, Role: ${participant.role}');
        if (participant.user?.id == currentUserId) {
          print(
              '✅ Đây là bạn! Role hiện tại của bạn trong nhóm là: ${participant.role}');
          return;
        }
      }
    }

    print('❌ Không tìm thấy currentUser trong danh sách participants.');
  }

  void _showAddGroupOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Tạo nhóm mới'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateGroupScreen(),
                  ),
                ).then((_) {
                  _loadGroupsByCategory();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Tham gia nhóm có sẵn'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinGroupScreen()),
                ).then((result) {
                  if (result == true) {
                    _loadGroupsByCategory();
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterMenu(BuildContext context, List<Category> categories) {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có danh mục nào để lọc')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Lọc theo danh mục",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    // Tùy chọn hiển thị tất cả danh mục
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: const Icon(
                          Icons.all_inclusive,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      title: const Text('Tất cả danh mục'),
                      selected: _selectedCategory == null,
                      trailing: _selectedCategory == null
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategory = null;
                        });
                        this.setState(() {});
                        Navigator.pop(context);
                      },
                    ),

                    // Các danh mục
                    ...categories.map((category) {
                      final isSelected = _selectedCategory?.id == category.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              HexColor.fromHex(category.color ?? '#000000'),
                          child: Icon(
                            getIconDataFromCode(category.iconCode),
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        title: Text(category.name),
                        selected: isSelected,
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.blue)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedCategory = category;
                          });
                          this.setState(() {});
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, Group group) {
    if (!isAdminOfGroup(group, _currentUser?.id ?? '')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không có quyền xóa nhóm này.')),
      );
      return;
    }

    int countdown = 5;
    bool confirmEnabled = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            // ✅ Đếm ngược: gọi 1 lần duy nhất khi dialog vừa mở
            Future.delayed(const Duration(seconds: 1), () {
              if (context.mounted) {
                if (countdown > 0) {
                  setState(() {
                    countdown--;
                  });
                } else if (!confirmEnabled) {
                  setState(() {
                    confirmEnabled = true;
                  });
                }
              }
            });

            return AlertDialog(
              title: const Text('Xác nhận xoá nhóm'),
              content: Text(
                confirmEnabled
                    ? 'Bạn có chắc chắn muốn xoá nhóm "${group.name}" không?'
                    : 'Vui lòng đợi ${countdown > 0 ? countdown : 0} giây để xác nhận...',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Huỷ'),
                ),
                ElevatedButton(
                  onPressed: confirmEnabled
                      ? () async {
                          Navigator.pop(ctx); // Đóng dialog trước
                          await _deleteGroup(group.id); // Gọi API xoá
                        }
                      : null,
                  child: const Text('Xác nhận xoá'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteGroup(int groupId) async {
    try {
      await AuthService.dio.delete('/group/$groupId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xoá nhóm thành công.')),
        );
        _loadGroupsByCategory();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi xoá nhóm: $e')),
      );
    }
  }

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
              'Nhóm',
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
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.filter_list,
                  color: Colors.white,
                ),
                tooltip: 'Lọc theo danh mục',
                onPressed: () {
                  if (_allGroups.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bạn chưa có nhóm nào để lọc')),
                    );
                    return;
                  }
                  _loadCategoriesForFilter();
                },
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.grey[50],
      body: _buildBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
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
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _showAddGroupOptions,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎯 New: Build body with proper animation handling
  Widget _buildBody() {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _allGroups.isEmpty
            ? _buildEmptyState()
            : FutureBuilder<Map<Category, List<Group>>>(
                future: _groupsByCategoryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Nếu có lỗi hoặc không có dữ liệu, hiển thị danh sách phẳng
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return _buildFlatGroupList();
                  }

                  // Hiển thị danh sách phân nhóm theo danh mục với collapsible headers
                  return _buildCategorizedGroupList(snapshot.data!);
                },
              );

    // Apply fade animation if available
    return _fadeAnimation != null
        ? FadeTransition(
            opacity: _fadeAnimation!,
            child: content,
          )
        : content;
  }

  // 🎯 New: Empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Bạn chưa có nhóm nào',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tạo nhóm mới hoặc tham gia nhóm có sẵn',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 New: Flat group list for fallback
  Widget _buildFlatGroupList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // 🎯 Bottom padding for navigation bar
      itemCount: _allGroups.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _buildModernGroupCard(_allGroups[index]),
        );
      },
    );
  }

  // 🎯 New: Categorized group list with collapsible headers
  Widget _buildCategorizedGroupList(
      Map<Category, List<Group>> groupsByCategory) {
    final entries = groupsByCategory.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Nếu đã chọn danh mục, chỉ hiển thị nhóm trong danh mục đó
    if (_selectedCategory != null) {
      final filteredGroups = _allGroups
          .where((group) => group.categoryId == _selectedCategory!.id)
          .toList();

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100), // 🎯 Bottom padding for navigation bar
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: HexColor.fromHex(_selectedCategory!.color ?? '#000000')
                  .withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: HexColor.fromHex(_selectedCategory!.color ?? '#000000')
                    .withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 🎯 Key change: fit content
            children: [
              _buildCategoryHeader(_selectedCategory!, filteredGroups.length,
                  _getTotalMembersInGroups(filteredGroups),
                  isFiltered: true),
              if (filteredGroups.isNotEmpty) ...[
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        HexColor.fromHex(_selectedCategory!.color ?? '#000000')
                            .withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Group cards with proper padding
                ...filteredGroups.asMap().entries.map((entry) {
                  final groupIndex = entry.key;
                  final group = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: groupIndex == filteredGroups.length - 1 ? 16 : 8,
                    ),
                    child: _buildModernGroupCard(group),
                  );
                }).toList(),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 🎯 Fit empty state content
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Không có nhóm nào trong danh mục này',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100), // 🎯 Bottom padding for navigation bar
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final category = entries[index].key;
        final groups = entries[index].value;
        final isExpanded = _categoryExpansionState[category.id] ?? true;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: HexColor.fromHex(category.color ?? '#000000')
                  .withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: HexColor.fromHex(category.color ?? '#000000')
                    .withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildCollapsibleCategoryHeader(category, groups),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: isExpanded ? null : 0,
                child: isExpanded
                    ? Column(
                        children: [
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  HexColor.fromHex(category.color ?? '#000000')
                                      .withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...groups.asMap().entries.map((entry) {
                            final groupIndex = entry.key;
                            final group = entry.value;
                            return Padding(
                              padding: EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom:
                                    groupIndex == groups.length - 1 ? 16 : 8,
                              ),
                              child: _buildModernGroupCard(group),
                            );
                          }).toList(),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🎯 New: Collapsible category header
  Widget _buildCollapsibleCategoryHeader(
      Category category, List<Group> groups) {
    final isExpanded = _categoryExpansionState[category.id] ?? true;
    final totalMembers = _getTotalMembersInGroups(groups);
    final categoryColor = HexColor.fromHex(category.color ?? '#000000');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        onTap: () {
          setState(() {
            _categoryExpansionState[category.id] = !isExpanded;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                categoryColor.withOpacity(0.08),
                categoryColor.withOpacity(0.03),
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
              // Category icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: categoryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  getIconDataFromCode(category.iconCode),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),

              // Category info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                          '${groups.length} nhóm',
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

              // Expand/Collapse icon
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: categoryColor,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 Updated: Category header for filtered view
  Widget _buildCategoryHeader(
      Category category, int groupCount, int totalMembers,
      {bool isFiltered = false}) {
    final categoryColor = HexColor.fromHex(category.color ?? '#000000');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withOpacity(0.08),
            categoryColor.withOpacity(0.03),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: categoryColor.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              getIconDataFromCode(category.iconCode),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$groupCount nhóm',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 New: Modern group card design
  Widget _buildModernGroupCard(Group group) {
    // Get category color if available
    Color categoryColor = const Color(0xFF667eea); // Default color

    return FutureBuilder<Map<Category, List<Group>>>(
      future: _groupsByCategoryFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && group.categoryId != null) {
          final category = snapshot.data!.keys.firstWhere(
            (cat) => cat.id == group.categoryId,
            orElse: () =>
                Category(id: 0, name: '', description: '', type: 'GROUP'),
          );
          if (category.id != 0) {
            categoryColor = HexColor.fromHex(category.color ?? '#667eea');
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: categoryColor.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: categoryColor.withOpacity(0.08),
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
                    builder: (context) => GroupDetailScreen(
                      groupId: group.id,
                      groupName: group.name,
                    ),
                  ),
                );
                if (result == true) {
                  _loadGroupsByCategory();
                }
              },
              onLongPress: () {
                checkCurrentUserRoleInGroup(group, _currentUser?.id);
                _confirmDeleteGroup(context, group);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Group avatar with gradient border
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            categoryColor,
                            categoryColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: categoryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: group.avatarUrl != null &&
                                group.avatarUrl!.isNotEmpty
                            ? (group.avatarUrl!.startsWith('assets/')
                                ? Image.asset(
                                    group.avatarUrl!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    group.avatarUrl!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 52,
                                        height: 52,
                                        color: categoryColor.withOpacity(0.1),
                                        child: Icon(
                                          Icons.group,
                                          color: categoryColor,
                                          size: 24,
                                        ),
                                      );
                                    },
                                  ))
                            : Container(
                                width: 52,
                                height: 52,
                                color: categoryColor.withOpacity(0.1),
                                child: Icon(
                                  Icons.group,
                                  color: categoryColor,
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Group info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${group.createdAt.day.toString().padLeft(2, '0')}-'
                                '${group.createdAt.month.toString().padLeft(2, '0')}-'
                                '${group.createdAt.year}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${group.participants.length} thành viên',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Arrow icon
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: categoryColor.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🎯 New: Helper method to calculate total members
  int _getTotalMembersInGroups(List<Group> groups) {
    return groups.fold(0, (total, group) => total + group.participants.length);
  }

  // Hàm mới để lấy danh mục cho bộ lọc
  void _loadCategoriesForFilter() {
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải dữ liệu, vui lòng đợi...')),
      );
      return;
    }

    _groupsByCategoryFuture.then((groupsByCategory) {
      if (groupsByCategory.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có danh mục nào để lọc')),
        );
        return;
      }
      final categories = groupsByCategory.keys.toList();
      _showFilterMenu(context, categories);
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải danh mục để lọc')),
      );
    });
  }

  // Hàm mới để lọc nhóm theo danh mục đã chọn
  List<Group> _getGroupsForCategory(Category category) {
    return _allGroups
        .where((group) => group.categoryId == category.id)
        .toList();
  }
}
