import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/events/app_events.dart';
import 'package:money_tracker/data/local/daos/account_dao.dart';
import 'package:money_tracker/data/local/daos/category_dao.dart';
import 'package:money_tracker/data/local/daos/settings_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/data/repositories/account_repository_impl.dart';
import 'package:money_tracker/data/repositories/category_repository_impl.dart';
import 'package:money_tracker/data/repositories/settings_repository_impl.dart';
import 'package:money_tracker/data/repositories/transaction_repository_impl.dart';
import 'package:money_tracker/features/settings/presentation/controllers/settings_controller.dart';
import 'package:money_tracker/features/transactions/presentation/controllers/transaction_form_controller.dart';

import '../helpers/test_database.dart';

/// The quick-add sheet drives the amount through the controller instead of a
/// system keyboard, so these rules are the only thing between a keypad tap and
/// a malformed amount.
void main() {
  late TransactionFormController controller;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    addTearDown(Get.reset);

    final accounts = AccountRepositoryImpl(AccountDao(database.db));
    final settings = SettingsController(
      SettingsRepositoryImpl(SettingsDao(database.db)),
      accounts,
    );
    await settings.load();

    controller = TransactionFormController(
      TransactionRepositoryImpl(TransactionDao(database.db)),
      accounts,
      CategoryRepositoryImpl(CategoryDao(database.db)),
      settings,
      AppEvents(),
      seed: const TransactionFormArgs(type: TransactionType.expense),
    );
  });

  String type(String keys) {
    for (final key in keys.split('')) {
      key == '.'
          ? controller.appendDecimalPoint()
          : controller.appendDigit(key);
    }
    return controller.amountField.text;
  }

  test('types digits in order', () {
    expect(type('1234'), '1234');
  });

  test('replaces a lone leading zero rather than keeping it', () {
    expect(type('05'), '5');
  });

  test('keeps zero when it starts a decimal', () {
    expect(type('0.75'), '0.75');
  });

  test('allows only one decimal point', () {
    expect(type('12.3.4'), '12.34');
  });

  test('stops at two decimal places', () {
    expect(type('9.999'), '9.99');
  });

  test('starts a decimal with a leading zero when typed first', () {
    controller.appendDecimalPoint();
    expect(controller.amountField.text, '0.');
    expect(type('5'), '0.5');
  });

  test('caps the whole-number part', () {
    expect(
      type('12345678901234').length,
      TransactionFormController.maxWholeDigits,
    );
  });

  test('backspace removes the last character', () {
    type('420');
    controller.backspace();
    expect(controller.amountField.text, '42');
  });

  test('backspace on an empty amount is a no-op', () {
    controller.backspace();
    expect(controller.amountField.text, isEmpty);
  });

  test('clear empties the amount', () {
    type('99.50');
    controller.clearAmount();
    expect(controller.amountField.text, isEmpty);
  });

  test('editing the amount clears a stale amount error', () {
    controller.fieldErrors['amount'] = 'Amount is required';
    controller.appendDigit('1');
    expect(controller.fieldErrors.containsKey('amount'), isFalse);
  });

  test('the caret stays at the end so the next tap appends', () {
    type('75');
    expect(controller.amountField.selection.baseOffset, 2);
  });
}
