/// Géolocalisation — miroir de [Geolocalisation] côté backend.
class Geolocalisation {
  final int? id;
  final double? latitude;
  final double? longitude;
  final DateTime? horodatage;

  const Geolocalisation({
    this.id,
    this.latitude,
    this.longitude,
    this.horodatage,
  });
}
