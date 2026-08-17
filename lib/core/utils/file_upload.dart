// Selector de archivos que usa el input nativo del navegador en web.
// La implementación real se elige por importación condicional.
export 'file_upload_stub.dart' if (dart.library.html) 'file_upload_web.dart';
