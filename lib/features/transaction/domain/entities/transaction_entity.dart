enum TransactionType { income, expense }

/// Pure business object. No JSON, no Flutter, no GetX — the domain layer must
/// stay independent of how data arrives or how it is displayed.
class TransactionEntity {
  const TransactionEntity({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.category = 'Uncategorized',
    this.note,
  });

  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String category;
  final String? note;

  bool get isIncome => type == TransactionType.income;

  /// Amount signed for balance math: income adds, expense subtracts.
  double get signedAmount => isIncome ? amount : -amount;

  TransactionEntity copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    DateTime? date,
    String? category,
    String? note,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      category: category ?? this.category,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TransactionEntity && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
