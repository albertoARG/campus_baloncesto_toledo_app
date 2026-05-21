import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/firebase_constants.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  FirebaseMessaging? _messaging;

  // Project ID from google-services.json
  static const String _projectId = 'campus-baloncesto';

  // Service account credentials - loaded from embedded JSON
  // The user must provide the service account JSON from Firebase Console
  static Map<String, dynamic>? _serviceAccountCredentials;

  /// Initialize Firebase and request notification permissions
  Future<void> initialize() async {
    _messaging = FirebaseMessaging.instance;

    try {
      // Request permissions (iOS needs explicit permission, Android 13+ too, Web too)
      await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kIsWeb) {
        // Web: SIEMPRE refrescar el token en Supabase (pueden cambiar)
        await _saveWebToken();
      } else {
        // Native: solo suscribirse al topic la primera vez
        final prefs = await SharedPreferences.getInstance();
        final alreadySubscribed =
            prefs.getBool('fcm_general_subscribed') ?? false;

        if (!alreadySubscribed) {
          await _subscribeToTopic('campus_general');
          prefs.setBool('fcm_general_subscribed', true);
        }
      }

      if (kDebugMode) {
        _messaging!
            .getToken(vapidKey: kIsWeb ? FirebaseConstants.vapidKey : null)
            .then((token) {
              print('FCM Token: $token');
            })
            .catchError((e) {
              print('Error getting token: $e');
            });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Firebase Messaging permissions: $e');
      }
    }
  }

  /// Save/refresh the web FCM token in Supabase (called every time on web)
  Future<void> _saveWebToken() async {
    try {
      final token = await _messaging!.getToken(
        vapidKey: FirebaseConstants.vapidKey,
      );
      if (kDebugMode) print('FCM Web: Token obtenido: $token');
      if (token == null) return;

      final userId = Supabase.instance.client.auth.currentSession?.user.id;

      // Borrar TODOS los tokens web anteriores de este usuario
      // Esto evita que Chrome y la PWA tengan tokens duplicados
      try {
        if (userId != null) {
          await Supabase.instance.client
              .from('fcm_tokens')
              .delete()
              .eq('platform', 'web')
              .eq('user_id', userId);
        }
        // También borrar el token exacto por si existe con otro user_id
        await Supabase.instance.client
            .from('fcm_tokens')
            .delete()
            .eq('token', token);
      } catch (_) {
        // Ignorar errores de borrado
      }

      await Supabase.instance.client.from('fcm_tokens').insert({
        'token': token,
        'platform': 'web',
        'user_id': userId,
      });
      
      if (kDebugMode) print('FCM Web: Token guardado correctamente en Supabase');
    } catch (e) {
      if (kDebugMode) print('FCM Web: Error guardando token: $e');
    }
  }

  /// Internal method to subscribe to a topic (native only)
  Future<void> _subscribeToTopic(String topic) async {
    try {
      await _messaging!.subscribeToTopic(topic);
      if (kDebugMode) print('FCM: Subscrito a $topic en Nativo');
    } catch (e) {
      if (kDebugMode) print('Error en _subscribeToTopic para $topic: $e');
    }
  }

  /// Subscribe to staff topic (call this for admin/entrenador users)
  Future<void> subscribeToStaffTopic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadySubscribed = prefs.getBool('fcm_staff_subscribed') ?? false;
      if (alreadySubscribed) return;

      await _subscribeToTopic('campus_staff');
      prefs.setBool('fcm_staff_subscribed', true);
    } catch (e) {
      if (kDebugMode) print('Error subscribing to staff topic: $e');
    }
  }

  /// Unsubscribe from staff topic (call if user role changes)
  Future<void> unsubscribeFromStaffTopic() async {
    try {
      if (kIsWeb) {
        final token = await FirebaseMessaging.instance.getToken(
          vapidKey: FirebaseConstants.vapidKey,
        );
        if (token == null) return;
        final accessToken = await _getAccessToken();
        if (accessToken == null) return;

        final url = Uri.parse('https://iid.googleapis.com/iid/v1:batchRemove');
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'to': '/topics/campus_staff',
            'registration_tokens': [token],
          }),
        );
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('campus_staff');
      }
    } catch (e) {
      if (kDebugMode) print('Error unsubscribing from staff topic: $e');
    }
  }

  /// Set the service account credentials
  static void setServiceAccountCredentials(Map<String, dynamic> credentials) {
    _serviceAccountCredentials = credentials;
  }

  Future<String?> _getAccessToken() async {
    if (_serviceAccountCredentials == null) return null;

    final email = _serviceAccountCredentials!['client_email'];
    final privateKey = _serviceAccountCredentials!['private_key'];

    final jwt = JWT({
      'iss': email,
      'scope': 'https://www.googleapis.com/auth/firebase.messaging',
      'aud': 'https://oauth2.googleapis.com/token',
      'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
      'iat': (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    });

    final token = jwt.sign(
      RSAPrivateKey(privateKey),
      algorithm: JWTAlgorithm.RS256,
    );

    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': token,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['access_token'];
    }
    return null;
  }

  /// Send a push notification to a FCM topic using the V1 API
  /// [topic] can be 'campus_general' or 'campus_staff'
  Future<void> sendNotificationToTopic({
    required String title,
    required String body,
    required bool isStaffOnly,
  }) async {
    if (_serviceAccountCredentials == null) {
      if (kDebugMode)
        print(
          'Service account credentials not configured. Skipping notification.',
        );
      return;
    }

    final topic = isStaffOnly ? 'campus_staff' : 'campus_general';

    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) throw Exception('Failed to get access token');

      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
      );

      // 1. Enviar al topic (móviles)
      final payloadTopic = {
        'message': {
          'topic': topic,
          'notification': {'title': title, 'body': body},
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'campus_notifications',
              'sound': 'default',
            },
          },
          'apns': {
            'payload': {
              'aps': {'sound': 'default', 'badge': 1},
            },
          },
        },
      };

      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payloadTopic),
      );

      // 2. Enviar a los tokens web guardados en Supabase
      try {
        List tokensResponse;

        if (isStaffOnly) {
          // Solo enviar a tokens de admin y entrenadores
          final staffUsers = await Supabase.instance.client
              .from('users')
              .select('id')
              .or('role.eq.admin,role.eq.entrenador');

          final staffIds = (staffUsers as List).map((u) => u['id'] as String).toList();

          if (staffIds.isEmpty) {
            if (kDebugMode) print('FCM Web: No hay usuarios staff para notificar');
            return;
          }

          tokensResponse = await Supabase.instance.client
              .from('fcm_tokens')
              .select('token')
              .eq('platform', 'web')
              .inFilter('user_id', staffIds);
        } else {
          // Enviar a todos los tokens web
          tokensResponse = await Supabase.instance.client
              .from('fcm_tokens')
              .select('token')
              .eq('platform', 'web');
        }

        if (kDebugMode) print('FCM Web: Enviando a ${tokensResponse.length} tokens web (staff=$isStaffOnly)');

        for (var row in tokensResponse) {
          final webToken = row['token'];
          final payloadToken = {
            'message': {
              'token': webToken,
              'data': {'title': title, 'body': body},
            },
          };

          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(payloadToken),
          );

          if (kDebugMode) {
            print('FCM Web: Respuesta para token ${webToken.substring(0, 20)}...: ${response.statusCode} ${response.body}');
          }

          // Si el token es inválido (404 o error de registro), borrarlo
          if (response.statusCode == 404 || response.body.contains('UNREGISTERED') || response.body.contains('INVALID_ARGUMENT')) {
            try {
              await Supabase.instance.client
                  .from('fcm_tokens')
                  .delete()
                  .eq('token', webToken);
              if (kDebugMode) print('FCM Web: Token inválido eliminado de Supabase');
            } catch (_) {}
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error sending to web tokens: $e');
      }
    } catch (e) {
      if (kDebugMode) print('Error sending notification: $e');
    }
  }
}
