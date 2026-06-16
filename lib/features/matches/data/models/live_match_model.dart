class LiveMatchModel {
  final String id;
  final String? team1Id;
  final String? team2Id;
  final String team1Name;
  final String team2Name;
  final int score1;
  final int score2;
  final int fouls1;
  final int fouls2;
  final String estado; // 'en_juego' | 'finalizado'
  final DateTime createdAt;

  LiveMatchModel({
    required this.id,
    this.team1Id,
    this.team2Id,
    required this.team1Name,
    required this.team2Name,
    this.score1 = 0,
    this.score2 = 0,
    this.fouls1 = 0,
    this.fouls2 = 0,
    this.estado = 'en_juego',
    required this.createdAt,
  });

  bool get finalizado => estado == 'finalizado';

  factory LiveMatchModel.fromJson(Map<String, dynamic> json) {
    return LiveMatchModel(
      id: json['id'] as String,
      team1Id: json['team1_id'] as String?,
      team2Id: json['team2_id'] as String?,
      team1Name: json['team1_name'] ?? 'Equipo 1',
      team2Name: json['team2_name'] ?? 'Equipo 2',
      score1: json['score1'] ?? 0,
      score2: json['score2'] ?? 0,
      fouls1: json['fouls1'] ?? 0,
      fouls2: json['fouls2'] ?? 0,
      estado: json['estado'] ?? 'en_juego',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
