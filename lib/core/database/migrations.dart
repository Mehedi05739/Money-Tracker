import 'package:sqflite/sqflite.dart';

/// One entry per schema version. [Migration.version] 1 is the initial schema;
/// every later version must be additive and idempotent so an upgrade from any
/// older install replays cleanly.
///
/// Never edit a shipped migration — add a new one.
class Migration {
  const Migration({required this.version, required this.statements});

  final int version;
  final List<String> statements;
}

/// Bumped whenever a migration is appended.
const int kDatabaseVersion = 1;

const List<Migration> kMigrations = [
  Migration(version: 1, statements: _v1),
];

Future<void> applyMigrations(
  DatabaseExecutor db, {
  required int from,
  required int to,
}) async {
  for (final migration in kMigrations) {
    if (migration.version <= from || migration.version > to) continue;
    for (final statement in migration.statements) {
      await db.execute(statement);
    }
  }
}

const List<String> _v1 = [
  '''
  CREATE TABLE accounts (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    name             TEXT    NOT NULL,
    type             TEXT    NOT NULL,
    opening_balance  REAL    NOT NULL DEFAULT 0,
    current_balance  REAL    NOT NULL DEFAULT 0,
    currency         TEXT    NOT NULL DEFAULT 'USD',
    icon             TEXT,
    color            INTEGER,
    is_archived      INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    sort_order       INTEGER NOT NULL DEFAULT 0,
    created_at       TEXT    NOT NULL,
    updated_at       TEXT    NOT NULL
  )
  ''',
  '''
  CREATE TABLE categories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL,
    type        TEXT    NOT NULL CHECK (type IN ('income', 'expense')),
    icon        TEXT,
    color       INTEGER,
    is_default  INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
    is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
    created_at  TEXT    NOT NULL,
    UNIQUE (name, type)
  )
  ''',
  '''
  CREATE TABLE recurring_transactions (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id     INTEGER NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
    category_id    INTEGER REFERENCES categories (id) ON DELETE SET NULL,
    type           TEXT    NOT NULL CHECK (type IN ('income', 'expense')),
    amount         REAL    NOT NULL CHECK (amount > 0),
    title          TEXT    NOT NULL,
    note           TEXT,
    payment_method TEXT,
    frequency      TEXT    NOT NULL,
    interval_count INTEGER NOT NULL DEFAULT 1 CHECK (interval_count > 0),
    start_date     TEXT    NOT NULL,
    end_date       TEXT,
    next_run_date  TEXT    NOT NULL,
    last_run_date  TEXT,
    is_active      INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    auto_post      INTEGER NOT NULL DEFAULT 1 CHECK (auto_post IN (0, 1)),
    created_at     TEXT    NOT NULL,
    updated_at     TEXT    NOT NULL
  )
  ''',
  '''
  CREATE TABLE transactions (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id       INTEGER NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
    to_account_id    INTEGER REFERENCES accounts (id) ON DELETE SET NULL,
    type             TEXT    NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
    amount           REAL    NOT NULL CHECK (amount > 0),
    category_id      INTEGER REFERENCES categories (id) ON DELETE SET NULL,
    title            TEXT    NOT NULL,
    description      TEXT,
    transaction_date TEXT    NOT NULL,
    payment_method   TEXT,
    note             TEXT,
    recurring_id     INTEGER REFERENCES recurring_transactions (id) ON DELETE SET NULL,
    created_at       TEXT    NOT NULL,
    updated_at       TEXT    NOT NULL,
    CHECK (type <> 'transfer' OR to_account_id IS NOT NULL),
    CHECK (to_account_id IS NULL OR to_account_id <> account_id)
  )
  ''',
  '''
  CREATE TABLE budgets (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id      INTEGER REFERENCES categories (id) ON DELETE CASCADE,
    amount           REAL    NOT NULL CHECK (amount > 0),
    period           TEXT    NOT NULL,
    start_date       TEXT    NOT NULL,
    end_date         TEXT    NOT NULL,
    alert_percentage INTEGER NOT NULL DEFAULT 80
                     CHECK (alert_percentage BETWEEN 1 AND 100),
    is_active        INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at       TEXT    NOT NULL,
    updated_at       TEXT    NOT NULL,
    CHECK (end_date >= start_date)
  )
  ''',
  '''
  CREATE TABLE spending_plans (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL,
    total_limit REAL    NOT NULL CHECK (total_limit > 0),
    start_date  TEXT    NOT NULL,
    end_date    TEXT    NOT NULL,
    status      TEXT    NOT NULL DEFAULT 'active',
    note        TEXT,
    created_at  TEXT    NOT NULL,
    updated_at  TEXT    NOT NULL,
    CHECK (end_date >= start_date)
  )
  ''',
  '''
  CREATE TABLE spending_plan_items (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id        INTEGER NOT NULL REFERENCES spending_plans (id) ON DELETE CASCADE,
    category_id    INTEGER REFERENCES categories (id) ON DELETE SET NULL,
    planned_amount REAL    NOT NULL CHECK (planned_amount >= 0),
    note           TEXT,
    created_at     TEXT    NOT NULL,
    updated_at     TEXT    NOT NULL,
    UNIQUE (plan_id, category_id)
  )
  ''',
  '''
  CREATE TABLE financial_goals (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    name           TEXT    NOT NULL,
    target_amount  REAL    NOT NULL CHECK (target_amount > 0),
    current_amount REAL    NOT NULL DEFAULT 0,
    target_date    TEXT,
    icon           TEXT,
    color          INTEGER,
    status         TEXT    NOT NULL DEFAULT 'active',
    note           TEXT,
    created_at     TEXT    NOT NULL,
    updated_at     TEXT    NOT NULL
  )
  ''',
  '''
  CREATE TABLE goal_contributions (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    goal_id        INTEGER NOT NULL REFERENCES financial_goals (id) ON DELETE CASCADE,
    account_id     INTEGER REFERENCES accounts (id) ON DELETE SET NULL,
    amount         REAL    NOT NULL CHECK (amount <> 0),
    contributed_at TEXT    NOT NULL,
    note           TEXT,
    created_at     TEXT    NOT NULL
  )
  ''',
  '''
  CREATE TABLE app_settings (
    key        TEXT PRIMARY KEY,
    value      TEXT,
    updated_at TEXT NOT NULL
  )
  ''',

  // Covering indexes for the queries the app actually runs: date-ranged
  // reports, per-account ledgers and per-category breakdowns.
  'CREATE INDEX idx_tx_date ON transactions (transaction_date DESC)',
  'CREATE INDEX idx_tx_type_date ON transactions (type, transaction_date)',
  'CREATE INDEX idx_tx_account_date ON transactions (account_id, transaction_date)',
  'CREATE INDEX idx_tx_category_date ON transactions (category_id, transaction_date)',
  'CREATE INDEX idx_tx_recurring ON transactions (recurring_id)',
  'CREATE INDEX idx_budgets_category ON budgets (category_id, is_active)',
  'CREATE INDEX idx_budgets_range ON budgets (start_date, end_date)',
  'CREATE INDEX idx_plan_items_plan ON spending_plan_items (plan_id)',
  'CREATE INDEX idx_goal_contrib_goal ON goal_contributions (goal_id, contributed_at)',
  'CREATE INDEX idx_recurring_due ON recurring_transactions (is_active, next_run_date)',
  'CREATE INDEX idx_categories_type ON categories (type, is_archived)',
  'CREATE INDEX idx_accounts_active ON accounts (is_archived, sort_order)',
];
