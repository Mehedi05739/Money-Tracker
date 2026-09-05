import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/events/app_events.dart';

void main() {
  late AppEvents events;

  setUp(() => events = AppEvents());

  test('notifies listeners registered for that kind', () {
    var calls = 0;
    final worker = events.listen(const [DataChange.transactions], () => calls++);
    addTearDown(worker.dispose);

    events.emit(DataChange.transactions);

    expect(calls, 1);
  });

  test('ignores kinds a listener did not ask for', () {
    var calls = 0;
    final worker = events.listen(const [DataChange.goals], () => calls++);
    addTearDown(worker.dispose);

    events.emit(DataChange.transactions);

    expect(calls, 0);
  });

  test('fires again when the same kind is emitted twice', () {
    var calls = 0;
    final worker = events.listen(const [DataChange.transactions], () => calls++);
    addTearDown(worker.dispose);

    events
      ..emit(DataChange.transactions)
      ..emit(DataChange.transactions);

    expect(calls, 2, reason: 'a repeated change must not be swallowed');
  });

  test('notifies every interested listener', () {
    var dashboard = 0;
    var reports = 0;
    final a = events.listen(
      const [DataChange.transactions, DataChange.budgets],
      () => dashboard++,
    );
    final b = events.listen(const [DataChange.transactions], () => reports++);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    events.emit(DataChange.transactions);
    events.emit(DataChange.budgets);

    expect(dashboard, 2);
    expect(reports, 1);
  });

  test('a disposed listener stops receiving events', () {
    var calls = 0;
    final worker = events.listen(const [DataChange.transactions], () => calls++);

    events.emit(DataChange.transactions);
    worker.dispose();
    events.emit(DataChange.transactions);

    expect(calls, 1);
  });
}
