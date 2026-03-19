import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/bootstrap.dart';
import '../../core/utils/extensions.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/family/family_members_page.dart';
import '../../features/family/family_providers.dart';
import '../../features/family/onboarding_pages.dart';
import '../../features/menu/dish_form_page.dart';
import '../../features/menu/menu_page.dart';
import '../../features/order/join_order_page.dart';
import '../../features/order/order_detail_page.dart';
import '../../features/order/order_history_page.dart';
import '../../features/order/orders_page.dart';
import '../../features/settings/profile_page.dart';
import '../../features/settings/settings_page.dart';
import '../../shared/widgets/app_widgets.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final bootstrap = ref.watch(bootstrapStateProvider);
  final session = ref.watch(appSessionProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupRequiredPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingChoicePage(),
      ),
      GoRoute(
        path: '/app/join/:shareToken',
        builder: (context, state) {
          return JoinOrderPage(shareToken: state.pathParameters['shareToken']!);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/menu',
                builder: (context, state) => const MenuPage(),
                routes: [
                  GoRoute(
                    path: 'dish/new',
                    builder: (context, state) => const DishFormPage(),
                  ),
                  GoRoute(
                    path: 'dish/:dishId/edit',
                    builder: (context, state) =>
                        DishFormPage(dishId: state.pathParameters['dishId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/orders',
                builder: (context, state) => const OrdersPage(),
                routes: [
                  GoRoute(
                    path: ':orderId',
                    builder: (context, state) => OrderDetailPage(
                      orderId: state.pathParameters['orderId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/settings',
                builder: (context, state) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfilePage(),
                  ),
                  GoRoute(
                    path: 'family-members',
                    builder: (context, state) => const FamilyMembersPage(),
                  ),
                  GoRoute(
                    path: 'order-history',
                    builder: (context, state) => const OrderHistoryPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final path = state.uri.path;
      final onAuthPage = path == '/login' || path == '/register';
      final onOnboarding =
          path == '/onboarding' || path.startsWith('/onboarding/');
      final onJoinRoute = path.startsWith('/app/join/');
      final onSplash = path == '/splash';
      final onSetup = path == '/setup';

      if (!bootstrap.hasBackend) {
        return onSetup ? null : '/setup';
      }

      if (session.isLoading) {
        return onSplash ? null : '/splash';
      }

      final data = session.valueOrNull;
      if (data == null) {
        return onSplash ? null : '/splash';
      }

      if (!data.isAuthenticated) {
        if (onAuthPage) {
          return null;
        }
        return '/login';
      }

      if (data.needsOnboarding) {
        if (onOnboarding || onJoinRoute) {
          return null;
        }
        return '/onboarding';
      }

      if (onAuthPage || onOnboarding || onSplash || onSetup) {
        return '/app/menu';
      }

      return null;
    },
  );
});

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_rounded),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Setting',
          ),
        ],
      ),
    );
  }
}

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: session.hasError
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ErrorStateView(
                  message: session.error.toString(),
                  onRetry: () {
                    ref.invalidate(authSessionProvider);
                    ref.invalidate(currentUserProfileProvider);
                    ref.invalidate(currentUserFamiliesProvider);
                  },
                ),
              )
            : const LoadingView(label: '正在准备应用'),
      ),
    );
  }
}

class SetupRequiredPage extends ConsumerWidget {
  const SetupRequiredPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapStateProvider);
    final hasEnv = bootstrap.isSupabaseConfigured;
    final error = bootstrap.initError?.toString();

    return AppScaffold(
      title: '需要配置 Supabase',
      subtitle: '缺少运行时环境变量',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasEnv ? 'Supabase 初始化失败' : '请先通过 dart-define 提供 Supabase 配置',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  hasEnv
                      ? error ?? '初始化时发生未知错误'
                      : '运行示例：flutter run --dart-define=SUPABASE_URL=... '
                            '--dart-define=SUPABASE_ANON_KEY=...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
