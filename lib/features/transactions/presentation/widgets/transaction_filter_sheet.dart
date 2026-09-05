import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/repositories/transaction_repository.dart';

/// Multi-select filter sheet. Edits a local copy and only applies on confirm,
/// so cancelling leaves the list untouched.
class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({
    super.key,
    required this.initial,
    required this.categories,
    required this.accounts,
  });

  final TransactionFilter initial;
  final List<Category> categories;
  final List<Account> accounts;

  static Future<TransactionFilter?> show({
    required TransactionFilter initial,
    required List<Category> categories,
    required List<Account> accounts,
  }) {
    final context = Get.context;
    if (context == null) return Future.value();

    return showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionFilterSheet(
        initial: initial,
        categories: categories,
        accounts: accounts,
      ),
    );
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late Set<TransactionType> _types = {...widget.initial.types};
  late Set<int> _categoryIds = {...widget.initial.categoryIds};
  late Set<int> _accountIds = {...widget.initial.accountIds};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  Text('Filters', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _types = {};
                      _categoryIds = {};
                      _accountIds = {};
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  _Label('Type'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final type in TransactionType.values)
                        FilterChip(
                          label: Text(type.label),
                          selected: _types.contains(type),
                          onSelected: (selected) => setState(() {
                            selected ? _types.add(type) : _types.remove(type);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Label('Accounts'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final account in widget.accounts)
                        FilterChip(
                          label: Text(account.name),
                          selected: _accountIds.contains(account.id),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _accountIds.add(account.id)
                                : _accountIds.remove(account.id);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Label('Categories'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final category in widget.categories)
                        FilterChip(
                          avatar: CategoryAvatar(
                            icon: category.icon,
                            color: category.color,
                            seed: category.id,
                            size: 22,
                          ),
                          label: Text(category.name),
                          selected: _categoryIds.contains(category.id),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _categoryIds.add(category.id)
                                : _categoryIds.remove(category.id);
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  widget.initial.copyWith(
                    types: _types,
                    categoryIds: _categoryIds,
                    accountIds: _accountIds,
                  ),
                ),
                child: const Text('Apply filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
