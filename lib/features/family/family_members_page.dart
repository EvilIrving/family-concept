import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/extensions.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/family_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import 'family_providers.dart';
import 'onboarding_pages.dart';

final familyMembersProvider =
    FutureProvider.family<List<FamilyMembership>, String>(
      (ref, familyId) =>
          ref.watch(familyRepositoryProvider).fetchFamilyMembers(familyId),
    );

class FamilyMembersPage extends ConsumerWidget {
  const FamilyMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider);
    if (family == null) {
      return const AppScaffold(
        title: '成员管理',
        body: EmptyState(title: '当前没有家庭', description: '请先创建或加入一个家庭。'),
      );
    }

    final membersAsync = ref.watch(familyMembersProvider(family.id));

    return AppScaffold(
      title: '成员管理',
      subtitle: family.name,
      body: membersAsync.when(
        loading: () => const SizedBox(height: 320, child: LoadingView()),
        error: (error, _) => ErrorStateView(
          message: AppException.from(
            error,
            fallbackMessage: '成员加载失败，请稍后重试',
          ).message,
          onRetry: () => ref.invalidate(familyMembersProvider(family.id)),
        ),
        data: (members) {
          if (!family.role.canManageMembers) {
            return const ErrorStateView(message: '你没有查看该页面的权限');
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FamilyHeaderCard(
                family: family,
                onSwitch: () => showFamilySwitcherSheet(context, ref),
              ),
              const SizedBox(height: 24),
              SectionTitle('家庭成员'),
              const SizedBox(height: 12),
              for (final member in members) ...[
                _MemberCard(family: family, member: member),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({required this.family, required this.member});

  final FamilySummary family;
  final FamilyMembership member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref
        .watch(appSessionProvider)
        .valueOrNull
        ?.authenticatedUserId;
    final canActOnThisMember =
        member.userId != currentUserId && member.role != FamilyRole.owner;

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.primary,
            child: Text(
              (member.profile?.username ?? '?').substring(0, 1).toUpperCase(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.profile?.username ?? '未知用户',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '加入于 ${member.joinedAt.year}-${member.joinedAt.month}-${member.joinedAt.day}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusChip.role(member.role),
          if (canActOnThisMember) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'remove') {
                  final confirmed = await showConfirmDialog(
                    context: context,
                    title: '移除这个成员？',
                    message: '被移除后，对方将失去该家庭的后续访问权限。',
                    confirmLabel: '移除成员',
                    isDanger: true,
                  );
                  if (!confirmed) {
                    return;
                  }
                  try {
                    await ref
                        .read(familyRepositoryProvider)
                        .removeMember(familyId: family.id, memberId: member.id);
                    ref.invalidate(familyMembersProvider(family.id));
                    invalidateSessionScope(ref);
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('成员已移除')));
                    }
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    _showError(context, error);
                  }
                  return;
                }

                try {
                  await ref
                      .read(familyRepositoryProvider)
                      .updateMemberRole(
                        familyId: family.id,
                        memberId: member.id,
                        role: value == 'admin'
                            ? FamilyRole.admin
                            : FamilyRole.member,
                      );
                  ref.invalidate(familyMembersProvider(family.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('角色已更新')));
                  }
                } catch (error) {
                  if (!context.mounted) {
                    return;
                  }
                  _showError(context, error);
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[];
                if (family.role == FamilyRole.owner) {
                  items.add(
                    PopupMenuItem<String>(
                      value: member.role == FamilyRole.admin
                          ? 'member'
                          : 'admin',
                      child: Text(
                        member.role == FamilyRole.admin ? '取消管理员' : '设为管理员',
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
    );
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
