class StationScoreModel {
  final String id;
  final String userId;
  final String? coachId;
  final String stationId;
  final String stationDayId;
  final int score;
  final DateTime createdAt;

  StationScoreModel({
    required this.id,
    required this.userId,
    this.coachId,
    required this.stationId,
    required this.stationDayId,
    required this.score,
    required this.createdAt,
  });

  factory StationScoreModel.fromJson(Map<String, dynamic> json) {
    return StationScoreModel(
      id: json['id'],
      userId: json['user_id'],
      coachId: json['coach_id'],
      stationId: json['station_id'],
      stationDayId: json['station_day_id'],
      score: json['score'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      if (coachId != null) 'coach_id': coachId,
      'station_id': stationId,
      'station_day_id': stationDayId,
      'score': score,
    };
  }
}
