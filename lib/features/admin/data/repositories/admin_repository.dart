import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/user_model.dart';

class AdminRepository {
  final SupabaseClient _supabase;

  AdminRepository(this._supabase);

  Future<List<UserModel>> getAllUsers() async {
    final response = await _supabase
        .from('users')
        .select()
        .order('nombre', ascending: true);
    
    return (response as List).map((json) => UserModel.fromJson(json)).toList();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _supabase
        .from('users')
        .update({'role': newRole})
        .eq('id', userId);
  }

  /// Actualiza los datos de perfil de un jugador (uso de administrador).
  Future<void> updateUserData(
    String userId, {
    required String nombre,
    required String apellidos,
    String? posicion,
    double? estatura,
    int? edad,
    int? nivel,
  }) async {
    await _supabase.from('users').update({
      'nombre': nombre,
      'apellidos': apellidos,
      'posicion': posicion,
      'estatura': estatura,
      'edad': edad,
      'nivel': nivel,
    }).eq('id', userId);
  }
}
