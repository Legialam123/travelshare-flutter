class Category {
  final int id;
  final String name;
  final String description;
  final String? iconCode;
  final String? color;
  final bool isSystemCategory;
  final String type; // 'EXPENSE', 'GROUP', 'BOTH'

  Category({
    required this.id,
    required this.name,
    required this.description,
    this.iconCode,
    this.color,
    this.isSystemCategory = false,
    required this.type,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      iconCode: json['iconCode'],
      color: json['color'],
      isSystemCategory: json['isSystemCategory'] ?? false,
      type: json['type'] ?? 'EXPENSE',
    );
  }
}
