import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../shared/repositories/auth_repository.dart';
import '../../shared/repositories/family_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _familyNameController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _isCreateFamilyExpanded = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      await ref
          .read(authRepositoryProvider)
          .register(
            username: _usernameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );

      final familyRepository = ref.read(familyRepositoryProvider);
      final family = inviteCode.isNotEmpty
          ? await familyRepository.joinFamilyByCode(inviteCode)
          : await familyRepository.createFamily(familyName);

      await ref.read(currentFamilyIdProvider.notifier).selectFamily(family.id);
      invalidateSessionScope(ref);

      if (mounted) {
        context.go('/app/menu');
      }
    } catch (error) {
      setState(() {
        _errorText = AppException.from(
          error,
          fallbackMessage: '注册失败，请稍后再试',
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
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final authPadding = EdgeInsets.fromLTRB(
      AppSpacing.lg,
      viewportHeight * 0.022,
      AppSpacing.lg,
      viewportHeight * 0.036,
    );

    return AppScaffold(
      title: '注册',
      subtitle: '创建账号并进入家庭',
      scrollable: true,
      showAppBar: false,
      useGradientHeader: false,
      bodyPadding: authPadding,
      body: CenteredContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '开始使用 Family Kitchen',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _usernameController,
              label: '用户名',
              hintText: '3-20 位字母、数字或下划线',
              errorText: _errorText,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _emailController,
              label: '邮箱',
              hintText: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _passwordController,
              label: '密码',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _inviteCodeController,
              label: '邀请码',
              textInputAction: TextInputAction.done,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: _familyNameController,
                      label: '家庭名称',
                      hintText: '低频操作，可选填写',
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '如果同时填写邀请码和家庭名称，会优先按邀请码加入家庭',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PrimaryButton(
              label: '注册',
              onPressed: _submit,
              icon: Icons.check_circle_rounded,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: '去登录',
              icon: Icons.login_rounded,
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}
