import '../../core/enums/account_type.dart';

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.currentBalance,
    required this.currency,
    this.icon,
    this.color,
    this.isArchived = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Draft used by the create form, before the database assigns an id.
  factory Account.draft() => Account(
        id: 0,
        name: '',
        type: AccountType.cash,
        openingBalance: 0,
        currentBalance: 0,
        currency: 'USD',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  final int id;
  final String name;
  final AccountType type;
  final double openingBalance;
  final double currentBalance;
  final String currency;
  final String? icon;
  final int? color;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPersisted => id > 0;

  /// Net movement since the account was opened.
  double get netChange => currentBalance - openingBalance;

  Account copyWith({
    int? id,
    String? name,
    AccountType? type,
    double? openingBalance,
    double? currentBalance,
    String? currency,
    String? icon,
    int? color,
    bool? isArchived,
    int? sortOrder,
    DateTime? updatedAt,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        openingBalance: openingBalance ?? this.openingBalance,
        currentBalance: currentBalance ?? this.currentBalance,
        currency: currency ?? this.currency,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        isArchived: isArchived ?? this.isArchived,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) => other is Account && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
