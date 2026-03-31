import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/extensions.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/order_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';
import '../order/order_providers.dart';
import 'menu_providers.dart';

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({super.key});

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage> {
  final _searchController = TextEditingController();
  String _selectedCategory = '全部';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const AppScaffold(
        title: '菜单',
        showAppBar: false,
        body: EmptyState(title: '还没有家庭', description: '请先创建或加入一个家庭。'),
      );
    }

    final dishesAsync = ref.watch(dishesProvider(family.id));
    final orderSummaryAsync = ref.watch(activeOrderSummaryProvider(family.id));
    final currentOrderId = orderSummaryAsync.valueOrNull?.order.id;
    final orderDetailAsync = currentOrderId == null
        ? const AsyncValue<OrderDetail?>.data(null)
        : ref
              .watch(orderDetailProvider(currentOrderId))
              .whenData((value) => value);

    return AppScaffold(
      title: '菜单',
      showAppBar: false,
      floatingActionButton: family.role.canManageMenu
          ? FloatingActionButton(
              onPressed: () => context.push('/app/menu/dish/new'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      body: dishesAsync.when(
        loading: () => const SizedBox(height: 360, child: LoadingView()),
        error: (error, _) => ErrorStateView(
          message: AppException.from(
            error,
            fallbackMessage: '菜品加载失败，请稍后重试',
          ).message,
          onRetry: () => ref.invalidate(dishesProvider(family.id)),
        ),
        data: (dishes) {
          final categories = {
            '全部',
            ...dishes.map((dish) => dish.category),
          }.toList()..sort();
          final search = _searchController.text.trim().toLowerCase();
          final filtered = dishes.where((dish) {
            final matchesCategory =
                _selectedCategory == '全部' || dish.category == _selectedCategory;
            final matchesSearch =
                search.isEmpty || dish.name.toLowerCase().contains(search);
            return matchesCategory && matchesSearch;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: AppTextField(
                  controller: _searchController,
                  label: '搜索菜品',
                  hintText: '搜菜名',
                  suffixIcon: search.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        label: category,
                        selected: category == _selectedCategory,
                        onTap: () {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              SectionTitle(
                '家庭菜单',
                trailing: Text(
                  '${filtered.length} 道',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              if (dishes.isEmpty)
                EmptyState(
                  title: '还没有菜品',
                  description: '先把常做的菜加进菜单，点菜时会方便很多。',
                  actionLabel: family.role.canManageMenu ? '新增菜品' : null,
                  onAction: family.role.canManageMenu
                      ? () => context.push('/app/menu/dish/new')
                      : null,
                  icon: Icons.ramen_dining_rounded,
                )
              else if (filtered.isEmpty)
                EmptyState(
                  title: '没有找到相关菜品',
                  description: '试试换个关键词，或者切换分类。',
                  actionLabel: '清空搜索',
                  onAction: () {
                    _searchController.clear();
                    setState(() {
                      _selectedCategory = '全部';
                    });
                  },
                  icon: Icons.search_off_rounded,
                )
              else
                _DishGrid(
                  family: family,
                  dishes: filtered,
                  orderSummaryAsync: orderSummaryAsync,
                  orderDetailAsync: orderDetailAsync,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DishGrid extends StatelessWidget {
  const _DishGrid({
    required this.family,
    required this.dishes,
    required this.orderSummaryAsync,
    required this.orderDetailAsync,
  });

  final FamilySummary family;
  final List<Dish> dishes;
  final AsyncValue<OrderSummary?> orderSummaryAsync;
  final AsyncValue<OrderDetail?> orderDetailAsync;

  @override
  Widget build(BuildContext context) {
    final detail = orderDetailAsync.valueOrNull;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dishes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final dish = dishes[index];
        return _DishCard(
          dish: dish,
          family: family,
          orderSummary: orderSummaryAsync.valueOrNull,
          orderDetail: detail,
        );
      },
    );
  }
}

class _DishCard extends ConsumerStatefulWidget {
  const _DishCard({
    required this.dish,
    required this.family,
    required this.orderSummary,
    required this.orderDetail,
  });

  final Dish dish;
  final FamilySummary family;
  final OrderSummary? orderSummary;
  final OrderDetail? orderDetail;

  @override
  ConsumerState<_DishCard> createState() => _DishCardState();
}

class _DishCardState extends ConsumerState<_DishCard> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final imageAsync = ref.watch(dishImageProvider(widget.dish.imageUrl));
    final currentRoundDishQuantity = _currentRoundDishQuantity();
    final showBadge =
        widget.orderDetail?.isOrdering == true && currentRoundDishQuantity > 0;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InkWell(
                    onTap: () {
                      showAppBottomSheet<void>(
                        context: context,
                        builder: (_) => _DishDetailSheet(dish: widget.dish),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg),
                      ),
                      child: imageAsync.when(
                        loading: () =>
                            _DishPlaceholder(icon: Icons.image_rounded),
                        error: (_, _) => const _DishPlaceholder(
                          icon: Icons.image_not_supported_rounded,
                        ),
                        data: (url) => url == null
                            ? const _DishPlaceholder(
                                icon: Icons.rice_bowl_rounded,
                              )
                            : Image.network(url, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                if (showBadge)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$currentRoundDishQuantity',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.dish.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _QuantityStepper(
                      isLoading: _isUpdating,
                      onDecrease: () => _changeQuantity(isIncrement: false),
                      onIncrease: () => _changeQuantity(isIncrement: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeQuantity({required bool isIncrement}) async {
    if (_isUpdating) {
      return;
    }

    final orderSummary = widget.orderSummary;
    if (orderSummary == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.family.role.canManageMenu ? '请先创建订单，再开始点菜' : '当前没有进行中的订单',
          ),
        ),
      );
      return;
    }

    final repository = ref.read(orderRepositoryProvider);
    final detail = widget.orderDetail;
    var currentMemberId = detail?.currentMemberIdForUser(
      ref.read(appSessionProvider).valueOrNull?.authenticatedUserId ?? '',
    );

    setState(() {
      _isUpdating = true;
    });

    try {
      if (currentMemberId == null) {
        final joined = await repository.joinOrderByShareToken(
          orderSummary.order.shareToken,
        );
        ref.invalidate(orderDetailProvider(joined.orderId));
        ref.invalidate(activeOrderSummaryProvider(joined.familyId));
      }

      final refreshedDetail = await repository.fetchOrderDetail(
        orderSummary.order.id,
      );
      currentMemberId = refreshedDetail.currentMemberIdForUser(
        ref.read(appSessionProvider).valueOrNull?.authenticatedUserId ?? '',
      );
      if (currentMemberId == null) {
        throw const AppException('加入订单失败，请稍后重试');
      }

      Map<String, String>? selectedSpecs;
      if (isIncrement && widget.dish.hasSpecs) {
        if (!mounted) {
          return;
        }
        selectedSpecs = await showAppBottomSheet<Map<String, String>?>(
          context: context,
          builder: (_) => _DishSpecSheet(dish: widget.dish),
        );
        if (!mounted || selectedSpecs == null) {
          return;
        }
      }

      if (isIncrement) {
        final existing = refreshedDetail.items
            .where(
              (item) =>
                  item.dishId == widget.dish.id &&
                  item.addedByMemberId == currentMemberId &&
                  item.orderRound == refreshedDetail.order.currentRound &&
                  _sameSelectedSpecs(
                    item.selectedSpecs,
                    selectedSpecs ?? const {},
                  ),
            )
            .lastOrNull;
        if (existing == null) {
          await repository.addDishToOrder(
            order: refreshedDetail.order,
            dishId: widget.dish.id,
            orderMemberId: currentMemberId,
            quantity: 1,
            selectedSpecs: selectedSpecs ?? const {},
          );
        } else {
          await repository.updateItemQuantity(
            itemId: existing.id,
            quantity: existing.quantity + 1,
          );
        }
      } else {
        final currentRoundItems = refreshedDetail.items
            .where(
              (item) =>
                  item.dishId == widget.dish.id &&
                  item.addedByMemberId == currentMemberId &&
                  item.orderRound == refreshedDetail.order.currentRound,
            )
            .toList();
        if (currentRoundItems.isEmpty) {
          return;
        }

        Map<String, String> targetSpecs = const {};
        if (widget.dish.hasSpecs) {
          final distinctVariants = <String, OrderItemRecord>{};
          for (final item in currentRoundItems) {
            distinctVariants[item.specsDisplay] = item;
          }

          if (distinctVariants.length == 1) {
            targetSpecs = distinctVariants.values.first.selectedSpecs;
          } else {
            if (!mounted) {
              return;
            }
            targetSpecs =
                await showAppBottomSheet<Map<String, String>?>(
                  context: context,
                  builder: (_) => _DishVariantSheet(
                    dish: widget.dish,
                    items: distinctVariants.values.toList(),
                  ),
                ) ??
                const {};
            if (targetSpecs.isEmpty) {
              return;
            }
          }
        }

        final existing = currentRoundItems
            .where(
              (item) => _sameSelectedSpecs(item.selectedSpecs, targetSpecs),
            )
            .lastOrNull;
        if (existing == null) {
          return;
        }
        if (existing.quantity > 1) {
          await repository.updateItemQuantity(
            itemId: existing.id,
            quantity: existing.quantity - 1,
          );
        } else {
          await repository.deleteItem(existing.id);
        }
      }

      ref.invalidate(orderDetailProvider(orderSummary.order.id));
      ref.invalidate(activeOrderSummaryProvider(widget.family.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppException.from(
                error,
                fallbackMessage: isIncrement ? '加菜失败，请稍后重试' : '减菜失败，请稍后重试',
              ).message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  int _currentRoundDishQuantity() {
    final detail = widget.orderDetail;
    if (detail == null) {
      return 0;
    }

    final currentRound = detail.order.currentRound;
    return detail.items
        .where(
          (item) =>
              item.dishId == widget.dish.id && item.orderRound == currentRound,
        )
        .fold(0, (sum, item) => sum + item.quantity);
  }

  bool _sameSelectedSpecs(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

class _DishPlaceholder extends StatelessWidget {
  const _DishPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceSoft,
      child: Center(child: Icon(icon, size: 38, color: AppColors.primary)),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.onDecrease,
    required this.onIncrease,
    required this.isLoading,
  });

  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlainAction(
          onTap: isLoading ? null : onDecrease,
          child: const Text(
            '−',
            style: TextStyle(
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _PlainAction(
          onTap: isLoading ? null : onIncrease,
          child: isLoading
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  '+',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PlainAction extends StatelessWidget {
  const _PlainAction({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(width: 26, height: 26, child: Center(child: child)),
    );
  }
}

class _DishDetailSheet extends ConsumerWidget {
  const _DishDetailSheet({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageAsync = ref.watch(dishImageProvider(dish.imageUrl));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 220,
              child: imageAsync.when(
                loading: () =>
                    const _DishPlaceholder(icon: Icons.image_rounded),
                error: (_, _) => const _DishPlaceholder(
                  icon: Icons.image_not_supported_rounded,
                ),
                data: (url) => url == null
                    ? const _DishPlaceholder(icon: Icons.rice_bowl_rounded)
                    : Image.network(url, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(dish.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            dish.category,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (dish.hasSpecs) ...[
            const SizedBox(height: 16),
            Text('规格', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final spec in dish.specs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(spec.name)),
                        if (spec.required) const _SpecRequiredBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: spec.values
                          .map(
                            (value) => Chip(
                              label: Text(value),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text('食材', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (dish.ingredients.isEmpty)
            Text(
              '暂未填写食材',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else
            for (final ingredient in dish.ingredients)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(ingredient.name)),
                    Text('${ingredient.amount} ${ingredient.unit}'),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _DishSpecSheet extends StatefulWidget {
  const _DishSpecSheet({required this.dish});

  final Dish dish;

  @override
  State<_DishSpecSheet> createState() => _DishSpecSheetState();
}

class _DishSpecSheetState extends State<_DishSpecSheet> {
  late final Map<String, String?> _selectedValues;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedValues = {for (final spec in widget.dish.specs) spec.name: null};
  }

  void _toggleValue(String specName, String value) {
    setState(() {
      _selectedValues[specName] = _selectedValues[specName] == value
          ? null
          : value;
      _errorText = null;
    });
  }

  void _clearValue(String specName) {
    setState(() {
      _selectedValues[specName] = null;
      _errorText = null;
    });
  }

  void _confirm() {
    final selected = <String, String>{};
    for (final spec in widget.dish.specs) {
      final value = _selectedValues[spec.name];
      if (value == null || value.trim().isEmpty) {
        if (spec.required) {
          setState(() {
            _errorText = '请先选择 ${spec.name}';
          });
          return;
        }
        continue;
      }
      selected[spec.name] = value;
    }

    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择规格', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            widget.dish.name,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (widget.dish.specs.isEmpty)
            const SizedBox.shrink()
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final spec in widget.dish.specs) ...[
                      Text(
                        spec.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!spec.required)
                            ChoiceChip(
                              label: const Text('不选'),
                              selected: _selectedValues[spec.name] == null,
                              onSelected: (_) => _clearValue(spec.name),
                            ),
                          for (final value in spec.values)
                            ChoiceChip(
                              label: Text(value),
                              selected: _selectedValues[spec.name] == value,
                              onSelected: (_) => _toggleValue(spec.name, value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          if (_errorText != null) ...[
            Text(
              _errorText!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: 12),
          ],
          PrimaryButton(label: '确认添加', onPressed: _confirm),
        ],
      ),
    );
  }
}

class _DishVariantSheet extends StatelessWidget {
  const _DishVariantSheet({required this.dish, required this.items});

  final Dish dish;
  final List<OrderItemRecord> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择要减少的规格', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            dish.name,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return AppCard(
                  onTap: () => Navigator.of(context).pop(item.selectedSpecs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.specsDisplay.isEmpty
                                  ? '默认规格'
                                  : item.specsDisplay,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '当前数量：${item.quantity}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
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

class _SpecRequiredBadge extends StatelessWidget {
  const _SpecRequiredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '必选',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
