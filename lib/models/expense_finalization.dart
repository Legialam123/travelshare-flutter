class ExpenseFinalization {
  final int id;
  final int groupId;
  final String groupName;
  final FinalizationStatus status;
  final DateTime finalizedAt;
  final DateTime deadline;
  final String? description;
  final String initiatedBy;
  final String initiatedByName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<FinalizationRequestInfo> memberResponses;

  ExpenseFinalization({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.status,
    required this.finalizedAt,
    required this.deadline,
    this.description,
    required this.initiatedBy,
    required this.initiatedByName,
    required this.createdAt,
    this.updatedAt,
    required this.memberResponses,
  });

  factory ExpenseFinalization.fromJson(Map<String, dynamic> json) {
    return ExpenseFinalization(
      id: json['id'],
      groupId: json['groupId'],
      groupName: json['groupName'] ?? '',
      status: FinalizationStatus.fromString(json['status']),
      finalizedAt: DateTime.parse(json['finalizedAt']),
      deadline: DateTime.parse(json['deadline']),
      description: json['description'],
      initiatedBy: json['initiatedBy'],
      initiatedByName: json['initiatedByName'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      memberResponses: (json['memberResponses'] as List<dynamic>? ?? [])
          .map((e) => FinalizationRequestInfo.fromJson(e))
          .toList(),
    );
  }

  // Helper methods
  bool get isPending => status == FinalizationStatus.pending;
  bool get isApproved => status == FinalizationStatus.approved;
  bool get isRejected => status == FinalizationStatus.rejected;
  bool get isExpired => status == FinalizationStatus.expired;
  
  bool get isDeadlinePassed => DateTime.now().isAfter(deadline);
  
  int get pendingResponsesCount => memberResponses
      .where((r) => r.requestStatus == 'PENDING')
      .length;
      
  int get approvedResponsesCount => memberResponses
      .where((r) => r.requestStatus == 'ACCEPTED')
      .length;
      
  int get rejectedResponsesCount => memberResponses
      .where((r) => r.requestStatus == 'DECLINED')
      .length;

  String get statusDisplayText {
    switch (status) {
      case FinalizationStatus.pending:
        return 'Đang chờ phản hồi';
      case FinalizationStatus.approved:
        return 'Đã phê duyệt';
      case FinalizationStatus.rejected:
        return 'Bị từ chối';
      case FinalizationStatus.expired:
        return 'Đã hết hạn';
    }
  }

  String get progressText {
    if (isPending) {
      return '$approvedResponsesCount/${memberResponses.length} đã phản hồi';
    }
    return statusDisplayText;
  }
}

class FinalizationRequestInfo {
  final int requestId;
  final String participantId;
  final String participantName;
  final String requestStatus; // PENDING, ACCEPTED, DECLINED
  final DateTime? respondedAt;
  final String? note;

  FinalizationRequestInfo({
    required this.requestId,
    required this.participantId,
    required this.participantName,
    required this.requestStatus,
    this.respondedAt,
    this.note,
  });

  factory FinalizationRequestInfo.fromJson(Map<String, dynamic> json) {
    return FinalizationRequestInfo(
      requestId: json['requestId'],
      participantId: json['participantId'],
      participantName: json['participantName'] ?? '',
      requestStatus: json['requestStatus'],
      respondedAt: json['respondedAt'] != null ? DateTime.parse(json['respondedAt']) : null,
      note: json['note'],
    );
  }

  bool get isPending => requestStatus == 'PENDING';
  bool get isAccepted => requestStatus == 'ACCEPTED';
  bool get isDeclined => requestStatus == 'DECLINED';

  String get statusDisplayText {
    switch (requestStatus) {
      case 'PENDING':
        return 'Chờ phản hồi';
      case 'ACCEPTED':
        return 'Đã đồng ý';
      case 'DECLINED':
        return 'Đã từ chối';
      default:
        return 'Không xác định';
    }
  }
}

enum FinalizationStatus {
  pending,
  approved,
  rejected,
  expired;

  static FinalizationStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return FinalizationStatus.pending;
      case 'APPROVED':
        return FinalizationStatus.approved;
      case 'REJECTED':
        return FinalizationStatus.rejected;
      case 'EXPIRED':
        return FinalizationStatus.expired;
      default:
        throw ArgumentError('Unknown finalization status: $status');
    }
  }

  String get apiValue {
    switch (this) {
      case FinalizationStatus.pending:
        return 'PENDING';
      case FinalizationStatus.approved:
        return 'APPROVED';
      case FinalizationStatus.rejected:
        return 'REJECTED';
      case FinalizationStatus.expired:
        return 'EXPIRED';
    }
  }
}
