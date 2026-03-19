import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_environment.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences override is missing.');
});

final bootstrapStateProvider = Provider<AppBootstrapState>((ref) {
  throw UnimplementedError('Bootstrap state override is missing.');
});

/// Initializes platform services before the app starts.
final class AppBootstrap {
  AppBootstrap._({required this.preferences, required this.state});

  final SharedPreferences preferences;
  final AppBootstrapState state;

  static Future<AppBootstrap> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    Object? initError;

    if (AppEnvironment.isSupabaseConfigured) {
      try {
        await Supabase.initialize(
          url: AppEnvironment.supabaseUrl,
          anonKey: AppEnvironment.supabaseAnonKey,
        );
      } catch (error) {
        initError = error;
      }
    }

    return AppBootstrap._(
      preferences: preferences,
      state: AppBootstrapState(
        isSupabaseConfigured: AppEnvironment.isSupabaseConfigured,
        initError: initError,
      ),
    );
  }
}

/// Immutable bootstrap summary consumed by routing and setup screens.
final class AppBootstrapState {
  const AppBootstrapState({required this.isSupabaseConfigured, this.initError});

  final bool isSupabaseConfigured;
  final Object? initError;

  bool get hasBackend => isSupabaseConfigured && initError == null;
}
