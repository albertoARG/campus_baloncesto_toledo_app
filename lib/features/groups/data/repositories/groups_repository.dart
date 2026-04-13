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
}
