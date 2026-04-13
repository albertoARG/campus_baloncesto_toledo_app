import 'siesta_participant_model.dart';

class SiestaMatchModel {
  final String id;
  final String competitionId;
  final String participant1Id;
  final String participant2Id;
  final int score1;
  final int score2;
  final String? ronda;
  final String estado;
  final DateTime? fecha;
  
  // Populated when doing joins
  final SiestaParticipantModel? participant1;
  final SiestaParticipantModel? participant2;

  SiestaMatchModel({
    required this.id,
    required this.competitionId,
    required this.participant1Id,
    required this.participant2Id,
    this.score1 = 0,
    this.score2 = 0,
    this.ronda,
    this.estado = 'programado',
    this.fecha,
    this.participant1,
    this.participant2,
  });

  factory SiestaMatchModel.fromJson(Map<String, dynamic> json) {
    return SiestaMatchModel(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      participant1Id: json['participant1_id'] as String,
      participant2Id: json['participant2_id'] as String,
      score1: json['score1'] ?? 0,
      score2: json['score2'] ?? 0,
      ronda: json['ronda'] as String?,
      estado: json['estado'] ?? 'programado',
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha'] as String) : null,
      // If we do complex joins fetching the participants and users inside
      participant1: json['participant1'] != null 
          ? SiestaParticipantModel.fromJson(json['participant1']) 
          : null,
      participant2: json['participant2'] != null 
          ? SiestaParticipantModel.fromJson(json['participant2']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'competition_id': competitionId,
      'participant1_id': participant1Id,
      'participant2_id': participant2Id,
      'score1': score1,
      'score2': score2,
      'ronda': ronda,
      'estado': estado,
      if (fecha != null) 'fecha': fecha!.toIso8601String(),
    };
  }
}
