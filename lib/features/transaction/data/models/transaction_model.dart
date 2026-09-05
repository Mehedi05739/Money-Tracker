import '../../domain/entities/transaction_entity.dart';

/// Serialization lives here, never on the entity — the API's shape is a data
/// layer concern.
class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.title,
    required super.amount,
    required super.type,
    required super.date,
    super.category,
    super.note,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: '${json['id']}',
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      type: _typeFromJson(json['type'] as String?),
      date: DateTime.tryParse('${json['date']}')?.toLocal() ?? DateTime.now(),
      category: json['category'] as String? ?? 'Uncategorized',
      note: json['note'] as String?,
    );
  }

  factory TransactionModel.fromEntity(TransactionEntity entity) {
    return TransactionModel(
      id: entity.id,
      title: entity.title,
      amount: entity.amount,
      type: entity.type,
      date: entity.date,
      category: entity.category,
      note: entity.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'date': date.toUtc().toIso8601String(),
        'category': category,
        'note': note,
      };

  static List<TransactionModel> listFromJson(dynamic body) {
    final list = body is Map<String, dynamic> ? body['data'] : body;
    return (list as List<dynamic>)
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static TransactionType _typeFromJson(String? raw) =>
      raw == TransactionType.income.name
          ? TransactionType.income
          : TransactionType.expense;
}
