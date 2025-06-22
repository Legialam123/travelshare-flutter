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
      senderId: json['senderId'].toString(),
      senderName: json['senderName'] ?? '',
      receiverId: json['receiverId'].toString(),
      receiverName: json['receiverName'] ?? '',
      groupId: json['groupId'],
      groupName: json['groupName'],
      referenceId: json['referenceId'],
      content: json['content'] ?? '',
      actionUrl: json['actionUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
} 