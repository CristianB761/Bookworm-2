import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static const String carpetaLibros = 'libros_pdf';
  static const String carpetaAudios = 'audios_libros';
  static const String carpetaUsuarios = 'usuarios';

  static Future<String> subirPDF({
    required File archivo,
    required String nombreLibro,
    required String nombrePDF,
  }) async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        throw Exception('Usuario no autenticado en Firebase');
      }

      final nombreLibroLimpio = nombreLibro
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_áéíóúñÑ]'), '')
          .toLowerCase();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nombrePDFLimpio = nombrePDF
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_áéíóúñÑ]'), '')
          .toLowerCase();

      final rutaArchivo = '$carpetaUsuarios/${firebaseUser.uid}/$carpetaLibros/$nombreLibroLimpio/${timestamp}_$nombrePDFLimpio.pdf';

      print('Subiendo PDF a Firebase Storage: $rutaArchivo');

      final ref = _storage.ref().child(rutaArchivo);
      
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'tituloLibro': nombreLibro,
          'nombreOriginal': nombrePDF,
          'fechaSubida': DateTime.now().toIso8601String(),
          'usuarioId': firebaseUser.uid,
          'tipo': 'pdf',
        },
      );

      final taskSnapshot = await ref.putFile(archivo, metadata);
      final urlPublica = await taskSnapshot.ref.getDownloadURL();

      print('PDF subido exitosamente a Firebase Storage: $urlPublica');
      return urlPublica;
    } catch (e) {
      print('Error al subir PDF a Firebase Storage: $e');
      throw Exception('Error al subir PDF: $e');
    }
  }

  static Future<String> subirAudio({
    required File archivo,
    required String nombreLibro,
    required String nombreAudio,
  }) async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        throw Exception('Usuario no autenticado en Firebase');
      }

      final nombreLibroLimpio = nombreLibro
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_áéíóúñÑ]'), '')
          .toLowerCase();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nombreAudioLimpio = nombreAudio
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_áéíóúñÑ]'), '')
          .toLowerCase();

      final extension = archivo.path.split('.').last.toLowerCase();
      final rutaArchivo = '$carpetaUsuarios/${firebaseUser.uid}/$carpetaAudios/$nombreLibroLimpio/${timestamp}_$nombreAudioLimpio.$extension';

      print('Subiendo audio a Firebase Storage: $rutaArchivo');

      final ref = _storage.ref().child(rutaArchivo);
      
      String contentType = 'audio/mpeg';
      if (extension == 'mp3') contentType = 'audio/mpeg';
      else if (extension == 'm4a') contentType = 'audio/mp4';
      else if (extension == 'wav') contentType = 'audio/wav';
      else if (extension == 'ogg') contentType = 'audio/ogg';
      else if (extension == 'aac') contentType = 'audio/aac';

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'tituloLibro': nombreLibro,
          'nombreOriginal': nombreAudio,
          'fechaSubida': DateTime.now().toIso8601String(),
          'usuarioId': firebaseUser.uid,
          'tipo': 'audio',
          'duracion': '0',
        },
      );

      final taskSnapshot = await ref.putFile(archivo, metadata);
      final urlPublica = await taskSnapshot.ref.getDownloadURL();

      print('Audio subido exitosamente a Firebase Storage: $urlPublica');
      return urlPublica;
    } catch (e) {
      print('Error al subir audio a Firebase Storage: $e');
      throw Exception('Error al subir audio: $e');
    }
  }

  static Future<void> eliminarArchivo(String urlArchivo) async {
    try {
      if (urlArchivo.isEmpty) return;
      
      final ref = _storage.refFromURL(urlArchivo);
      await ref.delete();
      print('Archivo eliminado de Firebase Storage');
    } catch (e) {
      print('Error al eliminar archivo: $e');
    }
  }

  static Future<String?> obtenerURLArchivo(String ruta) async {
    try {
      final ref = _storage.ref().child(ruta);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error obteniendo URL del archivo: $e');
      return null;
    }
  }

  static Future<List<Map<String, String>>> listarArchivosUsuario(String tipo) async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) return [];

      final carpeta = tipo == 'audio' ? carpetaAudios : carpetaLibros;
      final ref = _storage.ref().child('$carpetaUsuarios/${firebaseUser.uid}/$carpeta');
      final result = await ref.listAll();
      
      final List<Map<String, String>> archivos = [];
      for (final item in result.items) {
        final url = await item.getDownloadURL();
        archivos.add({
          'ruta': item.fullPath,
          'url': url,
          'nombre': item.name,
        });
      }
      
      return archivos;
    } catch (e) {
      print('Error listando archivos: $e');
      return [];
    }
  }
}