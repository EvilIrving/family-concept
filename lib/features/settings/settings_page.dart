import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/auth_repository.dart';
import '../../shared/repositories/family_repository.dart';
import '../../shared/repositories/profile_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';
import '../family/onboarding_pages.dart';
import '../order/order_providers.dart';

final familyMembersProvider =
    FutureProvider.family<List<FamilyMembership>, String>(
      (ref, familyId) =>
          ref.watch(familyRepositoryProvider).fetchFamilyMembers(familyId),
    );

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _confirmLogout = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final family = session?.currentFamily;
    final profile = session?.profile;
    final email =
        ref.watch(supabaseClientProvider).auth.currentUser?.email ?? '';

    if (family == null || profile == null) {
      return const AppScaffold(
        title: '设置',
        showAppBar: false,
        body: EmptyState(title: '还没有可用内容', description: '请先登录并进入一个家庭。'),
      );
    }

    final isChef = family.role == FamilyRole.owner ||
        family.role == FamilyRole.admin;

    return AppScaffold(
      title: '设置',
      showAppBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileCard(
            username: profile.username,
            email: email,
            familyName: family.name,
            isChef: isChef,
            onEdit: () => showAppBottomSheet<void>(
              context: context,
              builder: (_) => const _ProfileSheet(),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                _SettingsRow(
                  title: '切换家庭',
                  subtitle: '当前：${family.name}',
                  onTap: () => showFamilySwitcherSheet(context, ref),
                ),
                const Divider(height: 20),
                _SettingsRow(
                  title: '邀请码',
                  subtitle: family.family.joinCode,
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      AppIconButton(
                        icon: Icons.copy_rounded,
                        tooltip: '复制邀请码',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: family.family.joinCode),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('邀请码已复制')),
                            );
                          }
                        },
                      ),
                      if (family.role.canManageMenu)
                        AppIconButton(
                          icon: Icons.refresh_rounded,
                          tooltip: '刷新邀请码',
                          onPressed: () => _rotateJoinCode(context, ref),
                        ),
                    ],
                  ),
                ),
                if (family.role.canManageMembers) ...[
                  const Divider(height: 20),
                  _SettingsRow(
                    title: '成员管理',
                    subtitle: '查看成员、调整角色、移除成员',
                    onTap: () => showAppBottomSheet<void>(
                      context: context,
                      builder: (_) => _MembersSheet(family: family),
                    ),
                  ),
                ],
                const Divider(height: 20),
                _SettingsRow(
                  title: '历史订单',
                  subtitle: '查看已结束订单',
                  onTap: () => showAppBottomSheet<void>(
                    context: context,
                    builder: (_) => _HistoryOrdersSheet(family: family),
                  ),
                ),
              ],
            ),
          ),
          if (family.role != FamilyRole.owner) ...[
            const SizedBox(height: 16),
            DangerButton(
              label: '退出家庭',
              icon: Icons.exit_to_app_rounded,
              onPressed: () => _leaveFamily(context, ref),
            ),
          ],
          const SizedBox(height: 12),
          DangerButton(
            label: _confirmLogout ? '确认退出登录' : '退出登录',
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
      if (context.mounted) {
        _showError(context, error);
      }
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
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    if (!_confirmLogout) {
      setState(() {
        _confirmLogout = true;
      });
      return;
    }

    try {
      await ref.read(authRepositoryProvider).signOut();
      ref.read(currentFamilyIdProvider.notifier).clear();
      invalidateSessionScope(ref);
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _confirmLogout = false;
        });
      }
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.username,
    required this.email,
    required this.familyName,
    required this.isChef,
    required this.onEdit,
  });

  final String username;
  final String email;
  final String familyName;
  final bool isChef;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isChef ? '👩‍🍳' : '👴',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  email.isEmpty ? '未读取到邮箱' : email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.home_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      familyName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.edit_rounded,
            tooltip: '编辑个人信息',
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet();

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  late final TextEditingController _usernameController;
  late final TextEditingController _avatarController;
  bool _initialized = false;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _avatarController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: profileAsync.when(
          loading: () => const SizedBox(height: 280, child: LoadingView()),
          error: (error, _) => ErrorStateView(
            message: AppException.from(
              error,
              fallbackMessage: '用户信息加载失败，请稍后重试',
            ).message,
            onRetry: () => ref.invalidate(currentUserProfileProvider),
          ),
          data: (profile) {
            if (profile == null) {
              return const EmptyState(
                title: '没有可编辑的资料',
                description: '请重新登录后再试。',
              );
            }

            if (!_initialized) {
              _usernameController.text = profile.username;
              _avatarController.text = profile.avatarUrl ?? '';
              _initialized = true;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('编辑个人信息', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _usernameController,
                  label: '用户名',
                  errorText: _errorText,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _avatarController,
                  label: '头像地址',
                  hintText: '可选，输入图片 URL',
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: '保存',
                  onPressed: _save,
                  icon: Icons.save_rounded,
                  isLoading: _isSaving,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateMyProfile(
            username: _usernameController.text,
            avatarUrl: _avatarController.text,
          );
      invalidateSessionScope(ref);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存')));
        Navigator.of(context).pop();
      }
    } catch (error) {
      setState(() {
        _errorText = AppException.from(
          error,
          fallbackMessage: '保存失败，请稍后重试',
        ).message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _MembersSheet extends ConsumerWidget {
  const _MembersSheet({required this.family});

  final FamilySummary family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider(family.id));
    final currentUserId = ref
        .watch(appSessionProvider)
        .valueOrNull
        ?.authenticatedUserId;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: membersAsync.when(
          loading: () => const SizedBox(height: 280, child: LoadingView()),
          error: (error, _) => ErrorStateView(
            message: AppException.from(
              error,
              fallbackMessage: '成员加载失败，请稍后重试',
            ).message,
            onRetry: () => ref.invalidate(familyMembersProvider(family.id)),
          ),
          data: (members) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('成员管理', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final canAct =
                          member.userId != currentUserId &&
                          member.role != FamilyRole.owner;

                      return SizedBox(
                        width: double.infinity,
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.profile?.username ?? '未知用户',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '加入于 ${formatDate(member.joinedAt)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              StatusChip.role(member.role),
                              if (canAct) ...[
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  onSelected: (value) => _handleMemberAction(
                                    context,
                                    ref,
                                    family,
                                    member,
                                    value,
                                  ),
                                  itemBuilder: (context) {
                                    final items = <PopupMenuEntry<String>>[];
                                    if (family.role == FamilyRole.owner) {
                                      items.add(
                                        PopupMenuItem<String>(
                                          value: member.role == FamilyRole.admin
                                              ? 'member'
                                              : 'admin',
                                          child: Text(
                                            member.role == FamilyRole.admin
                                                ? '取消管理员'
                                                : '设为管理员',
                                          ),
                                        ),
                                      );
                                    }
                                    if (family.role == FamilyRole.owner ||
                                        (family.role == FamilyRole.admin &&
                                            member.role == FamilyRole.member)) {
                                      items.add(
                                        const PopupMenuItem<String>(
                                          value: 'remove',
                                          child: Text('移除成员'),
                                        ),
                                      );
                                    }
                                    return items;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleMemberAction(
    BuildContext context,
    WidgetRef ref,
    FamilySummary family,
    FamilyMembership member,
    String value,
  ) async {
    try {
      if (value == 'remove') {
        await ref
            .read(familyRepositoryProvider)
            .removeMember(familyId: family.id, memberId: member.id);
      } else {
        await ref
            .read(familyRepositoryProvider)
            .updateMemberRole(
              familyId: family.id,
              memberId: member.id,
              role: value == 'admin' ? FamilyRole.admin : FamilyRole.member,
            );
      }
      ref.invalidate(familyMembersProvider(family.id));
      invalidateSessionScope(ref);
    } catch (error) {
      if (context.mounted) {
        final message = AppException.from(
          error,
          fallbackMessage: '操作失败，请稍后重试',
        ).message;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }
}

class _HistoryOrdersSheet extends ConsumerWidget {
  const _HistoryOrdersSheet({required this.family});

  final FamilySummary family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(orderHistoryProvider(family.id));

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: historyAsync.when(
          loading: () => const SizedBox(height: 280, child: LoadingView()),
          error: (error, _) => ErrorStateView(
            message: AppException.from(
              error,
              fallbackMessage: '历史订单加载失败，请稍后重试',
            ).message,
            onRetry: () => ref.invalidate(orderHistoryProvider(family.id)),
          ),
          data: (orders) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('历史订单', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (orders.isEmpty)
                  const SizedBox(
                    width: double.infinity,
                    child: EmptyState(
                      title: '还没有历史订单',
                      description: '完成过的订单会显示在这里。',
                      icon: Icons.history_rounded,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 520),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return SizedBox(
                          width: double.infinity,
                          child: AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '订单 ${order.id.substring(0, 8)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        order.finishedAt == null
                                            ? formatDate(order.createdAt)
                                            : formatDateTime(order.finishedAt!),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                StatusChip.order(order.status),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
