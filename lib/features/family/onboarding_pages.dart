import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/extensions.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/family_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import 'family_providers.dart';

class OnboardingChoicePage extends ConsumerStatefulWidget {
  const OnboardingChoicePage({super.key});

  @override
  ConsumerState<OnboardingChoicePage> createState() =>
      _OnboardingChoicePageState();
}

class _OnboardingChoicePageState extends ConsumerState<OnboardingChoicePage> {
  final _inviteCodeController = TextEditingController();
  final _familyNameController = TextEditingController();
  bool _isSubmitting = false;
  bool _isCreateFamilyExpanded = false;
  String? _errorText;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final inviteCode = _inviteCodeController.text.trim();
    final familyName = _familyNameController.text.trim();
    if (inviteCode.isEmpty && familyName.isEmpty) {
      setState(() {
        _errorText = '请输入邀请码，或展开创建家庭并填写家庭名称';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final repository = ref.read(familyRepositoryProvider);
      final family = inviteCode.isNotEmpty
          ? await repository.joinFamilyByCode(inviteCode)
          : await repository.createFamily(familyName);
      await ref.read(currentFamilyIdProvider.notifier).selectFamily(family.id);
      invalidateSessionScope(ref);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      setState(() {
        _errorText = AppException.from(
          error,
          fallbackMessage: '进入家庭失败，请稍后重试',
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
      title: '进入家庭',
      subtitle: '必须先创建或加入一个家庭',
      useGradientHeader: false,
      body: CenteredContent(
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '先完成家庭归属',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '默认通过邀请码进入；如果你是第一次创建家庭，再展开创建家庭。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              AppTextField(
                controller: _inviteCodeController,
                label: '邀请码',
                hintText: '输入邀请码加入家庭',
                errorText: _errorText,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isCreateFamilyExpanded = !_isCreateFamilyExpanded;
                    });
                  },
                  child: Text(_isCreateFamilyExpanded ? '收起创建家庭' : '创建家庭'),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: _isCreateFamilyExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: AppTextField(
                    controller: _familyNameController,
                    label: '家庭名称',
                    hintText: '邀请码为空时按创建家庭处理',
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              PrimaryButton(
                label: '进入家庭',
                onPressed: _submit,
                icon: Icons.check_circle_rounded,
                isLoading: _isSubmitting,
              ),
            ],
          ),
        ),
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
