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
        .select('*, stations(nombre), station_days(nombre)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
        
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateScore(String id, int newScore) async {
    await _supabaseClient
        .from('station_scores')
        .update({'score': newScore})
        .eq('id', id);
  }

  Future<void> deleteScore(String id) async {
    await _supabaseClient
        .from('station_scores')
        .delete()
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getGlobalStandings({String? groupId, String? dayId}) async {
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

    // 2. Get all scores
    var query = _supabaseClient.from('station_scores').select();
    if (dayId != null) {
      query = query.eq('station_day_id', dayId);
    }
    final scoresResponse = await query;
    
    final allScores = (scoresResponse as List).map((j) => StationScoreModel.fromJson(j)).toList();

    // 3. Process rankings
    List<Map<String, dynamic>> rankings = [];

    for (var player in players) {
      final playerScores = allScores.where((s) => s.userId == player.id).toList();
      int totalScore = 0;
      
      // Group by station
      final Set<String> uniqueStations = playerScores.map((s) => s.stationId).toSet();
      
      for (var stationId in uniqueStations) {
        final stationAttempts = playerScores.where((s) => s.stationId == stationId).toList();
        // Sort descending to get the best ones
        stationAttempts.sort((a, b) => b.score.compareTo(a.score));
        
        // Take top 2 and sum
        final topAttempts = stationAttempts.take(2);
        for (var attempt in topAttempts) {
          totalScore += attempt.score;
        }
      }

      rankings.add({
        'player': player,
        'totalScore': totalScore,
      });
    }

    // Sort rankings by total score descending
    rankings.sort((a, b) => (b['totalScore'] as int).compareTo(a['totalScore'] as int));

    return rankings;
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
