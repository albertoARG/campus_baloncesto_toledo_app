import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/veladas_repository.dart';
import '../../data/models/velada_model.dart';
import '../../data/models/velada_group_model.dart';
import '../../data/models/velada_member_model.dart';

// Provide Supabase instance
final supabaseVeladasProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

// Provide Repository
final veladasRepositoryProvider = Provider<VeladasRepository>((ref) {
  return VeladasRepository(ref.watch(supabaseVeladasProvider));
});

// Provide all Veladas
final allVeladasProvider = FutureProvider<List<VeladaModel>>((ref) {
  return ref.watch(veladasRepositoryProvider).getVeladas();
});

// Provide groups for a specific velada
final veladaGroupsProvider =
    FutureProvider.family<List<VeladaGroupModel>, String>((ref, veladaId) {
      return ref.watch(veladasRepositoryProvider).getGroups(veladaId);
    });

// Provide members for a specific group
final veladaGroupMembersProvider =
    FutureProvider.family<List<VeladaMemberModel>, String>((ref, groupId) {
      return ref.watch(veladasRepositoryProvider).getGroupMembers(groupId);
    });

// Provide the global standings for veladas
final veladasStandingsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(veladasRepositoryProvider).getVeladasStandings();
});
