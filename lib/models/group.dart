import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'category.dart';

class Group {
  final int id;
  final String name;
  final UserSummaryResponse createdBy;
  final DateTime createdAt;
  final String defaultCurrency;
  final String joinCode;
  final List<GroupParticipant> participants;
  final List<Media> groupImages;
  final Category? category;
  final int categoryId;

  Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.defaultCurrency,
    required this.participants,
    required this.groupImages,
    required this.joinCode,
    this.category,
    required this.categoryId,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'],
      createdBy: UserSummaryResponse.fromJson(json['createdBy']),
      createdAt: DateTime.parse(json['createdAt']),
      defaultCurrency: json['defaultCurrency'],
      participants: (json['participants'] as List)
          .map((e) => GroupParticipant.fromJson(e as Map<String, dynamic>))
          .toList(),
      groupImages: (json['groupImages'] != null && json['groupImages'] is List)
          ? (json['groupImages'] as List).map((e) => Media.fromJson(e)).toList()
          : [],
      joinCode: json['joinCode'],
      category: json['category'] != null 
          ? Category.fromJson(json['category']) 
          : null,
      categoryId: json['categoryId'] is int
          ? json['categoryId']
          : (json['category'] != null && json['category']['id'] is int)
              ? json['category']['id']
              : 0,
    );
  }

  String? get avatarUrl {
    for (final media in groupImages) {
      if (media.description == "avatar") {
        return media.fileUrl.replaceFirst(
          'http://localhost:8080/TravelShare',
          dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/TravelShare',
        );
      }
    }
    // Nếu không có avatar, trả về ảnh mặc định trong assets
    return 'assets/images/default_group_avatar.png';
  }
}

class UserSummaryResponse {
  final String? id;
  final String? fullName;
  final DateTime? dob;
  final String? email;
  final String? phoneNumber;
  final String? role;

  UserSummaryResponse({
    this.id,
    this.fullName,
    this.dob,
    this.email,
    this.phoneNumber,
    this.role,
  });

  factory UserSummaryResponse.fromJson(Map<String, dynamic> json) {
    return UserSummaryResponse(
      id: json['id']?.toString(),
      fullName: json['fullName'],
      dob: json['dob'] != null ? DateTime.tryParse(json['dob']) : null,
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      role: json['role'],
    );
  }
}

class GroupParticipant {
  final int id;
  final String name;
  final String role;
  final DateTime? joinedAt;
  final UserSummaryResponse? user;

  GroupParticipant({
    required this.id,
    required this.name,
    required this.role,
    this.joinedAt,
    this.user,
  });

  factory GroupParticipant.fromJson(Map<String, dynamic> json) {
    return GroupParticipant(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'],
      role: json['role'],
      joinedAt:
          json['joinedAt'] != null ? DateTime.tryParse(json['joinedAt']) : null,
      user: json['user'] != null
          ? UserSummaryResponse.fromJson(json['user'])
          : null,
    );
  }
  
  // Helper method để xác định trạng thái participant
  String get displayStatus {
    if (user != null) {
      return "Đã tham gia";  // Có user liên kết
    } else {
      return "Chờ tham gia";  // Chưa có user liên kết
    }
  }
  
  // Helper method để kiểm tra có user liên kết không
  bool get hasLinkedUser => user != null;
}

class Media {
  final int id;
  final String fileUrl;
  final String? description;

  Media({required this.id, required this.fileUrl, this.description});

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      fileUrl: json['fileUrl'],
      description: json['description'],
    );
  }
}
 