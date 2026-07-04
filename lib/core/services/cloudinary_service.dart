import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  final String cloudName = 'dui2duhbv';
  final String uploadPreset = 'campus_preset';

  /// Devuelve la URL de Cloudinary con transformaciones de entrega
  /// (f_auto,q_auto,w_...) para que el CDN sirva una versión ligera y
  /// cacheada en lugar del archivo original. Las URLs que no son de
  /// Cloudinary se devuelven sin tocar.
  static String optimizedUrl(String url, {int width = 1200}) {
    const marker = '/upload/';
    if (!url.contains('res.cloudinary.com') || !url.contains(marker)) {
      return url;
    }
    final idx = url.indexOf(marker);
    final prefix = url.substring(0, idx + marker.length);
    final rest = url.substring(idx + marker.length);
    // Si la URL ya lleva transformaciones, no añadir otras encima.
    if (rest.startsWith('f_auto') || rest.startsWith('q_auto') || rest.startsWith('w_')) {
      return url;
    }
    return '${prefix}f_auto,q_auto,c_limit,w_$width/$rest';
  }

  Future<String?> uploadImage(XFile imageFile) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
    
    final bytes = await imageFile.readAsBytes();
    
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name,
      ));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData);
      return jsonResponse['secure_url'];
    } else {
      print('Failed to upload image. Status code: ${response.statusCode}');
      return null;
    }
  }
}
