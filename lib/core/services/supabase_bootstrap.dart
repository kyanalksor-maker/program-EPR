import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:warehouse_manager_app/core/constants/app_constants.dart';
import 'package:warehouse_manager_app/core/constants/app_enums.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static AppMode get mode => isConfigured ? AppMode.live : AppMode.setupRequired;

  static bool get isConfigured =>
      AppConstants.supabaseUrl.isNotEmpty &&
      AppConstants.supabaseAnonKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }
}
