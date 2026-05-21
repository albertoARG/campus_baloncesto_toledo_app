import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/training_model.dart';

class TrainingsRepository {
  final SupabaseClient _supabase;

  TrainingsRepository(this._supabase);

  Future<List<TrainingModel>> getTrainings() async {
    final response = await _supabase
        .from('trainings')
        .select('*, teams(*), users(*)')
        .order('fecha', ascending: false);
    return (response as List).map((e) => TrainingModel.fromJson(e)).toList();
  }

  Future<TrainingModel> createTraining(TrainingModel training) async {
    final response = await _supabase
        .from('trainings')
        .insert(training.toJson())
        .select('*, teams(*), users(*)')
        .single();
    return TrainingModel.fromJson(response);
  }

  Future<void> deleteTraining(String id) async {
    await _supabase.from('trainings').delete().eq('id', id);
  }

  Future<void> updateTraining(String id, TrainingModel training) async {
    final data = training.toJson();
    data.remove('id'); // We don't update ID
    await _supabase.from('trainings').update(data).eq('id', id);
  }
}
