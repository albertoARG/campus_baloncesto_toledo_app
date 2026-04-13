class StationDayModel {
  final String id;
  final String nombre;
  final DateTime? fecha;
  final DateTime createdAt;

  StationDayModel({
    required this.id,
    required this.nombre,
    this.fecha,
    required this.createdAt,
  });

  factory StationDayModel.fromJson(Map<String, dynamic> json) {
    return StationDayModel(
      id: json['id'],
      nombre: json['nombre'],
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'nombre': nombre,
      if (fecha != null) 'fecha': fecha!.toIso8601String(),
    };
  }
}
