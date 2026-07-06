import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';

/// Une vidange enregistrée pour un véhicule. La plus récente d'un véhicule fait
/// office de « dernière vidange » ; sa cible (date/km prochaine) fait office de
/// « prochaine vidange ».
class Vidange {
  final int? id;
  final int? vehiculeId;
  final DateTime dateVidange;
  final int kilometrageVidange;
  final DateTime? dateProchaineVidange;
  final int? kilometrageProchaineVidange;
  final String? commentaire;

  const Vidange({
    this.id,
    this.vehiculeId,
    required this.dateVidange,
    required this.kilometrageVidange,
    this.dateProchaineVidange,
    this.kilometrageProchaineVidange,
    this.commentaire,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v as String);
    } catch (_) {
      return null;
    }
  }

  factory Vidange.fromJson(Map<String, dynamic> j) => Vidange(
        id: j['id'] as int?,
        vehiculeId: j['vehiculeId'] as int?,
        dateVidange: _parseDate(j['dateVidange']) ?? DateTime.now(),
        kilometrageVidange: (j['kilometrageVidange'] as num?)?.toInt() ?? 0,
        dateProchaineVidange: _parseDate(j['dateProchaineVidange']),
        kilometrageProchaineVidange:
            (j['kilometrageProchaineVidange'] as num?)?.toInt(),
        commentaire: j['commentaire'] as String?,
      );

  /// Payload de création (POST). Les dates sont envoyées au format `yyyy-MM-dd`.
  Map<String, dynamic> toCreateJson() => {
        'dateVidange': _fmtDate(dateVidange),
        'kilometrageVidange': kilometrageVidange,
        if (dateProchaineVidange != null)
          'dateProchaineVidange': _fmtDate(dateProchaineVidange!),
        if (kilometrageProchaineVidange != null)
          'kilometrageProchaineVidange': kilometrageProchaineVidange,
        if (commentaire != null && commentaire!.trim().isNotEmpty)
          'commentaire': commentaire!.trim(),
      };

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Historique des vidanges d'un véhicule (de la plus récente à la plus ancienne).
final vidangesByVehiculeProvider =
    FutureProvider.family<List<Vidange>, int>((ref, vehiculeId) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/vehicules/$vehiculeId/vidanges');
  if (data is! List) return [];
  return data
      .map((e) => Vidange.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Enregistre une nouvelle vidange puis invalide le provider d'historique.
Future<Vidange> creerVidange(
  WidgetRef ref, {
  required int vehiculeId,
  required Vidange vidange,
}) async {
  final client = ref.read(apiClientProvider);
  final data = await client.post(
    '/vehicules/$vehiculeId/vidanges',
    vidange.toCreateJson(),
  );
  ref.invalidate(vidangesByVehiculeProvider(vehiculeId));
  return Vidange.fromJson(data as Map<String, dynamic>);
}
