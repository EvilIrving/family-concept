import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/utils/app_exception.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Handles sign-in and registration flows.
class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<Session?> authStateChanges() async* {
    yield _client.auth.currentSession;

    await for (final event in _client.auth.onAuthStateChange) {
      yield event.session;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const AppException('请输入邮箱');
    }

    try {
      await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '登录失败，请稍后重试');
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final normalized = username.trim().toLowerCase();
    final normalizedEmail = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const AppException('请输入用户名');
    }
    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(normalized)) {
      throw const AppException('用户名需为 3-20 位字母、数字或下划线');
    }
    if (normalizedEmail.isEmpty) {
      throw const AppException('请输入邮箱');
    }

    try {
      final response = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'username': normalized},
      );

      final user = response.user;
      if (user == null) {
        throw const AppException('注册失败，请稍后再试');
      }

      await _client
          .from('profiles')
          .upsert({'id': user.id, 'username': normalized, 'avatar_url': null})
          .select()
          .single();

      if (_client.auth.currentSession == null) {
        final signInResponse = await _client.auth.signInWithPassword(
          email: normalizedEmail,
          password: password,
        );
        if (signInResponse.session == null) {
          throw const AppException('当前项目需要关闭邮箱确认，才能在注册后直接进入应用');
        }
      }
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '注册失败，请稍后再试');
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
