import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../globals.dart';

/// Operación pendiente de subir. [kind] indica cómo reproducirla:
/// - 'insert': un `insert` en [table] (estaciones, etc.).
/// - 'siesta_daily_score': insert en siesta_daily_scores + suma al contador
///   `puntos_liga` del participante.
/// El [id] (uuid) es la clave de la fila, para que reintentar sea idempotente.
class _PendingOp {
  final String id;
  final String table;
  final Map<String, dynamic> payload;
  final String label;
  final String kind;

  _PendingOp({
    required this.id,
    required this.table,
    required this.payload,
    required this.label,
    this.kind = 'insert',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'payload': payload,
        'label': label,
        'kind': kind,
      };

  factory _PendingOp.fromJson(Map<String, dynamic> j) => _PendingOp(
        id: j['id'] as String,
        table: j['table'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        label: (j['label'] ?? '') as String,
        kind: (j['kind'] ?? 'insert') as String,
      );
}

/// Cola de sincronización offline. Guarda resultados en el dispositivo cuando
/// no hay conexión y los sube automáticamente al recuperarla.
class SyncQueue extends ChangeNotifier {
  final SupabaseClient _supabase;
  SyncQueue(this._supabase);

  static const _prefsKey = 'sync_queue_v1';
  static const _timeout = Duration(seconds: 10);

  SharedPreferences? _prefs;
  final List<_PendingOp> _ops = [];
  bool _flushing = false;
  bool _isOnline = true;
  bool _initialized = false;
  StreamSubscription? _connSub;
  Timer? _retryTimer;

  int get pendingCount => _ops.length;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _ops
          ..clear()
          ..addAll(
            list.map(
              (e) => _PendingOp.fromJson(Map<String, dynamic>.from(e as Map)),
            ),
          );
      }
    } catch (_) {}

    try {
      _isOnline = _resultIsOnline(await Connectivity().checkConnectivity());
    } catch (_) {}

    _connSub = Connectivity().onConnectivityChanged.listen((dynamic result) {
      _isOnline = _resultIsOnline(result);
      notifyListeners();
      if (_isOnline) flush();
    });

    _retryTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_ops.isNotEmpty) flush();
    });

    notifyListeners();
    flush();
  }

  bool _resultIsOnline(dynamic result) {
    if (result is List) {
      return result.any((r) => r != ConnectivityResult.none);
    }
    return result != ConnectivityResult.none;
  }

  /// Genera un uuid v4 (sin dependencias externas).
  String newId() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int x) => x.toRadixString(16).padLeft(2, '0');
    final s = b.map(h).toList();
    return '${s[0]}${s[1]}${s[2]}${s[3]}-${s[4]}${s[5]}-${s[6]}${s[7]}-'
        '${s[8]}${s[9]}-${s[10]}${s[11]}${s[12]}${s[13]}${s[14]}${s[15]}';
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setString(
        _prefsKey,
        jsonEncode(_ops.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _incrementParticipant(
      String competitionId, String userId, int delta) async {
    final pData = await _supabase
        .from('siesta_participants')
        .select('id, puntos_liga')
        .eq('competition_id', competitionId)
        .eq('user_id', userId)
        .maybeSingle()
        .timeout(_timeout);
    if (pData != null) {
      final current = (pData['puntos_liga'] ?? 0) as int;
      await _supabase
          .from('siesta_participants')
          .update({'puntos_liga': current + delta})
          .eq('id', pData['id'])
          .timeout(_timeout);
    }
  }

  /// Ejecuta la operación online. Lanza [PostgrestException] en errores reales
  /// del servidor; lanza otras excepciones en fallos de red/timeout.
  Future<void> _execute(_PendingOp op) async {
    if (op.kind == 'siesta_daily_score') {
      try {
        await _supabase.from(op.table).insert(op.payload).timeout(_timeout);
      } on PostgrestException catch (e) {
        // 23505 = clave duplicada: la fila ya se subió (y el contador ya se
        // aplicó en su momento). No repetimos el incremento.
        if (e.code == '23505') return;
        rethrow;
      }
      await _incrementParticipant(
        op.payload['competition_id'] as String,
        op.payload['user_id'] as String,
        op.payload['puntos'] as int,
      );
    } else {
      await _supabase.from(op.table).insert(op.payload).timeout(_timeout);
    }
  }

  /// Intenta subir la operación; si no hay conexión, la encola. Devuelve true si
  /// se subió, false si quedó pendiente. Relanza errores reales del servidor.
  Future<bool> _tryOrQueue(_PendingOp op) async {
    try {
      await _execute(op);
      if (!_isOnline) {
        _isOnline = true;
        notifyListeners();
      }
      return true;
    } on PostgrestException {
      rethrow;
    } catch (_) {
      _ops.add(op);
      _isOnline = false;
      await _persist();
      notifyListeners();
      return false;
    }
  }

  /// Inserta una fila (estaciones u otras tablas de solo-insert).
  Future<bool> insertOrQueue(
    String table,
    Map<String, dynamic> payload, {
    String label = '',
  }) async {
    final data = Map<String, dynamic>.from(payload);
    data['id'] ??= newId();
    return _tryOrQueue(_PendingOp(
      id: data['id'] as String,
      table: table,
      payload: data,
      label: label,
      kind: 'insert',
    ));
  }

  /// Registra una puntuación de siesta (puntos o tiros libres), sumando también
  /// al contador del participante. Funciona sin conexión.
  Future<bool> addSiestaDailyScore(
    String competitionId,
    String userId,
    int puntos,
    DateTime fecha, {
    String label = '',
  }) async {
    final dateStr = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
    final id = newId();
    return _tryOrQueue(_PendingOp(
      id: id,
      table: 'siesta_daily_scores',
      payload: {
        'id': id,
        'competition_id': competitionId,
        'user_id': userId,
        'puntos': puntos,
        'fecha': dateStr,
      },
      label: label,
      kind: 'siesta_daily_score',
    ));
  }

  /// Intenta subir todo lo pendiente. Seguro de llamar en cualquier momento.
  Future<void> flush() async {
    if (_flushing || _ops.isEmpty) return;
    _flushing = true;
    int processed = 0;
    try {
      while (_ops.isNotEmpty) {
        final op = _ops.first;
        try {
          await _execute(op);
        } on PostgrestException catch (e) {
          if (kDebugMode) {
            print('Sync: descartando op con error de servidor: ${e.message}');
          }
        } catch (_) {
          _isOnline = false;
          notifyListeners();
          break;
        }
        _ops.removeAt(0);
        processed++;
        await _persist();
        notifyListeners();
      }
      if (_ops.isEmpty) {
        if (!_isOnline) {
          _isOnline = true;
          notifyListeners();
        }
        if (processed > 0) {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('✓ Todo sincronizado'),
              backgroundColor: Color(0xFF2E7D32),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      _flushing = false;
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}

/// Instancia global de la cola de sincronización. Es un [ChangeNotifier]:
/// para reaccionar a los cambios en la UI, envuélvelo en un [ListenableBuilder]
/// (ver [SyncStatusBanner]).
final syncQueueProvider = Provider<SyncQueue>((ref) {
  final queue = SyncQueue(Supabase.instance.client);
  queue.init();
  ref.onDispose(queue.dispose);
  return queue;
});
