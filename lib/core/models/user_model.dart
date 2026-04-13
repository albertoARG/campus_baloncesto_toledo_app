class UserModel {
  final String id;
  final String role;
  final String nombre;
  final String apellidos;
  final String? fotoUrl;
  final String? posicion;
  final double? estatura;
  final int? edad;

  UserModel({
    required this.id,
    required this.role,
    required this.nombre,
    required this.apellidos,
    this.fotoUrl,
    this.posicion,
    this.estatura,
    this.edad,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      role: json['role'] ?? 'jugador',
      nombre: json['nombre'] ?? '',
      apellidos: json['apellidos'] ?? '',
      fotoUrl: json['foto_url'],
      posicion: json['posicion'],
      estatura: json['estatura'] != null ? double.parse(json['estatura'].toString()) : null,
      edad: json['edad'] != null ? int.parse(json['edad'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'nombre': nombre,
      'apellidos': apellidos,
      'foto_url': fotoUrl,
      'posicion': posicion,
      'estatura': estatura,
      'edad': edad,
    };
  }
}
