import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/order_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';
import 'order_providers.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    final session = ref.watch(appSessionProvider).valueOrNull;
    final detailAsync = ref.watch(orderDetailProvider(orderId));

    return AppScaffold(
      title: '订单详情',
      subtitle: family?.name,
      actions: detailAsync.valueOrNull == null
          ? null
          : [
              IconButton(
                onPressed: () => showAppBottomSheet<void>(
                  context: context,
                  builder: (_) =>
                      _ShoppingListSheet(detail: detailAsync.valueOrNull!),
                ),
                icon: const Icon(Icons.shopping_basket_rounded),
              ),
              IconButton(
                onPressed: () async {
                  final link = ref
                      .read(orderRepositoryProvider)
                      .buildShareLink(
                        detailAsync.valueOrNull!.order.shareToken,
                      );
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('分享链接已复制')));
                  }
                },
                icon: const Icon(Icons.share_rounded),
              ),
            ],
      body: detailAsync.when(
        loading: () => const SizedBox(height: 320, child: LoadingView()),
        error: (error, _) => ErrorStateView(
          message: AppException.from(
            error,
            fallbackMessage: '订单加载失败，请稍后重试',
          ).message,
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
        data: (detail) {
          final currentUserId = session?.authenticatedUserId ?? '';
          final currentMemberId = detail.currentMemberIdForUser(currentUserId);
          final canManageOrder = family?.role.canManageMenu ?? false;
          final hasItemsInCurrentRound = detail.items.any(
            (item) => item.orderRound == detail.order.currentRound,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '订单 ${detail.order.id.substring(0, 8)}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        StatusChip.order(detail.order.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '创建于 ${formatDateTime(detail.order.createdAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '当前轮次 第${detail.order.currentRound}轮',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (currentMemberId == null && !detail.isFinished)
                PrimaryButton(
                  label: '加入订单',
                  icon: Icons.group_add_rounded,
                  onPressed: () => _joinOrder(context, ref, detail),
                ),
              if (currentMemberId == null && !detail.isFinished)
                const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '参与成员',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: detail.participants.map((participant) {
                        return Chip(
                          backgroundColor: AppColors.surfaceSoft,
                          label: Text(participant.profile?.username ?? '未知'),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '菜品项',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (!detail.isFinished)
                    TextButton(
                      onPressed: () => context.go('/app/menu'),
                      child: const Text('去点菜'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (detail.items.isEmpty)
                const EmptyState(
                  title: '还没人点菜',
                  description: '从菜单里选几道菜，订单就会出现在这里。',
                  icon: Icons.ramen_dining_rounded,
                )
              else
                for (final item in detail.items) ...[
                  _OrderItemCard(
                    detail: detail,
                    item: item,
                    currentMemberId: currentMemberId,
                    canManageOrder: canManageOrder,
                  ),
                  const SizedBox(height: 12),
                ],
              if (canManageOrder && !detail.isFinished) ...[
                const SizedBox(height: 24),
                if (hasItemsInCurrentRound)
                  PrimaryButton(
                    label: '确认下单',
                    icon: Icons.done_all_rounded,
                    onPressed: () => _placeCurrentRound(context, ref, detail),
                  ),
                if (hasItemsInCurrentRound) const SizedBox(height: 12),
                DangerButton(
                  label: '结束订单',
                  icon: Icons.stop_circle_outlined,
                  onPressed: () => _finishOrder(context, ref, detail.order.id),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _joinOrder(
    BuildContext context,
    WidgetRef ref,
    OrderDetail detail,
  ) async {
    try {
      final result = await ref
          .read(orderRepositoryProvider)
          .joinOrderByShareToken(detail.order.shareToken);
      await ref
          .read(currentFamilyIdProvider.notifier)
          .selectFamily(result.familyId);
      ref.invalidate(orderDetailProvider(result.orderId));
      ref.invalidate(activeOrderSummaryProvider(result.familyId));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已加入订单')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppException.from(error, fallbackMessage: '加入订单失败，请稍后重试').message,
            ),
          ),
        );
      }
    }
  }

  Future<void> _placeCurrentRound(
    BuildContext context,
    WidgetRef ref,
    OrderDetail detail,
  ) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: '确认本轮下单？',
      message: '下单后新增菜品会进入下一轮。',
      confirmLabel: '确认下单',
    );
    if (!confirmed) {
      return;
    }

    try {
      await ref.read(orderRepositoryProvider).placeCurrentRound(detail.order);
      ref.invalidate(orderDetailProvider(detail.order.id));
      ref.invalidate(activeOrderSummaryProvider(detail.order.familyId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppException.from(error, fallbackMessage: '下单失败，请稍后重试').message,
            ),
          ),
        );
      }
    }
  }

  Future<void> _finishOrder(
    BuildContext context,
    WidgetRef ref,
    String orderId,
  ) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: '结束当前订单？',
      message: '结束后该订单将进入历史记录，不能再继续点菜。',
      confirmLabel: '结束订单',
      isDanger: true,
    );
    if (!confirmed) {
      return;
    }

    try {
      await ref.read(orderRepositoryProvider).finishOrder(orderId);
      ref.invalidate(orderDetailProvider(orderId));
      final family = ref.read(currentFamilyProvider);
      if (family != null) {
        ref.invalidate(activeOrderSummaryProvider(family.id));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订单已结束')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppException.from(error, fallbackMessage: '结束订单失败，请稍后重试').message,
            ),
          ),
        );
      }
    }
  }
}

class _OrderItemCard extends ConsumerWidget {
  const _OrderItemCard({
    required this.detail,
    required this.item,
    required this.currentMemberId,
    required this.canManageOrder,
  });

  final OrderDetail detail;
  final OrderItemRecord item;
  final String? currentMemberId;
  final bool canManageOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addedBy = detail.participants
        .where((participant) => participant.id == item.addedByMemberId)
        .map((participant) => participant.profile?.username ?? '未知成员')
        .firstOrNull;

    final canDelete =
        currentMemberId != null &&
        currentMemberId == item.addedByMemberId &&
        detail.order.status == OrderStatus.ordering;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.dish?.name ?? '未知菜品',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StatusChip.item(item.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('数量 ${item.quantity}'),
                const SizedBox(height: 4),
                Text(
                  '第${item.orderRound}轮 · ${addedBy ?? '未记录'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (canManageOrder)
            PopupMenuButton<ItemStatus>(
              onSelected: (status) async {
                try {
                  await ref
                      .read(orderRepositoryProvider)
                      .updateItemStatus(itemId: item.id, status: status);
                  ref.invalidate(orderDetailProvider(detail.order.id));
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppException.from(
                            error,
                            fallbackMessage: '状态更新失败，请稍后重试',
                          ).message,
                        ),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) {
                return ItemStatus.values.map((status) {
                  return PopupMenuItem<ItemStatus>(
                    value: status,
                    child: Text(status.label),
                  );
                }).toList();
              },
            ),
          if (canDelete)
            IconButton(
              onPressed: () async {
                try {
                  await ref.read(orderRepositoryProvider).deleteItem(item.id);
                  ref.invalidate(orderDetailProvider(detail.order.id));
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppException.from(
                            error,
                            fallbackMessage: '删除失败，请稍后重试',
                          ).message,
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _ShoppingListSheet extends StatelessWidget {
  const _ShoppingListSheet({required this.detail});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final entries = detail.aggregateShoppingList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('采购清单', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (entries.isEmpty)
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
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return AppCard(
                    padding: const EdgeInsets.all(12),
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
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
