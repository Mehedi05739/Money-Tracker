import '../../core/enums/transaction_type.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.isDefault = false,
    this.isArchived = false,
    required this.createdAt,
  });

  factory Category.draft(TransactionType type) =>
      Category(id: 0, name: '', type: type, createdAt: DateTime.now());

  final int id;
  final String name;
  final TransactionType type;
  final String? icon;
  final int? color;
  final bool isDefault;
  final bool isArchived;
  final DateTime createdAt;

  bool get isPersisted => id > 0;

  Category copyWith({
    int? id,
    String? name,
    TransactionType? type,
    String? icon,
    int? color,
    bool? isDefault,
    bool? isArchived,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    isDefault: isDefault ?? this.isDefault,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
