import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/notification.dart';
import 'auth_service.dart';

class NotificationService {
  static Future<List<NotificationModel>> getMyNotifications({
    String? groupId,
    String? type,
    DateTimeRange? dateRange,
  }) async {
    final Map<String, dynamic> params = {};
    if (groupId != null && groupId.isNotEmpty) params['groupId'] = groupId;
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (dateRange != null) {
      params['fromDate'] = dateRange.start.toIso8601String().substring(0, 10); // yyyy-MM-dd
      params['toDate'] = dateRange.end.toIso8601String().substring(0, 10);
    }
    final response = await AuthService.dio.get(
      '/notification/my',
      queryParameters: params,
      options: Options(headers: {'Cache-Control': 'no-cache'}),
    );
    final List data = response.data['result'];
    return data.map((e) => NotificationModel.fromJson(e)).toList();
  }
}
