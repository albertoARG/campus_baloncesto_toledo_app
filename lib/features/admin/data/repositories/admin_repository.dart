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

  /// Crea un jugador como ficha (sin cuenta de acceso). El id lo genera la BD.
  Future<void> createPlayer({
    required String nombre,
    required String apellidos,
    String? posicion,
    double? estatura,
    int? edad,
    int? nivel,
  }) async {
    await _supabase.from('users').insert({
      'role': 'jugador',
      'nombre': nombre,
      'apellidos': apellidos,
      'posicion': posicion,
      'estatura': estatura,
      'edad': edad,
      'nivel': nivel ?? 3,
    });
  }

  /// Elimina un jugador (y en cascada sus datos asociados si las FK lo permiten).
  Future<void> deletePlayer(String userId) async {
    await _supabase.from('users').delete().eq('id', userId);
  }

  /// Inserta varios jugadores de golpe (importación). Cada mapa: {nombre,
  /// apellidos, edad?, nivel?}. Devuelve cuántos se han insertado.
  Future<int> importPlayers(List<Map<String, dynamic>> players) async {
    if (players.isEmpty) return 0;
    final rows = players
        .map((p) => {
              'role': 'jugador',
              'nombre': p['nombre'],
              'apellidos': p['apellidos'] ?? '',
              if (p['edad'] != null) 'edad': p['edad'],
              'nivel': p['nivel'] ?? 3,
            })
        .toList();
    await _supabase.from('users').insert(rows);
    return rows.length;
  }
}
