import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/extensions.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/order_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';
import '../family/onboarding_pages.dart';
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
        body: EmptyState(title: '还没有家庭', description: '请先创建或加入一个家庭。'),
      );
    }

    final dishesAsync = ref.watch(dishesProvider(family.id));

    return AppScaffold(
      title: '菜单',
      subtitle: family.name,
      actions: [
        IconButton(
          onPressed: () => showFamilySwitcherSheet(context, ref),
          icon: const Icon(Icons.swap_horiz_rounded),
        ),
        if (family.role.canManageMenu)
          IconButton(
            onPressed: () => context.push('/app/menu/dish/new'),
            icon: const Icon(Icons.add_rounded),
          ),
      ],
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
                search.isEmpty ||
                dish.name.toLowerCase().contains(search) ||
                dish.ingredients.any(
                  (ingredient) =>
                      ingredient.name.toLowerCase().contains(search),
                );
            return matchesCategory && matchesSearch;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FamilyHeaderCard(
                family: family,
                onSwitch: () => showFamilySwitcherSheet(context, ref),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: AppTextField(
                  controller: _searchController,
                  label: '搜索菜品',
                  hintText: '搜菜名或食材',
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
                for (final dish in filtered) ...[
                  _DishCard(dish: dish, family: family),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _DishCard extends ConsumerWidget {
  const _DishCard({required this.dish, required this.family});

  final Dish dish;
  final FamilySummary family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageAsync = ref.watch(dishImageProvider(dish.imageUrl));

    return AppCard(
      onTap: () {
        showAppBottomSheet<void>(
          context: context,
          builder: (_) => _DishDetailSheet(dish: dish, family: family),
        );
      },
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 84,
              height: 84,
              child: imageAsync.when(
                loading: () => Container(
                  color: AppColors.surfaceSoft,
                  child: const Icon(Icons.image_rounded),
                ),
                error: (_, _) => Container(
                  color: AppColors.surfaceSoft,
                  child: const Icon(Icons.image_not_supported_rounded),
                ),
                data: (url) => url == null
                    ? Container(
                        color: AppColors.surfaceSoft,
                        child: const Icon(Icons.rice_bowl_rounded),
                      )
                    : Image.network(url, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dish.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  dish.category,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${dish.ingredients.length} 个食材',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _DishDetailSheet extends ConsumerStatefulWidget {
  const _DishDetailSheet({required this.dish, required this.family});

  final Dish dish;
  final FamilySummary family;

  @override
  ConsumerState<_DishDetailSheet> createState() => _DishDetailSheetState();
}

class _DishDetailSheetState extends ConsumerState<_DishDetailSheet> {
  int _quantity = 1;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(activeOrderSummaryProvider(widget.family.id));
    final session = ref.watch(appSessionProvider).valueOrNull;
    final currentUserId = session?.authenticatedUserId;
    final imageAsync = ref.watch(dishImageProvider(widget.dish.imageUrl));

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
              height: 180,
              child: imageAsync.when(
                loading: () => Container(
                  color: AppColors.surfaceSoft,
                  child: const LoadingView(label: '图片加载中'),
                ),
                error: (_, _) => Container(
                  color: AppColors.surfaceSoft,
                  child: const Icon(Icons.image_not_supported_rounded),
                ),
                data: (url) => url == null
                    ? Container(
                        color: AppColors.surfaceSoft,
                        child: const Icon(Icons.rice_bowl_rounded, size: 48),
                      )
                    : Image.network(url, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.dish.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            widget.dish.category,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text('食材', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final ingredient in widget.dish.ingredients)
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
          const SizedBox(height: 16),
          orderAsync.when(
            loading: () => const SecondaryButton(
              label: '正在检查订单',
              onPressed: null,
              icon: Icons.hourglass_top_rounded,
            ),
            error: (error, _) => ErrorStateView(
              message: AppException.from(
                error,
                fallbackMessage: '订单状态加载失败，请稍后重试',
              ).message,
            ),
            data: (summary) {
              if (summary == null) {
                return SecondaryButton(
                  label: '当前没有进行中的订单',
                  icon: Icons.receipt_long_rounded,
                  onPressed: () => context.go('/app/orders'),
                );
              }

              if (!summary.isCurrentUserJoined) {
                return SecondaryButton(
                  label: '先加入订单',
                  icon: Icons.group_add_rounded,
                  onPressed: () =>
                      context.go('/app/orders/${summary.order.id}'),
                );
              }

              final orderMemberId = summary.participants
                  .firstWhere(
                    (participant) => participant.userId == currentUserId,
                  )
                  .id;

              return Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _quantity > 1
                            ? () => setState(() {
                                _quantity -= 1;
                              })
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      Text(
                        '$_quantity 份',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          _quantity += 1;
                        }),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                  PrimaryButton(
                    label: '加一道',
                    icon: Icons.add_shopping_cart_rounded,
                    isLoading: _isSubmitting,
                    onPressed: () async {
                      setState(() {
                        _isSubmitting = true;
                      });
                      try {
                        await ref
                            .read(orderRepositoryProvider)
                            .addDishToOrder(
                              order: summary.order,
                              dishId: widget.dish.id,
                              orderMemberId: orderMemberId,
                              quantity: _quantity,
                            );
                        ref.invalidate(orderDetailProvider(summary.order.id));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已加入订单')),
                          );
                          Navigator.of(context).pop();
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppException.from(
                                  error,
                                  fallbackMessage: '加菜失败，请稍后重试',
                                ).message,
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSubmitting = false;
                          });
                        }
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
