class SiestaCompetitionModel {
  final String id;
  final String nombre;
  final String juego;
  final String formato;
  final String estado;
  final DateTime createdAt;

  SiestaCompetitionModel({
    required this.id,
    required this.nombre,
    required this.juego,
    required this.formato,
    required this.estado,
    required this.createdAt,
  });

  factory SiestaCompetitionModel.fromJson(Map<String, dynamic> json) {
    return SiestaCompetitionModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      juego: json['juego'] as String,
      formato: json['formato'] as String,
      estado: json['estado'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'juego': juego,
      'formato': formato,
      'estado': estado,
      // created_at is handled by DB on insert usually, unless specified
    };
  }
}
