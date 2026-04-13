class VeladaGroupModel {
  final String id;
  final String veladaId;
  final String nombre;
  final bool isWinner;

  VeladaGroupModel({
    required this.id,
    required this.veladaId,
    required this.nombre,
    required this.isWinner,
  });

  factory VeladaGroupModel.fromJson(Map<String, dynamic> json) {
    return VeladaGroupModel(
      id: json['id'],
      veladaId: json['velada_id'],
      nombre: json['nombre'],
      isWinner: json['is_winner'] ?? false,
    );
  }
}
