import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';
import 'order_providers.dart';

class OrderHistoryPage extends ConsumerWidget {
  const OrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const AppScaffold(
        title: '历史订单',
        body: EmptyState(title: '还没有家庭', description: '请先创建或加入一个家庭。'),
      );
    }

    final historyAsync = ref.watch(orderHistoryProvider(family.id));

    return AppScaffold(
      title: '历史订单',
      subtitle: family.name,
      body: historyAsync.when(
        loading: () => const SizedBox(height: 280, child: LoadingView()),
        error: (error, _) => ErrorStateView(
          message: AppException.from(
            error,
            fallbackMessage: '历史订单加载失败，请稍后重试',
          ).message,
          onRetry: () => ref.invalidate(orderHistoryProvider(family.id)),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              title: '还没有历史订单',
              description: '完成过的订单会显示在这里。',
              icon: Icons.history_rounded,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final order in orders) ...[
                AppCard(
                  onTap: () => context.push('/app/orders/${order.id}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '订单 ${order.id.substring(0, 8)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.finishedAt == null
                                  ? formatDate(order.createdAt)
                                  : formatDateTime(order.finishedAt!),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      StatusChip.order(order.status),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}
