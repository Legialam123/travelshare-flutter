import '../models/category.dart';
import '../services/auth_service.dart';

class CategoryService {
  /// Lấy danh sách category cho Group
  static Future<List<Category>> fetchGroupCategories() async {
    try {
      final response = await AuthService.dio.get('/category/group');
      if (response.statusCode == 200 && response.data['result'] != null) {
        final List<dynamic> data = response.data['result'];
        return data.map((json) => Category.fromJson(json)).toList();
      } else {
        throw Exception('Phản hồi không hợp lệ từ máy chủ');
      }
    } catch (e) {
      throw Exception('Không thể tải danh sách category: $e');
    }
  }

  /// Lấy danh sách category cho Expense
  static Future<List<Category>> fetchExpenseCategories() async {
    try {
      final response = await AuthService.dio.get('/category/expense');
      if (response.statusCode == 200 && response.data['result'] != null) {
        final List<dynamic> data = response.data['result'];
        return data.map((json) => Category.fromJson(json)).toList();
      } else {
        throw Exception('Phản hồi không hợp lệ từ máy chủ');
      }
    } catch (e) {
      throw Exception('Không thể tải danh sách category: $e');
    }
  }

  /// Lấy danh sách category EXPENSE của một group cụ thể
  static Future<List<Category>> fetchGroupExpenseCategories(int groupId) async {
    try {
      final response =
          await AuthService.dio.get('/category/group/$groupId/expense');
      if (response.statusCode == 200 && response.data['result'] != null) {
        final List<dynamic> data = response.data['result'];
        return data.map((json) => Category.fromJson(json)).toList();
      } else {
        throw Exception('Phản hồi không hợp lệ từ máy chủ');
      }
    } catch (e) {
      throw Exception('Không thể tải danh sách category: $e');
    }
  }

  /// Tạo category EXPENSE cho group
  static Future<Category> createExpenseCategoryForGroup(
      int groupId, Map<String, dynamic> data) async {
    try {
      final response = await AuthService.dio
          .post('/category/group/$groupId/expense', data: data);
      if (response.statusCode == 200 && response.data['result'] != null) {
        return Category.fromJson(response.data['result']);
      } else {
        throw Exception('Tạo category thất bại: ${response.data}');
      }
    } catch (e) {
      throw Exception('Lỗi khi tạo category: $e');
    }
  }

  /// Cập nhật thông tin category
  static Future<Category> updateCategory(
      int categoryId, Map<String, dynamic> data) async {
    try {
      final response =
          await AuthService.dio.put('/category/$categoryId', data: data);
      if (response.statusCode == 200 && response.data['result'] != null) {
        return Category.fromJson(response.data['result']);
      } else {
        throw Exception('Cập nhật category thất bại: ${response.data}');
      }
    } catch (e) {
      throw Exception('Lỗi khi cập nhật category: $e');
    }
  }

  /// Xóa category
  static Future<void> deleteCategory(int categoryId) async {
    try {
      await AuthService.dio.delete('/category/$categoryId');
    } catch (e) {
      throw Exception('Lỗi khi xóa category: $e');
    }
  }

  /// Lấy danh sách category theo ID
  static Future<List<Category>> fetchCategoriesByIds(List<int> categoryIds) async {
    if (categoryIds.isEmpty) return [];
    
    try {
      // Lấy từng danh mục một thay vì dùng API /category/by-ids
      List<Category> categories = [];
      for (int id in categoryIds) {
        try {
          final response = await AuthService.dio.get('/category/$id');
          if (response.statusCode == 200 && response.data['result'] != null) {
            categories.add(Category.fromJson(response.data['result']));
          }
        } catch (e) {
          print('Không thể tải category ID $id: $e');
        }
      }
      return categories;
    } catch (e) {
      throw Exception('Không thể tải danh sách category: $e');
    }
  }
}
