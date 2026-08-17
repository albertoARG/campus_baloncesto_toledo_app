import 'package:campus_baloncesto_app/core/constants/supabase_constants.dart';
import 'package:campus_baloncesto_app/core/constants/firebase_constants.dart';
import 'package:campus_baloncesto_app/core/router/app_router.dart';
import 'package:campus_baloncesto_app/core/theme/app_theme.dart';
import 'package:campus_baloncesto_app/core/services/notification_service.dart';
import 'package:campus_baloncesto_app/core/sync/sync_queue.dart';
import 'package:campus_baloncesto_app/core/theme/theme_mode_provider.dart';
import 'package:campus_baloncesto_app/core/globals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// This MUST be a top-level function for background notifications
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background notification is automatically shown by the system
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: FirebaseConstants.webFirebaseOptions['apiKey']!,
          appId: FirebaseConstants.webFirebaseOptions['appId']!,
          messagingSenderId:
              FirebaseConstants.webFirebaseOptions['messagingSenderId']!,
          projectId: FirebaseConstants.webFirebaseOptions['projectId']!,
          authDomain: FirebaseConstants.webFirebaseOptions['authDomain'],
          storageBucket: FirebaseConstants.webFirebaseOptions['storageBucket'],
          measurementId: FirebaseConstants.webFirebaseOptions['measurementId'],
        ),
      );
    } else {
      await Firebase.initializeApp();
    }

    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    if (kDebugMode) print('Error initializing Firebase: $e');
  }

  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
      // Flujo implícito: el token de recuperación viaja en el propio enlace,
      // así funciona aunque el correo se abra en otro navegador (típico en
      // móvil). Con PKCE fallaba porque el verificador no estaba en ese
      // navegador.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
  } catch (e) {
    if (kDebugMode) print('Error initializing Supabase: $e');
  }

  // Cuando el usuario abre el enlace de recuperación de contraseña del correo,
  // Supabase emite este evento: lo llevamos a la pantalla para elegir una nueva.
  try {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        passwordRecoveryPending.value = true;
        appRouter.go('/reset-password');
      }
    });
  } catch (e) {
    if (kDebugMode) print('Error setting up password recovery listener: $e');
  }

  try {
    // Load Firebase service account credentials for sending notifications
    NotificationService.setServiceAccountCredentials(
      FirebaseConstants.serviceAccountCredentials,
    );

    // Initialize notifications (permissions + topic subscription)
    final notificationService = NotificationService();
    await notificationService.initialize();
  } catch (e) {
    if (kDebugMode) print('Error initializing Notifications: $e');
  }

  // Handle notification clicks - no navigation needed, home refreshes automatically

  // When the app is in the foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Intentar leer de notification (nativo) o de data (web data-only)
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if (title != null) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (body != null) Text(body),
            ],
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () {
              appRouter.push('/tablon');
            },
          ),
        ),
      );
    }
  });

  runApp(
    // ProviderScope is required for Riverpod
    const ProviderScope(child: CampusBaloncestoApp()),
  );
}

class CampusBaloncestoApp extends ConsumerWidget {
  const CampusBaloncestoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Arranca la cola de sincronización offline (carga lo pendiente y lo sube
    // en cuanto hay conexión).
    ref.watch(syncQueueProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Campus Baloncesto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: appRouter,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        // En pantallas anchas (escritorio/proyector) centramos la app con un
        // ancho máximo para que no se vea estirada. Salvo si hay una pantalla
        // que pide todo el ancho (la pizarra a pantalla completa).
        return ValueListenableBuilder<int>(
          valueListenable: fullBleedRoutes,
          builder: (context, fullBleed, _) {
            final width = MediaQuery.sizeOf(context).width;
            if (fullBleed > 0 || width <= 720) return child;
            final dark = Theme.of(context).brightness == Brightness.dark;
            return ColoredBox(
              color: dark ? const Color(0xFF0E0D12) : const Color(0xFFE9E7F0),
              child: Center(child: SizedBox(width: 720, child: child)),
            );
          },
        );
      },
    );
  }
}
