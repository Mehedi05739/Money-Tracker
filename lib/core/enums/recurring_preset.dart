import '../enums/recurrence_frequency.dart';
import '../enums/transaction_type.dart';

/// The commitments people actually schedule, offered as one-tap starting
/// points on the form.
///
/// Each carries only the shape of the commitment — what it is called, whether
/// money comes in or goes out, how often, and an icon. Amount, account and
/// category stay the user's to choose; guessing those would be worse than
/// leaving them blank.
enum RecurringPreset {
  rent(
    label: 'Rent',
    icon: 'home',
    type: TransactionType.expense,
    frequency: RecurrenceFrequency.monthly,
  ),
  internet(
    label: 'Internet bill',
    icon: 'wifi',
    type: TransactionType.expense,
    frequency: RecurrenceFrequency.monthly,
  ),
  electricity(
    label: 'Electricity',
    icon: 'bolt',
    type: TransactionType.expense,
    frequency: RecurrenceFrequency.monthly,
  ),
  salary(
    label: 'Salary',
    icon: 'payments',
    type: TransactionType.income,
    frequency: RecurrenceFrequency.monthly,
  ),
  subscription(
    label: 'Subscription',
    icon: 'subscriptions',
    type: TransactionType.expense,
    frequency: RecurrenceFrequency.monthly,
  ),
  loanPayment(
    label: 'Loan payment',
    icon: 'bank',
    type: TransactionType.expense,
    frequency: RecurrenceFrequency.monthly,
  ),
  insurance(
    label: 'Insurance',
    icon: 'shield',
    type: TransactionType.expense,
    frequency: RecurrenceFrequency.yearly,
  );

  const RecurringPreset({
    required this.label,
    required this.icon,
    required this.type,
    required this.frequency,
  });

  final String label;
  final String icon;
  final TransactionType type;
  final RecurrenceFrequency frequency;
}
