class GroupModel {
  final String id;
  final String nombre;
  final String? categoria;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.nombre,
    this.categoria,
    required this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      nombre: json['nombre'],
      categoria: json['categoria'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'nombre': nombre,
      'categoria': categoria,
    };
  }
}
