import 'dart:typed_data';

/// Archivo elegido por el usuario: nombre + contenido en bytes.
class PickedFileData {
  final String name;
  final Uint8List bytes;
  const PickedFileData(this.name, this.bytes);
}

/// Implementación de reserva para plataformas que no son web.
Future<PickedFileData?> pickFile(List<String> extensions) async {
  throw UnsupportedError(
    'La selección de archivos solo está disponible en la versión web.',
  );
}

/// Descarga bytes como archivo (solo web; aquí es un no-op).
void downloadBytes(String name, Uint8List bytes,
    {String mime = 'application/octet-stream'}) {}

/// Bloqueo de orientación (solo web; aquí es un no-op).
void setLandscape(bool on) {}

/// Pantalla completa horizontal (solo web; aquí es un no-op).
void enterFullscreenLandscape() {}
