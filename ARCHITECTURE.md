# Architecture

Offline-first personal finance app. **Clean Architecture + GetX** (state, DI,
routing) with **sqflite** as the only source of truth. No network layer, no
cloud services — everything lives in a local SQLite database.

## Dependency rule

```
presentation  ──▶  domain  ◀──  data
```

Dependencies point **inward**. `domain/` is pure Dart: no Flutter, no GetX, no
sqflite. Outer layers depend on the interfaces it declares, never the reverse.

## Layout

```
lib/
├── main.dart               init DI → runApp → catch up recurring transactions
├── app.dart                GetMaterialApp: theme, routes, text-scale clamp
├── di/
│   └── dependency_injection.dart   global singletons (database, DAOs, repos)
├── routes/
│   ├── app_routes.dart     route name constants
│   ├── app_bindings.dart   per-route controller wiring
│   └── app_pages.dart      GetPage table
│
├── core/                   framework-facing, feature-agnostic
│   ├── base/               BaseController, ViewState
│   ├── constants/          app constants, setting keys, currencies
│   ├── database/           schema, versioned migrations, seed data, opener
│   ├── enums/              transaction/account/budget/recurrence/goal types
│   ├── errors/             exceptions (data) → failures (domain)
│   ├── theme/              colours, text styles, ThemeData, icon registry
│   ├── utils/              Result, dates, ranges, validators, formatters
│   └── widgets/            cards, charts, pickers, state views
│
├── data/                   sqflite implementation
│   ├── local/daos/         one DAO per aggregate; all SQL lives here
│   ├── models/             row ⇄ entity mappers
│   └── repositories/       contract impls; exception → Failure boundary
│
├── domain/                 pure business layer
│   ├── entities/           Account, MoneyTransaction, Budget, Goal, …
│   ├── repositories/       abstract contracts
│   └── services/           rules spanning repositories (recurring catch-up)
│
└── features/<module>/presentation/
    ├── controllers/        GetxController; orchestrates repositories
    ├── bindings/           (see routes/app_bindings.dart)
    ├── pages/              GetView screens
    └── widgets/            feature-local widgets
```

**Modules:** shell · dashboard · transactions · accounts · categories · budgets
· plans · goals · recurring · reports · more · settings

## Two deliberate deviations from the original boilerplate

1. **`domain/` and `data/` are top-level, not per-feature.** Twelve modules share
   one bounded context — the dashboard, reports and budgets all read
   transactions. Feature-scoped domain layers would force cross-feature imports.
2. **No per-action `UseCase` classes.** Controllers call repositories directly;
   logic that spans repositories lives in `domain/services/`. Sixty passthrough
   classes would add indirection without behaviour.

## How data flows

```
Page → Controller → Repository (contract) → RepositoryImpl → DAO → sqflite
                          ▲                       │
                          └───── Result<T> ───────┘
```

Errors travel as values, never as exceptions crossing a layer:

- DAOs let sqflite throw.
- `guard()` in `data/repositories/repository_guard.dart` catches everything and
  maps it to a `Failure` — this is the only place `DatabaseException` is handled.
- Everything above receives `Result<T>`: `Success` or `Failed`.

> `Failed` is named that way deliberately: an `Error` variant would collide with
> `dart:core.Error`, so a `case Error(...)` in a file missing the import would
> silently match the wrong type.

## Database

Schema version and migrations: `core/database/migrations.dart`. Every version is
one entry in `kMigrations`; `applyMigrations` replays only what an install is
missing, in version order. **Never edit a shipped migration — append a new one
and bump `kDatabaseVersion`.** Editing one would skip existing installs and give
fresh installs a schema no upgrade path ever produced.

sqflite runs `onCreate` and `onUpgrade` inside a transaction, so a failing
statement rolls the step back and the stored version stays put; the next launch
retries from the same place rather than landing half-migrated. A failure is
wrapped in `MigrationException`, which names the version and statement — a bare
SQL error gives no clue which step produced it.

**Downgrade fails rather than deleting.** sqflite's `onDatabaseDowngradeDelete`
would drop the file and start over; for a ledger that is silent, unrecoverable
loss, so opening a newer database throws `DatabaseDowngradeException` and leaves
the data untouched.

**Startup failure is recoverable.** `main()` catches an open/migration failure
and runs `StartupFailureApp` with the reason and a retry, instead of leaving a
blank window with the cause only in the logs.

Tables: `accounts`, `categories`, `transactions`, `budgets`, `spending_plans`,
`spending_plan_items`, `financial_goals`, `goal_contributions`,
`recurring_transactions`, `app_settings`.

**Constraints do real work.** `CHECK (amount > 0)`, `CHECK (type <> 'transfer'
OR to_account_id IS NOT NULL)`, unique category names per type, and
`ON DELETE CASCADE` from accounts to transactions are enforced by SQLite, not
just by Dart. Foreign keys are enabled per connection in `onConfigure` — SQLite
has them off by default.

**Dates** are stored as ISO-8601 local strings without a timezone suffix, so
lexicographic ordering equals chronological ordering and a day can be extracted
with `substr(column, 1, 10)`.

### Query paths

Every filtered query is built by `TransactionDao._buildWhere`, which appends
`?` placeholders and pushes values into a bound argument list — user input never
reaches SQL text. `IN` clauses build their placeholders from
`List.filled(n, '?')`, and `LIKE` searches escape `%` and `_` with an explicit
`ESCAPE` clause so a typed `%` matches literally.

`TransactionRepository` exposes the named queries (`getToday`, `getThisWeek`,
`getThisMonth`, `getByDateRange`, `getByCategory`, `getByAccount`, `getIncome`,
`getExpenses`, `getTransfers`) and the aggregates (`getTotals`,
`getTotalIncome`, `getTotalExpenses`, `getCategorySpending`,
`getDailySpending`). Each composes onto a `TransactionFilter`, so a total always
describes exactly the rows the list is showing.

### Integrity invariants

- **Account balances** are maintained incrementally inside the same SQL
  transaction as the row that changes them. An update reverses the stored row's
  effect before applying the new one, so changing an amount, account or type can
  never leave a balance stale. `AccountDao.recalculateAll()` rebuilds every
  balance from the ledger and is verified by test to agree with the incremental
  path.
- **Goal totals** are recomputed from the contribution ledger on every write, so
  `current_amount` cannot drift from its history.
- **Recurring catch-up** posts all missed occurrences and advances the schedule
  cursor in one transaction — a crash mid-way cannot double-post on next launch.
  Capped at `RecurringDao.maxOccurrencesPerRun`.

## GetX conventions

```
UI (GetView / Obx)
  ↓  reads state, calls methods
GetxController          — state and orchestration, no SQL
  ↓
Repository (contract)   — domain-owned interface
  ↓
RepositoryImpl → DAO    — the only layer that writes SQL
  ↓
AppDatabase → SQLite
```

- **Widgets never touch repositories.** Anything a screen needs goes through
  its controller; anything a sheet needs to construct goes through a binding.
- **Controllers never see the data layer.** They import `domain/`, never
  `data/` or `package:sqflite`.
- **`Rx` only where the UI must react.** Everything derived — budget roll-ups,
  savings rate, category shares — is a plain getter or a domain value object,
  not another observable to keep in sync.
- **`Obx` wraps the smallest widget that reads an observable.** A loading gate
  swaps a `const` body rather than wrapping the whole form, so a rebuild is one
  widget swap instead of a tree walk.
- **Bindings live with their feature** in `presentation/bindings/`, registered
  on the `GetPage`. `Get.lazyPut` keeps a controller unbuilt until its page
  asks; the shell's tab controllers add `fenix: true` so one disposed during a
  deep back-navigation can come back.
- **Global singletons** (database, DAOs, repositories, `AppEvents`,
  `CurrencyFormatter`, `SettingsController`) are `permanent: true` in
  `di/dependency_injection.dart`. Mutable statics are not used for application
  state — the currency symbol lives in an injected `CurrencyFormatter`, not a
  global, so it has one source of truth and resets with `Get.reset()`.

## Spending plans

A plan answers "how much can I spend before I spend it". The user sets the
income they expect for a month and splits it across categories; **actual
spending is never entered** — it comes from the transactions already recorded,
matched by category within the plan's month.

`expectedIncome` is the plan's ceiling. It maps to the `total_limit` column,
which shipped before the concept had a name; `SpendingPlanMapper` is the only
place the two meet.

- `unallocated` = income − planned — what is still free to assign
- `remaining` = income − spent — what is left to spend
- Per category: planned, spent, remaining and percentage used

`SpendingWarning` classifies consumption at the thresholds the brief calls for:
70%, 90%, 100%, and beyond. It drives the chip, the bar colour and the
plan-level banner, so one rule decides all three rather than each widget
picking its own cutoff.

Copying last month's plan writes the plan and every allocation in **one SQL
transaction** — a half-copied plan would understate what the user had
allocated, and they would have no way to notice.

## Transactions

**Search** covers title, note, description and category name. Category matching
uses `EXISTS` rather than a join, because `count` and the aggregate queries
share the same `WHERE` clause and a join there would change their row counts.
`LIKE` escapes `%` and `_`, so a typed `100%` matches literally.

**Sort** is a closed `TransactionSort` enum mapped to fixed `ORDER BY`
fragments — a free-form sort string would be user input reaching SQL text.
Every ordering ends with the row id: without a tiebreaker, rows sharing a
timestamp or amount can reshuffle between pages and appear twice or not at all.

**Grouping follows the sort.** Date orders keep day sections with a net per
day; amount and title orders interleave days, so the list switches to a flat
view with the date on each row instead of a header above almost every one.

**Deleting** asks first, then runs as one SQL transaction that removes the row
and reverses its effect on the affected account balances. It emits
`DataChange.transactions`, which refreshes the dashboard totals, the ledger,
budget spend and spending-plan progress. Goals are not touched: their totals
come from `goal_contributions`, not from transactions.

## Keeping screens in sync

The shell keeps tab bodies alive, so a transaction added from the floating
action button would otherwise leave the dashboard, ledger and reports showing
stale figures. `core/events/app_events.dart` broadcasts typed `DataChange`
events; controllers subscribe to the kinds they care about and reload
themselves. Emit after a successful write, and dispose the returned `Worker` in
`onClose`.

Listeners reload **only what a change invalidates**. `DashboardController`
maps each `DataChange` to the sections it affects: a transaction refreshes
totals, the recent list, budget spend and plan progress, but not goals; a goal
refreshes goals alone; a recurring-schedule edit refreshes nothing, because
posting one emits `DataChange.transactions` instead. Reloading every section on
every event meant saving a goal re-queried the ledger.

## Two GetX pitfalls this codebase works around

1. **`Get.back()` silently does nothing while a snackbar is open.** Its first
   statement is `if (isSnackbarOpen && !closeOverlays) { closeCurrentSnackbar();
   return; }` — so a form that shows "Saved" and then navigates back would
   dismiss its own snackbar and never pop, stranding the user on a form whose
   data was already written. Pops go through `Navigator.pop` instead; see
   `core/utils/app_navigation.dart`. After an `await`, capture the navigator
   before the gap.
2. **`Get` extends `BuildContext` with `theme`, `textTheme` and `isDarkMode`.**
   Redefining those in an app-level extension makes every call site ambiguous,
   so `core/utils/extensions.dart` only adds names GetX does not already
   provide.

## Dashboard

Sections, in the order they answer questions: header (greeting, date, settings)
→ balance card (total, account scope, hide toggle) → period selector → quick
actions → savings and today's spend → budget status → spending overview →
recent activity → spending plan → goals.

**Account scope.** The balance card's chip picks one account or all of them.
Scoping pushes an `account_id = ?` predicate into the totals, breakdown and
trend queries rather than filtering rows in Dart, and swaps the balance for
that account's own. Budgets, plans and goals are not account-scoped, so
changing the scope reloads only the summary and the recent list.

**Hidden balances.** The toggle masks every monetary figure while leaving
context ("0% of income kept", "Top: Food & Drinks") readable. The choice is
persisted in `app_settings`, so opening the app in public does not reveal
figures first and hide them after.

**Query budget.** A full load is 12 statements: the headline totals are one
conditional aggregate covering the current period, the previous period, today
and this month in a single scan — those were four separate queries — plus the
account balance, the category breakdown and its grand total, the trend, recent
rows, the account list, budget statuses, the current plan (3), and goals.
Everything starts together and is awaited in order, so it costs one round trip
of wall time.

## Performance

- Reports and dashboards are indexed `GROUP BY` aggregates. No screen loads
  transaction rows into Dart to sum them.
- Budget statuses use one correlated-subquery pass, not a query per budget.
- The ledger paginates in SQL (`LIMIT`/`OFFSET`) and appends pages; it never
  refetches rows already in memory.
- The dashboard starts its reads concurrently and awaits them in order, so it
  costs one round trip of wall time rather than five.
- List rows carry their category and account names from a join — no N+1 lookups.
- Tab bodies are built lazily and kept alive by an `IndexedStack`, so switching
  tabs re-runs no queries.
- `Obx` scopes are kept narrow: each observable is read inside the smallest
  widget that needs it.

## Security & privacy

- All data stays on device. There is no network layer in the app.
- `AppLogger` is stripped in release builds; the repository guard logs error
  *types*, never row values.
- Snackbars and logs never include amounts or account names.
- Every write is parameterised — user input is bound, never interpolated into
  SQL. `LIKE` searches escape `%` and `_` with an explicit `ESCAPE` clause.
- `app_settings` holds preferences only. No credentials are ever stored.

## Testing

`test/` runs against the real schema on an in-memory database
(`sqflite_common_ffi`), so migrations, constraints and SQL are all exercised:

| File | Covers |
|---|---|
| `database/schema_test.dart` | tables, FK enforcement, CHECK constraints, cascades, seed |
| `data/transaction_dao_test.dart` | balance maintenance across insert/update/delete/transfer, LIKE escaping |
| `data/transaction_repository_test.dart` | validation rules, cent rounding, pagination |
| `data/analytics_dao_test.dart` | totals, savings rate, transfer exclusion, breakdowns, trends |
| `data/budget_dao_test.dart` | spend pairing, overall budgets, exceeded/at-risk, overlap detection |
| `data/goal_dao_test.dart` | contribution roll-up, withdrawals, achieved transitions |
| `data/spending_plan_dao_test.dart` | planned vs actual, unallocated, over-allocation |
| `domain/recurring_service_test.dart` | catch-up posting, idempotency, end dates, safety cap |

Run with `flutter test`.

## Adding a feature

1. `domain/entities/<name>.dart`
2. `domain/repositories/<name>_repository.dart` (abstract)
3. `data/local/daos/<name>_dao.dart` — all SQL
4. `data/models/<name>_mapper.dart` — row ⇄ entity
5. `data/repositories/<name>_repository_impl.dart` — wrap DAO calls in `guard()`
6. `features/<name>/presentation/` — controller extending `BaseController`, page
7. Register the repository in `di/dependency_injection.dart`, the controller in
   `routes/app_bindings.dart`, and the route in `app_routes.dart` + `app_pages.dart`

## Adding a database column

1. Append a `Migration` to `kMigrations` with `ALTER TABLE …`
2. Bump `kDatabaseVersion`
3. Add the column constant to `core/database/db_tables.dart`
4. Read/write it in the mapper
