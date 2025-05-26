import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String? id; // Đổi từ int? thành String?
  final String? email;
  final String? username;
  final String? fullName;
  final DateTime? dob; // Thêm trường dob
  final String? avatarUrl;
  final DateTime? createdAt;
  final String? phoneNumber; // Thêm trường phone

  User({
    this.id,
    this.email,
    this.username,
    this.dob,
    this.fullName,
    this.avatarUrl,
    this.createdAt,
    this.phoneNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
