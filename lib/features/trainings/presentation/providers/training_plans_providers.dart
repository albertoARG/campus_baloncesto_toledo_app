import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/training_plans_repository.dart';
import '../../data/models/training_plan_model.dart';

final trainingPlansRepositoryProvider =
    Provider<TrainingPlansRepository>((ref) {
  return TrainingPlansRepository(Supabase.instance.client);
});

final trainingPlansProvider =
    FutureProvider<List<TrainingPlanModel>>((ref) {
  return ref.watch(trainingPlansRepositoryProvider).getPlans();
});
