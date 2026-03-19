import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/bootstrap.dart';
import '../utils/app_exception.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final bootstrap = ref.watch(bootstrapStateProvider);
  if (!bootstrap.hasBackend) {
    throw const AppException('Supabase 尚未配置完成');
  }

  return Supabase.instance.client;
});
