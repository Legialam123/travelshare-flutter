// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id']
          as String?, // Đổi từ (json['id'] as num?)?.toInt() thành (json['id'] as String?)
      email: json['email'] as String?,
      username: json['username'] as String?,
      fullName: json['fullName'] as String?,
      dob: json['dob'] == null ? null : DateTime.parse(json['dob']),
      phoneNumber: json['phoneNumber'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id, // Đảm bảo là String
      'email': instance.email,
      'username': instance.username,
      'fullName': instance.fullName,
      'dob': instance.dob?.toIso8601String(),
      'phoneNumber': instance.phoneNumber,
      'avatarUrl': instance.avatarUrl,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
