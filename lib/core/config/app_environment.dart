/// Compile-time environment variables for the app.
abstract final class AppEnvironment {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pblxomvdjzlujmcwjifq.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBibHhvbXZkanpsdWptY3dqaWZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4OTE3MzUsImV4cCI6MjA4OTQ2NzczNX0.8Sxo9p-C82zO8F20UWyYczvHbWapAsUDMFgUnfKoYGo',
  );
  static const deepLinkBaseUrl = String.fromEnvironment(
    'APP_BASE_URL',
    defaultValue: '',
  );
  static const dishesBucket = 'dishes';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
