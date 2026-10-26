import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache disque des images (photos de véhicules et de chauffeurs, éléments du
/// référentiel), séparé de celui des autres paquets pour pouvoir être vidé à
/// la déconnexion.
///
/// Une image déjà vue s'affiche aussitôt, depuis le disque, puis est
/// revalidée en arrière-plan quand le serveur la déclare périmée — la photo
/// d'un chauffeur, servie sans cache côté API, est ainsi toujours rechargée
/// mais reste visible hors connexion.
final cacheImages = CacheManager(
  Config(
    'tmk_images',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 400,
  ),
);

/// Remplace `NetworkImage` : `Image(image: imageReseau(url, headers: h))`.
ImageProvider imageReseau(String url, {Map<String, String>? headers}) =>
    CachedNetworkImageProvider(
      url,
      headers: headers,
      cacheKey: cleImage(url),
      cacheManager: cacheImages,
    );

/// Clé de cache d'une image : son URL sans la signature d'une URL présignée
/// (MinIO, `X-Amz-*`). Renouvelée à chaque lecture de la fiche, la signature
/// ferait de chaque affichage un nouveau téléchargement — et l'image serait
/// introuvable hors connexion.
///
/// Les autres paramètres restent dans la clé : `?v=3` désigne bien une autre
/// version de la photo.
String cleImage(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasQuery) return url;
  final params = Map.of(uri.queryParameters)
    ..removeWhere((k, _) => k.toLowerCase().startsWith('x-amz-'));
  final base = url.substring(0, url.indexOf('?'));
  return params.isEmpty ? base : '$base?${Uri(queryParameters: params).query}';
}
