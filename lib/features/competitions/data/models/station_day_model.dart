class StationDayModel {
  final String id;
  final String nombre;
  final DateTime? fecha;
  final bool isPublished;
  final bool visibleEntrenadores;
  final DateTime createdAt;

  StationDayModel({
    required this.id,
    required this.nombre,
    this.fecha,
    this.isPublished = false,
    this.visibleEntrenadores = false,
    required this.createdAt,
  });

  /// Estado de visibilidad: 'publico' | 'entrenadores' | 'borrador'.
  String get estado => isPublished
      ? 'publico'
      : (visibleEntrenadores ? 'entrenadores' : 'borrador');

  factory StationDayModel.fromJson(Map<String, dynamic> json) {
    return StationDayModel(
      id: json['id'],
      nombre: json['nombre'],
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : null,
      isPublished: json['is_published'] ?? false,
      visibleEntrenadores: json['visible_entrenadores'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'nombre': nombre,
      if (fecha != null) 'fecha': fecha!.toIso8601String(),
      'is_published': isPublished,
      'visible_entrenadores': visibleEntrenadores,
    };
  }
}
