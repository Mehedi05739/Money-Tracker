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

## Budgets

A budget is a ceiling for a period: monthly, weekly, quarterly, yearly or a
custom range, scoped to one category or to all expenses (`category_id IS
NULL`). Spend is matched from transactions by category and date — nothing is
entered by hand.

Each budget reports amount, spend, remaining, percentage used, **days
remaining** and a **recommended daily spend** (`remaining / daysRemaining`).
`daysRemaining` is derived from the dates rather than from elapsed days:
`dayCount - elapsed + 1` returns 1 for a period that has already ended, which
would recommend spending the whole remaining balance on a day outside the
budget.

**Pausing** is its own write, not a full update — resuming should not risk
rewriting a period the user did not mean to change. A paused budget keeps its
history, raises no alerts and is excluded from roll-up totals, but stays
visible on the budgets screen: one the user cannot see is one they cannot
resume. `getStatuses(includePaused:)` is how each caller states which it wants;
the dashboard leaves it off.

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

## Financial goals

A goal stores only its own definition — name, target, target date, icon,
colour, description, status. `current_amount` is **derived**: it is the sum of
the rows in `goal_contributions`, never a number the user types. `GoalDao`
recomputes it inside the same SQL transaction as every contribution write
(`_refreshTotal`), so the stored total and the visible history can never
disagree, and `GoalDao.update` strips `current_amount` from the edit form's row
so editing a goal's name cannot silently rewrite its balance.

Contributions are a separate table, kept as history: editing one rewrites that
row rather than appending a correction, and deleting a goal cascades to its
entries. A negative amount is a withdrawal; the repository rejects one that
would take the goal below zero, measuring an *edit* against the total with the
entry's own stored amount excluded so changing −50 to −60 is not checked
against a sum that still contains the −50.

`_refreshTotal` also moves the goal between `active` and `achieved` as the
total crosses the target — including back to `active` when an edit drops it
below — while leaving an `archived` goal archived.

The pace figures come from the entity, not the UI:
`requiredMonthlyContribution` and `requiredWeeklyContribution` divide what is
left by the periods remaining, rounding the period count **up** — three-and-a-
bit months to save in is three full months plus a part month, and recommending
against the fractional figure would leave the user short. Both return `null`
once the goal is achieved or its date has passed, which is what suppresses the
hint rather than a widget-level check.

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

## Three GetX pitfalls this codebase works around

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
3. **`Rx.value = x` skips the assignment when `x ==` the value already held.**
   The domain entities originally compared on `id` alone, which reads as
   harmless — two rows with the same primary key *are* the same record — but it
   made that dedupe fire on every reload: after a goal contribution, `goal.value
   = freshGoal` was dropped and the screen kept rendering the old balance while
   the database held the new one. Entities now mix in
   `core/base/value_equality.dart` and compare every field, so an unchanged row
   still compares equal (identity lookups and dropdown matching keep working)
   while a real change gets through. `test/domain/entity_equality_test.dart`
   pins both halves.

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

## Settings

Preferences live in the `app_settings` key–value table and are loaded before
the first frame, so the theme, currency symbol and monthly boundary are right
on the very first paint rather than flashing a default.

### First day of month

The one preference that is not just a stored value. Someone paid on the 25th
thinks in cycles that run 25th to 24th, and a budget resetting on the 1st is
useless to them, so `AppDate.firstDayOfMonth` moves `startOfMonth` and
`endOfMonth` — and with them budget periods, spending plans and "This month" —
together. It is a mutable static on purpose: this is one app-wide fact, like
the locale, and threading it through every call would put a preference lookup
in the middle of pure date arithmetic. Capped at 28 so the anchor exists in
February.

### Security

The app lock stores no secret. The original brief forbids keeping credentials
in SQLite, and the way to honour that is not to hash a PIN of our own but to
have none: `local_auth` defers to the operating system, which already holds the
user's biometric and device credential. Settings persists only *whether* the
lock is on.

Enabling asks for authentication first — the user must prove they can get back
in before the door is locked behind them — and `unlock()` treats an
*unavailable* authenticator as pass, not fail, so a device whose biometrics
were removed cannot lock someone out of their own ledger.

### Notifications

`flutter_local_notifications`, scheduled on the device only. Permission is
requested when a reminder is switched on, never at startup: prompting before
the user has asked for anything is the fastest way to be refused. If permission
is declined the toggle returns to off rather than showing an "on" switch that
will never fire. Notification bodies deliberately carry no amounts — a lock
screen is a public surface.

### Data

Export is JSON: readable, inspectable, portable. Backup is a byte copy of the
SQLite file: exact, including schema version. They answer different questions,
so both exist.

Files are written beside the database, derived from the open connection's path
rather than the global `databaseFactory`, which is process-wide state anything
can reassign — a file written to one directory and looked for in another is a
backup the user cannot find.

**Restore copies contents rather than swapping the file.** The obvious
implementation — close, copy over, reopen — does not work: every DAO holds the
`Database` handle resolved at startup, so reopening leaves them all pointing at
a closed connection and the next query anywhere in the app fails with
`database_closed`. The backup is opened on its own read-only connection and its
rows copied into the live one inside a single transaction, which keeps that
connection valid and makes a failed restore leave the current data untouched.
Preferences are not part of a restore: it should bring back the ledger, not
silently change the theme.

Destructive actions go through `DangerDialog`, which requires typing a word
before the button enables, states plainly what disappears, and is not
dismissible by tapping away. A single tap is too easy to give by reflex, and
there is no undo behind it — the ledger is the only copy.

## Accounts, balances and transfers

An account carries a name, type, opening balance, current balance, currency,
icon and colour. `current_balance` is owned by the ledger, not the edit form:
`AccountDao.update` strips it, so renaming an account cannot rewrite its money,
and the opening balance is locked once the account exists because changing it
would shift every historical balance underneath the user.

### One definition of the balance rule

Balances are maintained two ways and both are needed: incrementally as each
transaction is written, and rebuilt in bulk by `recalculateAll` — the repair
path, and what an import uses instead of thousands of per-row updates.

Those two used to encode the rule separately, Dart arithmetic on one side and a
hand-written SQL `CASE` on the other, with nothing keeping them in step. A new
transaction type or a changed `TransactionType.balanceSign` would have updated
one and not the other, and the disagreement would only surface as a wrong
balance *after* a repair — the operation meant to fix the ledger would have been
the one that broke it.

`data/local/account_balance.dart` is now the single definition.
`AccountBalance.sourceDelta`/`destinationDelta` give the Dart form;
`sourceDeltaSql` generates the `CASE` from the same `balanceSign`, so a new
transaction type appears in both automatically.
`test/data/account_balance_test.dart` holds the two paths to each other across
every type, after edits and deletes, and asserts the generated SQL covers every
enum value.

### Transfers

A transfer debits its source exactly as an expense would and credits its
destination by the same amount, in one SQL transaction — so it nets to zero
across the two accounts and changes no net worth. What makes it *not* an
expense is that every reporting aggregate excludes `type = 'transfer'`, and the
schema enforces the shape: a transfer must name a destination, and that
destination cannot be the source account.

Because the row and both balance updates share one transaction, a transfer that
fails — a destination that no longer exists, say — moves neither balance and
leaves no half-written row.

### Deleting an account

Transactions *in* the account go with it; the schema cascades and the confirm
dialog says so. Transfers *into* it are the awkward case: the foreign key would
only null their destination, leaving rows that still claim to be transfers,
still debit their source, and now point nowhere — the other account's balance
would stay reduced with nothing on screen to explain where the money went.

They are reclassified as expenses in the same transaction as the delete. The
debit is identical, so no balance moves, the row stays visible in the source
account's history, and it now says something true: the money left the accounts
being tracked.

## Recurring transactions

A rule stores the commitment — title, amount, type, category, account,
frequency, start and end date, next occurrence, active flag, note. Rules are
materialised into real transactions by `RecurringService.runDue()`, called at
startup and from the "run now" button: the app is offline-first with no
background execution, so "catch up on everything missed since last launch" is
the correct model.

### Not creating duplicates

Two independent layers, and the second is the one that actually guarantees it.

The **cursor** (`next_run_date`) says where to resume. On its own that is only
as trustworthy as the procedure around it: `runDue` reads its rules up front, so
the startup catch-up overlapping with a manual run leaves both holding a copy
whose cursor is still the original, and both would post the same day.

The **ledger** is the guarantee. `recurring_occurrences` holds one row per
occurrence a rule has produced, under a unique index on
`(recurring_id, occurrence_date)`. Posting claims that row *before* writing the
transaction; a claim that collides with the index means the occurrence is
already processed, so the insert is skipped. Duplicate prevention is therefore a
database invariant, not a procedure that has to be executed carefully — a
replayed run, two overlapping runs, or a cursor rewound by a bad edit or a
restored backup all bounce off the index.

`occurrence_date` is a day key (`YYYY-MM-DD`), not a timestamp, so uniqueness
cannot be defeated by what time of day the app happened to run. Posting also
re-reads the rule inside its own SQL transaction, which is what stops a rule
paused between fetch and post from being posted anyway.

The ledger deliberately outlives the transaction it created: `transaction_id`
becomes `NULL` when that transaction is deleted, but the occurrence row stays.
Deleting a generated transaction is a decision, and the next catch-up must not
quietly undo it.

`isOccurrenceProcessed(ruleId, date)` is the direct form of the question, a
covering-index lookup. `getOccurrences(ruleId)` lists what a rule has produced.

Migration v3 creates the table and **backfills** it from transactions that
already carry a `recurring_id`, so an install upgrading from v2 starts with a
truthful ledger rather than an empty one that would report every past occurrence
as unprocessed.

### Upcoming

`getUpcoming()` projects the next occurrences across active rules from
`upcomingDates()` and sorts them. Nothing is written ahead of time: a projection
cannot drift out of step with an edited schedule the way a table of pre-written
future rows would, and there is nothing to clean up when a rule changes.

## Reports & analytics

Eight reports — income vs expense, monthly and daily spending, by category, by
account, savings trend, budget performance, plan performance — grouped into
three tabs by the question they answer, because one scroll cannot hold eight
legibly.

Every figure is a SQL aggregate. `AnalyticsRepository.getReportSnapshot` runs
five grouped queries (totals, the previous window's totals, the trend, the
category breakdown with its grand total, the account breakdown, the heaviest
day), starts them together and awaits them in order, so the screen costs one
round trip rather than one per chart. Budget and plan performance reuse
`BudgetDao.findWithSpend` and `SpendingPlanDao.findProgress`, which already join
their spend in a single pass — the report layer adds no second way to compute
the same numbers.

The one thing computed in Dart is the savings trend's running total, a prefix
sum over the buckets the database already grouped — at most a few dozen points,
never the transactions behind them. SQLite could do it with a window function,
but those need SQLite 3.25+, which is not guaranteed on the older Android system
libraries this app still runs on.

"Highest spending day" is its own `GROUP BY day ... LIMIT 1` rather than a scan
of the trend series, so it stays a real calendar day even when the chart is
bucketed by month. Both new aggregates resolve through `idx_tx_type_date`.

Filters are rolling windows — `last7Days` through `lastYear` — distinct from the
calendar presets the dashboard uses: "30 days" is the last thirty days wherever
today falls, where "This month" restarts on the 1st. Picking a window longer
than about three months switches the trend to monthly buckets, since a year of
daily bars is unreadable.

### Charts

`core/widgets/charts/` holds four components, each driven by a plain data class
so no chart knows what it is plotting: `DonutChart`, `GroupedBarChart`,
`LineTrendChart`, and `MeasureBarList` — the ranked label/amount/bar row shared
by the category, account, budget and plan reports, which is what keeps those
four looking like one product.

None of them animate. A chart here is read, not watched, and a bar that grows
into place on every filter change makes comparing two periods slower rather than
nicer.

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
