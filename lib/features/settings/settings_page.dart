import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/extensions.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/auth_repository.dart';
import '../../shared/repositories/family_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';
import '../family/onboarding_pages.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final family = session?.currentFamily;
    final profile = session?.profile;

    if (family == null || profile == null) {
      return const AppScaffold(
        title: '设置',
        body: EmptyState(title: '还没有可用内容', description: '请先登录并进入一个家庭。'),
      );
    }

    return AppScaffold(
      title: '设置',
      subtitle: family.name,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FamilyHeaderCard(
            family: family,
            onSwitch: () => showFamilySwitcherSheet(context, ref),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前账号', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  profile.username,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  profile.avatarUrl?.isNotEmpty == true
                      ? profile.avatarUrl!
                      : '未设置头像地址',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SecondaryButton(
                  label: '编辑个人信息',
                  icon: Icons.account_circle_rounded,
                  onPressed: () => context.push('/app/settings/profile'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '家庭信息',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (family.role.canManageMenu)
                      IconButton(
                        onPressed: () => _showRenameDialog(context, ref),
                        icon: const Icon(Icons.edit_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '邀请码 ${family.family.joinCode}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '你当前是 ${family.role.label}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SecondaryButton(
                  label: '复制邀请码',
                  icon: Icons.copy_rounded,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: family.family.joinCode),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('邀请码已复制')));
                    }
                  },
                ),
                if (family.role.canManageMenu) ...[
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: '刷新邀请码',
                    icon: Icons.refresh_rounded,
                    onPressed: () => _rotateJoinCode(context, ref),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (family.role.canManageMembers)
            SecondaryButton(
              label: '成员管理',
              icon: Icons.group_rounded,
              onPressed: () => context.push('/app/settings/family-members'),
            ),
          if (family.role.canManageMembers) const SizedBox(height: 12),
          SecondaryButton(
            label: '历史订单',
            icon: Icons.history_rounded,
            onPressed: () => context.push('/app/settings/order-history'),
          ),
          if (family.role != FamilyRole.owner) ...[
            const SizedBox(height: 12),
            DangerButton(
              label: '退出家庭',
              icon: Icons.exit_to_app_rounded,
              onPressed: () => _leaveFamily(context, ref),
            ),
          ],
          const SizedBox(height: 12),
          DangerButton(
            label: '退出登录',
            icon: Icons.logout_rounded,
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _rotateJoinCode(BuildContext context, WidgetRef ref) async {
    final family = ref.read(currentFamilyProvider);
    if (family == null) {
      return;
    }

    try {
      final code = await ref
          .read(familyRepositoryProvider)
          .rotateJoinCode(family.id);
      invalidateSessionScope(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('邀请码已刷新：$code')));
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showError(context, error);
    }
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final family = ref.read(currentFamilyProvider);
    if (family == null) {
      return;
    }

    final controller = TextEditingController(text: family.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑家庭名称'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '家庭名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null || result.trim().isEmpty) {
      return;
    }

    try {
      await ref
          .read(familyRepositoryProvider)
          .renameFamily(familyId: family.id, name: result);
      invalidateSessionScope(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('家庭名称已更新')));
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showError(context, error);
    }
  }

  Future<void> _leaveFamily(BuildContext context, WidgetRef ref) async {
    final family = ref.read(currentFamilyProvider);
    if (family == null) {
      return;
    }

    final confirmed = await showConfirmDialog(
      context: context,
      title: '退出这个家庭？',
      message: '退出后你会失去这个家庭的后续访问权限。',
      confirmLabel: '退出家庭',
      isDanger: true,
    );
    if (!confirmed) {
      return;
    }

    try {
      await ref.read(familyRepositoryProvider).leaveFamily(family.id);
      await ref.read(currentFamilyIdProvider.notifier).clear();
      invalidateSessionScope(ref);
      if (context.mounted) {
        context.go('/onboarding');
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showError(context, error);
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: '退出当前账号？',
      message: '退出后需要重新登录才能继续使用。',
      confirmLabel: '退出登录',
      isDanger: true,
    );
    if (!confirmed) {
      return;
    }

    await ref.read(currentFamilyIdProvider.notifier).clear();
    await ref.read(authRepositoryProvider).signOut();
    invalidateSessionScope(ref);
    if (context.mounted) {
      context.go('/login');
    }
  }

  void _showError(BuildContext context, Object error) {
    final message = AppException.from(
      error,
      fallbackMessage: '操作失败，请稍后重试',
    ).message;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
