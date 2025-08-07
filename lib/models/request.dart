class RequestModel {
  final int id;
  final String type;
  final String status;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final int? groupId;
  final String? groupName;
  final int? referenceId;
  final String content;
  final String? actionUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RequestModel({
    required this.id,
    required this.type,
    required this.status,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    this.groupId,
    this.groupName,
    this.referenceId,
    required this.content,
    this.actionUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'],
      type: json['type'],
      status: json['status'],
      senderId: json['sender']?['id']?.toString() ?? '',
      senderName: json['sender']?['fullName'] ?? '',
      receiverId: json['receiver']?['id']?.toString() ?? '',
      receiverName: json['receiver']?['fullName'] ?? '',
      groupId: json['group']?['id'],
      groupName: json['group']?['name'],
      referenceId: json['referenceId'],
      content: json['content'] ?? '',
      actionUrl: json['actionUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  // Helper methods for different request types
  bool get isExpenseFinalization => type == 'EXPENSE_FINALIZATION';
  bool get isJoinGroupInvite => type == 'JOIN_GROUP_INVITE';
  bool get isJoinGroupRequest => type == 'JOIN_GROUP_REQUEST';
  bool get isPaymentRequest => type == 'PAYMENT_REQUEST';
  bool get isPaymentConfirm => type == 'PAYMENT_CONFIRM';
  
  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isDeclined => status == 'DECLINED';
  bool get isCancelled => status == 'CANCELLED';
  
  String get statusDisplayText {
    switch (status) {
      case 'PENDING':
        return 'Chờ xử lý';
      case 'ACCEPTED':
        return 'Đã chấp nhận';
      case 'DECLINED':
        return 'Đã từ chối';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }
  
  String get typeDisplayText {
    switch (type) {
      case 'EXPENSE_FINALIZATION':
        return 'Tất toán chi phí';
      case 'JOIN_GROUP_INVITE':
        return 'Lời mời tham gia';
      case 'JOIN_GROUP_REQUEST':
        return 'Yêu cầu tham gia';
      case 'PAYMENT_REQUEST':
        return 'Yêu cầu thanh toán';
      case 'PAYMENT_CONFIRM':
        return 'Xác nhận thanh toán';
      default:
        return 'Yêu cầu khác';
    }
  }
}
