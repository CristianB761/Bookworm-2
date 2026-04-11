import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupabaseStorageService {
  static final supabase = Supabase.instance.client;
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static const String bucketName = 'bookworm-pdfs';

  /// Sincroniza la autenticación de Firebase con Supabase
  static Future<void> _sincronizarAuth() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw Exception('Usuario no autenticado en Firebase');
    }

    // Verificar si ya hay sesión en Supabase
    final supabaseUser = supabase.auth.currentUser;
    
    if (supabaseUser == null) {
      // Si no hay sesión en Supabase, iniciar sesión con email/contraseña
      // Nota: Necesitas tener el mismo email/contraseña en ambos sistemas
      if (firebaseUser.email != null && firebaseUser.email!.isNotEmpty) {
        // Esta es la parte complicada - necesitas la contraseña
        print('Necesitas implementar autenticación en Supabase');
        print('El email es: ${firebaseUser.email}');
      }
    }
  }

  static Future<String> subirPDF({
    required File archivo,
    required String nombreLibro,
    required String nombrePDF,
  }) async {
    try {
      // Verificar autenticación en Firebase
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        throw Exception('Usuario no autenticado en Firebase');
      }

      // Intentar sincronizar con Supabase
      await _sincronizarAuth();

      final supabaseUser = supabase.auth.currentUser;
      if (supabaseUser == null) {
        // Si no podemos autenticar en Supabase, usar Firebase Storage como fallback
        print('Usando Firebase Storage como fallback');
        return await _subirAFirebaseStorage(archivo, nombreLibro, nombrePDF, firebaseUser);
      }

      // Subir a Supabase Storage
      return await _subirASupabaseStorage(archivo, nombreLibro, nombrePDF, supabaseUser);
    } catch (e) {
      print('Error al subir PDF: $e');
      throw Exception('Error al subir PDF: $e');
    }
  }

  static Future<String> _subirASupabaseStorage(
    File archivo,
    String nombreLibro,
    String nombrePDF,
    User supabaseUser,
  ) async {
    final nombreLibroLimpio = nombreLibro
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_áéíóúñÑ]'), '')
        .toLowerCase();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nombrePDFLimpio = nombrePDF
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_áéíóúñÑ]'), '')
        .toLowerCase();

    final rutaArchivo = 'usuarios/${supabaseUser.id}/libros/$nombreLibroLimpio/${timestamp}_$nombrePDFLimpio.pdf';

    print('Subiendo PDF a Supabase Storage: $rutaArchivo');

    final bytes = await archivo.readAsBytes();

    await supabase.storage.from(bucketName).uploadBinary(
          rutaArchivo,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            cacheControl: '3600',
          ),
        );

    final urlPublica = supabase.storage.from(bucketName).getPublicUrl(rutaArchivo);
    
    print('PDF subido exitosamente a Supabase: $urlPublica');
    return urlPublica;
  }

  static Future<String> _subirAFirebaseStorage(
    File archivo,
    String nombreLibro,
    String nombrePDF,
    User firebaseUser,
  ) async {
    final storage = FirebaseStorage.instance;
    
    final nombreLibroLimpio = nombreLibro
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_áéíóúñÑ]'), '')
        .toLowerCase();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nombrePDFLimpio = nombrePDF
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_áéíóúñÑ]'), '')
        .toLowerCase();

    final rutaArchivo = 'usuarios/${firebaseUser.uid}/libros/$nombreLibroLimpio/${timestamp}_$nombrePDFLimpio.pdf';

    print('Subiendo PDF a Firebase Storage: $rutaArchivo');

    final ref = storage.ref().child(rutaArchivo);
    final taskSnapshot = await ref.putFile(archivo);
    final urlPublica = await taskSnapshot.ref.getDownloadURL();

    print('PDF subido exitosamente a Firebase Storage: $urlPublica');
    return urlPublica;
  }
}