import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/live_match_model.dart';
import '../models/match_team_model.dart';

class MatchesRepository {
  final SupabaseClient _client;
  MatchesRepository(this._client);

  // ---- Equipos de partidos (independientes de los grupos de competición) ----

  // Los equipos de partido son filas de 'teams' marcadas con is_match_team=true
  // (creados manualmente aquí o generados desde "Auto-generar Equipos").
  Future<List<MatchTeamModel>> getTeams() async {
    final res = await _client
        .from('teams')
        .select('id, nombre')
        .eq('is_match_team', true)
        .order('nombre');
    return (res as List).map((r) => MatchTeamModel.fromJson(r)).toList();
  }

  Future<void> createTeam(String nombre) async {
    await _client.from('teams').insert({'nombre': nombre, 'is_match_team': true});
  }

  Future<void> deleteTeam(String id) async {
    await _client.from('teams').delete().eq('id', id);
  }

  // ---- Partidos ----

  /// Suscripción en tiempo real (WebSockets) a la tabla de partidos.
  Stream<List<LiveMatchModel>> watchMatches() {
    return _client
        .from('live_matches')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => LiveMatchModel.fromJson(r)).toList());
  }

  Future<String> createMatch({
    required String team1Id,
    required String team1Name,
    required String team2Id,
    required String team2Name,
  }) async {
    final res = await _client
        .from('live_matches')
        .insert({
          'team1_id': team1Id,
          'team1_name': team1Name,
          'team2_id': team2Id,
          'team2_name': team2Name,
          'estado': 'en_juego',
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('live_matches').update(data).eq('id', id);
  }

  Future<void> deleteMatch(String id) async {
    await _client.from('live_matches').delete().eq('id', id);
  }
}
