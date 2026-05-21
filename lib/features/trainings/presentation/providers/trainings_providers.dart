import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/trainings_repository.dart';
import '../../data/models/training_model.dart';

final trainingsRepositoryProvider = Provider<TrainingsRepository>((ref) {
  return TrainingsRepository(Supabase.instance.client);
});

final trainingsProvider = FutureProvider<List<TrainingModel>>((ref) {
  return ref.watch(trainingsRepositoryProvider).getTrainings();
});
