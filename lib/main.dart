import 'package:campus_baloncesto_app/core/constants/supabase_constants.dart';
import 'package:campus_baloncesto_app/core/router/app_router.dart';
import 'package:campus_baloncesto_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  runApp(
    // ProviderScope is required for Riverpod
    const ProviderScope(
      child: CampusBaloncestoApp(),
    ),
  );
}

class CampusBaloncestoApp extends ConsumerWidget {
  const CampusBaloncestoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Campus Baloncesto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
