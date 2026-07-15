import '../../domain/entities/remplacant.dart';

class RemplacantModel extends Remplacant {
  const RemplacantModel({
    required super.id,
    required super.nomComplet,
    super.telephone,
  });

  factory RemplacantModel.fromJson(Map<String, dynamic> j) => RemplacantModel(
        id: j['id'] as int,
        nomComplet: (j['nomComplet'] ?? '') as String,
        telephone: j['telephone'] as String?,
      );
}
