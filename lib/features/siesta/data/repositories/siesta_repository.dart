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
        .select(
          '*, users!siesta_participants_user_id_fkey(*), partner:users!siesta_participants_partner_user_id_fkey(*)',
        )
        .eq('competition_id', competitionId)
        .order('puntos_liga', ascending: false);
    return (response as List).map((j) => SiestaParticipantModel.fromJson(j)).toList();
  }

  Future<void> addParticipant(String competitionId, String userId,
      {String? partnerUserId, String? grupo}) async {
    await _supabaseClient.from('siesta_participants').insert({
      'competition_id': competitionId,
      'user_id': userId,
      'partner_user_id': partnerUserId,
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

  /// Genera partidos "todos contra todos" dentro de cada grupo. No duplica
  /// enfrentamientos que ya existan. Devuelve cuántos partidos ha creado.
  Future<int> generateGroupMatches(String competitionId) async {
    final participants = await getParticipants(competitionId);
    final existing = await getMatches(competitionId);

    // Clave de un enfrentamiento, sin importar el orden.
    String pairKey(String a, String b) =>
        a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

    final existingPairs = <String>{
      for (final m in existing) pairKey(m.participant1Id, m.participant2Id),
    };

    // Agrupar por grupo (null/vacío => un grupo común "sin grupo").
    final Map<String, List<SiestaParticipantModel>> groups = {};
    for (final p in participants) {
      final g =
          (p.grupo == null || p.grupo!.trim().isEmpty) ? '' : p.grupo!.trim();
      groups.putIfAbsent(g, () => []).add(p);
    }

    final rows = <Map<String, dynamic>>[];
    for (final entry in groups.entries) {
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final a = list[i].id;
          final b = list[j].id;
          final key = pairKey(a, b);
          if (existingPairs.contains(key)) continue;
          existingPairs.add(key);
          rows.add({
            'competition_id': competitionId,
            'participant1_id': a,
            'participant2_id': b,
            if (entry.key.isNotEmpty) 'ronda': 'Grupo ${entry.key}',
          });
        }
      }
    }

    if (rows.isNotEmpty) {
      await _supabaseClient.from('siesta_matches').insert(rows);
    }
    return rows.length;
  }

  bool _isPlayoffRound(String? ronda) {
    if (ronda == null) return false;
    final r = ronda.toLowerCase();
    return r.contains('octavo') ||
        r.contains('cuarto') ||
        r.contains('semifinal') ||
        r.contains('final') ||
        r.contains('dieciseis') ||
        r.contains('playoff');
  }

  /// Ordena los participantes de un grupo: 1) puntos de liga, 2) enfrentamiento
  /// directo, 3) partidos ganados, 4) menos partidos perdidos.
  List<SiestaParticipantModel> _rankGroup(
      List<SiestaParticipantModel> group, List<SiestaMatchModel> groupMatches) {
    final ids = group.map((p) => p.id).toSet();
    final internal = groupMatches
        .where((m) =>
            ids.contains(m.participant1Id) && ids.contains(m.participant2Id))
        .toList();

    int h2hPoints(String a, String b) {
      int pts = 0;
      for (final m in internal) {
        if (m.participant1Id == a && m.participant2Id == b) {
          if (m.score1 > m.score2) {
            pts += 3;
          } else if (m.score1 == m.score2) {
            pts += 1;
          }
        } else if (m.participant1Id == b && m.participant2Id == a) {
          if (m.score2 > m.score1) {
            pts += 3;
          } else if (m.score1 == m.score2) {
            pts += 1;
          }
        }
      }
      return pts;
    }

    final sorted = [...group];
    sorted.sort((a, b) {
      if (a.puntosLiga != b.puntosLiga) {
        return b.puntosLiga.compareTo(a.puntosLiga);
      }
      final ah = h2hPoints(a.id, b.id);
      final bh = h2hPoints(b.id, a.id);
      if (ah != bh) return bh.compareTo(ah);
      if (a.partidosGanados != b.partidosGanados) {
        return b.partidosGanados.compareTo(a.partidosGanados);
      }
      if (a.partidosPerdidos != b.partidosPerdidos) {
        return a.partidosPerdidos.compareTo(b.partidosPerdidos);
      }
      return 0;
    });
    return sorted;
  }

  int _compareOverall(SiestaParticipantModel a, SiestaParticipantModel b) {
    if (a.puntosLiga != b.puntosLiga) {
      return b.puntosLiga.compareTo(a.puntosLiga);
    }
    if (a.partidosGanados != b.partidosGanados) {
      return b.partidosGanados.compareTo(a.partidosGanados);
    }
    if (a.partidosPerdidos != b.partidosPerdidos) {
      return a.partidosPerdidos.compareTo(b.partidosPerdidos);
    }
    return 0;
  }

  /// Orden de siembra estándar de un cuadro de tamaño [n] (potencia de 2).
  /// Ej. n=4 -> [1,4,2,3]; n=8 -> [1,8,4,5,2,7,3,6].
  List<int> _bracketSeedOrder(int n) {
    List<int> order = [1, 2];
    while (order.length < n) {
      final sum = order.length * 2 + 1;
      final next = <int>[];
      for (final s in order) {
        next.add(s);
        next.add(sum - s);
      }
      order = next;
    }
    return order;
  }

  /// Intenta evitar que dos del mismo grupo se crucen en la primera ronda.
  void _avoidSameGroupFirstRound(List<SiestaParticipantModel> ordered) {
    String grp(SiestaParticipantModel p) => (p.grupo ?? '').trim();
    for (var i = 0; i + 1 < ordered.length; i += 2) {
      if (grp(ordered[i]).isEmpty) continue;
      if (grp(ordered[i]) != grp(ordered[i + 1])) continue;
      for (var j = 0; j + 1 < ordered.length; j += 2) {
        if (j == i) continue;
        final a = ordered[i];
        final b = ordered[j + 1];
        final c = ordered[j];
        final d = ordered[i + 1];
        if (grp(a).isNotEmpty && grp(a) == grp(b)) continue;
        if (grp(c).isNotEmpty && grp(c) == grp(d)) continue;
        final tmp = ordered[i + 1];
        ordered[i + 1] = ordered[j + 1];
        ordered[j + 1] = tmp;
        break;
      }
    }
  }

  /// Genera la fase eliminatoria. [bracketSize] = 4 (semifinales), 8 (cuartos)
  /// o 16 (octavos). Clasifican los primeros de cada grupo, luego los segundos,
  /// luego los mejores terceros, etc., hasta completar el cuadro. Borra un
  /// playoff anterior si lo hubiera. Devuelve cuántos partidos ha creado.
  Future<int> generatePlayoff(String competitionId, int bracketSize) async {
    final participants = await getParticipants(competitionId);
    final allMatches = await getMatches(competitionId);

    final groupMatches = allMatches
        .where((m) => m.estado == 'finalizado' && !_isPlayoffRound(m.ronda))
        .toList();

    // Agrupar por grupo.
    final Map<String, List<SiestaParticipantModel>> groups = {};
    for (final p in participants) {
      final g =
          (p.grupo == null || p.grupo!.trim().isEmpty) ? '' : p.grupo!.trim();
      groups.putIfAbsent(g, () => []).add(p);
    }

    // Clasificación de cada grupo (con enfrentamiento directo).
    final Map<String, List<SiestaParticipantModel>> ranked = {};
    groups.forEach((g, list) => ranked[g] = _rankGroup(list, groupMatches));

    // Sembrado: 1º de cada grupo (ordenados entre sí), luego 2º, luego 3º...
    final maxPos =
        ranked.values.map((l) => l.length).fold(0, (a, b) => a > b ? a : b);
    final seedList = <SiestaParticipantModel>[];
    for (var pos = 0; pos < maxPos; pos++) {
      final tier = <SiestaParticipantModel>[];
      ranked.forEach((g, list) {
        if (pos < list.length) tier.add(list[pos]);
      });
      tier.sort(_compareOverall);
      seedList.addAll(tier);
    }

    if (seedList.length < bracketSize) {
      throw Exception(
          'No hay suficientes participantes: se necesitan $bracketSize y hay ${seedList.length}.');
    }

    final qualifiers = seedList.take(bracketSize).toList(); // cabezas 1..N
    final slots = _bracketSeedOrder(bracketSize);
    final ordered = slots.map((seed) => qualifiers[seed - 1]).toList();
    _avoidSameGroupFirstRound(ordered);

    final roundName = bracketSize == 16
        ? 'Octavos'
        : bracketSize == 8
            ? 'Cuartos'
            : 'Semifinal';

    // Aseguramos formato con playoffs para que estas rondas no alteren la
    // clasificación de grupos.
    await _supabaseClient
        .from('siesta_competitions')
        .update({'formato': 'grupos_playoffs'}).eq('id', competitionId);

    // Borrar cualquier playoff previo (para regenerar limpio).
    for (final m in allMatches.where((m) => _isPlayoffRound(m.ronda))) {
      await _supabaseClient.from('siesta_matches').delete().eq('id', m.id);
    }

    // Crear la primera ronda en orden de cuadro (fecha = orden del slot).
    final base = DateTime(2000);
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i + 1 < ordered.length; i += 2) {
      rows.add({
        'competition_id': competitionId,
        'participant1_id': ordered[i].id,
        'participant2_id': ordered[i + 1].id,
        'ronda': roundName,
        'fecha': base.add(Duration(seconds: i ~/ 2)).toIso8601String(),
      });
    }
    if (rows.isNotEmpty) {
      await _supabaseClient.from('siesta_matches').insert(rows);
    }
    return rows.length;
  }

  /// Si una ronda de playoff está completa, crea automáticamente la siguiente
  /// emparejando a los ganadores en orden de cuadro. Crea una ronda por llamada.
  Future<void> advancePlayoffIfReady(String competitionId) async {
    final matches = await getMatches(competitionId);
    const nextName = {
      'octavos': 'Cuartos',
      'cuartos': 'Semifinal',
      'semifinal': 'Final',
    };

    for (final r in ['octavos', 'cuartos', 'semifinal']) {
      final roundMatches = matches
          .where((m) => (m.ronda ?? '').toLowerCase().contains(r))
          .toList();
      if (roundMatches.length < 2) continue;
      final nextLabel = nextName[r]!;
      final nextExists = matches
          .any((m) => (m.ronda ?? '').toLowerCase() == nextLabel.toLowerCase());
      if (nextExists) continue;
      if (!roundMatches.every((m) => m.estado == 'finalizado')) continue;

      roundMatches.sort((a, b) =>
          (a.fecha ?? DateTime(2100)).compareTo(b.fecha ?? DateTime(2100)));
      final winners = roundMatches
          .map((m) =>
              m.score1 >= m.score2 ? m.participant1Id : m.participant2Id)
          .toList();

      final base = DateTime(2000);
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i + 1 < winners.length; i += 2) {
        rows.add({
          'competition_id': competitionId,
          'participant1_id': winners[i],
          'participant2_id': winners[i + 1],
          'ronda': nextLabel,
          'fecha': base.add(Duration(seconds: i ~/ 2)).toIso8601String(),
        });
      }
      if (rows.isNotEmpty) {
        await _supabaseClient.from('siesta_matches').insert(rows);
      }
      break; // solo una ronda por llamada
    }
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
