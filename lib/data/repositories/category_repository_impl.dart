import '../../core/enums/transaction_type.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../local/daos/category_dao.dart';
import 'repository_guard.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  const CategoryRepositoryImpl(this._dao);

  final CategoryDao _dao;

  static const ValidationFailure _duplicateName = ValidationFailure(
    'A category with that name already exists',
    fieldErrors: {'name': 'Already in use'},
  );

  @override
  Future<Result<List<Category>>> getCategories({
    TransactionType? type,
    bool includeArchived = false,
  }) =>
      guard(
        () => _dao.find(type: type, includeArchived: includeArchived),
        context: 'getCategories',
      );

  @override
  Future<Result<Category>> getById(int id) => guardFound(
        () => _dao.findById(id),
        notFoundMessage: 'Category not found',
      );

  @override
  Future<Result<Category>> create(Category category) async {
    final invalid = _validate(category);
    if (invalid != null) return Result.error(invalid);

    final duplicate = await _isDuplicate(category);
    if (duplicate != null) return Result.error(duplicate);

    return guard(() async {
      final id = await _dao.insert(category);
      final created = await _dao.findById(id);
      if (created == null) throw StateError('Category $id missing after insert');
      return created;
    }, context: 'createCategory');
  }

  @override
  Future<Result<Category>> update(Category category) async {
    final invalid = _validate(category);
    if (invalid != null) return Result.error(invalid);

    final duplicate = await _isDuplicate(category, excludingId: category.id);
    if (duplicate != null) return Result.error(duplicate);

    return guard(() async {
      await _dao.update(category);
      final updated = await _dao.findById(category.id);
      if (updated == null) throw StateError('Category ${category.id} missing');
      return updated;
    }, context: 'updateCategory');
  }

  /// Deleting is blocked while transactions reference the category, so history
  /// keeps its labels. The UI offers archiving instead.
  @override
  Future<Result<void>> delete(int id) async {
    final used = await countTransactions(id);
    if (used case Failed(:final failure)) return Result.error(failure);
    if (used case Success(:final data) when data > 0) {
      return Result.error(
        ValidationFailure(
          'This category is used by $data transaction${data == 1 ? '' : 's'}. '
          'Archive it instead to keep your history intact.',
        ),
      );
    }
    return guard(() => _dao.delete(id), context: 'deleteCategory');
  }

  @override
  Future<Result<void>> setArchived(int id, bool archived) =>
      guard(() => _dao.setArchived(id, archived), context: 'archiveCategory');

  @override
  Future<Result<int>> countTransactions(int categoryId) =>
      guard(() => _dao.countTransactions(categoryId), context: 'countCategory');

  Failure? _validate(Category category) {
    final nameError = Validators.name(category.name, field: 'Category name');
    if (nameError == null) return null;
    return ValidationFailure(nameError, fieldErrors: {'name': nameError});
  }

  /// Returns the duplicate failure, or `null` when the name is free.
  /// A lookup error is surfaced rather than being mistaken for "available".
  Future<Failure?> _isDuplicate(Category category, {int? excludingId}) async {
    final result = await guard(
      () => _dao.existsWithName(
        category.name,
        category.type,
        excludingId: excludingId,
      ),
      context: 'categoryNameCheck',
    );
    return result.fold(
      onSuccess: (exists) => exists ? _duplicateName : null,
      onError: (failure) => failure,
    );
  }
}
