import '../config/app_environment.dart';
import 'app_exception.dart';

/// Maps username + password UX onto Supabase email auth.
abstract final class UsernameCodec {
  static final _pattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static String normalize(String input) {
    return input.trim().toLowerCase();
  }

  static String emailFor(String username) {
    return '${normalize(username)}@${AppEnvironment.usernameEmailDomain}';
  }

  static void validate(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) {
      throw const AppException('请输入用户名');
    }
    if (!_pattern.hasMatch(normalized)) {
      throw const AppException('用户名需为 3-20 位字母、数字或下划线');
    }
  }
}
