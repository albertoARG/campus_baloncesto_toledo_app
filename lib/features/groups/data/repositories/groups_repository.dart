import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../models/group_model.dart';

class GroupsRepository {
  final SupabaseClient _supabase;

  GroupsRepository(this._supabase);

  // Obtener todos los grupos
  Future<List<GroupModel>> getGroups() async {
    final response = await _supabase
        .from('teams')
        .select()
        .order('nombre', ascending: true);
    return (response as List).map((e) => GroupModel.fromJson(e)).toList();
  }

  // Crear un nuevo grupo
  Future<GroupModel> createGroup(String nombre, String? categoria) async {
    final response = await _supabase.from('teams').insert({
      'nombre': nombre,
      'categoria': categoria,
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

  // Generar equipos equilibrados automáticamente
  Future<void> autoGenerateBalancedTeams(int numTeams, String prefix) async {
    if (numTeams <= 0) return;

    // 1. Fetch players
    final usersRes = await _supabase.from('users').select().eq('role', 'jugador');
    List<UserModel> players = (usersRes as List).map((e) => UserModel.fromJson(e)).toList();

    // 2. Sort players by age descending (older players first)
    players.sort((a, b) => (b.edad ?? 0).compareTo(a.edad ?? 0));

    // 3. Create teams
    List<Map<String, dynamic>> teamsToInsert = [];
    for (int i = 0; i < numTeams; i++) {
      teamsToInsert.add({
        'nombre': '$prefix ${i + 1}',
      });
    }

    final createdTeams = await _supabase.from('teams').insert(teamsToInsert).select();
    final teamIds = (createdTeams as List).map((t) => t['id'] as String).toList();

    // 4. Distribute players using snake draft
    List<Map<String, dynamic>> membersToInsert = [];
    int currentTeamIdx = 0;
    bool forward = true;

    for (var player in players) {
      membersToInsert.add({
        'team_id': teamIds[currentTeamIdx],
        'user_id': player.id,
      });

      if (forward) {
        currentTeamIdx++;
        if (currentTeamIdx >= numTeams) {
          currentTeamIdx = numTeams - 1;
          forward = false;
        }
      } else {
        currentTeamIdx--;
        if (currentTeamIdx < 0) {
          currentTeamIdx = 0;
          forward = true;
        }
      }
    }

    if (membersToInsert.isNotEmpty) {
      await _supabase.from('team_members').insert(membersToInsert);
    }
  }
}
