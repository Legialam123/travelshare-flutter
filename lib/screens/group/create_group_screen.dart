import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

import '../../models/currency.dart';
import '../../models/category.dart';
import '../../services/currency_service.dart';
import '../../services/category_service.dart';
import '../../services/auth_service.dart';
import '../../services/group_service.dart';
import '../../utils/color_utils.dart';
import '../../utils/icon_utils.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetLimitController = TextEditingController();
  final _participantNameController = TextEditingController();

  Future<List<Currency>>? _currenciesFuture;
  Future<List<Category>>? _categoriesFuture;
  XFile? _pickedImage;
  final _picker = ImagePicker();
  final List<Map<String, String>> _participants = [];
  String _participantRole = 'MEMBER';
  String? _creatorFullName;
  bool _creatorAdded = false;
  bool _isSubmitting = false;
  List<Currency> _allCurrencies = [];
  List<Category> _allCategories = [];
  Currency? _selectedCurrency;
  Category? _selectedCategory;
  bool _showAllCurrencies = false;

  @override
  void initState() {
    super.initState();
    _currenciesFuture = CurrencyService.fetchCurrencies().then((data) {
      _allCurrencies = data;
      _selectedCurrency = _allCurrencies.firstWhere(
        (c) => c.code == 'VND',
        orElse: () => _allCurrencies.first,
      );
      return data;
    });

    _categoriesFuture = CategoryService.fetchGroupCategories().then((data) {
      _allCategories = data;
      if (_allCategories.isNotEmpty) {
        _selectedCategory = _allCategories.first;
      }
      return data;
    });

    _initCreator();
  }

  Future<void> _initCreator() async {
    final fullName = await AuthService.getCurrentFullName();
    if (fullName != null) {
      setState(() {
        _creatorFullName = fullName;
        _participants.insert(0, {
          'name': fullName,
          'role': 'ADMIN',
          'isCreator': 'true',
        });
        _creatorAdded = true;
      });
    }
  }

  void _addParticipant() {
    final name = _participantNameController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _participants.add({'name': name, 'role': _participantRole});
        _participantNameController.clear();
        _participantRole = 'MEMBER';
      });
    }
  }

  void _showCurrencySelectorModal(BuildContext context) async {
    final selected = await showModalBottomSheet<Currency>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        List<Currency> filtered = [..._allCurrencies];
        final searchController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            void _filter(String query) {
              setModalState(() {
                filtered = _allCurrencies
                    .where((c) =>
                        c.name.toLowerCase().contains(query.toLowerCase()) ||
                        c.code.toLowerCase().contains(query.toLowerCase()))
                    .toList();
              });
            }

            return Padding(
              padding: MediaQuery.of(ctx).viewInsets,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: TextField(
                      controller: searchController,
                      onChanged: _filter,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm tiền tệ...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        final isSelected = _selectedCurrency?.code == c.code;

                        return ListTile(
                          title: Text('${c.name} (${c.symbol})'),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () {
                            Navigator.pop(context, c); // Trả về currency chọn
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Sau khi chọn xong:
    if (selected != null) {
      setState(() => _selectedCurrency = selected);
    }
  }

  void _showCurrencyShortList(BuildContext context) {
    showModalBottomSheet<Currency>(
      context: context,
      builder: (ctx) {
        final shortList = _allCurrencies.take(5).toList();

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...shortList.map((c) => ListTile(
                    title: Text('${c.name} (${c.symbol})'),
                    trailing: _selectedCurrency?.code == c.code
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      Navigator.pop(context); // đóng mini modal
                      setState(() => _selectedCurrency = c);
                    },
                  )),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.arrow_drop_down, color: Colors.orange),
                title: const Text("Hiển thị tất cả tiền tệ"),
                onTap: () {
                  Navigator.pop(context); // đóng rút gọn
                  _showCurrencySelectorModal(context); // mở full list
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeParticipant(int index) {
    if (_participants[index]['isCreator'] == 'true') return;
    setState(() => _participants.removeAt(index));
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedCurrency == null || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> groupData = {
        'name': _nameController.text.trim(),
        'defaultCurrency': _selectedCurrency!.code,
        'budgetLimit': _budgetLimitController.text.isNotEmpty
            ? int.tryParse(_budgetLimitController.text)
            : null,
        'participants': _participants
            .where((p) => p['isCreator'] != 'true') // bỏ người tạo
            .toList(),
        'categoryId': _selectedCategory!.id,
      };

      final groupId = await GroupService.createGroup(groupData);

      if (_pickedImage != null) {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            _pickedImage!.path,
            filename: _pickedImage!.name,
            contentType: _getMediaType(_pickedImage!.path),
          ),
          'description': 'avatar',
        });
        await AuthService.dio.post('/media/group/$groupId', data: formData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo nhóm thành công!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tạo nhóm: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo nhóm mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Tên nhóm'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Nhập tên nhóm'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _budgetLimitController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Ngân sách dự kiến'),
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      int.tryParse(value) == null) {
                    return 'Vui lòng nhập số hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Phần chọn danh mục
              FutureBuilder<List<Category>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text('Lỗi tải danh mục: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('Không có dữ liệu danh mục');
                  }

                  return DropdownButtonFormField<Category>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Danh mục'),
                    items: snapshot.data!.map((category) => 
                      DropdownMenuItem(
                        value: category, 
                        child: Row(
                          children: [
                            if (category.iconCode != null)
                              Icon(
                                getIconDataFromCode(category.iconCode),
                                color: HexColor.fromHex(category.color ?? '#000000'),
                                size: 20,
                              ),
                            const SizedBox(width: 8),
                            Text(category.name),
                          ],
                        ),
                      ),
                    ).toList(),
                    onChanged: (Category? value) {
                      setState(() => _selectedCategory = value);
                    },
                    validator: (value) => value == null 
                      ? 'Vui lòng chọn danh mục' 
                      : null,
                  );
                },
              ),
              
              const SizedBox(height: 16),
              FutureBuilder<List<Currency>>(
                future: _currenciesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text('Lỗi tải tiền tệ: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('Không có dữ liệu tiền tệ');
                  }

                  return InkWell(
                    onTap: () => _showCurrencyShortList(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Tiền tệ'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCurrency != null
                                ? '${_selectedCurrency!.name} (${_selectedCurrency!.symbol})'
                                : 'Chọn đơn vị tiền tệ',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Chọn ảnh đại diện'),
                  ),
                  const SizedBox(width: 12),
                  if (_pickedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.file(
                            File(_pickedImage!.path),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _pickedImage = null),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Thành viên tham gia',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              // Dòng thêm thành viên
              Container(
                margin: const EdgeInsets.only(top: 6, bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _participantNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Nhập tên...',
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 🔥 Không Expanded nữa - chỉ cố định width
                    SizedBox(
                      width: 100, // chỉ 100 thôi
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _participantRole,
                          onChanged: (v) {
                            if (v != null) setState(() => _participantRole = v);
                          },
                          items: const [
                            DropdownMenuItem(
                                value: 'MEMBER',
                                child: Text('MEMBER',
                                    style: TextStyle(fontSize: 14))),
                            DropdownMenuItem(
                                value: 'ADMIN',
                                child: Text('ADMIN',
                                    style: TextStyle(fontSize: 14))),
                          ],
                          isExpanded:
                              true, // 🔥 Cho Dropdown co gọn trong 100px
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    SizedBox(
                      width: 32, // 🔥 nhỏ nút + còn 32
                      child: IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: Colors.deepPurple, size: 22),
                        onPressed: _addParticipant,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),

              // Kẻ đường phân cách
              const Divider(
                height: 24,
                thickness: 1.2,
                color: Color.fromARGB(255, 50, 47, 47),
              ),
              const SizedBox(height: 4),

              // Danh sách thành viên
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _participants.length,
                itemBuilder: (context, index) {
                  final p = _participants[index];
                  final isCreator = p['isCreator'] == 'true';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Tên
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            initialValue: p['name'],
                            onChanged: (value) {
                              _participants[index]['name'] = value;
                            },
                            readOnly: isCreator,
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Vai trò
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: p['role'],
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'MEMBER', child: Text('MEMBER')),
                              DropdownMenuItem(
                                  value: 'ADMIN', child: Text('ADMIN')),
                            ],
                            onChanged: isCreator
                                ? null
                                : (v) {
                                    if (v != null) {
                                      setState(() {
                                        _participants[index]['role'] = v;
                                      });
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Action
                        SizedBox(
                          width: 36,
                          child: isCreator
                              ? const Center(
                                  child: Text('(Bạn)',
                                      style: TextStyle(
                                          color: Colors.blue, fontSize: 11)),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.redAccent, size: 20),
                                  onPressed: () => _removeParticipant(index),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Tạo nhóm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}
 