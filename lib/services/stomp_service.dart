import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:travel_share/services/auth_service.dart';
import 'package:travel_share/models/notification.dart';
import 'dart:async';
import 'package:travel_share/services/group_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StompService {
  static final StompService _instance = StompService._internal();
  factory StompService() => _instance;
  StompService._internal();

  StompClient? _client;
  StreamController<NotificationModel> _notificationController =
      StreamController.broadcast();
  Stream<NotificationModel> get notificationStream =>
      _notificationController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _userId;
  String? _token;

  Future<void> connect() async {
    if (_isConnected) return;
    _token = await AuthService.getAccessToken();
    final user = await AuthService.getCurrentUser();
    _userId = user?.id;
    if (_token == null || _userId == null) {
      debugPrint('Không có token hoặc userId, không thể kết nối STOMP');
      return;
    }
    final currentUserId = _userId;
    // Lấy danh sách groupId
    List<int> groupIds = [];
    try {
      final groups = await GroupService.fetchGroups();
      groupIds = groups.map((g) => g.id).toList();
    } catch (e) {
      debugPrint('Lỗi lấy danh sách group khi subscribe STOMP: $e');
    }
    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final wsUrl = apiBaseUrl + '/ws';
    debugPrint('STOMP wsUrl: $wsUrl');
    _client = StompClient(
      config: StompConfig.SockJS(
        url: wsUrl,
        onConnect: (frame) => _onConnect(frame, groupIds, currentUserId),
        beforeConnect: () async {
          debugPrint('Đang kết nối STOMP...');
        },
        onWebSocketError: (dynamic error) => debugPrint('STOMP error: $error'),
        onStompError: (frame) {
          debugPrint('❌ STOMP error frame: ${frame.body}');
        },
        onDisconnect: (frame) {
          debugPrint('🔌 STOMP disconnected');
          _isConnected = false;
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $_token',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $_token',
        },
        heartbeatOutgoing: Duration(milliseconds: 10000),
        heartbeatIncoming: Duration(milliseconds: 10000),
        reconnectDelay: Duration(milliseconds: 5000),
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame frame, List<int> groupIds, String? currentUserId) {
    debugPrint('✅ STOMP connected!');
    _isConnected = true;
    // Subscribe notification cá nhân
    if (_userId != null) {
      _client?.subscribe(
        destination: '/user/$_userId/queue/notifications',
        callback: (frame) {
          if (frame.body != null) {
            try {
              final data = jsonDecode(frame.body!);
              final notification = NotificationModel.fromJson(data);
              if (notification.createdBy.id == currentUserId) return; // Bỏ qua nếu là creator
              _notificationController.add(notification);
            } catch (e) {
              debugPrint('Lỗi parse notification: $e');
            }
          }
        },
      );
    }
    // Subscribe tất cả group mà user tham gia
    for (final groupId in groupIds) {
      _client?.subscribe(
        destination: '/topic/group/$groupId',
        callback: (frame) {
          if (frame.body != null) {
            try {
              final data = jsonDecode(frame.body!);
              final notification = NotificationModel.fromJson(data);
              if (notification.createdBy.id == currentUserId) return; // Bỏ qua nếu là creator
              _notificationController.add(notification);
            } catch (e) {
              debugPrint('Lỗi parse notification group: $e');
            }
          }
        },
      );
    }
  }

  void disconnect() {
    _client?.deactivate();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _notificationController.close();
  }
}
