import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/siesta_competition_model.dart';
import '../models/siesta_participant_model.dart';
import '../models/siesta_match_model.dart';
import '../models/siesta_daily_score_model.dart';

class SiestaRepository {
  final SupabaseClient _supabaseClient;

  SiestaRepository(this._supabaseClient);

  Future<List<SiestaCompetitionModel>> getCompetitions() async {
    final response = await _supabaseClient
        .from('siesta_competitions')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((j) => SiestaCompetitionModel.fromJson(j)).toList();
  }

  Future<SiestaCompetitionModel> createCompetition(String nombre, String juego, String formato) async {
    final response = await _supabaseClient
        .from('siesta_competitions')
        .insert({'nombre': nombre, 'juego': juego, 'formato': formato})
        .select()
        .single();
    return SiestaCompetitionModel.fromJson(response);
  }
  
  Future<void> updateCompetitionStatus(String id, String estado) async {
    await _supabaseClient
        .from('siesta_competitions')
        .update({'estado': estado})
        .eq('id', id);
  }

  Future<List<SiestaParticipantModel>> getParticipants(String competitionId) async {
    final response = await _supabaseClient
        .from('siesta_participants')
        .select('*, users(*)')
        .eq('competition_id', competitionId)
        .order('puntos_liga', ascending: false);
    return (response as List).map((j) => SiestaParticipantModel.fromJson(j)).toList();
  }

  Future<void> addParticipant(String competitionId, String userId, {String? grupo}) async {
    await _supabaseClient.from('siesta_participants').insert({
      'competition_id': competitionId,
      'user_id': userId,
      'grupo': grupo,
    });
  }

  Future<List<SiestaMatchModel>> getMatches(String competitionId) async {
    // For joining we can try this if foreign keys are properly named, but simpler is returning raw and joining on client
    final response = await _supabaseClient
        .from('siesta_matches')
        .select()
        .eq('competition_id', competitionId)
        .order('created_at');
        
    return (response as List).map((j) => SiestaMatchModel.fromJson(j)).toList();
  }
  
  Future<void> createMatch(String competitionId, String p1Id, String p2Id, {String? ronda}) async {
    await _supabaseClient.from('siesta_matches').insert({
      'competition_id': competitionId,
      'participant1_id': p1Id,
      'participant2_id': p2Id,
      'ronda': ronda,
    });
  }

  Future<void> updateMatchScore(String matchId, int score1, int score2) async {
    // 1. Fetch match to check status and ronda
    final matchData = await _supabaseClient.from('siesta_matches').select().eq('id', matchId).single();
    final match = SiestaMatchModel.fromJson(matchData);
    
    // Fetch competition to check format
    final compData = await _supabaseClient.from('siesta_competitions').select('formato').eq('id', match.competitionId).single();
    final String formato = compData['formato'] as String;

    final bool isFirstTimeFinishing = match.estado != 'finalizado';

    // 2. Update match
    await _supabaseClient.from('siesta_matches').update({
      'score1': score1,
      'score2': score2,
      'estado': 'finalizado',
    }).eq('id', matchId);
    
    // 3. Update participant standings
    bool shouldUpdateStandings = false;
    final f = formato.toLowerCase();
    if (f == 'liga') {
      shouldUpdateStandings = true;
    } else if (f == 'grupos_playoffs') {
      if (match.ronda == null || match.ronda!.trim().isEmpty) {
        shouldUpdateStandings = true;
      } else {
        final r = match.ronda!.toLowerCase();
        if (!r.contains('octavo') && !r.contains('cuarto') && !r.contains('semifinal') && !r.contains('final') && !r.contains('playoff')) {
          shouldUpdateStandings = true;
        } else if (r.contains('grupo')) {
          shouldUpdateStandings = true;
        }
      }
    }

    if (shouldUpdateStandings) {
      // Fetch participants
      final p1Data = await _supabaseClient.from('siesta_participants').select().eq('id', match.participant1Id).single();
      final p2Data = await _supabaseClient.from('siesta_participants').select().eq('id', match.participant2Id).single();
      final p1 = SiestaParticipantModel.fromJson(p1Data);
      final p2 = SiestaParticipantModel.fromJson(p2Data);

      int p1Ganados = p1.partidosGanados;
      int p1Perdidos = p1.partidosPerdidos;
      int p1PtosLiga = p1.puntosLiga;
      int p1Jugados = p1.partidosJugados;
      
      int p2Ganados = p2.partidosGanados;
      int p2Perdidos = p2.partidosPerdidos;
      int p2PtosLiga = p2.puntosLiga;
      int p2Jugados = p2.partidosJugados;

      if (!isFirstTimeFinishing) {
        // Reverse old points
        int oldScore1 = match.score1;
        int oldScore2 = match.score2;
        if (oldScore1 > oldScore2) {
          p1Ganados--; p2Perdidos--; p1PtosLiga -= 3;
        } else if (oldScore2 > oldScore1) {
          p2Ganados--; p1Perdidos--; p2PtosLiga -= 3;
        } else {
          p1PtosLiga -= 1; p2PtosLiga -= 1;
        }
        // Jugados stays the same since it's still finished.
      } else {
        // It's the first time, so increment jugados.
        p1Jugados++;
        p2Jugados++;
      }

      // Add new score
      if (score1 > score2) {
        p1Ganados++; p2Perdidos++; p1PtosLiga += 3;
      } else if (score2 > score1) {
        p2Ganados++; p1Perdidos++; p2PtosLiga += 3;
      } else {
        p1PtosLiga += 1; p2PtosLiga += 1;
      }

      // Safety clamps just in case
      p1Jugados = p1Jugados >= 0 ? p1Jugados : 0;
      p1Ganados = p1Ganados >= 0 ? p1Ganados : 0;
      p1Perdidos = p1Perdidos >= 0 ? p1Perdidos : 0;
      p1PtosLiga = p1PtosLiga >= 0 ? p1PtosLiga : 0;

      p2Jugados = p2Jugados >= 0 ? p2Jugados : 0;
      p2Ganados = p2Ganados >= 0 ? p2Ganados : 0;
      p2Perdidos = p2Perdidos >= 0 ? p2Perdidos : 0;
      p2PtosLiga = p2PtosLiga >= 0 ? p2PtosLiga : 0;

      // Update P1
      await _supabaseClient.from('siesta_participants').update({
        'partidos_jugados': p1Jugados,
        'partidos_ganados': p1Ganados,
        'partidos_perdidos': p1Perdidos,
        'puntos_liga': p1PtosLiga,
      }).eq('id', match.participant1Id);

      // Update P2
      await _supabaseClient.from('siesta_participants').update({
        'partidos_jugados': p2Jugados,
        'partidos_ganados': p2Ganados,
        'partidos_perdidos': p2Perdidos,
        'puntos_liga': p2PtosLiga,
      }).eq('id', match.participant2Id);
    }
  }

  Future<void> deleteMatch(String matchId) async {
    // 1. Fetch match to see if we need to revert points
    final matchData = await _supabaseClient.from('siesta_matches').select().eq('id', matchId).single();
    final match = SiestaMatchModel.fromJson(matchData);
    
    if (match.estado == 'finalizado') {
      // Check competition format
      final compData = await _supabaseClient.from('siesta_competitions').select('formato').eq('id', match.competitionId).single();
      final String formato = compData['formato'] as String;
      
      bool shouldRevertStandings = false;
      final f = formato.toLowerCase();
      if (f == 'liga') {
        shouldRevertStandings = true;
      } else if (f == 'grupos_playoffs') {
        if (match.ronda == null || match.ronda!.trim().isEmpty) {
          shouldRevertStandings = true;
        } else {
          final r = match.ronda!.toLowerCase();
          if (!r.contains('octavo') && !r.contains('cuarto') && !r.contains('semifinal') && !r.contains('final') && !r.contains('playoff')) {
            shouldRevertStandings = true;
          } else if (r.contains('grupo')) {
            shouldRevertStandings = true;
          }
        }
      }
      
      if (shouldRevertStandings) {
        // Fetch participants
        final p1Data = await _supabaseClient.from('siesta_participants').select().eq('id', match.participant1Id).single();
        final p2Data = await _supabaseClient.from('siesta_participants').select().eq('id', match.participant2Id).single();
        final p1 = SiestaParticipantModel.fromJson(p1Data);
        final p2 = SiestaParticipantModel.fromJson(p2Data);
        
        int p1Ganados = p1.partidosGanados;
        int p1Perdidos = p1.partidosPerdidos;
        int p1PtosLiga = p1.puntosLiga;
        
        int p2Ganados = p2.partidosGanados;
        int p2Perdidos = p2.partidosPerdidos;
        int p2PtosLiga = p2.puntosLiga;
        
        int score1 = match.score1;
        int score2 = match.score2;
        
        if (score1 > score2) {
          p1Ganados--;
          p2Perdidos--;
          p1PtosLiga -= 3;
        } else if (score2 > score1) {
          p2Ganados--;
          p1Perdidos--;
          p2PtosLiga -= 3;
        } else {
          p1PtosLiga -= 1;
          p2PtosLiga -= 1;
        }
        
        // Update P1
        await _supabaseClient.from('siesta_participants').update({
          'partidos_jugados': (p1.partidosJugados > 0 ? p1.partidosJugados - 1 : 0),
          'partidos_ganados': (p1Ganados > 0 ? p1Ganados : 0),
          'partidos_perdidos': (p1Perdidos > 0 ? p1Perdidos : 0),
          'puntos_liga': (p1PtosLiga > 0 ? p1PtosLiga : 0),
        }).eq('id', match.participant1Id);

        // Update P2
        await _supabaseClient.from('siesta_participants').update({
          'partidos_jugados': (p2.partidosJugados > 0 ? p2.partidosJugados - 1 : 0),
          'partidos_ganados': (p2Ganados > 0 ? p2Ganados : 0),
          'partidos_perdidos': (p2Perdidos > 0 ? p2Perdidos : 0),
          'puntos_liga': (p2PtosLiga > 0 ? p2PtosLiga : 0),
        }).eq('id', match.participant2Id);
      }
    }

    // Finally delete match
    await _supabaseClient.from('siesta_matches').delete().eq('id', matchId);
  }

  Future<List<SiestaDailyScoreModel>> getDailyScores(String competitionId, {DateTime? date}) async {
    var query = _supabaseClient
        .from('siesta_daily_scores')
        .select('*, users(*)')
        .eq('competition_id', competitionId);
    
    if (date != null) {
      final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
      query = query.eq('fecha', dateStr);
    }
    
    final response = await query.order('puntos', ascending: false);
    return (response as List).map((j) => SiestaDailyScoreModel.fromJson(j)).toList();
  }

  Future<void> addDailyScore(String competitionId, String userId, int puntos, DateTime fecha) async {
    final dateStr = "${fecha.year}-${fecha.month.toString().padLeft(2,'0')}-${fecha.day.toString().padLeft(2,'0')}";
    await _supabaseClient.from('siesta_daily_scores').insert({
      'competition_id': competitionId,
      'user_id': userId,
      'puntos': puntos,
      'fecha': dateStr,
    });

    // Update participant
    final pData = await _supabaseClient.from('siesta_participants').select()
        .eq('competition_id', competitionId).eq('user_id', userId).maybeSingle();
    if (pData != null) {
      final p = SiestaParticipantModel.fromJson(pData);
      await _supabaseClient.from('siesta_participants')
          .update({'puntos_liga': p.puntosLiga + puntos})
          .eq('id', p.id);
    }
  }

  Future<void> deleteDailyScore(String scoreId) async {
    final scoreData = await _supabaseClient.from('siesta_daily_scores').select().eq('id', scoreId).single();
    final score = SiestaDailyScoreModel.fromJson(scoreData);
    
    // Update participant
    final pData = await _supabaseClient.from('siesta_participants').select()
        .eq('competition_id', score.competitionId).eq('user_id', score.userId).maybeSingle();
    if (pData != null) {
      final p = SiestaParticipantModel.fromJson(pData);
      await _supabaseClient.from('siesta_participants')
          .update({'puntos_liga': p.puntosLiga - score.puntos})
          .eq('id', p.id);
    }
    
    
    await _supabaseClient.from('siesta_daily_scores').delete().eq('id', scoreId);
  }

  Future<void> removeParticipant(String participantId) async {
    final pData = await _supabaseClient.from('siesta_participants').select().eq('id', participantId).single();
    final p = SiestaParticipantModel.fromJson(pData);

    await _supabaseClient.from('siesta_matches').delete().or('participant1_id.eq.$participantId,participant2_id.eq.$participantId');
    await _supabaseClient.from('siesta_daily_scores').delete().eq('competition_id', p.competitionId).eq('user_id', p.userId);
    await _supabaseClient.from('siesta_participants').delete().eq('id', participantId);
  }

  Future<void> removeParticipantByUser(String competitionId, String userId) async {
    final pData = await _supabaseClient.from('siesta_participants').select().eq('competition_id', competitionId).eq('user_id', userId).maybeSingle();
    if (pData != null) {
      final participantId = pData['id'];
      await _supabaseClient.from('siesta_matches').delete().or('participant1_id.eq.$participantId,participant2_id.eq.$participantId');
      await _supabaseClient.from('siesta_participants').delete().eq('id', participantId);
    }
    await _supabaseClient.from('siesta_daily_scores').delete().eq('competition_id', competitionId).eq('user_id', userId);
  }

  Future<void> deleteCompetition(String id) async {
    await _supabaseClient.from('siesta_matches').delete().eq('competition_id', id);
    await _supabaseClient.from('siesta_daily_scores').delete().eq('competition_id', id);
    await _supabaseClient.from('siesta_participants').delete().eq('competition_id', id);
    await _supabaseClient.from('siesta_competitions').delete().eq('id', id);
  }
}
