import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../domain/entities/category.dart';
import '../../../../routes/app_routes.dart';
import '../controllers/categories_controller.dart';

class CategoriesPage extends GetView<CategoriesController> {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: controller.showArchived.value
                  ? 'Hide archived'
                  : 'Show archived',
              onPressed: controller.toggleArchived,
              icon: Icon(
                controller.showArchived.value
                    ? Icons.visibility_off_outlined
                    : Icons.archive_outlined,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(controller.selectedType.value),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Category'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Obx(
              () => AppSegmented<TransactionType>(
                values: const [TransactionType.expense, TransactionType.income],
                selected: controller.selectedType.value,
                labelOf: (type) => type.label,
                iconOf: (type) => type.isIncome
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                colorOf: (type) =>
                    type.isIncome ? context.incomeColor : context.expenseColor,
                onChanged: controller.changeType,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: controller.refreshData,
              child: Obx(() {
                final state = controller.state;

                return switch (state) {
                  IdleState() || LoadingState() => const AppLoader(),
                  ErrorState(:final message) => AppErrorView(
                    message: message,
                    onRetry: controller.load,
                  ),
                  EmptyState() => AppEmptyView(
                    title: 'No categories',
                    message:
                        'Add a ${controller.selectedType.value.label.toLowerCase()} '
                        'category to start organising your money.',
                    icon: Icons.label_outline_rounded,
                    action: FilledButton.icon(
                      onPressed: () => _openForm(controller.selectedType.value),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add category'),
                    ),
                  ),
                  LoadedState() => _CategoryList(controller: controller),
                };
              }),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(Object argument) async {
    final saved = await Get.toNamed(
      AppRoutes.categoryForm,
      arguments: argument,
    );
    if (saved == true) await controller.load(showLoader: false);
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.controller});

  final CategoriesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.visible;

      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 70),
        itemBuilder: (context, index) =>
            _CategoryTile(category: items[index], controller: controller),
      );
    });
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.controller});

  final Category category;
  final CategoriesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CategoryAvatar(
        icon: category.icon,
        color: category.color,
        seed: category.id,
      ),
      title: Text(category.name, style: theme.textTheme.titleSmall),
      subtitle: category.isArchived
          ? Text(
              'Archived',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      onTap: () async {
        final saved = await Get.toNamed(
          AppRoutes.categoryForm,
          arguments: category,
        );
        if (saved == true) await controller.load(showLoader: false);
      },
      trailing: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onSelected: _handle,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'archive',
            child: Text(category.isArchived ? 'Restore' : 'Archive'),
          ),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  Future<void> _handle(String action) async {
    if (action == 'archive') {
      await controller.setArchived(category, !category.isArchived);
      return;
    }

    final confirmed = await ConfirmDialog.show(
      title: 'Delete ${category.name}?',
      message:
          'Categories still used by transactions cannot be deleted — '
          'archive them instead.',
    );
    if (confirmed) await controller.delete(category);
  }
}
