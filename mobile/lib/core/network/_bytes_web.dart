// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Télécharge un fichier binaire via XHR avec responseType='arraybuffer'.
/// Cela évite le bug Flutter Web "detached ArrayBuffer" causé par le
/// streaming XHR de BrowserClient (ByteConversionSink.add).
Future<({int statusCode, Uint8List bytes})> fetchBytesNative(
  Uri uri,
  Map<String, String> headers,
  Duration timeout,
) async {
  final completer = Completer<({int statusCode, Uint8List bytes})>();

  final xhr = html.HttpRequest();
  xhr.open('GET', uri.toString(), async: true);
  xhr.responseType = 'arraybuffer';
  xhr.timeout = timeout.inMilliseconds;
  headers.forEach(xhr.setRequestHeader);

  xhr.onLoad.listen((_) {
    if (completer.isCompleted) return;
    final status = xhr.status ?? 0;
    // response est un ByteBuffer (dart:typed_data) quand responseType='arraybuffer'
    final buffer = xhr.response as ByteBuffer;
    completer.complete((statusCode: status, bytes: buffer.asUint8List()));
  });

  xhr.onError.listen((_) {
    if (completer.isCompleted) return;
    completer.completeError(Exception('Erreur réseau XHR'));
  });

  xhr.onTimeout.listen((_) {
    if (completer.isCompleted) return;
    completer.completeError(
      TimeoutException('Le serveur ne répond pas (timeout).', timeout),
    );
  });

  xhr.send();
  return completer.future;
}
