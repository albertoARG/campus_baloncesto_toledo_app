import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/training_plan_model.dart';

class TrainingPlansRepository {
  final SupabaseClient _supabase;

  TrainingPlansRepository(this._supabase);

  static const String _bucket = 'training-plans';

  Future<List<TrainingPlanModel>> getPlans() async {
    final response = await _supabase
        .from('training_plans')
        .select('*')
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => TrainingPlanModel.fromJson(e))
        .toList();
  }

  Future<TrainingPlanModel> uploadPlan({
    required String titulo,
    required Uint8List bytes,
    required String filename,
  }) async {
    final storagePath =
        '${DateTime.now().millisecondsSinceEpoch}_${_sanitize(filename)}';

    await _supabase.storage.from(_bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: false,
          ),
        );

    final url = _supabase.storage.from(_bucket).getPublicUrl(storagePath);

    final response = await _supabase
        .from('training_plans')
        .insert({
          'titulo': titulo,
          'url': url,
          'filename': filename,
          'uploaded_by': _supabase.auth.currentUser?.id,
          'storage_path': storagePath,
        })
        .select('*')
        .single();

    return TrainingPlanModel.fromJson(response);
  }

  Future<void> deletePlan(TrainingPlanModel plan) async {
    await _supabase.storage.from(_bucket).remove([plan.storagePath]);
    await _supabase.from('training_plans').delete().eq('id', plan.id);
  }

  String _sanitize(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
