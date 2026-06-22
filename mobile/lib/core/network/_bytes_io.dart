import 'dart:typed_data';

/// Stub natif — jamais appelé sur iOS/Android/desktop.
/// L'implémentation native de getBytes utilise directement le streaming http.
Future<({int statusCode, Uint8List bytes})> fetchBytesNative(
  Uri uri,
  Map<String, String> headers,
  Duration timeout,
) {
  throw UnsupportedError('fetchBytesNative ne doit pas être appelé sur natif');
}
