import 'package:dio/dio.dart';
import '../services/auth_service.dart';
import '../models/group.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class GroupService {
  /// Lấy danh sách tất cả nhóm của người dùng hiện tại
  static Future<List<Group>> fetchGroups() async {
    try {
      final response = await AuthService.dio.get('/group/myGroups');

      if (response.statusCode == 200 && response.data['result'] != null) {
        final List<dynamic> data = response.data['result'];
        return data.map((json) => Group.fromJson(json)).toList();
      } else {
        throw Exception('Phản hồi không hợp lệ từ máy chủ');
      }
    } catch (e) {
      throw Exception('Không thể tải danh sách nhóm: $e');
    }
  }

  /// Lấy danh sách người tham gia một nhóm cụ thể
  static Future<List<GroupParticipant>> fetchParticipants(int groupId) async {
    try {
      final response = await AuthService.dio.get('/group/$groupId');
      final participantsJson = response.data['result']['participants'] as List;
      return participantsJson.map((e) => GroupParticipant.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Không thể tải danh sách thành viên: $e');
    }
  }

  static Future<int> createGroup(Map<String, dynamic> data) async {
    try {
      final response = await AuthService.dio.post('/group', data: data);
      if (response.statusCode == 200 && response.data['result'] != null) {
        return response.data['result']['id'];
      } else {
        throw Exception('Tạo nhóm thất bại: ${response.data}');
      }
    } catch (e) {
      throw Exception('Lỗi khi tạo nhóm: $e');
    }
  }

  /// Lấy chi tiết một nhóm cụ thể
  static Future<Group> getGroupById(int groupId) async {
    try {
      final response = await AuthService.dio.get(
        '/group/$groupId',
        options: Options(headers: {'Cache-Control': 'no-cache'}),
      );
      final data = response.data['result'];
      return Group.fromJson(data);
    } catch (e) {
      throw Exception('Không thể tải chi tiết nhóm: $e');
    }
  }

  /// Lấy danh sách nhóm phân loại theo danh mục
  static Future<Map<Category, List<Group>>> fetchGroupsByCategory() async {
    try {
      final response = await AuthService.dio.get('/group/myGroups');
      if (response.statusCode == 200 && response.data['result'] != null) {
        final List<dynamic> data = response.data['result'];
        final List<Group> allGroups =
            data.map((json) => Group.fromJson(json)).toList();

        // Nhóm theo danh mục
        final Map<int, List<Group>> groupsByCategory = {};
        for (var group in allGroups) {
          if (!groupsByCategory.containsKey(group.categoryId)) {
            groupsByCategory[group.categoryId] = [];
          }
          groupsByCategory[group.categoryId]!.add(group);
        }

        // Lấy thông tin chi tiết các danh mục
        final categoryIds = groupsByCategory.keys.toList();
        final List<Category> categories =
            await CategoryService.fetchCategoriesByIds(categoryIds);

        // Tạo map cuối cùng
        final Map<Category, List<Group>> result = {};
        for (var category in categories) {
          if (groupsByCategory.containsKey(category.id)) {
            result[category] = groupsByCategory[category.id]!;
          }
        }

        return result;
      } else {
        throw Exception('Phản hồi không hợp lệ từ máy chủ');
      }
    } catch (e) {
      throw Exception('Không thể tải danh sách nhóm theo danh mục: $e');
    }
  }

  /// Cập nhật danh mục của nhóm
  static Future<void> updateGroupCategory(int groupId, int categoryId) async {
    try {
      await AuthService.dio.put('/group/$groupId/category', data: {
        'categoryId': categoryId,
      });
    } catch (e) {
      throw Exception('Không thể cập nhật danh mục: $e');
    }
  }
}
