/// Compile-time environment variables for the app.
abstract final class AppEnvironment {
  static const supabaseUrl = String.fromEnvironment('https://pblxomvdjzlujmcwjifq.supabase.co');
  static const supabaseAnonKey = String.fromEnvironment('sb_publishable_kkMJ7Bdyv6Cltn8rJIEMHw_6j8ib95q');
  static const deepLinkBaseUrl = String.fromEnvironment(
    'APP_BASE_URL',
    defaultValue: '',
  );
  static const usernameEmailDomain = String.fromEnvironment(
    'USERNAME_AUTH_DOMAIN',
    defaultValue: 'family.local',
  );
  static const dishesBucket = 'dishes';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
