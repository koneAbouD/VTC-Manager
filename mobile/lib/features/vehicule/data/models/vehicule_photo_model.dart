class VehiculePhotoModel {
  final int id;
  final String url;
  final int? ordre;

  const VehiculePhotoModel({required this.id, required this.url, this.ordre});

  factory VehiculePhotoModel.fromJson(Map<String, dynamic> json) =>
      VehiculePhotoModel(
        id: json['id'] as int,
        url: json['url'] as String,
        ordre: json['ordre'] as int?,
      );
}
