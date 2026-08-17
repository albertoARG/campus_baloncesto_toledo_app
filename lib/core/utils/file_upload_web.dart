import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Archivo elegido por el usuario: nombre + contenido en bytes.
class PickedFileData {
  final String name;
  final Uint8List bytes;
  const PickedFileData(this.name, this.bytes);
}

/// Abre el selector de archivos nativo del navegador y devuelve el archivo
/// elegido (o null si se cancela). [extensions] son extensiones sin punto,
/// p. ej. ['xlsx'].
Future<PickedFileData?> pickFile(List<String> extensions) async {
  final input = html.FileUploadInputElement()
    ..accept = extensions.map((e) => '.$e').join(',');

  // Preparamos la escucha antes de abrir el diálogo.
  final changeFuture = input.onChange.first;
  input.click();
  await changeFuture;

  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final file = files.first;

  final reader = html.FileReader();
  final loadFuture = reader.onLoad.first;
  reader.readAsArrayBuffer(file);
  await loadFuture;

  final result = reader.result;
  final Uint8List bytes;
  if (result is Uint8List) {
    bytes = result;
  } else if (result is ByteBuffer) {
    bytes = result.asUint8List();
  } else {
    return null;
  }
  return PickedFileData(file.name, bytes);
}

/// Intenta bloquear la orientación a horizontal (o liberarla). Best-effort:
/// en muchos navegadores móviles solo funciona en PWA instalada / pantalla
/// completa; si no se permite, se ignora sin error.
void setLandscape(bool on) {
  try {
    final orientation = html.window.screen?.orientation;
    if (orientation == null) return;
    if (on) {
      orientation.lock('landscape').catchError((_) {});
    } else {
      orientation.unlock();
    }
  } catch (_) {}
}

/// Entra en pantalla completa y bloquea horizontal. Debe llamarse desde un
/// gesto del usuario (un botón) para que el navegador lo permita.
void enterFullscreenLandscape() {
  try {
    html.document.documentElement?.requestFullscreen();
    html.window.screen?.orientation?.lock('landscape').catchError((_) {});
  } catch (_) {}
}

/// Descarga [bytes] como un archivo llamado [name] en el navegador.
void downloadBytes(String name, Uint8List bytes,
    {String mime = 'application/octet-stream'}) {
  final blob = html.Blob(<Object>[bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = name;
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
