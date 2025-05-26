import 'package:flutter/material.dart';

/// Hàm tiện ích để chuyển đổi chuỗi iconCode thành IconData
/// Hỗ trợ cả định dạng hex (như: "0xe3ab", "e3ab") và tên biểu tượng (như: "home", "travel_explore")
IconData getIconDataFromCode(String? iconCode) {
  if (iconCode == null || iconCode.isEmpty) {
    return Icons.category; // Icon mặc định nếu không có
  }

  // Chuẩn hóa chuỗi iconCode, loại bỏ "0x" nếu có
  final normalizedCode = iconCode.replaceAll("0x", "");

  // Trước tiên, thử chuyển đổi từ tên biểu tượng sang IconData
  switch (normalizedCode) {
    // Các biểu tượng phổ biến cho danh mục
    case 'travel_explore':
      return Icons.travel_explore;
    case 'restaurant':
      return Icons.restaurant;
    case 'restaurant_menu':
      return Icons.restaurant_menu;
    case 'home':
      return Icons.home;
    case 'celebration':
      return Icons.celebration;
    case 'work':
      return Icons.work;
    case 'more_horiz':
      return Icons.more_horiz;
    case 'category':
      return Icons.category;
    case 'shopping_bag':
      return Icons.shopping_cart;
    case 'local_grocery_store':
      return Icons.local_grocery_store;
    case 'flight':
      return Icons.flight;
    case 'hotel':
      return Icons.hotel;
    case 'directions_bus':
      return Icons.directions_bus;
    case 'directions_car':
      return Icons.directions_car;
    case 'local_taxi':
      return Icons.local_taxi;
    case 'local_hospital':
      return Icons.local_hospital;
    case 'school':
      return Icons.school;
    case 'local_bar':
      return Icons.local_bar;
    case 'local_cafe':
      return Icons.local_cafe;
    case 'local_atm':
      return Icons.local_atm;
    case 'local_mall':
      return Icons.local_mall;
    case 'local_activity':
      return Icons.local_activity;
    case 'local_offer':
      return Icons.local_offer;

    // Thêm các trường hợp khác khi cần thiết

    default:
      // Nếu không phải tên biểu tượng, thử phân tích như mã hex
      try {
        final iconValue = int.parse('0x$normalizedCode');
        return IconData(
          iconValue,
          fontFamily: 'MaterialIcons',
        );
      } catch (e) {
        print('Lỗi khi phân tích iconCode: $iconCode - $e');
        return Icons.category; // Icon mặc định trong trường hợp lỗi
      }
  }
}
