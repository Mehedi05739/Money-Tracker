import '../../core/utils/logger.dart';
import '../repositories/recurring_repository.dart';

/// Result of a catch-up run, so the UI can tell the user what was posted.
class RecurringRunReport {
  const RecurringRunReport({required this.rulesRun, required this.posted});

  const RecurringRunReport.none() : rulesRun = 0, posted = 0;

  final int rulesRun;
  final int posted;

  bool get hasChanges => posted > 0;

  String get summary => posted == 1
      ? '1 recurring transaction was added'
      : '$posted recurring transactions were added';
}

/// Materialises due recurring rules into real transactions.
///
/// Run once at startup rather than on a timer: the app is offline-first and has
/// no background execution, so "catch up on everything missed since last
/// launch" is the correct model. Each rule is posted in its own SQL
/// transaction, so one bad rule cannot block the rest.
class RecurringService {
  const RecurringService(this._repository);

  final RecurringRepository _repository;

  Future<RecurringRunReport> runDue() async {
    final due = await _repository.getDue();

    return due.fold(
      onSuccess: (rules) async {
        if (rules.isEmpty) return const RecurringRunReport.none();

        var posted = 0;
        var rulesRun = 0;

        for (final rule in rules) {
          final result = await _repository.postDueOccurrences(rule);
          result.fold(
            onSuccess: (count) {
              if (count > 0) {
                posted += count;
                rulesRun += 1;
              }
              return null;
            },
            onError: (failure) {
              // Log the rule id only — never its amount or title.
              AppLogger.w(
                'Recurring rule ${rule.id} could not be posted: '
                '${failure.runtimeType}',
                name: 'RECURRING',
              );
              return null;
            },
          );
        }

        return RecurringRunReport(rulesRun: rulesRun, posted: posted);
      },
      onError: (failure) async {
        AppLogger.w(
          'Could not load due recurring rules: ${failure.runtimeType}',
          name: 'RECURRING',
        );
        return const RecurringRunReport.none();
      },
    );
  }
}
