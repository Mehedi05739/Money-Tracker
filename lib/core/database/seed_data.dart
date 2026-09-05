import 'package:sqflite/sqflite.dart';

import '../enums/account_type.dart';
import '../enums/transaction_type.dart';
import '../utils/date_utils.dart';
import 'db_tables.dart';

/// First-run content: one cash account and a starter category set, so the user
/// can record a transaction immediately instead of configuring the app first.
class SeedData {
  const SeedData._();

  static Future<void> populate(DatabaseExecutor db) async {
    final now = AppDate.toDb(DateTime.now());
    final batch = db.batch();

    batch.insert(Tables.accounts, {
      AccountColumns.name: 'Cash',
      AccountColumns.type: AccountType.cash.name,
      AccountColumns.openingBalance: 0.0,
      AccountColumns.currentBalance: 0.0,
      AccountColumns.currency: 'USD',
      AccountColumns.icon: 'wallet',
      AccountColumns.color: 0xFF2E7D62,
      AccountColumns.sortOrder: 0,
      AccountColumns.createdAt: now,
      AccountColumns.updatedAt: now,
    });

    for (final category in _defaultCategories) {
      batch.insert(Tables.categories, {
        CategoryColumns.name: category.name,
        CategoryColumns.type: category.type.name,
        CategoryColumns.icon: category.icon,
        CategoryColumns.color: category.color,
        CategoryColumns.isDefault: 1,
        CategoryColumns.createdAt: now,
      });
    }

    await batch.commit(noResult: true);
  }
}

class _SeedCategory {
  const _SeedCategory(this.name, this.type, this.icon, this.color);
  final String name;
  final TransactionType type;
  final String icon;
  final int color;
}

const List<_SeedCategory> _defaultCategories = [
  // Expenses
  _SeedCategory('Food & Drinks', TransactionType.expense, 'restaurant', 0xFFEF6C00),
  _SeedCategory('Groceries', TransactionType.expense, 'shopping_cart', 0xFF43A047),
  _SeedCategory('Transport', TransactionType.expense, 'directions_bus', 0xFF1E88E5),
  _SeedCategory('Housing & Rent', TransactionType.expense, 'home', 0xFF6D4C41),
  _SeedCategory('Utilities', TransactionType.expense, 'bolt', 0xFFFBC02D),
  _SeedCategory('Health', TransactionType.expense, 'favorite', 0xFFE53935),
  _SeedCategory('Shopping', TransactionType.expense, 'shopping_bag', 0xFF8E24AA),
  _SeedCategory('Entertainment', TransactionType.expense, 'movie', 0xFF3949AB),
  _SeedCategory('Education', TransactionType.expense, 'school', 0xFF00897B),
  _SeedCategory('Subscriptions', TransactionType.expense, 'subscriptions', 0xFF5E35B1),
  _SeedCategory('Travel', TransactionType.expense, 'flight', 0xFF00ACC1),
  _SeedCategory('Family', TransactionType.expense, 'group', 0xFFD81B60),
  _SeedCategory('Fees & Charges', TransactionType.expense, 'receipt_long', 0xFF757575),
  _SeedCategory('Other Expense', TransactionType.expense, 'more_horiz', 0xFF546E7A),

  // Income
  _SeedCategory('Salary', TransactionType.income, 'payments', 0xFF2E7D32),
  _SeedCategory('Business', TransactionType.income, 'storefront', 0xFF00695C),
  _SeedCategory('Freelance', TransactionType.income, 'laptop', 0xFF1565C0),
  _SeedCategory('Investments', TransactionType.income, 'trending_up', 0xFF4527A0),
  _SeedCategory('Gifts', TransactionType.income, 'card_giftcard', 0xFFAD1457),
  _SeedCategory('Refunds', TransactionType.income, 'undo', 0xFF00838F),
  _SeedCategory('Other Income', TransactionType.income, 'more_horiz', 0xFF546E7A),
];
