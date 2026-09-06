import '../../core/database/db_tables.dart';

/// One group of records in the export file.
///
/// The export is described here rather than being "whatever the tables happen
/// to contain", so the file has a contract: what it carries, what each record
/// must have, and how records point at each other. Import validates against
/// this before it writes anything.
class ExportGroup {
  const ExportGroup({
    required this.key,
    required this.label,
    required this.table,
    required this.required,
    this.references = const {},
    this.identity,
  });

  /// The key this group appears under in the JSON.
  final String key;

  /// Singular, human name for one record, used in messages the user reads.
  final String label;

  final String table;

  /// Columns a record cannot be missing. Taken from the schema's NOT NULL
  /// columns that have no default — a record without one cannot be stored.
  final List<String> required;

  /// Columns holding another group's id, as column → group key. Used to rewrite
  /// links when incoming ids are renumbered.
  final Map<String, String> references;

  /// Columns that identify the same real-world thing across two databases.
  ///
  /// Where this is set, a merge reuses the existing record instead of adding a
  /// second one — importing a file that also has a "Groceries" category should
  /// not leave the user with two.
  final List<String>? identity;
}

/// The export format.
///
/// Ordered so a record is always written after whatever it points at.
/// Deliberately excludes `recurring_occurrences`: that is internal bookkeeping
/// about which schedule runs have been posted, not the user's financial data,
/// and it is rebuilt from the imported transactions afterwards.
class ExportSchema {
  const ExportSchema._();

  /// Bumped when the file shape changes, so an import can refuse a file it does
  /// not understand rather than half-loading it.
  static const int formatVersion = 2;

  /// The JSON key holding the record groups.
  static const String dataKey = 'data';

  /// The JSON key holding preferences, which are a key–value map rather than
  /// rows.
  static const String settingsKey = 'settings';

  static const List<ExportGroup> groups = [
    ExportGroup(
      key: 'accounts',
      label: 'account',
      table: Tables.accounts,
      required: ['name', 'type', 'created_at', 'updated_at'],
      identity: ['name', 'type'],
    ),
    ExportGroup(
      key: 'categories',
      label: 'category',
      table: Tables.categories,
      required: ['name', 'type', 'created_at'],
      identity: ['name', 'type'],
    ),
    ExportGroup(
      key: 'recurring_transactions',
      label: 'recurring transaction',
      table: Tables.recurringTransactions,
      required: [
        'account_id',
        'type',
        'amount',
        'title',
        'frequency',
        'start_date',
        'next_run_date',
        'created_at',
        'updated_at',
      ],
      references: {'account_id': 'accounts', 'category_id': 'categories'},
    ),
    ExportGroup(
      key: 'transactions',
      label: 'transaction',
      table: Tables.transactions,
      required: [
        'account_id',
        'type',
        'amount',
        'title',
        'transaction_date',
        'created_at',
        'updated_at',
      ],
      references: {
        'account_id': 'accounts',
        'to_account_id': 'accounts',
        'category_id': 'categories',
        'recurring_id': 'recurring_transactions',
      },
    ),
    ExportGroup(
      key: 'budgets',
      label: 'budget',
      table: Tables.budgets,
      required: [
        'amount',
        'period',
        'start_date',
        'end_date',
        'created_at',
        'updated_at',
      ],
      references: {'category_id': 'categories'},
    ),
    ExportGroup(
      key: 'spending_plans',
      label: 'spending plan',
      table: Tables.spendingPlans,
      required: [
        'name',
        'total_limit',
        'start_date',
        'end_date',
        'created_at',
        'updated_at',
      ],
    ),
    ExportGroup(
      key: 'spending_plan_items',
      label: 'spending plan item',
      table: Tables.spendingPlanItems,
      required: ['plan_id', 'planned_amount', 'created_at', 'updated_at'],
      references: {'plan_id': 'spending_plans', 'category_id': 'categories'},
    ),
    ExportGroup(
      key: 'goals',
      label: 'goal',
      table: Tables.financialGoals,
      required: ['name', 'target_amount', 'created_at', 'updated_at'],
    ),
    ExportGroup(
      key: 'goal_contributions',
      label: 'goal contribution',
      table: Tables.goalContributions,
      required: ['goal_id', 'amount', 'contributed_at', 'created_at'],
      references: {'goal_id': 'goals', 'account_id': 'accounts'},
    ),
  ];

  static ExportGroup byKey(String key) =>
      groups.firstWhere((group) => group.key == key);
}
