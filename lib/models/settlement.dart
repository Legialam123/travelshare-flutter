class Settlement {
  final int id;
  final int groupId;
  final String groupName;
  final int fromParticipantId;
  final String fromParticipantName;
  final int toParticipantId;
  final String toParticipantName;
  final double amount;
  final String currencyCode;
  final String status;
  final String method;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Settlement({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.fromParticipantId,
    required this.fromParticipantName,
    required this.toParticipantId,
    required this.toParticipantName,
    required this.amount,
    required this.currencyCode,
    required this.status,
    required this.method,
    this.description,
    required this.createdAt,
    this.updatedAt,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'],
      groupId: json['groupId'],
      groupName: json['groupName'] ?? '',
      fromParticipantId: json['fromParticipantId'],
      fromParticipantName: json['fromParticipantName'] ?? '',
      toParticipantId: json['toParticipantId'],
      toParticipantName: json['toParticipantName'] ?? '',
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currencyCode'],
      status: json['status'],
      method: json['settlementMethod'] ?? '',
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
}
