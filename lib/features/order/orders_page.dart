import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../shared/repositories/order_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';
import '../family/onboarding_pages.dart';
import 'order_providers.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const AppScaffold(
        title: '订单',
        body: EmptyState(title: '还没有家庭', description: '请先创建或加入一个家庭。'),
      );
    }

    final orderAsync = ref.watch(activeOrderSummaryProvider(family.id));

    return AppScaffold(
      title: '订单',
      subtitle: family.name,
      actions: [
        IconButton(
          onPressed: () => showFamilySwitcherSheet(context, ref),
          icon: const Icon(Icons.swap_horiz_rounded),
        ),
      ],
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
              FamilyHeaderCard(
                family: family,
                onSwitch: () => showFamilySwitcherSheet(context, ref),
              ),
              const SizedBox(height: 24),
              SectionTitle('当前订单'),
              const SizedBox(height: 12),
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
              else
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '订单 ${summary.order.id.substring(0, 8)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          StatusChip.order(summary.order.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当前轮次 第${summary.order.currentRound}轮',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '参与人数 ${summary.participants.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: summary.isCurrentUserJoined ? '进入订单' : '去加入订单',
                        icon: summary.isCurrentUserJoined
                            ? Icons.open_in_new_rounded
                            : Icons.group_add_rounded,
                        onPressed: () =>
                            context.push('/app/orders/${summary.order.id}'),
                      ),
                    ],
                  ),
                ),
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
        context.push('/app/orders/${summary.order.id}');
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
