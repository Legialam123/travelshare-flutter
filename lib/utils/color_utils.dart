import 'package:flutter/material.dart';

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));

  static Color fromHex(String hexString) {
    return HexColor(hexString);
  }
  
  /// Tạo màu với độ trong suốt
  static Color hexWithOpacity(String hexString, double opacity) {
    final color = HexColor(hexString);
    return color.withOpacity(opacity);
  }
}

/// Chuyển đổi từ String sang Color
Color getColorFromHex(String hexColor) {
  return HexColor(hexColor);
} 