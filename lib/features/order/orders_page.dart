import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/order_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';
import 'order_detail_page.dart';
import 'order_providers.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const AppScaffold(
        title: '订单',
        showAppBar: false,
        body: EmptyState(title: '还没有家庭', description: '请先创建或加入一个家庭。'),
      );
    }

    final orderAsync = ref.watch(activeOrderSummaryProvider(family.id));

    return AppScaffold(
      title: '订单',
      showAppBar: false,
      body: orderAsync.when(
        loading: () => const SizedBox(height: 320, child: LoadingView()),
        error: (error, _) => ErrorStateView(
          message: AppException.from(
            error,
            fallbackMessage: '订单加载失败，请稍后重试',
          ).message,
          onRetry: () => ref.invalidate(activeOrderSummaryProvider(family.id)),
        ),
        data: (summary) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary == null)
                EmptyState(
                  title: '当前没有进行中的订单',
                  description: family.role.canManageMenu
                      ? '创建一个订单后，大家就可以一起点菜了。'
                      : '等待管理员创建订单后，再回来加入。',
                  actionLabel: family.role.canManageMenu ? '创建订单' : null,
                  onAction: family.role.canManageMenu
                      ? () => _createOrder(context, ref, family.id)
                      : null,
                  icon: Icons.receipt_long_rounded,
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '当前订单',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.shopping_basket_rounded,
                      tooltip: '采购清单',
                      onPressed: () async {
                        final detail = await ref.read(
                          orderDetailProvider(summary.order.id).future,
                        );
                        if (context.mounted) {
                          await showAppBottomSheet<void>(
                            context: context,
                            builder: (_) =>
                                _OrdersShoppingSheet(detail: detail),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OrderDetailBody(orderId: summary.order.id),
              ],
              if (family.role.canManageMenu && summary == null) ...[
                const SizedBox(height: 16),
                SecondaryButton(
                  label: '创建订单',
                  icon: Icons.add_circle_rounded,
                  onPressed: () => _createOrder(context, ref, family.id),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _createOrder(
    BuildContext context,
    WidgetRef ref,
    String familyId,
  ) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: '创建新订单？',
      message: '创建后，家庭成员就可以围绕这个订单一起点菜。',
      confirmLabel: '创建订单',
    );
    if (!confirmed) {
      return;
    }

    try {
      final summary = await ref
          .read(orderRepositoryProvider)
          .createOrder(familyId);
      ref.invalidate(activeOrderSummaryProvider(familyId));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订单已创建')));
        ref.invalidate(orderDetailProvider(summary.order.id));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppException.from(error, fallbackMessage: '创建订单失败，请稍后重试').message,
            ),
          ),
        );
      }
    }
  }
}

class _OrdersShoppingSheet extends StatelessWidget {
  const _OrdersShoppingSheet({required this.detail});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final groups = detail.groupShoppingListByRound();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('采购清单', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const EmptyState(
              title: '还没有可汇总的食材',
              description: '等有人点菜后，这里会自动生成采购清单。',
              icon: Icons.shopping_basket_outlined,
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '第${group.round}轮采购单',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              group.round == detail.order.currentRound
                                  ? '当前轮次'
                                  : '历史轮次',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final entry in group.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(child: Text(entry.name)),
                                if (entry.isLatestRound)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Icon(
                                      Icons.fiber_new_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                Text(
                                  '${formatIngredientAmount(entry.amount)} ${entry.unit}',
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
