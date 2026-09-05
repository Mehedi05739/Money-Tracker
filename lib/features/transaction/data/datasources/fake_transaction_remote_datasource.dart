import '../../domain/entities/transaction_entity.dart';
import '../models/transaction_model.dart';
import 'transaction_remote_datasource.dart';

/// In-memory stand-in for the backend so the boilerplate runs end to end
/// before an API exists.
///
/// Delete this file and bind [TransactionRemoteDataSourceImpl] in
/// `lib/di/dependency_injection.dart` once the real endpoints are live.
class FakeTransactionRemoteDataSource implements TransactionRemoteDataSource {
  final List<TransactionModel> _store = [
    TransactionModel(
      id: '1',
      title: 'Monthly salary',
      amount: 4200,
      type: TransactionType.income,
      date: DateTime.now().subtract(const Duration(days: 1)),
      category: 'Salary',
    ),
    TransactionModel(
      id: '2',
      title: 'Groceries',
      amount: 86.40,
      type: TransactionType.expense,
      date: DateTime.now().subtract(const Duration(days: 2)),
      category: 'Food',
    ),
    TransactionModel(
      id: '3',
      title: 'Electricity bill',
      amount: 120,
      type: TransactionType.expense,
      date: DateTime.now().subtract(const Duration(days: 4)),
      category: 'Utilities',
    ),
  ];

  static const Duration _latency = Duration(milliseconds: 600);

  @override
  Future<List<TransactionModel>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    await Future<void>.delayed(_latency);
    final start = (page - 1) * limit;
    if (start >= _store.length) return const [];
    return _store.skip(start).take(limit).toList();
  }

  @override
  Future<TransactionModel> getTransactionById(String id) async {
    await Future<void>.delayed(_latency);
    return _store.firstWhere((e) => e.id == id);
  }

  @override
  Future<TransactionModel> addTransaction(TransactionModel transaction) async {
    await Future<void>.delayed(_latency);
    final created = TransactionModel.fromEntity(
      transaction.copyWith(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    _store.insert(0, created);
    return created;
  }

  @override
  Future<TransactionModel> updateTransaction(
    TransactionModel transaction,
  ) async {
    await Future<void>.delayed(_latency);
    final index = _store.indexWhere((e) => e.id == transaction.id);
    if (index != -1) _store[index] = transaction;
    return transaction;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await Future<void>.delayed(_latency);
    _store.removeWhere((e) => e.id == id);
  }
}
