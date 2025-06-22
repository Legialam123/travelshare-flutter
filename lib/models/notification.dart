class NotificationModel {
  final int id;
  final String type;
  final String content;
  final DateTime createdAt;
  final GroupSummary group;
  final UserSummary createdBy;
  final int? referenceId;

  NotificationModel({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.group,
    required this.createdBy,
    this.referenceId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      type: json['type'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      group: GroupSummary.fromJson(json['group']),
      createdBy: UserSummary.fromJson(json['createdBy']),
      referenceId: json['referenceId'],
    );
  }
}

class GroupSummary {
  final int id;
  final String name;
  GroupSummary({required this.id, required this.name});
  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    return GroupSummary(
      id: json['id'],
      name: json['name'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupSummary &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class UserSummary {
  final String id;
  final String fullName;
  final String email;
  final String role;
  UserSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });
  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'],
      fullName: json['fullName'],
      email: json['email'],
      role: json['role'],
    );
  }
} 