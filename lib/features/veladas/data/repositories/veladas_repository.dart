import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../models/velada_model.dart';
import '../models/velada_group_model.dart';
import '../models/velada_member_model.dart';

class VeladasRepository {
  final SupabaseClient _supabase;

  VeladasRepository(this._supabase);

  // Obtener todas las veladas
  Future<List<VeladaModel>> getVeladas() async {
    final res = await _supabase.from('veladas').select().order('fecha', ascending: false);
    return (res as List).map((j) => VeladaModel.fromJson(j)).toList();
  }

  // Crear una velada
  Future<void> createVelada(String nombre) async {
    await _supabase.from('veladas').insert({'nombre': nombre});
  }

  // Borrar una velada (borra en cascada grupos y miembros)
  Future<void> deleteVelada(String veladaId) async {
    await _supabase.from('veladas').delete().eq('id', veladaId);
  }

  // Obtener grupos de una velada
  Future<List<VeladaGroupModel>> getGroups(String veladaId) async {
    final res = await _supabase.from('velada_groups').select().eq('velada_id', veladaId).order('nombre');
    return (res as List).map((j) => VeladaGroupModel.fromJson(j)).toList();
  }

  // Marcar un grupo como ganador
  Future<void> markGroupAsWinner(String veladaId, String groupId) async {
    // 1. Quitar ganador de todos los grupos de esta velada
    await _supabase.from('velada_groups')
       .update({'is_winner': false})
       .eq('velada_id', veladaId);
       
    // 2. Asignar ganador al seleccionado
    await _supabase.from('velada_groups')
       .update({'is_winner': true})
       .eq('id', groupId);
  }

  // Obtener miembros de un grupo con datos de usuario (join manual o directo de app)
  Future<List<VeladaMemberModel>> getGroupMembers(String groupId) async {
    final res = await _supabase.from('velada_group_members')
        .select('*, users(*)')
        .eq('group_id', groupId);
    return (res as List).map((j) => VeladaMemberModel.fromJson(j)).toList();
  }

  // Algoritmo de balanceo por edades
  Future<void> generateBalancedGroups(String veladaId, int numGroups) async {
    if (numGroups <= 0) return;

    // 1. Obtener todos los jugadores
    final usersRes = await _supabase.from('users').select().eq('role', 'jugador');
    List<UserModel> players = (usersRes as List).map((j) => UserModel.fromJson(j)).toList();

    // 2. Ordenar de mayor a menor edad (los que no tengan edad, van al final con 0)
    players.sort((a, b) => (b.edad ?? 0).compareTo(a.edad ?? 0));

    // 3. Borrar grupos existentes de la velada
    await _supabase.from('velada_groups').delete().eq('velada_id', veladaId);

    // 4. Crear los N grupos en base de datos para obtener sus IDs
    List<Map<String, dynamic>> groupsToInsert = [];
    for (int i = 0; i < numGroups; i++) {
       groupsToInsert.add({
         'velada_id': veladaId,
         'nombre': 'Grupo Velada ${i + 1}',
       });
    }
    final createdGroups = await _supabase.from('velada_groups').insert(groupsToInsert).select();
    final groupIds = (createdGroups as List).map((g) => g['id'] as String).toList();

    // 5. Asignar capitanes y repartir jugadores usando Tiers Aleatorios
    List<Map<String, dynamic>> membersToInsert = [];
    
    int numCaptains = numGroups;
    if (players.length < numGroups) numCaptains = players.length;

    for (int i = 0; i < numCaptains; i++) {
       membersToInsert.add({
          'group_id': groupIds[i],
          'user_id': players[i].id,
          'is_captain': true,
       });
    }

    if (players.length > numGroups) {
       List<UserModel> remainingPlayers = players.sublist(numGroups);
       int numTiers = (remainingPlayers.length / numGroups).ceil();

       for (int t = 0; t < numTiers; t++) {
          int start = t * numGroups;
          int end = start + numGroups;
          if (end > remainingPlayers.length) end = remainingPlayers.length;

          List<UserModel> tierPlayers = remainingPlayers.sublist(start, end);
          tierPlayers.shuffle();

          // Repartimos los jugadores mezclados uno a cada grupo de forma aleatoria
          List<String> shuffledGroups = List.from(groupIds)..shuffle();

          for (int i = 0; i < tierPlayers.length; i++) {
             membersToInsert.add({
                'group_id': shuffledGroups[i], 
                'user_id': tierPlayers[i].id,
                'is_captain': false,
             });
          }
       }
    }

    // Insertar miembros en bloque
    if (membersToInsert.isNotEmpty) {
      await _supabase.from('velada_group_members').insert(membersToInsert);
    }
  }

  // Eliminar un miembro manualmente de un grupo
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    await _supabase.from('velada_group_members')
        .delete()
        .match({'group_id': groupId, 'user_id': userId});
  }

  // Añadir un miembro manualmente a un grupo
  Future<void> addMemberToGroup(String groupId, String userId, {bool isCaptain = false}) async {
    // Para simplificar, primero lo borramos de cualquier otro grupo de ESTA misma velada
    // (Opcional: aquí podríamos buscar a qué velada pertenece el grupo 
    // y borrarlo de todos los grupos de esa velada para no duplicarlo,
    // pero de momento lo insertamos directamente).
    await _supabase.from('velada_group_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'is_captain': isCaptain,
    });
  }

  // Clasificación de veladas (Ranking global de jugadores)
  Future<List<Map<String, dynamic>>> getVeladasStandings() async {
    final gamersRes = await _supabase.from('users').select().eq('role', 'jugador');
    List<UserModel> players = (gamersRes as List).map((j) => UserModel.fromJson(j)).toList();

    final winnerMembersRes = await _supabase.from('velada_group_members')
      .select('user_id, velada_groups!inner(is_winner)')
      .eq('velada_groups.is_winner', true);

    Map<String, int> pointsMap = {};
    for (var row in winnerMembersRes as List) {
       String uid = row['user_id'];
       pointsMap[uid] = (pointsMap[uid] ?? 0) + 1;
    }

    List<Map<String, dynamic>> standings = [];
    for (var p in players) {
      standings.add({
         'player': p,
         'veladas_won': pointsMap[p.id] ?? 0,
      });
    }

    standings.sort((a, b) => (b['veladas_won'] as int).compareTo(a['veladas_won'] as int));
    return standings;
  }
}
