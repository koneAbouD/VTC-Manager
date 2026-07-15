import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/secure_storage.dart';

/// Providers transverses partagés par toutes les features.
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return const SecureStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(secureStorageProvider));
});

/// Mapping centralisé d'une [Failure] vers un message présentable, réutilisé
/// par les providers de présentation.
String failureMessage(Object failure) {
  // Import différé pour éviter un cycle ; on lit juste le message.
  final dynamic f = failure;
  try {
    return (f.message as String?) ?? 'Une erreur est survenue.';
  } catch (_) {
    return 'Une erreur est survenue.';
  }
}
