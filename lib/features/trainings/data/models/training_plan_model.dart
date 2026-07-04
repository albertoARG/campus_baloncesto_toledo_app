class TrainingPlanModel {
  final String id;
  final String titulo;
  final String url;
  final String filename;
  final String? uploadedBy;
  final DateTime? createdAt;
  final String storagePath;

  TrainingPlanModel({
    required this.id,
    required this.titulo,
    required this.url,
    required this.filename,
    this.uploadedBy,
    this.createdAt,
    required this.storagePath,
  });

  factory TrainingPlanModel.fromJson(Map<String, dynamic> json) {
    return TrainingPlanModel(
      id: json['id'],
      titulo: json['titulo'],
      url: json['url'],
      filename: json['filename'],
      uploadedBy: json['uploaded_by'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : null,
      storagePath: json['storage_path'],
    );
  }
}
