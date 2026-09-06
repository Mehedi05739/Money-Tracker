import 'export_schema.dart';

/// One thing wrong with an import file.
///
/// Carries where the problem is, not just that there is one: "transactions,
/// record 12: missing amount" is something a user can act on, where "invalid
/// file" is not.
class ImportProblem {
  const ImportProblem({required this.message, this.group, this.index});

  final String message;
  final String? group;
  final int? index;

  @override
  String toString() {
    if (group == null) return message;
    if (index == null) return '$group: $message';
    return '$group, record ${index! + 1}: $message';
  }
}

/// Raised when a file cannot be imported. Carries every problem found, not
/// just the first, so one pass tells the user everything to fix.
class ImportValidationException implements Exception {
  const ImportValidationException(this.problems);

  final List<ImportProblem> problems;

  String get summary => problems.length == 1
      ? problems.first.toString()
      : '${problems.length} problems found, starting with: ${problems.first}';

  @override
  String toString() => summary;
}

/// A validated export file, ready to write.
class ImportPayload {
  const ImportPayload({
    required this.records,
    required this.settings,
    required this.formatVersion,
    this.exportedAt,
    this.appVersion,
  });

  /// Group key → records, already checked against [ExportSchema].
  final Map<String, List<Map<String, Object?>>> records;

  final Map<String, String> settings;
  final int formatVersion;
  final DateTime? exportedAt;
  final String? appVersion;

  int get recordCount =>
      records.values.fold(0, (sum, rows) => sum + rows.length);

  bool get isEmpty => recordCount == 0 && settings.isEmpty;
}

/// Checks an export file before a single row is written.
///
/// Everything is verified up front rather than as rows are inserted: a file
/// that fails halfway would otherwise have already deleted the user's data in
/// replace mode, and rolling back is a worse answer than never starting.
class ImportValidator {
  const ImportValidator._();

  static ImportPayload parse(Object? decoded) {
    final problems = <ImportProblem>[];

    if (decoded is! Map<String, Object?>) {
      throw const ImportValidationException([
        ImportProblem(message: 'This is not a Money Tracker export file'),
      ]);
    }

    final version = decoded['format_version'];
    if (version is! int) {
      throw const ImportValidationException([
        ImportProblem(
          message: 'This file does not say which export format it uses',
        ),
      ]);
    }
    if (version > ExportSchema.formatVersion) {
      throw ImportValidationException([
        ImportProblem(
          message:
              'This export was made by a newer version of the app '
              '(format $version, this app understands '
              '${ExportSchema.formatVersion})',
        ),
      ]);
    }

    final data = decoded[ExportSchema.dataKey];
    if (data is! Map<String, Object?>) {
      throw const ImportValidationException([
        ImportProblem(message: 'This export has no data section'),
      ]);
    }

    final records = <String, List<Map<String, Object?>>>{};

    for (final group in ExportSchema.groups) {
      final raw = data[group.key];
      // A missing group is allowed — an export from a user with no budgets
      // should still import.
      if (raw == null) {
        records[group.key] = const [];
        continue;
      }
      if (raw is! List) {
        problems.add(
          ImportProblem(
            group: group.key,
            message: 'expected a list of records',
          ),
        );
        continue;
      }

      final rows = <Map<String, Object?>>[];
      for (var i = 0; i < raw.length; i++) {
        final row = raw[i];
        if (row is! Map) {
          problems.add(
            ImportProblem(
              group: group.key,
              index: i,
              message: 'expected an object',
            ),
          );
          continue;
        }

        final typed = Map<String, Object?>.from(row);
        for (final field in group.required) {
          final value = typed[field];
          if (value == null || (value is String && value.trim().isEmpty)) {
            problems.add(
              ImportProblem(
                group: group.key,
                index: i,
                message: 'missing $field',
              ),
            );
          }
        }

        // An id is optional — merge renumbers anyway — but a non-integer one
        // means links cannot be resolved.
        final id = typed['id'];
        if (id != null && id is! int) {
          problems.add(
            ImportProblem(
              group: group.key,
              index: i,
              message: 'id must be a whole number',
            ),
          );
        }

        rows.add(typed);
      }
      records[group.key] = rows;
    }

    _checkReferences(records, problems);

    final settings = <String, String>{};
    final rawSettings = decoded[ExportSchema.settingsKey];
    if (rawSettings is Map) {
      for (final entry in rawSettings.entries) {
        settings['${entry.key}'] = '${entry.value}';
      }
    } else if (rawSettings != null) {
      problems.add(
        const ImportProblem(
          group: 'settings',
          message: 'expected a map of preferences',
        ),
      );
    }

    if (problems.isNotEmpty) throw ImportValidationException(problems);

    return ImportPayload(
      records: records,
      settings: settings,
      formatVersion: version,
      exportedAt: DateTime.tryParse('${decoded['exported_at']}'),
      appVersion: decoded['app_version'] as String?,
    );
  }

  /// Every link must point at a record that is actually in the file.
  ///
  /// A transaction naming an account the export does not contain would fail on
  /// the foreign key mid-write; catching it here means the import never starts.
  static void _checkReferences(
    Map<String, List<Map<String, Object?>>> records,
    List<ImportProblem> problems,
  ) {
    final ids = {
      for (final group in ExportSchema.groups)
        group.key: {
          for (final row in records[group.key] ?? const [])
            if (row['id'] is int) row['id']! as int,
        },
    };

    for (final group in ExportSchema.groups) {
      if (group.references.isEmpty) continue;
      final rows = records[group.key] ?? const [];

      for (var i = 0; i < rows.length; i++) {
        group.references.forEach((column, targetKey) {
          final value = rows[i][column];
          if (value == null) return;
          if (value is! int) {
            problems.add(
              ImportProblem(
                group: group.key,
                index: i,
                message: '$column must be a whole number',
              ),
            );
            return;
          }
          if (!(ids[targetKey]?.contains(value) ?? false)) {
            problems.add(
              ImportProblem(
                group: group.key,
                index: i,
                // Phrased without an article so it reads correctly for
                // every group name: "an account", "a budget".
                message:
                    '$column has no matching '
                    '${ExportSchema.byKey(targetKey).label} in this file',
              ),
            );
          }
        });
      }
    }
  }
}
