import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/station_day_model.dart';
import '../models/station_model.dart';
import '../models/station_score_model.dart';
import '../../../../core/models/user_model.dart';

class CompetitionsRepository {
  final SupabaseClient _supabaseClient;

  CompetitionsRepository(this._supabaseClient);

  Future<List<StationDayModel>> getStationDays() async {
    final response = await _supabaseClient
        .from('station_days')
        .select()
        .order('fecha', ascending: true);
    
    return (response as List).map((json) => StationDayModel.fromJson(json)).toList();
  }

  Future<List<StationModel>> getStations() async {
    final response = await _supabaseClient
        .from('stations')
        .select()
        .order('nombre', ascending: true);
    
    return (response as List).map((json) => StationModel.fromJson(json)).toList();
  }

  Future<void> addScore(StationScoreModel score) async {
    await _supabaseClient.from('station_scores').insert(score.toJson());
  }

  Future<List<Map<String, dynamic>>> getScoresForUser(String userId) async {
    final response = await _supabaseClient
        .from('station_scores')
        .select('*, stations(nombre), station_days(nombre, is_published)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
        
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateScore(String id, int newScore, {String? newDayId}) async {
    final data = <String, dynamic>{'score': newScore};
    if (newDayId != null) {
      data['station_day_id'] = newDayId;
    }
    await _supabaseClient
        .from('station_scores')
        .update(data)
        .eq('id', id);
  }

  Future<void> deleteScore(String id) async {
    await _supabaseClient
        .from('station_scores')
        .delete()
        .eq('id', id);
  }

  /// Clasificación por estaciones.
  /// - [staffView]: si true (admin/entrenador), incluye días publicados y días
  ///   visibles solo para entrenadores. Si false (jugadores/familiares), solo
  ///   los días públicos.
  /// - [ignorePublish]: uso interno; considera el día indicado sin importar su
  ///   estado de publicación (para calcular el auto-mínimo).
  Future<List<Map<String, dynamic>>> getGlobalStandings({
    String? groupId,
    String? dayId,
    bool staffView = false,
    bool ignorePublish = false,
  }) async {
    // 1. Get players
    List<UserModel> players;
    if (groupId == null) {
      final usersResponse = await _supabaseClient
          .from('users')
          .select()
          .eq('role', 'jugador');
      players = (usersResponse as List).map((j) => UserModel.fromJson(j)).toList();
    } else {
      final teamMembersResponse = await _supabaseClient
          .from('team_members')
          .select('users(*)')
          .eq('team_id', groupId);

      players = (teamMembersResponse as List)
          .map((j) => UserModel.fromJson(j['users']))
          .where((u) => u.role == 'jugador') // Only rank players
          .toList();
    }

    List<Map<String, dynamic>> buildRankings(Map<String, int> totals) {
      final r = players
          .map((p) => {'player': p, 'totalScore': totals[p.id] ?? 0})
          .toList();
      r.sort((a, b) => (b['totalScore'] as int).compareTo(a['totalScore'] as int));
      return r;
    }

    // 2. Determinar qué días son visibles para este consumidor.
    List<String> allowedDayIds;
    if (ignorePublish && dayId != null) {
      allowedDayIds = [dayId];
    } else {
      final daysResp = await _supabaseClient.from('station_days').select();
      allowedDayIds = (daysResp as List).where((d) {
        final pub = d['is_published'] == true;
        final coach = d['visible_entrenadores'] == true;
        return staffView ? (pub || coach) : pub;
      }).map<String>((d) => d['id'] as String).toList();
      if (dayId != null) {
        allowedDayIds = allowedDayIds.where((id) => id == dayId).toList();
      }
    }

    if (allowedDayIds.isEmpty) {
      return buildRankings({});
    }

    // 3. Get all scores for the allowed days. Supabase caps each request at
    // 1000 rows, so we paginate until a page comes back short.
    const pageSize = 1000;
    final List<StationScoreModel> allScores = [];
    var offset = 0;
    while (true) {
      final page = await _supabaseClient
          .from('station_scores')
          .select()
          .inFilter('station_day_id', allowedDayIds)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      allScores.addAll((page as List).map((j) => StationScoreModel.fromJson(j)));
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    // 4. Totales: por estación y día, se suman las 2 mejores puntuaciones.
    final Map<String, int> totals = {};
    for (var player in players) {
      final playerScores = allScores.where((s) => s.userId == player.id).toList();
      int totalScore = 0;
      final Set<String> uniqueStationDays =
          playerScores.map((s) => '${s.stationId}|${s.stationDayId}').toSet();
      for (var stationDayKey in uniqueStationDays) {
        final stationAttempts = playerScores
            .where((s) => '${s.stationId}|${s.stationDayId}' == stationDayKey)
            .toList();
        stationAttempts.sort((a, b) => b.score.compareTo(a.score));
        for (var attempt in stationAttempts.take(2)) {
          totalScore += attempt.score;
        }
      }
      totals[player.id] = totalScore;
    }

    return buildRankings(totals);
  }

  Future<void> createStationDay(String nombre, DateTime? fecha) async {
    final data = <String, dynamic>{
      'nombre': nombre,
    };
    if (fecha != null) {
      data['fecha'] = "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";
    }
    await _supabaseClient.from('station_days').insert(data);
  }

  Future<void> deleteStationDay(String id) async {
    await _supabaseClient.from('station_scores').delete().eq('station_day_id', id);
    await _supabaseClient.from('station_days').delete().eq('id', id);
  }

  /// Asigna a los jugadores con 0 puntos ese día la menor puntuación obtenida
  /// por el resto de jugadores de SU GRUPO DE COMPETICIÓN que sí compitieron.
  /// Idempotente: primero borra las asignaciones automáticas previas del día.
  Future<void> _autoAssignMinimumScores(String dayId) async {
    // 0. Limpiar asignaciones automáticas anteriores de este día.
    await _supabaseClient
        .from('station_scores')
        .delete()
        .eq('station_day_id', dayId)
        .eq('auto_assigned', true);

    // 1. Mapa jugador -> grupo de COMPETICIÓN (excluye equipos de partido,
    //    is_match_team=true, que también tienen filas en team_members).
    final compTeamsResp =
        await _supabaseClient.from('teams').select('id').eq('is_match_team', false);
    final Set<String> compTeamIds =
        (compTeamsResp as List).map<String>((t) => t['id'] as String).toSet();
    final teamMembersResponse =
        await _supabaseClient.from('team_members').select('team_id, user_id');
    final Map<String, String> userToTeam = {};
    for (var row in teamMembersResponse as List) {
      final tid = row['team_id'] as String?;
      if (tid != null && compTeamIds.contains(tid)) {
        userToTeam[row['user_id']] = tid;
      }
    }

    // 2. Clasificación real de ese día (sin filtrar por publicación; las filas
    //    automáticas ya se borraron en el paso 0).
    final rankings = await getGlobalStandings(dayId: dayId, ignorePublish: true);

    final Map<String, int> teamMinimums = {};
    final Map<String, List<UserModel>> teamZeros = {};
    for (var ranking in rankings) {
      final UserModel player = ranking['player'];
      final int score = ranking['totalScore'];
      final teamId = userToTeam[player.id];
      if (teamId == null) continue;
      if (score > 0) {
        final currentMin = teamMinimums[teamId];
        if (currentMin == null || score < currentMin) {
          teamMinimums[teamId] = score;
        }
      } else {
        teamZeros.putIfAbsent(teamId, () => []).add(player);
      }
    }

    // 3. Estación de referencia (una cualquiera con puntuación real ese día).
    final stationsResponse = await _supabaseClient
        .from('station_scores')
        .select('station_id')
        .eq('station_day_id', dayId)
        .limit(1);
    if ((stationsResponse as List).isEmpty) return;
    final String fallbackStationId = stationsResponse.first['station_id'];
    final authUserId = _supabaseClient.auth.currentUser?.id;

    // 4. Asignar el mínimo del grupo a los jugadores con 0.
    for (var teamId in teamZeros.keys) {
      final minScore = teamMinimums[teamId];
      if (minScore != null && minScore > 0) {
        for (var player in teamZeros[teamId]!) {
          await _supabaseClient.from('station_scores').insert({
            'user_id': player.id,
            if (authUserId != null) 'coach_id': authUserId,
            'station_id': fallbackStationId,
            'station_day_id': dayId,
            'score': minScore,
            'auto_assigned': true,
          });
        }
      }
    }
  }

  /// Cambia la visibilidad de un día de competición.
  /// [state]: 'borrador' | 'entrenadores' | 'publico'.
  Future<void> setStationDayVisibility(String id, String state) async {
    final bool pub = state == 'publico';
    final bool coach = state == 'entrenadores' || state == 'publico';
    await _supabaseClient
        .from('station_days')
        .update({'is_published': pub, 'visible_entrenadores': coach})
        .eq('id', id);

    if (coach) {
      // Al hacerse visible (entrenadores o público) se recalcula el auto-mínimo.
      await _autoAssignMinimumScores(id);
    } else {
      // Borrador: quitar las asignaciones automáticas.
      await _supabaseClient
          .from('station_scores')
          .delete()
          .eq('station_day_id', id)
          .eq('auto_assigned', true);
    }
  }

  Future<void> createStation(String nombre, String? descripcion) async {
    final data = <String, dynamic>{
      'nombre': nombre,
    };
    if (descripcion != null && descripcion.isNotEmpty) {
      data['descripcion'] = descripcion;
    }
    await _supabaseClient.from('stations').insert(data);
  }

  Future<void> deleteStation(String id) async {
    await _supabaseClient.from('station_scores').delete().eq('station_id', id);
    await _supabaseClient.from('stations').delete().eq('id', id);
  }
}
