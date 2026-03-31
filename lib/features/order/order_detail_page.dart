import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final detailAsync = ref.watch(orderDetailProvider(orderId));

    return AppScaffold(
      title: '订单详情',
      subtitle: ref.watch(currentFamilyProvider)?.name,
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
      body: OrderDetailBody(orderId: orderId),
    );
  }
}

class OrderDetailBody extends ConsumerWidget {
  const OrderDetailBody({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    final session = ref.watch(appSessionProvider).valueOrNull;
    final detailAsync = ref.watch(orderDetailProvider(orderId));

    return detailAsync.when(
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
        final isParticipant = currentMemberId != null;
        final roundGroups = detail.groupItemsByRound();
        final hasItemsInCurrentRound = detail.items.any(
          (item) => item.orderRound == detail.order.currentRound,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentMemberId == null && !detail.isFinished)
              PrimaryButton(
                label: '加入订单',
                icon: Icons.group_add_rounded,
                onPressed: () => _joinOrder(context, ref, detail),
              ),
            if (currentMemberId == null && !detail.isFinished)
              const SizedBox(height: 16),
            if (roundGroups.isEmpty)
              const EmptyState(
                title: '还没人点菜',
                description: '从菜单里选几道菜，订单就会出现在这里。',
                icon: Icons.ramen_dining_rounded,
              )
            else
              for (final group in roundGroups) ...[
                _RoundGroupCard(
                  key: ValueKey('round-${group.round}'),
                  title: '第${group.round}轮',
                  subtitle: group.round == detail.order.currentRound
                      ? (hasItemsInCurrentRound ? '当前轮次' : '待下单')
                      : '已下单',
                  action:
                      group.round == detail.order.currentRound &&
                          isParticipant &&
                          !detail.isFinished &&
                          hasItemsInCurrentRound
                      ? _ConfirmableActionButton(
                          key: ValueKey(
                            'place-${detail.order.id}-round-${group.round}',
                          ),
                          label: '下单',
                          confirmLabel: '确认下单',
                          onConfirmed: () =>
                              _placeCurrentRound(context, ref, detail),
                        )
                      : null,
                  child: Column(
                    children: List.generate(group.items.length, (index) {
                      final item = group.items[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == group.items.length - 1 ? 0 : 12,
                        ),
                        child: _OrderItemCard(
                          key: ValueKey('item-${item.id}'),
                          detail: detail,
                          item: item,
                          currentMemberId: currentMemberId,
                          canManageOrder: canManageOrder,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            if (canManageOrder && !detail.isFinished) ...[
              const SizedBox(height: 12),
              _ConfirmableActionButton(
                key: ValueKey('finish-${detail.order.id}'),
                label: '结束订单',
                confirmLabel: '确认结束订单',
                icon: Icons.stop_circle_outlined,
                isDanger: true,
                fullWidth: true,
                onConfirmed: () => _finishOrder(context, ref, detail.order.id),
              ),
            ],
          ],
        );
      },
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
    super.key,
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
        .map((participant) => participant.profile?.username ?? '未记录')
        .firstOrNull;
    final canDelete =
        currentMemberId != null &&
        currentMemberId == item.addedByMemberId &&
        detail.order.status == OrderStatus.ordering;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.dish?.name ?? '未知菜品'} * ${item.quantity}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (addedBy != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· $addedBy',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    StatusChip.item(item.status),
                  ],
                ),
                if (item.specsDisplay.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.specsDisplay,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canManageOrder)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: item.status == ItemStatus.done
                  ? null
                  : () async {
                      final nextStatus = switch (item.status) {
                        ItemStatus.waiting => ItemStatus.cooking,
                        ItemStatus.cooking => ItemStatus.done,
                        ItemStatus.done => ItemStatus.done,
                      };
                      try {
                        await ref
                            .read(orderRepositoryProvider)
                            .updateItemStatus(
                              itemId: item.id,
                              status: nextStatus,
                            );
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
              child: Text(switch (item.status) {
                ItemStatus.waiting => '去制作',
                ItemStatus.cooking => '去出锅',
                ItemStatus.done => '已完成',
              }),
            ),
          if (canDelete)
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
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
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
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
                  return _RoundGroupCard(
                    title: '第${group.round}轮采购单',
                    subtitle: group.round == detail.order.currentRound
                        ? '当前轮次'
                        : '历史轮次',
                    child: Column(
                      children: group.entries.map((entry) {
                        return Padding(
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
                        );
                      }).toList(),
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

class _RoundGroupCard extends StatelessWidget {
  const _RoundGroupCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0x142D6A4F)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }
}

class _ConfirmableActionButton extends StatefulWidget {
  const _ConfirmableActionButton({
    super.key,
    required this.label,
    required this.confirmLabel,
    required this.onConfirmed,
    this.icon,
    this.isDanger = false,
    this.fullWidth = false,
  });

  final String label;
  final String confirmLabel;
  final Future<void> Function() onConfirmed;
  final IconData? icon;
  final bool isDanger;
  final bool fullWidth;

  @override
  State<_ConfirmableActionButton> createState() =>
      _ConfirmableActionButtonState();
}

class _ConfirmableActionButtonState extends State<_ConfirmableActionButton> {
  bool _needsConfirmation = false;
  bool _isBusy = false;

  Future<void> _handlePressed() async {
    if (_isBusy) {
      return;
    }

    if (!_needsConfirmation) {
      setState(() {
        _needsConfirmation = true;
      });
      return;
    }

    setState(() {
      _isBusy = true;
    });
    try {
      await widget.onConfirmed();
    } finally {
      if (mounted) {
        setState(() {
          _needsConfirmation = false;
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _needsConfirmation ? widget.confirmLabel : widget.label;
    final foreground = widget.isDanger ? AppColors.danger : AppColors.primary;
    final background = widget.isDanger
        ? AppColors.dangerSoft
        : AppColors.primaryContainer;

    final button = widget.fullWidth
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: background,
              foregroundColor: foreground,
            ),
            onPressed: _isBusy ? null : _handlePressed,
            icon: _isBusy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(widget.icon ?? Icons.warning_amber_rounded, size: 18),
            label: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          )
        : TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: background,
              foregroundColor: foreground,
            ),
            onPressed: _isBusy ? null : _handlePressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18),
                  const SizedBox(width: 6),
                ],
                if (_isBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
              ],
            ),
          );

    return widget.fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
