class StationModel {
  final String id;
  final String nombre;
  final String? descripcion;
  final DateTime createdAt;

  StationModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.createdAt,
  });

  factory StationModel.fromJson(Map<String, dynamic> json) {
    return StationModel(
      id: json['id'],
      nombre: json['nombre'],
      descripcion: json['descripcion'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
    };
  }
}
