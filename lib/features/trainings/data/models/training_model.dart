import '../../../../core/models/user_model.dart';
import '../../../groups/data/models/group_model.dart';

class TrainingModel {
  final String id;
  final String titulo;
  final String? descripcion;
  final String? multimediaUrl;
  final DateTime? fecha;
  final String? teamId;
  final String? coachId;
  
  // Opcionales para vista unida
  final GroupModel? team;
  final UserModel? coach;

  TrainingModel({
    required this.id,
    required this.titulo,
    this.descripcion,
    this.multimediaUrl,
    this.fecha,
    this.teamId,
    this.coachId,
    this.team,
    this.coach,
  });

  factory TrainingModel.fromJson(Map<String, dynamic> json) {
    return TrainingModel(
      id: json['id'],
      titulo: json['titulo'],
      descripcion: json['descripcion'],
      multimediaUrl: json['multimedia_url'],
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']).toLocal() : null,
      teamId: json['team_id'],
      coachId: json['coach_id'],
      team: json['teams'] != null ? GroupModel.fromJson(json['teams']) : null,
      coach: json['users'] != null ? UserModel.fromJson(json['users']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'multimedia_url': multimediaUrl,
      'fecha': fecha?.toUtc().toIso8601String(),
      'team_id': teamId,
      'coach_id': coachId,
    };
  }
}
