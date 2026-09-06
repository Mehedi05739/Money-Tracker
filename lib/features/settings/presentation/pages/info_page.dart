import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_scaffold.dart';

/// A plain reading page for the privacy policy, terms and support details.
///
/// The text ships with the app rather than being fetched: this app works
/// offline by design, and a policy that only loads with a connection is one the
/// user cannot read when they most want to.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.title, required this.sections});

  final String title;

  /// Heading to body. A heading may be empty for an opening paragraph.
  final List<({String heading, String body})> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            for (final section in sections) ...[
              if (section.heading.isNotEmpty) ...[
                Text(section.heading, style: theme.textTheme.titleMedium),
                AppSpacing.gapSm,
              ],
              Text(
                section.body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              AppSpacing.gapLg,
            ],
          ],
        ),
      ),
    );
  }
}

/// The text shown by [InfoPage].
///
/// Written to describe what this app actually does. It stores everything in a
/// local SQLite file and talks to no server, so the honest privacy policy is
/// short — and saying so plainly is worth more than boilerplate that implies
/// data collection which does not happen.
class AppLegalText {
  const AppLegalText._();

  static const List<({String heading, String body})> privacy = [
    (
      heading: '',
      body:
          'Money Tracker keeps your financial data on this device and nowhere '
          'else. There are no accounts, no servers and no analytics.',
    ),
    (
      heading: 'What is stored',
      body:
          'Your accounts, transactions, budgets, spending plans, goals and '
          'schedules are written to a SQLite database in this app’s private '
          'storage. Preferences such as your theme and currency are stored '
          'alongside them.',
    ),
    (
      heading: 'What is not stored',
      body:
          'No passwords or credentials are kept. The app lock uses your '
          'device’s own authentication, so your PIN, pattern and biometrics '
          'stay with the operating system and are never seen by this app.',
    ),
    (
      heading: 'What leaves the device',
      body:
          'Nothing. Exports and backups are written into the app’s own '
          'storage and are not uploaded or shared anywhere.',
    ),
    (
      heading: 'Deleting your data',
      body:
          'Clear all data in Settings removes every record permanently. '
          'Uninstalling the app removes the database with it.',
    ),
  ];

  static const List<({String heading, String body})> terms = [
    (
      heading: '',
      body:
          'Money Tracker is provided as-is to help you record and understand '
          'your own spending.',
    ),
    (
      heading: 'Your data is your responsibility',
      body:
          'Because everything is stored only on this device, losing or '
          'resetting the device means losing the data with it. Use Backup '
          'regularly if the history matters to you.',
    ),
    (
      heading: 'Not financial advice',
      body:
          'Budgets, plans, projections and reminders are arithmetic on the '
          'figures you enter. They are not financial advice, and the app makes '
          'no guarantee about decisions taken on the strength of them.',
    ),
    (
      heading: 'Accuracy',
      body:
          'Every total is derived from what you record. If a transaction is '
          'missing or wrong, the reports built on it will be too.',
    ),
  ];
}
