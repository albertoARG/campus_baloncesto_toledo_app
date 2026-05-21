import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/player_stat_model.dart';
import '../../data/repositories/stats_repository.dart';
import '../../../../core/models/user_model.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return StatsRepository(supabase);
});

final allStatsProvider = FutureProvider<List<PlayerStatModel>>((ref) async {
  final repository = ref.watch(statsRepositoryProvider);
  return await repository.getAllStats();
});

final currentUserStatsProvider = FutureProvider<List<PlayerStatModel>>((ref) async {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return [];
  
  final repository = ref.watch(statsRepositoryProvider);
  return await repository.getUserStats(user.id);
});

class PlayerRanking {
  final UserModel user;
  final int totalPoints;
  final int totalRebounds;
  final int totalAssists;
  final int totalSteals;
  final int totalBlocks;
  final int mvpAwards;

  PlayerRanking({
    required this.user,
    this.totalPoints = 0,
    this.totalRebounds = 0,
    this.totalAssists = 0,
    this.totalSteals = 0,
    this.totalBlocks = 0,
    this.mvpAwards = 0,
  });
}

final rankingsProvider = Provider<AsyncValue<List<PlayerRanking>>>((ref) {
  final statsAsync = ref.watch(allStatsProvider);

  return statsAsync.whenData((stats) {
    final Map<String, PlayerRanking> userTotals = {};

    for (var stat in stats) {
      if (stat.user == null) continue;
      
      final uId = stat.user!.id;
      if (!userTotals.containsKey(uId)) {
        userTotals[uId] = PlayerRanking(user: stat.user!);
      }

      final current = userTotals[uId]!;
      userTotals[uId] = PlayerRanking(
        user: current.user,
        totalPoints: current.totalPoints + stat.points,
        totalRebounds: current.totalRebounds + stat.rebounds,
        totalAssists: current.totalAssists + stat.assists,
        totalSteals: current.totalSteals + stat.steals,
        totalBlocks: current.totalBlocks + stat.blocks,
        mvpAwards: current.mvpAwards + (stat.isMvp ? 1 : 0),
      );
    }

    return userTotals.values.toList();
  });
});
