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

    // 2. Get all scores. Supabase caps each request at 1000 rows, so we
    // paginate until a page comes back short to make sure nothing is lost.
    const pageSize = 1000;
    final List<StationScoreModel> allScores = [];
    var offset = 0;
    while (true) {
      var query = _supabaseClient
          .from('station_scores')
          .select('*, station_days!inner(is_published)')
          .eq('station_days.is_published', true);
      if (dayId != null) {
        query = query.eq('station_day_id', dayId);
      }
      final page = await query.order('id', ascending: true).range(offset, offset + pageSize - 1);
      allScores.addAll((page as List).map((j) => StationScoreModel.fromJson(j)));
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    // 3. Process rankings
    List<Map<String, dynamic>> rankings = [];

    for (var player in players) {
      final playerScores = allScores.where((s) => s.userId == player.id).toList();
      int totalScore = 0;
      
      // Group by station AND day: the same station can run on several days
      // and each day contributes its own top-2 scores.
      final Set<String> uniqueStationDays =
          playerScores.map((s) => '${s.stationId}|${s.stationDayId}').toSet();

      for (var stationDayKey in uniqueStationDays) {
        final stationAttempts = playerScores
            .where((s) => '${s.stationId}|${s.stationDayId}' == stationDayKey)
            .toList();
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

  Future<void> _autoAssignMinimumScores(String dayId) async {
    final teamMembersResponse = await _supabaseClient.from('team_members').select('team_id, user_id');
    final Map<String, String> userToTeam = {};
    for (var row in teamMembersResponse as List) {
      userToTeam[row['user_id']] = row['team_id'];
    }

    final rankings = await getGlobalStandings(dayId: dayId);

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

    final stationsResponse = await _supabaseClient
        .from('station_scores')
        .select('station_id')
        .eq('station_day_id', dayId)
        .limit(1);
        
    if ((stationsResponse as List).isEmpty) return;
    
    final String fallbackStationId = stationsResponse.first['station_id'];
    final authUserId = _supabaseClient.auth.currentUser?.id;

    for (var teamId in teamZeros.keys) {
      final minScore = teamMinimums[teamId];
      if (minScore != null && minScore > 0) {
        final playersWithZero = teamZeros[teamId]!;
        for (var player in playersWithZero) {
          final newScore = StationScoreModel(
            id: '',
            userId: player.id,
            coachId: authUserId,
            stationId: fallbackStationId,
            stationDayId: dayId,
            score: minScore,
            createdAt: DateTime.now(),
          );
          await addScore(newScore);
        }
      }
    }
  }

  Future<void> toggleStationDayPublish(String id, bool isPublished) async {
    await _supabaseClient
        .from('station_days')
        .update({'is_published': isPublished})
        .eq('id', id);

    if (isPublished) {
      try {
        await _autoAssignMinimumScores(id);
      } catch (e) {
        print("Error auto-assigning scores: \$e");
      }
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
