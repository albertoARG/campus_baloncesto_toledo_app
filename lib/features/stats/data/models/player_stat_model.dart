import '../../../../core/models/user_model.dart';

class PlayerStatModel {
  final String id;
  final String userId;
  final String? matchName;
  final int points;
  final int rebounds;
  final int assists;
  final int steals;
  final int blocks;
  final bool isMvp;
  final DateTime createdAt;
  
  // Para las uniones con la tabla users
  final UserModel? user;

  PlayerStatModel({
    required this.id,
    required this.userId,
    this.matchName,
    this.points = 0,
    this.rebounds = 0,
    this.assists = 0,
    this.steals = 0,
    this.blocks = 0,
    this.isMvp = false,
    required this.createdAt,
    this.user,
  });

  factory PlayerStatModel.fromJson(Map<String, dynamic> json) {
    return PlayerStatModel(
      id: json['id'],
      userId: json['user_id'],
      matchName: json['match_name'],
      points: json['points'] ?? 0,
      rebounds: json['rebounds'] ?? 0,
      assists: json['assists'] ?? 0,
      steals: json['steals'] ?? 0,
      blocks: json['blocks'] ?? 0,
      isMvp: json['is_mvp'] ?? false,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      user: json['users'] != null ? UserModel.fromJson(json['users']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'match_name': matchName,
      'points': points,
      'rebounds': rebounds,
      'assists': assists,
      'steals': steals,
      'blocks': blocks,
      'is_mvp': isMvp,
    };
  }
}
