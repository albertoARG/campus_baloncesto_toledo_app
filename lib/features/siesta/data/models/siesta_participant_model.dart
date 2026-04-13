import '../../../../core/models/user_model.dart';

class SiestaParticipantModel {
  final String id;
  final String competitionId;
  final String userId;
  final int puntosLiga;
  final int partidosJugados;
  final int partidosGanados;
  final int partidosPerdidos;
  final String? grupo;
  final UserModel? user; // Populated from join

  SiestaParticipantModel({
    required this.id,
    required this.competitionId,
    required this.userId,
    this.puntosLiga = 0,
    this.partidosJugados = 0,
    this.partidosGanados = 0,
    this.partidosPerdidos = 0,
    this.grupo,
    this.user,
  });

  factory SiestaParticipantModel.fromJson(Map<String, dynamic> json) {
    return SiestaParticipantModel(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      userId: json['user_id'] as String,
      puntosLiga: json['puntos_liga'] ?? 0,
      partidosJugados: json['partidos_jugados'] ?? 0,
      partidosGanados: json['partidos_ganados'] ?? 0,
      partidosPerdidos: json['partidos_perdidos'] ?? 0,
      grupo: json['grupo'] as String?,
      user: json['users'] != null ? UserModel.fromJson(json['users']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'competition_id': competitionId,
      'user_id': userId,
      'puntos_liga': puntosLiga,
      'partidos_jugados': partidosJugados,
      'partidos_ganados': partidosGanados,
      'partidos_perdidos': partidosPerdidos,
      'grupo': grupo,
    };
  }
}
