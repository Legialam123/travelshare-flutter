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
import '../../widgets/currency_picker_modal.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _participantNameController = TextEditingController();
  final _participantEmailController = TextEditingController();

  Future<List<Currency>>? _currenciesFuture;
  Future<List<Category>>? _categoriesFuture;
  XFile? _pickedImage;
  final _picker = ImagePicker();
  final List<Map<String, String>> _participants = [];
  String _participantRole = 'MEMBER';
  String? _creatorFullName;
  String? _creatorEmail;
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
    final email = await AuthService.getCurrentEmail();
    if (fullName != null) {
      setState(() {
        _creatorFullName = fullName;
        _creatorEmail = email;
        _participants.insert(0, {
          'name': fullName,
          'email': email ?? '',
          'role': 'ADMIN',
          'isCreator': 'true',
        });
        _creatorAdded = true;
      });
    }
  }

  void _addParticipant() async {
    final name = _participantNameController.text.trim();
    final email = _participantEmailController.text.trim();
    if (name.isEmpty) return;

    if (email.isNotEmpty) {
      bool exists;
      try {
        exists = await AuthService.checkEmailExists(email);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kiểm tra email: $e')),
        );
        return;
      }

      setState(() {
        _participants.add({'name': name, 'email': email, 'emailExists': exists.toString()});
        _participantNameController.clear();
        _participantEmailController.clear();
      });

      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm thành viên có tài khoản liên kết với email $email thành công.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email $email chưa đăng ký hệ thống. Thành viên sẽ nhận được email mời tham gia nhóm sau khi nhóm được tạo.')),
        );
      }
    } else {
      setState(() {
        _participants.add({'name': name});
        _participantNameController.clear();
        _participantEmailController.clear();
      });
    }
  }

  void _showCurrencyPicker(BuildContext context) async {
    final selected = await CurrencyPickerModal.showShortList(
      context: context,
      currencies: _allCurrencies,
      selectedCurrency: _selectedCurrency,
      defaultCurrencyCode: null, // Group creation doesn't have default yet
    );

    if (selected != null) {
      setState(() => _selectedCurrency = selected);
    }
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
    if (!_formKey.currentState!.validate() ||
        _selectedCurrency == null ||
        _selectedCategory == null) {
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
        'creatorName': _creatorFullName,
        'participants': _participants
            .where((p) => p['isCreator'] != 'true')
            .map((p) => {
              'name': p['name'],
              if (p['email'] != null && p['email']!.isNotEmpty) 'email': p['email'],
            })
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
        title: const Text('Tạo nhóm mới',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
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
              // AVATAR CHỌN ẢNH ĐẠI DIỆN ĐẦU MÀN HÌNH
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: _pickedImage == null
                      ? Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.add_a_photo,
                                color: Colors.white, size: 32),
                          ),
                        )
                      : Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.file(
                                  File(_pickedImage!.path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _pickedImage = null),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Tên nhóm'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Nhập tên nhóm' : null,
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
                    items: snapshot.data!
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                if (category.iconCode != null)
                                  Icon(
                                    getIconDataFromCode(category.iconCode),
                                    color: HexColor.fromHex(
                                        category.color ?? '#000000'),
                                    size: 20,
                                  ),
                                const SizedBox(width: 8),
                                Text(category.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (Category? value) {
                      setState(() => _selectedCategory = value);
                    },
                    validator: (value) =>
                        value == null ? 'Vui lòng chọn danh mục' : null,
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
                    onTap: () => _showCurrencyPicker(context),
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

              const SizedBox(height: 18),
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
                      flex: 4,
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
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _participantEmailController,
                        decoration: const InputDecoration(
                          hintText: 'Email (nếu có)',
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 32,
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
                          flex: 4,
                          child: TextFormField(
                            initialValue: p['name'],
                            onChanged: (value) {
                              _participants[index]['name'] = value;
                              if (p['isCreator'] == 'true') {
                                _creatorFullName = value;
                              }
                            },
                            readOnly: false,
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Email
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            initialValue: p['email'] ?? '',
                            readOnly: true,
                            decoration: InputDecoration(
                              border: const UnderlineInputBorder(),
                              isDense: true,
                              hintText: (isCreator && (p['email'] == null || p['email']!.isEmpty)) ? '(Bạn)' : 'Email (nếu có)',
                              hintStyle: isCreator
                                  ? const TextStyle(color: Colors.blue, fontStyle: FontStyle.italic)
                                  : null,
                            ),
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
              // NÚT TẠO NHÓM GIAO DIỆN HIỆN ĐẠI
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: _isSubmitting ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.group_add, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text(
                                    'Tạo nhóm',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
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
