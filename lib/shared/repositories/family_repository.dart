import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/utils/app_exception.dart';
import '../models/app_models.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(ref.watch(supabaseClientProvider));
});

/// Family onboarding and member-management repository.
class FamilyRepository {
  const FamilyRepository(this._client);

  final SupabaseClient _client;

  Future<List<FamilySummary>> fetchCurrentUserFamilies() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    try {
      final response = await _client
          .from('family_members')
          .select(
            'id, family_id, user_id, role, status, joined_at, removed_at, '
            'invited_by, families!inner(*)',
          )
          .eq('user_id', user.id)
          .eq('status', 'active')
          .order('joined_at');

      return response
          .map(
            (row) => FamilyMembership.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((membership) => membership.family != null)
          .map(
            (membership) => FamilySummary(
              family: membership.family!,
              membership: membership,
            ),
          )
          .toList();
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '家庭信息加载失败，请稍后重试');
    }
  }

  Future<FamilySummary> createFamily(String name) async {
    try {
      final rpc = await _client.rpc(
        'create_family_with_owner',
        params: {'p_name': name.trim()},
      );

      final rows = (rpc as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final familyId = rows.first['family_id'] as String;

      return fetchFamilySummary(familyId);
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '创建家庭失败，请稍后重试');
    }
  }

  Future<FamilySummary> joinFamilyByCode(String code) async {
    try {
      final rpc = await _client.rpc(
        'join_family_by_code',
        params: {'p_code': code.trim()},
      );

      final rows = (rpc as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final familyId = rows.first['family_id'] as String;

      return fetchFamilySummary(familyId);
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '加入家庭失败，请稍后重试');
    }
  }

  Future<FamilySummary> fetchFamilySummary(String familyId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppException('请先登录');
    }

    try {
      final response = await _client
          .from('family_members')
          .select(
            'id, family_id, user_id, role, status, joined_at, removed_at, '
            'invited_by, families!inner(*)',
          )
          .eq('family_id', familyId)
          .eq('user_id', user.id)
          .eq('status', 'active')
          .single();

      final membership = FamilyMembership.fromJson(
        Map<String, dynamic>.from(response),
      );

      return FamilySummary(family: membership.family!, membership: membership);
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '家庭信息加载失败，请稍后重试');
    }
  }

  Future<String> rotateJoinCode(String familyId) async {
    try {
      final response = await _client.rpc(
        'rotate_family_join_code',
        params: {'p_family_id': familyId},
      );
      return response as String;
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '邀请码刷新失败，请稍后重试');
    }
  }

  Future<void> renameFamily({
    required String familyId,
    required String name,
  }) async {
    try {
      await _client.rpc(
        'rename_family',
        params: {'p_family_id': familyId, 'p_name': name.trim()},
      );
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '家庭名称更新失败，请稍后重试');
    }
  }

  Future<List<FamilyMembership>> fetchFamilyMembers(String familyId) async {
    try {
      final response = await _client
          .from('family_members')
          .select(
            'id, family_id, user_id, role, status, joined_at, removed_at, '
            'invited_by, profiles!inner(*)',
          )
          .eq('family_id', familyId)
          .eq('status', 'active')
          .order('joined_at');

      final members = response
          .map(
            (row) => FamilyMembership.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();

      members.sort((left, right) {
        final roleCompare = _roleWeight(
          left.role,
        ).compareTo(_roleWeight(right.role));
        if (roleCompare != 0) {
          return roleCompare;
        }
        return (left.profile?.username ?? '').compareTo(
          right.profile?.username ?? '',
        );
      });

      return members;
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '成员加载失败，请稍后重试');
    }
  }

  int _roleWeight(FamilyRole role) {
    return switch (role) {
      FamilyRole.owner => 0,
      FamilyRole.admin => 1,
      FamilyRole.member => 2,
    };
  }

  Future<void> updateMemberRole({
    required String familyId,
    required String memberId,
    required FamilyRole role,
  }) async {
    try {
      await _client.rpc(
        'update_family_member_role',
        params: {
          'p_family_id': familyId,
          'p_target_member_id': memberId,
          'p_new_role': role.name,
        },
      );
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '角色更新失败，请稍后重试');
    }
  }

  Future<void> removeMember({
    required String familyId,
    required String memberId,
  }) async {
    try {
      await _client.rpc(
        'remove_family_member',
        params: {'p_family_id': familyId, 'p_target_member_id': memberId},
      );
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '移除成员失败，请稍后重试');
    }
  }

  Future<void> leaveFamily(String familyId) async {
    try {
      await _client.rpc('leave_family', params: {'p_family_id': familyId});
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '退出家庭失败，请稍后重试');
    }
  }
}
