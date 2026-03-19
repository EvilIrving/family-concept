import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/bootstrap.dart';
import '../../core/utils/extensions.dart';
import '../../shared/models/app_models.dart';
import '../../shared/repositories/auth_repository.dart';
import '../../shared/repositories/family_repository.dart';
import '../../shared/repositories/profile_repository.dart';

final authSessionProvider = StreamProvider<Session?>((ref) {
  final bootstrap = ref.watch(bootstrapStateProvider);
  if (!bootstrap.hasBackend) {
    return Stream.value(null);
  }

  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentFamilyIdProvider =
    NotifierProvider<CurrentFamilyIdController, String?>(
      CurrentFamilyIdController.new,
    );

class CurrentFamilyIdController extends Notifier<String?> {
  static const _storageKey = 'current_family_id';

  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);

  @override
  String? build() => _preferences.getString(_storageKey);

  Future<void> selectFamily(String familyId) async {
    state = familyId;
    await _preferences.setString(_storageKey, familyId);
  }

  Future<void> clear() async {
    state = null;
    await _preferences.remove(_storageKey);
  }
}

final currentUserProfileProvider = FutureProvider<AppProfile?>((ref) async {
  final auth = ref.watch(authSessionProvider);
  if (auth.valueOrNull == null) {
    return null;
  }

  return ref.watch(profileRepositoryProvider).fetchMyProfile();
});

final currentUserFamiliesProvider = FutureProvider<List<FamilySummary>>((
  ref,
) async {
  final auth = ref.watch(authSessionProvider);
  if (auth.valueOrNull == null) {
    return const [];
  }

  return ref.watch(familyRepositoryProvider).fetchCurrentUserFamilies();
});

final appSessionProvider = Provider<AsyncValue<AppSessionData>>((ref) {
  final bootstrap = ref.watch(bootstrapStateProvider);
  if (!bootstrap.isSupabaseConfigured || bootstrap.initError != null) {
    return AsyncValue.data(
      AppSessionData(
        isConfigured: bootstrap.isSupabaseConfigured,
        initError: bootstrap.initError,
        authenticatedUserId: null,
        profile: null,
        families: const [],
        currentFamily: null,
      ),
    );
  }

  final auth = ref.watch(authSessionProvider);
  if (auth.isLoading) {
    return const AsyncLoading();
  }
  if (auth.hasError) {
    return AsyncValue.error(auth.error!, auth.stackTrace!);
  }

  final session = auth.valueOrNull;
  if (session == null) {
    return const AsyncValue.data(
      AppSessionData(
        isConfigured: true,
        initError: null,
        authenticatedUserId: null,
        profile: null,
        families: [],
        currentFamily: null,
      ),
    );
  }

  final profile = ref.watch(currentUserProfileProvider);
  final families = ref.watch(currentUserFamiliesProvider);
  if (profile.isLoading || families.isLoading) {
    return const AsyncLoading();
  }
  if (profile.hasError) {
    return AsyncValue.error(profile.error!, profile.stackTrace!);
  }
  if (families.hasError) {
    return AsyncValue.error(families.error!, families.stackTrace!);
  }

  final savedFamilyId = ref.watch(currentFamilyIdProvider);
  final currentFamily = _resolveCurrentFamily(
    savedFamilyId: savedFamilyId,
    families: families.requireValue,
  );

  return AsyncValue.data(
    AppSessionData(
      isConfigured: true,
      initError: null,
      authenticatedUserId: session.user.id,
      profile: profile.requireValue,
      families: families.requireValue,
      currentFamily: currentFamily,
    ),
  );
});

FamilySummary? _resolveCurrentFamily({
  required String? savedFamilyId,
  required List<FamilySummary> families,
}) {
  if (families.isEmpty) {
    return null;
  }

  if (savedFamilyId == null) {
    return families.first;
  }

  for (final family in families) {
    if (family.id == savedFamilyId) {
      return family;
    }
  }

  return families.first;
}

final currentFamilyProvider = Provider<FamilySummary?>((ref) {
  return ref.watch(appSessionProvider).valueOrNull?.currentFamily;
});

void invalidateSessionScope(WidgetRef ref) {
  ref.invalidate(currentUserProfileProvider);
  ref.invalidate(currentUserFamiliesProvider);
  ref.invalidate(appSessionProvider);
}
