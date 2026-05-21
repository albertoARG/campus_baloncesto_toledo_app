import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_stat_model.dart';

class StatsRepository {
  final SupabaseClient _supabase;

  StatsRepository(this._supabase);

  Future<List<PlayerStatModel>> getAllStats() async {
    final response = await _supabase
        .from('player_match_stats')
        .select('*, users(*)')
        .order('created_at', ascending: false);
        
    return (response as List).map((e) => PlayerStatModel.fromJson(e)).toList();
  }

  Future<List<PlayerStatModel>> getUserStats(String userId) async {
    final response = await _supabase
        .from('player_match_stats')
        .select('*, users(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
        
    return (response as List).map((e) => PlayerStatModel.fromJson(e)).toList();
  }

  Future<void> addStat(PlayerStatModel stat) async {
    await _supabase.from('player_match_stats').insert(stat.toJson());
  }

  Future<void> updateStat(String id, Map<String, dynamic> data) async {
    await _supabase.from('player_match_stats').update(data).eq('id', id);
  }

  Future<void> deleteStat(String id) async {
    await _supabase.from('player_match_stats').delete().eq('id', id);
  }
}
