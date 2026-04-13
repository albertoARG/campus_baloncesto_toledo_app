import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/groups_repository.dart';
import '../../data/models/group_model.dart';
import '../../../../core/models/user_model.dart';

// Provider original para supabase
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Provider del repositorio de grupos
final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.watch(supabaseClientProvider));
});

// Autocargar la lista de grupos
final groupsProvider = FutureProvider<List<GroupModel>>((ref) async {
  return ref.watch(groupsRepositoryProvider).getGroups();
});

// Autocargar los miembros de un grupo pasándole su ID
final groupMembersProvider = FutureProvider.family<List<UserModel>, String>((ref, groupId) async {
  return ref.watch(groupsRepositoryProvider).getGroupMembers(groupId);
});
