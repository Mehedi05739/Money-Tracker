import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/transaction_model.dart';

abstract class TransactionRemoteDataSource {
  Future<List<TransactionModel>> getTransactions({int page, int limit});
  Future<TransactionModel> getTransactionById(String id);
  Future<TransactionModel> addTransaction(TransactionModel transaction);
  Future<TransactionModel> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String id);
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  TransactionRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<TransactionModel>> getTransactions({
    int page = 1,
    int limit = 20,
  }) {
    return _client.getRequest(
      ApiEndpoints.transactions,
      query: {'page': page, 'limit': limit},
      decoder: TransactionModel.listFromJson,
    );
  }

  @override
  Future<TransactionModel> getTransactionById(String id) {
    return _client.getRequest(
      ApiEndpoints.transactionById(id),
      decoder: (body) =>
          TransactionModel.fromJson(body as Map<String, dynamic>),
    );
  }

  @override
  Future<TransactionModel> addTransaction(TransactionModel transaction) {
    return _client.postRequest(
      ApiEndpoints.transactions,
      body: transaction.toJson(),
      decoder: (body) =>
          TransactionModel.fromJson(body as Map<String, dynamic>),
    );
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel transaction) {
    return _client.putRequest(
      ApiEndpoints.transactionById(transaction.id),
      body: transaction.toJson(),
      decoder: (body) =>
          TransactionModel.fromJson(body as Map<String, dynamic>),
    );
  }

  @override
  Future<void> deleteTransaction(String id) =>
      _client.deleteRequest<void>(ApiEndpoints.transactionById(id));
}
