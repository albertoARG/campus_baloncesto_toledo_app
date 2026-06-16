class MatchTeamModel {
  final String id;
  final String nombre;

  MatchTeamModel({required this.id, required this.nombre});

  factory MatchTeamModel.fromJson(Map<String, dynamic> json) {
    return MatchTeamModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
    );
  }
}
