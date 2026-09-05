import 'package:flutter/material.dart';

import '../enums/transaction_type.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Renders a monetary value with the sign and colour its type implies.
class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.amount,
    this.type,
    this.style,
    this.showSign = true,
    this.colored = true,
    this.compact = false,
  });

  /// Colours by sign rather than by transaction type — for balances and totals.
  const AmountText.signed({
    super.key,
    required this.amount,
    this.style,
    this.showSign = false,
    this.compact = false,
  }) : type = null,
       colored = true;

  /// Neutral colour, used where the surrounding row already conveys direction.
  const AmountText.plain({
    super.key,
    required this.amount,
    this.style,
    this.compact = false,
  }) : type = null,
       showSign = false,
       colored = false;

  final double amount;
  final TransactionType? type;
  final TextStyle? style;
  final bool showSign;
  final bool colored;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.titleMedium;

    return Text(
      _label,
      style: base?.copyWith(color: colored ? _color(context) : null),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String get _label {
    final value = compact
        ? Money.compact(amount.abs())
        : Money.format(amount.abs());
    if (!showSign) {
      return compact ? Money.compact(amount) : Money.format(amount);
    }
    return '$_prefix$value';
  }

  String get _prefix => switch (type) {
    TransactionType.income => '+',
    TransactionType.expense => '−',
    TransactionType.transfer => '',
    null => amount < 0 ? '−' : (amount > 0 ? '+' : ''),
  };

  Color? _color(BuildContext context) {
    if (type != null) {
      return switch (type!) {
        TransactionType.income => context.incomeColor,
        TransactionType.expense => context.expenseColor,
        TransactionType.transfer => context.transferColor,
      };
    }
    if (amount > 0) return context.incomeColor;
    if (amount < 0) return context.expenseColor;
    return null;
  }
}
