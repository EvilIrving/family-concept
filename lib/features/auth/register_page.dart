import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../shared/repositories/auth_repository.dart';
import '../../shared/widgets/app_widgets.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorText = '两次输入的密码不一致';
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
            password: _passwordController.text,
          );
      if (mounted) {
        context.go('/onboarding');
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
    return AppScaffold(
      title: '注册',
      subtitle: '先有账号，再进入家庭',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '创建新账号',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '用户名仅支持字母、数字和下划线，注册成功后会直接进入 onboarding。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _usernameController,
                  label: '用户名',
                  hintText: '3-20 位字母、数字或下划线',
                  errorText: _errorText,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordController,
                  label: '密码',
                  obscureText: _obscurePassword,
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
                  controller: _confirmPasswordController,
                  label: '确认密码',
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: '注册',
                  onPressed: _submit,
                  icon: Icons.check_circle_rounded,
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            label: '去登录',
            icon: Icons.login_rounded,
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}
