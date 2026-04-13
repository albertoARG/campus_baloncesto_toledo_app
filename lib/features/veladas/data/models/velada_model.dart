class VeladaModel {
  final String id;
  final String nombre;
  final DateTime fecha;

  VeladaModel({required this.id, required this.nombre, required this.fecha});

  factory VeladaModel.fromJson(Map<String, dynamic> json) {
    return VeladaModel(
      id: json['id'],
      nombre: json['nombre'],
      fecha: DateTime.parse(json['fecha']),
    );
  }
}
