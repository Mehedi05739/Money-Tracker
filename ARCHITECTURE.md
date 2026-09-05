# Architecture

Clean Architecture + GetX (state management, DI, routing).

## Dependency rule

```
presentation  ──▶  domain  ◀──  data
```

Dependencies point **inward**. `domain/` is pure Dart — no Flutter, no GetX, no
JSON. Outer layers depend on the interfaces it declares, never the reverse.

## Layout

```
lib/
├── main.dart                  entry point: init DI, run app
├── app.dart                   GetMaterialApp: theme, routes
├── di/
│   └── dependency_injection.dart   app-wide singletons (permanent)
├── routes/
│   ├── app_routes.dart        route name constants only
│   └── app_pages.dart         GetPage table: page + binding per route
├── core/                      shared, feature-agnostic
│   ├── base/                  BaseController, ViewState
│   ├── constants/             app constants, storage keys
│   ├── errors/                exceptions (data) → failures (domain)
│   ├── network/               ApiClient (GetConnect), endpoints
│   ├── services/              StorageService abstraction
│   ├── theme/                 colors, text styles, ThemeData
│   ├── usecases/              UseCase contracts
│   ├── utils/                 Result, logger, extensions
│   └── widgets/               loader, error, empty, StateView
└── features/<feature>/
    ├── domain/
    │   ├── entities/          business objects
    │   ├── repositories/      abstract contracts
    │   └── usecases/          one business action each
    ├── data/
    │   ├── models/            entity + fromJson/toJson
    │   ├── datasources/       remote (HTTP) / local (cache)
    │   └── repositories/      contract impl, exception → failure
    └── presentation/
        ├── controllers/       GetxController, calls use cases
        ├── bindings/          feature DI graph
        ├── pages/             GetView screens
        └── widgets/           feature-local widgets
```

## How a request flows

```
Page → Controller → UseCase → Repository (contract)
                                   ↓
                       RepositoryImpl → RemoteDataSource → ApiClient → HTTP
                                     ↘ LocalDataSource  → StorageService
```

Errors travel back as values, not exceptions:

- Data sources throw `AppException` subtypes.
- `RepositoryImpl` catches them and calls `mapExceptionToFailure`.
- Everything above the repository receives `Result<T>` — `Success` or `Error`.

## Error handling

`Result<T>` (`core/utils/result.dart`) is a sealed success-or-failure type, so no
`dartz` dependency is needed:

```dart
result.fold(
  onSuccess: (data) => ...,
  onError: (failure) => ...,
);
```

## Screen state

Controllers extend `BaseController`, which exposes one observable `ViewState`
(`Idle | Loading | Loaded | Empty | Error`) instead of scattered boolean flags.
`execute()` runs a use case and moves that state automatically:

```dart
await execute(
  () => _getTransactions(const GetTransactionsParams()),
  onSuccess: transactions.assignAll,
);
```

`StateView` renders the matching widget, so pages only describe the loaded case.

## Dependency injection

- **Global** (`DependencyInjection.init()`): `StorageService`, `ApiClient` —
  `permanent: true`, created before `runApp`.
- **Per feature** (`Bindings` on each `GetPage`): data sources → repository →
  use cases → controller, all `lazyPut` so they are built on first use and
  disposed when the route is popped.

## Adding a feature

1. `features/<name>/domain/entities/<name>_entity.dart`
2. `features/<name>/domain/repositories/<name>_repository.dart` (abstract)
3. `features/<name>/domain/usecases/<action>.dart`
4. `features/<name>/data/models/<name>_model.dart` (`fromJson` / `toJson`)
5. `features/<name>/data/datasources/` remote + local
6. `features/<name>/data/repositories/<name>_repository_impl.dart`
7. `features/<name>/presentation/` controller, binding, page
8. Register the route in `routes/app_routes.dart` and `routes/app_pages.dart`

## Placeholders to replace

| What | Where | Replace with |
|---|---|---|
| In-memory storage | `core/services/storage_service.dart` | `get_storage` / `shared_preferences` impl |
| Fake API | `features/transaction/data/datasources/fake_transaction_remote_datasource.dart` | bind `TransactionRemoteDataSourceImpl` in `TransactionBinding` |
| Base URL | `core/network/api_endpoints.dart` | your API host |

## Testing

The domain layer has no framework dependencies, so use cases are tested with a
hand-written fake repository — no mocking package, no `WidgetTester`. See
`test/widget_test.dart`.
