import 'dart:convert';
import 'play_data.dart';

/// Un ejercicio/fila de la ficha de sesión.
class PlanExercise {
  final String tiempo;
  final String nombre;
  final String descripcion;
  const PlanExercise({
    this.tiempo = '',
    this.nombre = '',
    this.descripcion = '',
  });

  Map<String, dynamic> toJson() => {'t': tiempo, 'n': nombre, 'd': descripcion};

  factory PlanExercise.fromJson(Map j) => PlanExercise(
        tiempo: (j['t'] ?? '').toString(),
        nombre: (j['n'] ?? '').toString(),
        descripcion: (j['d'] ?? '').toString(),
      );

  bool get isEmpty =>
      tiempo.trim().isEmpty &&
      nombre.trim().isEmpty &&
      descripcion.trim().isEmpty;
}

/// Datos de la ficha de sesión de entrenamiento. Se serializa a JSON y se
/// guarda en el campo `descripcion` del entrenamiento (sin cambios en la BD).
class TrainingPlanData {
  final String dia;
  final String hora;
  final String duracion;
  final String lugar;
  final String sesion;
  final String objetivos;
  final String asistentes;
  final String ausentes;
  final List<PlanExercise> ejercicios;
  final List<Play> jugadas;

  const TrainingPlanData({
    this.dia = '',
    this.hora = '',
    this.duracion = '',
    this.lugar = '',
    this.sesion = '',
    this.objetivos = '',
    this.asistentes = '',
    this.ausentes = '',
    this.ejercicios = const [],
    this.jugadas = const [],
  });

  Map<String, dynamic> toJson() => {
        '_plantilla': true,
        'dia': dia,
        'hora': hora,
        'duracion': duracion,
        'lugar': lugar,
        'sesion': sesion,
        'objetivos': objetivos,
        'asistentes': asistentes,
        'ausentes': ausentes,
        'ejercicios': ejercicios.map((e) => e.toJson()).toList(),
        'jugadas': jugadas.map((e) => e.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  /// Devuelve la ficha si [raw] es JSON de plantilla; si no, null (texto normal).
  static TrainingPlanData? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is Map && j['_plantilla'] == true) {
        return TrainingPlanData(
          dia: (j['dia'] ?? '').toString(),
          hora: (j['hora'] ?? '').toString(),
          duracion: (j['duracion'] ?? '').toString(),
          lugar: (j['lugar'] ?? '').toString(),
          sesion: (j['sesion'] ?? '').toString(),
          objetivos: (j['objetivos'] ?? '').toString(),
          asistentes: (j['asistentes'] ?? '').toString(),
          ausentes: (j['ausentes'] ?? '').toString(),
          ejercicios: ((j['ejercicios'] as List?) ?? [])
              .map((e) => PlanExercise.fromJson(e as Map))
              .toList(),
          jugadas: ((j['jugadas'] as List?) ?? [])
              .map((e) => Play.fromJson(e as Map))
              .toList(),
        );
      }
    } catch (_) {}
    return null;
  }
}
