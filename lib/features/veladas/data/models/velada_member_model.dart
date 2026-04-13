import '../../../../core/models/user_model.dart';

class VeladaMemberModel {
  final String groupId;
  final String userId;
  final bool isCaptain;
  final UserModel? user; // Opcional, para llenarlo con un JOIN

  VeladaMemberModel({
    required this.groupId,
    required this.userId,
    required this.isCaptain,
    this.user,
  });

  factory VeladaMemberModel.fromJson(Map<String, dynamic> json) {
    return VeladaMemberModel(
      groupId: json['group_id'],
      userId: json['user_id'],
      isCaptain: json['is_captain'] ?? false,
      user: json['users'] != null ? UserModel.fromJson(json['users']) : null,
    );
  }
}
