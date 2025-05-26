import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'category.dart';

class Group {
  final int id;
  final String name;
  final UserSummaryResponse createdBy;
  final DateTime createdAt;
  final double? budgetLimit;
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
    this.budgetLimit,
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
      budgetLimit: (json['budgetLimit'] is num)
          ? (json['budgetLimit'] as num).toDouble()
          : double.tryParse(json['budgetLimit']?.toString() ?? ''),
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
  final String? fullName;
  final String? username;
  final String? id;

  UserSummaryResponse({this.fullName, this.username, this.id});

  factory UserSummaryResponse.fromJson(Map<String, dynamic> json) {
    return UserSummaryResponse(
      fullName: json['fullName'],
      username: json['username'],
      id: json['id'] is String
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
    );
  }
}

class GroupParticipant {
  final int id;
  final String name;
  final String role;
  final String status;
  final DateTime? joinedAt;
  final UserSummaryResponse? user;

  GroupParticipant({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
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
      status: json['status'].toString(),
      joinedAt:
          json['joinedAt'] != null ? DateTime.tryParse(json['joinedAt']) : null,
      user: json['user'] != null
          ? UserSummaryResponse.fromJson(json['user'])
          : null,
    );
  }
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
 