import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/recurrence_frequency.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/utils/date_utils.dart';
import 'package:money_tracker/data/local/daos/account_dao.dart';
import 'package:money_tracker/data/local/daos/recurring_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/data/repositories/recurring_repository_impl.dart';
import 'package:money_tracker/domain/entities/recurring_transaction.dart';
import 'package:money_tracker/domain/repositories/transaction_repository.dart';
import 'package:money_tracker/domain/services/recurring_service.dart';

import '../helpers/test_database.dart';

void main() {
  late RecurringDao recurringDao;
  late TransactionDao transactionDao;
  late AccountDao accountDao;
  late RecurringService service;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    recurringDao = RecurringDao(database.db);
    transactionDao = TransactionDao(database.db);
    accountDao = AccountDao(database.db);
    service = RecurringService(RecurringRepositoryImpl(recurringDao));
  });

  Future<RecurringTransaction> addRule({
    required DateTime start,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    DateTime? endDate,
    double amount = 100,
  }) async {
    final now = DateTime.now();
    final id = await recurringDao.insert(
      RecurringTransaction(
        id: 0,
        accountId: 1,
        categoryId: 1,
        type: TransactionType.expense,
        amount: amount,
        title: 'Rent',
        frequency: frequency,
        startDate: start,
        nextRunDate: start,
        endDate: endDate,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await recurringDao.findById(id))!;
  }

  test('posts one transaction per missed occurrence', () async {
    await addRule(
      start: AppDate.addMonths(AppDate.startOfDay(DateTime.now()), -3),
    );

    final report = await service.runDue();

    // Three months back, inclusive of today's month boundary crossings.
    expect(report.posted, greaterThanOrEqualTo(3));
    expect(report.rulesRun, 1);

    final posted = await transactionDao.find(
      filter: const TransactionFilter(),
      limit: 50,
    );
    expect(posted, hasLength(report.posted));
    expect(posted.every((t) => t.isRecurringInstance), isTrue);
  });

  test('moves the account balance for every posted occurrence', () async {
    await addRule(
      start: AppDate.addMonths(AppDate.startOfDay(DateTime.now()), -2),
      amount: 50,
    );

    final report = await service.runDue();
    final balance = (await accountDao.findById(1))!.currentBalance;

    expect(balance, -50.0 * report.posted);
  });

  test('is idempotent — a second run posts nothing new', () async {
    await addRule(
      start: AppDate.addMonths(AppDate.startOfDay(DateTime.now()), -2),
    );

    final first = await service.runDue();
    final second = await service.runDue();

    expect(first.posted, greaterThan(0));
    expect(second.posted, 0);
  });

  test('does not post a rule whose next run is still in the future', () async {
    await addRule(start: DateTime.now().add(const Duration(days: 10)));

    final report = await service.runDue();

    expect(report.posted, 0);
    expect(await transactionDao.count(const TransactionFilter()), 0);
  });

  test('stops at the end date and deactivates the rule', () async {
    final start = AppDate.addMonths(AppDate.startOfDay(DateTime.now()), -6);
    final rule = await addRule(
      start: start,
      endDate: AppDate.addMonths(start, 2),
    );

    final report = await service.runDue();
    final reloaded = await recurringDao.findById(rule.id);

    expect(report.posted, 3, reason: 'start month plus two');
    expect(reloaded!.isActive, isFalse);
  });

  test('advances daily rules without exceeding the safety cap', () async {
    await addRule(
      start: AppDate.startOfDay(DateTime.now())
          .subtract(const Duration(days: 400)),
      frequency: RecurrenceFrequency.daily,
    );

    final report = await service.runDue();

    expect(report.posted, RecurringDao.maxOccurrencesPerRun);
  });
}
