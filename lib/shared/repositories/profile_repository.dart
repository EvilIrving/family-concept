import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/username_codec.dart';
import '../models/app_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// Reads and updates the current user's profile.
class ProfileRepository {
  const ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<AppProfile?> fetchMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return AppProfile.fromJson(Map<String, dynamic>.from(response));
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '用户信息加载失败，请稍后重试');
    }
  }

  Future<AppProfile> updateMyProfile({
    required String username,
    required String avatarUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppException('请先登录');
    }

    UsernameCodec.validate(username);
    final normalized = UsernameCodec.normalize(username);

    try {
      final current = await fetchMyProfile();
      if (current == null) {
        throw const AppException('当前用户档案不存在');
      }

      if (current.username != normalized) {
        await _client.auth.updateUser(
          UserAttributes(
            email: UsernameCodec.emailFor(normalized),
            data: {'username': normalized},
          ),
        );
      }

      final response = await _client
          .from('profiles')
          .update({
            'username': normalized,
            'avatar_url': avatarUrl.trim().isEmpty ? null : avatarUrl.trim(),
          })
          .eq('id', user.id)
          .select()
          .single();

      return AppProfile.fromJson(Map<String, dynamic>.from(response));
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '保存失败，请稍后重试');
    }
  }
}
