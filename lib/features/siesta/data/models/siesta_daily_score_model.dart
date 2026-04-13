import '../../../../core/models/user_model.dart';

class SiestaDailyScoreModel {
  final String id;
  final String competitionId;
  final String userId;
  final DateTime fecha;
  final int puntos;
  
  final UserModel? user;

  SiestaDailyScoreModel({
    required this.id,
    required this.competitionId,
    required this.userId,
    required this.fecha,
    this.puntos = 0,
    this.user,
  });

  factory SiestaDailyScoreModel.fromJson(Map<String, dynamic> json) {
    return SiestaDailyScoreModel(
      id: json['id'] as String,
      competitionId: json['competition_id'] as String,
      userId: json['user_id'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      puntos: json['puntos'] ?? 0,
      user: json['users'] != null ? UserModel.fromJson(json['users']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'competition_id': competitionId,
      'user_id': userId,
      'fecha': "${fecha.year}-${fecha.month.toString().padLeft(2,'0')}-${fecha.day.toString().padLeft(2,'0')}",
      'puntos': puntos,
    };
  }
}
