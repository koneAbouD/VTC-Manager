import 'element_maintenance.dart';

class DetailMaintenance {
  final int? id;
  final int? dureeMaintenance;
  final List<ElementMaintenance> elements;

  const DetailMaintenance({
    this.id,
    this.dureeMaintenance,
    this.elements = const [],
  });
}
