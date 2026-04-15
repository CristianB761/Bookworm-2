import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static const String carpetaLibros = 'libros_pdf';
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

      // Limpiar nombres para la ruta
      final nombreLibroLimpio = nombreLibro
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_áéíóúñÑ]'), '')
          .toLowerCase();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nombrePDFLimpio = nombrePDF
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_áéíóúñÑ]'), '')
          .toLowerCase();

      // Ruta en Firebase Storage: usuarios/{uid}/libros_pdf/{nombre_libro}/{timestamp}_nombre.pdf
      final rutaArchivo = '$carpetaUsuarios/${firebaseUser.uid}/$carpetaLibros/$nombreLibroLimpio/${timestamp}_$nombrePDFLimpio.pdf';

      print('Subiendo PDF a Firebase Storage: $rutaArchivo');

      final ref = _storage.ref().child(rutaArchivo);
      
      // Subir archivo con metadatos
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'tituloLibro': nombreLibro,
          'nombreOriginal': nombrePDF,
          'fechaSubida': DateTime.now().toIso8601String(),
          'usuarioId': firebaseUser.uid,
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

  static Future<void> eliminarPDF(String pdfUrl) async {
    try {
      if (pdfUrl.isEmpty) return;
      
      // Obtener referencia desde la URL
      final ref = _storage.refFromURL(pdfUrl);
      await ref.delete();
      print('PDF eliminado de Firebase Storage');
    } catch (e) {
      print('Error al eliminar PDF: $e');
      // No lanzar excepción para no interrumpir la experiencia
    }
  }

  static Future<String?> obtenerURLPDF(String ruta) async {
    try {
      final ref = _storage.ref().child(ruta);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error obteniendo URL del PDF: $e');
      return null;
    }
  }

  static Future<List<Map<String, String>>> listarPDFsUsuario() async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) return [];

      final ref = _storage.ref().child('$carpetaUsuarios/${firebaseUser.uid}/$carpetaLibros');
      final result = await ref.listAll();
      
      final List<Map<String, String>> pdfs = [];
      for (final item in result.items) {
        final url = await item.getDownloadURL();
        pdfs.add({
          'ruta': item.fullPath,
          'url': url,
          'nombre': item.name,
        });
      }
      
      return pdfs;
    } catch (e) {
      print('Error listando PDFs: $e');
      return [];
    }
  }
}