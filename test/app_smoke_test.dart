import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_family_concept/app/app.dart';
import 'package:flutter_family_concept/app/bootstrap.dart';

void main() {
  testWidgets('shows setup page when Supabase is not configured', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          bootstrapStateProvider.overrideWithValue(
            const AppBootstrapState(isSupabaseConfigured: false),
          ),
        ],
        child: const FamilyApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('需要配置 Supabase'), findsOneWidget);
  });
}
