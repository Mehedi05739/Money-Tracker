import '../../core/enums/transaction_type.dart';
import '../../core/utils/result.dart';
import '../entities/category.dart';

abstract class CategoryRepository {
  Future<Result<List<Category>>> getCategories({
    TransactionType? type,
    bool includeArchived = false,
  });
  Future<Result<Category>> getById(int id);
  Future<Result<Category>> create(Category category);
  Future<Result<Category>> update(Category category);

  /// Fails when the category is still referenced, so history is never
  /// silently rewritten. Archive instead.
  Future<Result<void>> delete(int id);
  Future<Result<void>> setArchived(int id, bool archived);
  Future<Result<int>> countTransactions(int categoryId);
}
