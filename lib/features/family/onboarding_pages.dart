import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/extensions.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/family_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import 'family_providers.dart';

class OnboardingChoicePage extends StatelessWidget {
  const OnboardingChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '进入家庭',
      subtitle: '必须先创建或加入一个家庭',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择进入方式',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '创建家庭后，你会成为这个家庭的 owner；如果已经被邀请，直接输入邀请码即可。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: '创建家庭',
            icon: Icons.add_home_rounded,
            onPressed: () => context.push('/onboarding/create-family'),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: '加入家庭',
            icon: Icons.group_add_rounded,
            onPressed: () => context.push('/onboarding/join-family'),
          ),
        ],
      ),
    );
  }
}

class CreateFamilyPage extends ConsumerStatefulWidget {
  const CreateFamilyPage({super.key});

  @override
  ConsumerState<CreateFamilyPage> createState() => _CreateFamilyPageState();
}

class _CreateFamilyPageState extends ConsumerState<CreateFamilyPage> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final family = await ref
          .read(familyRepositoryProvider)
          .createFamily(_controller.text);
      await ref.read(currentFamilyIdProvider.notifier).selectFamily(family.id);
      invalidateSessionScope(ref);
      if (mounted) {
        context.go('/app/menu');
      }
    } catch (error) {
      setState(() {
        _errorText = AppException.from(
          error,
          fallbackMessage: '创建家庭失败，请稍后重试',
        ).message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '创建家庭',
      subtitle: '成功后你会成为 owner',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _controller,
                  label: '家庭名称',
                  hintText: '例如 Cain 家的小厨房',
                  errorText: _errorText,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: '创建家庭',
                  onPressed: _submit,
                  icon: Icons.check_rounded,
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JoinFamilyPage extends ConsumerStatefulWidget {
  const JoinFamilyPage({super.key});

  @override
  ConsumerState<JoinFamilyPage> createState() => _JoinFamilyPageState();
}

class _JoinFamilyPageState extends ConsumerState<JoinFamilyPage> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final family = await ref
          .read(familyRepositoryProvider)
          .joinFamilyByCode(_controller.text);
      await ref.read(currentFamilyIdProvider.notifier).selectFamily(family.id);
      invalidateSessionScope(ref);
      if (mounted) {
        context.go('/app/menu');
      }
    } catch (error) {
      setState(() {
        _errorText = AppException.from(
          error,
          fallbackMessage: '加入家庭失败，请稍后重试',
        ).message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '加入家庭',
      subtitle: '输入家庭邀请码',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _controller,
                  label: '邀请码',
                  hintText: '输入 10 位邀请码',
                  helperText: '如果邀请码已失效，请联系管理员刷新',
                  errorText: _errorText,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: '确认加入',
                  onPressed: _submit,
                  icon: Icons.check_rounded,
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showFamilySwitcherSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final session = ref.read(appSessionProvider).valueOrNull;
  final families = session?.families ?? const <FamilySummary>[];

  await showAppBottomSheet<void>(
    context: context,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('切换家庭', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final family in families) ...[
              AppCard(
                onTap: () async {
                  await ref
                      .read(currentFamilyIdProvider.notifier)
                      .selectFamily(family.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            family.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '角色 ${family.role.label}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    StatusChip.role(family.role),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    },
  );
}
