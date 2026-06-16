import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../models/group_model.dart';

class GroupsRepository {
  final SupabaseClient _supabase;

  GroupsRepository(this._supabase);

  // Obtener todos los grupos de COMPETICIÓN (excluye los equipos de partido)
  Future<List<GroupModel>> getGroups() async {
    final response = await _supabase
        .from('teams')
        .select()
        .eq('is_match_team', false)
        .order('nombre', ascending: true);
    return (response as List).map((e) => GroupModel.fromJson(e)).toList();
  }

  // Crear un nuevo grupo. Si [isMatchTeam] es true se crea como equipo de
  // partido (no aparece en la clasificación de competición).
  Future<GroupModel> createGroup(String nombre, String? categoria,
      {bool isMatchTeam = false}) async {
    final response = await _supabase.from('teams').insert({
      'nombre': nombre,
      'categoria': categoria,
      'is_match_team': isMatchTeam,
    }).select().single();

    return GroupModel.fromJson(response);
  }

  // Eliminar grupo
  Future<void> deleteGroup(String groupId) async {
    await _supabase.from('teams').delete().eq('id', groupId);
  }

  // Obtener miembros de un grupo
  Future<List<UserModel>> getGroupMembers(String groupId) async {
    final response = await _supabase
        .from('team_members')
        .select('users(*)')
        .eq('team_id', groupId);
    
    return (response as List)
        .map((e) => UserModel.fromJson(e['users']))
        .toList();
  }

  // Añadir usuario a grupo
  Future<void> addMemberToGroup(String groupId, String userId) async {
    await _supabase.from('team_members').upsert({
      'team_id': groupId,
      'user_id': userId,
    });
  }

  // Eliminar usuario de grupo
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    await _supabase
        .from('team_members')
        .delete()
        .eq('team_id', groupId)
        .eq('user_id', userId);
  }

  // Generar equipos equilibrados automáticamente en función de edad, nivel y posición.
  // Si [isMatchTeam] es true, los equipos se crean como EQUIPOS DE PARTIDO: no
  // cuentan en la clasificación de competición y no alteran los grupos de
  // competición existentes (los jugadores conservan su grupo).
  Future<void> autoGenerateBalancedTeams(
    int numTeams,
    String prefix, {
    bool isMatchTeam = false,
  }) async {
    if (numTeams <= 0) return;

    // 1. Obtener todos los jugadores (tanto estándar como premium)
    final usersRes = await _supabase
        .from('users')
        .select()
        .inFilter('role', ['jugador', 'jugador premium']);
    
    List<UserModel> players = (usersRes as List).map((e) => UserModel.fromJson(e)).toList();
    if (players.isEmpty) return;

    // 2. Agrupar jugadores por categoría táctica/posición para equilibrar el roster
    List<UserModel> guards = [];   // Bases y Escoltas
    List<UserModel> centers = [];  // Pívots y Ala-pívots
    List<UserModel> forwards = []; // Aleros y otros/sin definir

    for (var player in players) {
      final pos = (player.posicion ?? '').toLowerCase();
      if (pos.contains('base') || pos.contains('escolta') || pos.contains('guard') || pos.contains('point')) {
        guards.add(player);
      } else if (pos.contains('pivot') || pos.contains('pívot') || pos.contains('center') || pos.contains('ala-piv') || pos.contains('ala-pív')) {
        centers.add(player);
      } else {
        forwards.add(player);
      }
    }

    // Calcular puntuación de fuerza (nivel ponderado y edad como secundario)
    int getPlayerScore(UserModel p) {
      final lvl = p.nivel ?? 3; // Nivel por defecto: 3 (intermedio)
      final age = p.edad ?? 14; // Edad por defecto: 14 años
      return (lvl * 10) + age;
    }

    // Ordenar cada grupo de más fuerte a más débil
    guards.sort((a, b) => getPlayerScore(b).compareTo(getPlayerScore(a)));
    centers.sort((a, b) => getPlayerScore(b).compareTo(getPlayerScore(a)));
    forwards.sort((a, b) => getPlayerScore(b).compareTo(getPlayerScore(a)));

    // 3. Si es modo "equipo de partido", borrar los equipos de partido anteriores
    //    (y sus miembros) para no acumularlos. No se tocan los de competición.
    if (isMatchTeam) {
      final oldRes = await _supabase.from('teams').select('id').eq('is_match_team', true);
      final oldIds = (oldRes as List).map((t) => t['id'] as String).toList();
      if (oldIds.isNotEmpty) {
        await _supabase.from('team_members').delete().inFilter('team_id', oldIds);
        await _supabase.from('teams').delete().inFilter('id', oldIds);
      }
    }

    // 4. Crear los nuevos equipos en la base de datos
    List<Map<String, dynamic>> teamsToInsert = [];
    for (int i = 0; i < numTeams; i++) {
      teamsToInsert.add({
        'nombre': '$prefix ${i + 1}',
        'is_match_team': isMatchTeam,
      });
    }

    final createdTeams = await _supabase.from('teams').insert(teamsToInsert).select();
    final teamIds = (createdTeams as List).map((t) => t['id'] as String).toList();

    // 5. Limpiar pertenencias previas para evitar duplicados.
    //    - Competición: se borran solo las pertenencias a equipos de competición.
    //    - Partido: no se toca nada de competición (los equipos de partido viejos
    //      ya se eliminaron en el paso 3).
    final playerIds = players.map((p) => p.id).toList();
    if (!isMatchTeam && playerIds.isNotEmpty) {
      final compRes = await _supabase.from('teams').select('id').eq('is_match_team', false);
      final compIds = (compRes as List).map((t) => t['id'] as String).toList();
      if (compIds.isNotEmpty) {
        await _supabase
            .from('team_members')
            .delete()
            .inFilter('user_id', playerIds)
            .inFilter('team_id', compIds);
      }
    }

    // Estructura para llevar la fuerza acumulada de cada equipo
    List<int> teamStrengths = List.filled(numTeams, 0);
    List<Map<String, dynamic>> membersToInsert = [];

    // Distribución equilibrada codiciosa (greedy) por grupo táctico
    void distributeGroup(List<UserModel> group) {
      for (var player in group) {
        // Encontrar el equipo con la menor fuerza acumulada actualmente
        int weakestTeamIdx = 0;
        int minStrength = teamStrengths[0];
        
        for (int i = 1; i < numTeams; i++) {
          if (teamStrengths[i] < minStrength) {
            minStrength = teamStrengths[i];
            weakestTeamIdx = i;
          }
        }

        // Asignar jugador al equipo más débil
        membersToInsert.add({
          'team_id': teamIds[weakestTeamIdx],
          'user_id': player.id,
        });

        // Actualizar la fuerza del equipo
        teamStrengths[weakestTeamIdx] += getPlayerScore(player);
      }
    }

    // Distribuimos primero los pívots, luego las bases, y finalmente los aleros/otros
    distributeGroup(centers);
    distributeGroup(guards);
    distributeGroup(forwards);

    // 5. Insertar los nuevos miembros de equipo
    if (membersToInsert.isNotEmpty) {
      await _supabase.from('team_members').insert(membersToInsert);
    }
  }
}
