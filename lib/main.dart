import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_manager_app/core/constants/app_constants.dart';
import 'package:warehouse_manager_app/core/services/supabase_bootstrap.dart';
import 'package:warehouse_manager_app/core/theme/app_theme.dart';
import 'package:warehouse_manager_app/modules/auth/presentation/pages/login_page.dart';
import 'package:warehouse_manager_app/presentation/pages/app_shell.dart';
import 'package:warehouse_manager_app/presentation/pages/setup_required_page.dart';
import 'package:warehouse_manager_app/presentation/pages/splash_page.dart';
import 'package:warehouse_manager_app/presentation/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  runApp(const ProviderScope(child: WarehouseApp()));
}

class WarehouseApp extends ConsumerWidget {
  const WarehouseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AppRoot(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(backendConfiguredProvider)) {
      return const SetupRequiredPage();
    }

    final session = ref.watch(sessionProvider);
    return session.when(
      data: (user) => user == null ? const LoginPage() : const AppShell(),
      loading: () => const SplashPage(),
      error: (error, _) => Scaffold(
        body: Center(child: Text(error.toString())),
      ),
    );
  }
}
