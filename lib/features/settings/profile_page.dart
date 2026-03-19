import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_exception.dart';
import '../../shared/repositories/profile_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return AppScaffold(
      title: '个人信息',
      body: profileAsync.when(
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

          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
            ),
          );
        },
      ),
    );
  }
}
