import '../../domain/entities/geolocalisation.dart';

class GeolocalisationModel extends Geolocalisation {
  const GeolocalisationModel({
    super.id,
    super.latitude,
    super.longitude,
    super.horodatage,
  });

  factory GeolocalisationModel.fromJson(Map<String, dynamic> json) {
    return GeolocalisationModel(
      id: json['id'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      horodatage: json['horodatage'] != null
          ? DateTime.tryParse(json['horodatage'] as String)
          : null,
    );
  }
}
