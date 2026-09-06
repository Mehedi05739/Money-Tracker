import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/db_tables.dart';
import 'package:money_tracker/core/enums/recurrence_frequency.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/utils/date_utils.dart';
import 'package:money_tracker/data/local/daos/recurring_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/data/repositories/recurring_repository_impl.dart';
import 'package:money_tracker/domain/entities/recurring_transaction.dart';
import 'package:money_tracker/domain/services/recurring_service.dart';

import '../helpers/test_database.dart';

/// The occurrence ledger is what makes "generate transactions without creating
/// duplicates" a database guarantee rather than a procedure that has to be
/// executed carefully.
void main() {
  late RecurringDao dao;
  late TransactionDao transactions;
  late RecurringRepositoryImpl repository;
  late RecurringService service;
  late dynamic db;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    db = database.db;
    dao = RecurringDao(database.db);
    transactions = TransactionDao(database.db);
    repository = RecurringRepositoryImpl(dao);
    service = RecurringService(repository);
  });

  Future<RecurringTransaction> addRule({
    required DateTime start,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final id = await dao.insert(
      RecurringTransaction(
        id: 0,
        accountId: 1,
        categoryId: 1,
        type: TransactionType.expense,
        amount: 100,
        title: 'Rent',
        frequency: frequency,
        startDate: start,
        nextRunDate: start,
        endDate: endDate,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await dao.findById(id))!;
  }

  Future<int> transactionCount() async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.transactions}',
    );
    return rows.first['c']! as int;
  }

  Future<int> occurrenceCount() async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.recurringOccurrences}',
    );
    return rows.first['c']! as int;
  }

  DateTime monthsAgo(int n) =>
      AppDate.addMonths(AppDate.startOfDay(DateTime.now()), -n);

  group('occurrence ledger', () {
    test(
      'records one entry per posted occurrence, linked to its transaction',
      () async {
        final rule = await addRule(start: monthsAgo(2));
        await dao.postDueOccurrences(rule);

        final occurrences = await dao.findOccurrences(rule.id);
        expect(occurrences, hasLength(3));
        expect(await transactionCount(), 3);
        expect(
          occurrences.every((o) => o.hasTransaction),
          isTrue,
          reason: 'each occurrence points at the transaction it created',
        );
      },
    );

    test('answers whether a specific occurrence was processed', () async {
      final start = monthsAgo(1);
      final rule = await addRule(start: start);
      await dao.postDueOccurrences(rule);

      expect(await dao.isOccurrenceProcessed(rule.id, start), isTrue);
      expect(
        await dao.isOccurrenceProcessed(rule.id, AppDate.addMonths(start, 1)),
        isTrue,
      );
      // Next month has not come round yet.
      expect(
        await dao.isOccurrenceProcessed(rule.id, AppDate.addMonths(start, 2)),
        isFalse,
      );
      // A day the rule never lands on.
      expect(
        await dao.isOccurrenceProcessed(
          rule.id,
          start.add(const Duration(days: 3)),
        ),
        isFalse,
      );
    });

    test('is keyed by day, not by time of day', () async {
      final start = monthsAgo(1);
      final rule = await addRule(start: start);
      await dao.postDueOccurrences(rule);

      // Same calendar day, different clock time.
      final sameDayLater = DateTime(start.year, start.month, start.day, 23, 45);
      expect(await dao.isOccurrenceProcessed(rule.id, sameDayLater), isTrue);
    });
  });

  group('duplicate prevention', () {
    test('a second run posts nothing new', () async {
      await addRule(start: monthsAgo(2));

      await service.runDue();
      final afterFirst = await transactionCount();
      await service.runDue();

      expect(afterFirst, 3);
      expect(await transactionCount(), afterFirst);
      expect(await occurrenceCount(), 3);
    });

    test(
      'two overlapping runs holding the same stale rule post once',
      () async {
        // Reproduces the real hazard: the startup catch-up and the "Run now"
        // button both read the rule before either commits, so both hold a copy
        // whose next_run_date is still the original.
        final rule = await addRule(start: monthsAgo(2));

        final results = await Future.wait([
          dao.postDueOccurrences(rule),
          dao.postDueOccurrences(rule),
        ]);

        expect(
          await transactionCount(),
          3,
          reason: 'no occurrence posted twice',
        );
        expect(results.reduce((a, b) => a + b), 3);
      },
    );

    test('a rewound cursor cannot replay occurrences already posted', () async {
      final rule = await addRule(start: monthsAgo(2));
      await dao.postDueOccurrences(rule);
      expect(await transactionCount(), 3);

      // Whatever the cause — a bad edit, a restored backup, a bug — the cursor
      // is back at the start. The ledger, not the cursor, is what refuses.
      await db.update(
        Tables.recurringTransactions,
        {RecurringColumns.nextRunDate: AppDate.toDb(rule.startDate)},
        where: 'id = ?',
        whereArgs: [rule.id],
      );

      final posted = await dao.postDueOccurrences(
        (await dao.findById(rule.id))!,
      );

      expect(posted, 0);
      expect(await transactionCount(), 3);
    });

    test('deleting a generated transaction does not resurrect it', () async {
      final rule = await addRule(start: monthsAgo(1));
      await dao.postDueOccurrences(rule);

      final rows = await db.query(Tables.transactions, limit: 1);
      await transactions.delete(rows.first['id']! as int);
      expect(await transactionCount(), 1);

      // Rewind so the catch-up would otherwise reach that day again.
      await db.update(
        Tables.recurringTransactions,
        {RecurringColumns.nextRunDate: AppDate.toDb(rule.startDate)},
        where: 'id = ?',
        whereArgs: [rule.id],
      );
      await dao.postDueOccurrences((await dao.findById(rule.id))!);

      expect(
        await transactionCount(),
        1,
        reason: 'a deliberately deleted transaction must stay deleted',
      );
    });

    test('deleting a rule clears its ledger', () async {
      final rule = await addRule(start: monthsAgo(1));
      await dao.postDueOccurrences(rule);
      expect(await occurrenceCount(), 2);

      await dao.delete(rule.id);

      expect(await occurrenceCount(), 0, reason: 'cascade removes the ledger');
      expect(
        await transactionCount(),
        2,
        reason: 'transactions already recorded are kept',
      );
    });

    test('an inactive rule posts nothing even if called directly', () async {
      final rule = await addRule(start: monthsAgo(2));
      await dao.setActive(rule.id, false);

      expect(await dao.postDueOccurrences(rule), 0);
      expect(await transactionCount(), 0);
    });
  });

  group('upcoming schedule', () {
    test('projects future dates without writing them', () async {
      final tomorrow = AppDate.startOfDay(
        DateTime.now().add(const Duration(days: 1)),
      );
      await addRule(start: tomorrow);

      final upcoming = (await repository.getUpcoming()).dataOrNull!;

      expect(upcoming, hasLength(3));
      expect(upcoming.first.date, tomorrow);
      expect(upcoming.first.isDue, isFalse);
      expect(await occurrenceCount(), 0, reason: 'nothing is written ahead');
    });

    test('merges rules and orders soonest first', () async {
      final today = AppDate.startOfDay(DateTime.now());
      await addRule(
        start: today.add(const Duration(days: 5)),
        frequency: RecurrenceFrequency.yearly,
      );
      await addRule(
        start: today.add(const Duration(days: 2)),
        frequency: RecurrenceFrequency.yearly,
      );

      final upcoming = (await repository.getUpcoming()).dataOrNull!;

      expect(upcoming.first.date, today.add(const Duration(days: 2)));
      expect(upcoming[1].date, today.add(const Duration(days: 5)));
    });

    test('stops at the end date', () async {
      final today = AppDate.startOfDay(DateTime.now());
      await addRule(
        start: today.add(const Duration(days: 1)),
        frequency: RecurrenceFrequency.daily,
        endDate: today.add(const Duration(days: 2)),
      );

      final upcoming = (await repository.getUpcoming()).dataOrNull!;

      expect(upcoming, hasLength(2));
    });

    test('a paused rule contributes nothing', () async {
      final rule = await addRule(
        start: AppDate.startOfDay(DateTime.now()).add(const Duration(days: 1)),
      );
      await dao.setActive(rule.id, false);

      expect((await repository.getUpcoming()).dataOrNull, isEmpty);
    });
  });
}
