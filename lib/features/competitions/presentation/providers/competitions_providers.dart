import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/competitions_repository.dart';
import '../../data/models/station_day_model.dart';
import '../../data/models/station_model.dart';
import '../../../../core/models/user_model.dart';

// Provider for the Repository
final competitionsRepositoryProvider = Provider<CompetitionsRepository>((ref) {
  return CompetitionsRepository(ref.watch(supabaseClientProvider));
});

// Provider for fetching station days
final stationDaysProvider = FutureProvider<List<StationDayModel>>((ref) {
  final repository = ref.watch(competitionsRepositoryProvider);
  return repository.getStationDays();
});

// Provider for fetching stations
final stationsProvider = FutureProvider<List<StationModel>>((ref) {
  final repository = ref.watch(competitionsRepositoryProvider);
  return repository.getStations();
});

// State provider to hold the currently selected group ID for filtering standings
class SelectedGroupId extends Notifier<String?> {
  @override
  String? build() => null;
  
  void setGroup(String? id) {
    state = id;
  }
}

final selectedGroupIdProvider = NotifierProvider<SelectedGroupId, String?>(SelectedGroupId.new);

// State provider to hold the currently selected day ID for filtering standings
class SelectedDayId extends Notifier<String?> {
  @override
  String? build() => null;
  
  void setDay(String? id) {
    state = id;
  }
}

final selectedDayIdProvider = NotifierProvider<SelectedDayId, String?>(SelectedDayId.new);

// Provider for fetching the standings calculated locally
final globalStandingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(competitionsRepositoryProvider);
  final groupId = ref.watch(selectedGroupIdProvider);
  final dayId = ref.watch(selectedDayIdProvider);
  return repository.getGlobalStandings(groupId: groupId, dayId: dayId);
});

// Provider for fetching all players
final playersProvider = FutureProvider<List<UserModel>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase.from('users').select().eq('role', 'jugador').order('nombre');
  return (response as List).map((j) => UserModel.fromJson(j)).toList();
});

// Provider for fetching specific user scores with joins
final userScoresProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  final repository = ref.watch(competitionsRepositoryProvider);
  return repository.getScoresForUser(userId);
});
