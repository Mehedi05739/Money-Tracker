import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/payment_method.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/utils/app_navigation.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/entities/category.dart';

/// Bottom-sheet pickers shared by the transaction, budget and recurring forms.
class PickerSheets {
  const PickerSheets._();

  static Future<Category?> category(
    List<Category> categories, {
    Category? selected,
  }) =>
      _show<Category>(
        title: 'Choose a category',
        emptyMessage: 'No categories yet. Add one from More → Categories.',
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final item = categories[index];
          return _Row(
            leading: CategoryAvatar(
              icon: item.icon,
              color: item.color,
              seed: item.id,
              size: 40,
            ),
            title: item.name,
            isSelected: item.id == selected?.id,
            onTap: () => popRoute<Category>(context, item),
          );
        },
      );

  static Future<Account?> account(
    List<Account> accounts, {
    Account? selected,
    int? excludeId,
    String title = 'Choose an account',
  }) {
    final options =
        accounts.where((account) => account.id != excludeId).toList();

    return _show<Account>(
      title: title,
      emptyMessage: 'No other accounts available.',
      itemCount: options.length,
      itemBuilder: (context, index) {
        final item = options[index];
        return _Row(
          leading: CategoryAvatar(
            icon: item.icon,
            color: item.color,
            seed: item.id,
            size: 40,
          ),
          title: item.name,
          subtitle: Money.format(item.currentBalance),
          isSelected: item.id == selected?.id,
          onTap: () => popRoute<Account>(context, item),
        );
      },
    );
  }

  static Future<PaymentMethod?> paymentMethod({PaymentMethod? selected}) =>
      _show<PaymentMethod>(
        title: 'Payment method',
        emptyMessage: '',
        itemCount: PaymentMethod.values.length,
        itemBuilder: (context, index) {
          final item = PaymentMethod.values[index];
          return _Row(
            leading: Icon(
              _paymentIcon(item),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: item.label,
            isSelected: item == selected,
            onTap: () => popRoute<PaymentMethod>(context, item),
          );
        },
      );

  /// Generic single-choice sheet for enum-like option lists.
  static Future<T?> options<T>({
    required String title,
    required List<T> values,
    required String Function(T value) labelOf,
    T? selected,
  }) =>
      _show<T>(
        title: title,
        emptyMessage: '',
        itemCount: values.length,
        itemBuilder: (context, index) {
          final item = values[index];
          return _Row(
            title: labelOf(item),
            isSelected: item == selected,
            onTap: () => popRoute<T>(context, item),
          );
        },
      );

  static Future<String?> icon({String? selected}) => _show<String>(
        title: 'Choose an icon',
        emptyMessage: '',
        itemCount: 1,
        listBuilder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final name in CategoryIcons.pickable)
                InkWell(
                  onTap: () => popRoute<String>(context, name),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: name == selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: name == selected ? 2 : 1,
                      ),
                    ),
                    child: Icon(CategoryIcons.resolve(name), size: 22),
                  ),
                ),
            ],
          ),
        ),
      );

  static Future<T?> _show<T>({
    required String title,
    required String emptyMessage,
    required int itemCount,
    IndexedWidgetBuilder? itemBuilder,
    WidgetBuilder? listBuilder,
  }) {
    final context = Get.context;
    if (context == null) return Future<T?>.value();

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.7;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
                if (itemCount == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Text(
                      emptyMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else if (listBuilder != null)
                  Flexible(child: SingleChildScrollView(child: listBuilder(sheetContext)))
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: itemCount,
                      itemBuilder: itemBuilder!,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _paymentIcon(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => Icons.payments_rounded,
        PaymentMethod.card => Icons.credit_card_rounded,
        PaymentMethod.bankTransfer => Icons.account_balance_rounded,
        PaymentMethod.mobileWallet => Icons.smartphone_rounded,
        PaymentMethod.cheque => Icons.receipt_long_rounded,
        PaymentMethod.other => Icons.more_horiz_rounded,
      };
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.leading,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: leading,
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : null,
      selected: isSelected,
    );
  }
}
