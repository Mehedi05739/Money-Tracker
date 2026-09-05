import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/transaction_sort.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/core/utils/date_utils.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';
import 'package:money_tracker/domain/repositories/transaction_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late TransactionDao dao;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    dao = TransactionDao(database.db);
  });

  Future<void> add({
    required String title,
    required double amount,
    String? note,
    int? categoryId = 1,
    DateTime? date,
  }) async {
    final now = DateTime.now();
    await dao.insert(
      MoneyTransaction(
        id: 0,
        accountId: 1,
        type: TransactionType.expense,
        amount: amount,
        categoryId: categoryId,
        title: title,
        note: note,
        transactionDate: date ?? now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<List<String>> search(String term) async {
    final rows = await dao.find(filter: TransactionFilter(search: term));
    return rows.map((row) => row.title).toList();
  }

  group('search', () {
    test('matches the title', () async {
      await add(title: 'Bus ticket', amount: 3);
      await add(title: 'Coffee', amount: 4);

      expect(await search('bus'), ['Bus ticket']);
    });

    test('matches the note', () async {
      await add(title: 'Lunch', amount: 12, note: 'Client meeting');
      await add(title: 'Coffee', amount: 4);

      expect(await search('client'), ['Lunch']);
    });

    test('matches the category name', () async {
      // Category 1 is a seeded expense category.
      await add(title: 'Unrelated title', amount: 9, categoryId: 1);
      await add(title: 'Also unrelated', amount: 9, categoryId: 2);

      final categories = await dao.find(filter: const TransactionFilter());
      final firstCategory = categories
          .firstWhere((t) => t.categoryId == 1)
          .categoryName!;

      final matches = await search(firstCategory);
      expect(matches, isNotEmpty);
      expect(matches, contains('Unrelated title'));
    });

    test('is case insensitive', () async {
      await add(title: 'Groceries run', amount: 30);
      expect(await search('GROCERIES'), ['Groceries run']);
    });

    test('treats a typed % as a literal, not a wildcard', () async {
      await add(title: '100% wool scarf', amount: 40);
      await add(title: 'Anything else', amount: 5);

      expect(await search('100%'), ['100% wool scarf']);
    });

    test('an unmatched term returns nothing rather than everything', () async {
      await add(title: 'Coffee', amount: 4);
      expect(await search('zzzz'), isEmpty);
    });
  });

  group('sort', () {
    setUp(() async {
      final today = AppDate.startOfDay(DateTime.now());
      await add(title: 'Beta', amount: 50, date: today);
      await add(
        title: 'Alpha',
        amount: 10,
        date: today.subtract(const Duration(days: 2)),
      );
      await add(
        title: 'Gamma',
        amount: 30,
        date: today.subtract(const Duration(days: 1)),
      );
    });

    Future<List<String>> sorted(TransactionSort sort) async {
      final rows = await dao.find(sort: sort);
      return rows.map((row) => row.title).toList();
    }

    test('newest first is the default order', () async {
      expect(await sorted(TransactionSort.newestFirst), [
        'Beta',
        'Gamma',
        'Alpha',
      ]);
    });

    test('oldest first reverses it', () async {
      expect(await sorted(TransactionSort.oldestFirst), [
        'Alpha',
        'Gamma',
        'Beta',
      ]);
    });

    test('largest amount first', () async {
      expect(await sorted(TransactionSort.largestFirst), [
        'Beta',
        'Gamma',
        'Alpha',
      ]);
    });

    test('smallest amount first', () async {
      expect(await sorted(TransactionSort.smallestFirst), [
        'Alpha',
        'Gamma',
        'Beta',
      ]);
    });

    test('title A-Z ignores case', () async {
      await add(title: 'apple', amount: 1);
      expect(
        await sorted(TransactionSort.titleAZ).then((t) => t.first),
        'Alpha',
      );
    });

    test('only date orders keep the list groupable by day', () {
      expect(TransactionSort.newestFirst.groupsByDate, isTrue);
      expect(TransactionSort.oldestFirst.groupsByDate, isTrue);
      expect(TransactionSort.largestFirst.groupsByDate, isFalse);
      expect(TransactionSort.titleAZ.groupsByDate, isFalse);
    });

    test('paging stays stable when rows share a sort value', () async {
      // Ten rows at the same amount and timestamp: without an id tiebreaker
      // the pages could overlap or drop rows.
      final when = DateTime.now();
      for (var i = 0; i < 10; i++) {
        await add(title: 'Same $i', amount: 99, date: when);
      }

      final page1 = await dao.find(
        filter: const TransactionFilter(minAmount: 99),
        sort: TransactionSort.largestFirst,
        limit: 5,
      );
      final page2 = await dao.find(
        filter: const TransactionFilter(minAmount: 99),
        sort: TransactionSort.largestFirst,
        limit: 5,
        offset: 5,
      );

      final ids = {...page1.map((t) => t.id), ...page2.map((t) => t.id)};
      expect(ids, hasLength(10), reason: 'no duplicates and nothing skipped');
    });
  });

  group('yesterday preset', () {
    test('covers only yesterday', () async {
      final today = AppDate.startOfDay(DateTime.now());
      await add(title: 'Today', amount: 5, date: today);
      await add(
        title: 'Yesterday',
        amount: 6,
        date: today.subtract(const Duration(hours: 5)),
      );

      final range = DateRange.fromPreset(DateRangePreset.yesterday);
      final rows = await dao.find(filter: TransactionFilter(range: range));

      expect(rows.map((r) => r.title), ['Yesterday']);
    });
  });
}
