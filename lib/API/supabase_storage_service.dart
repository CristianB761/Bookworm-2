import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SupabaseStorageService {
  static final supabase.SupabaseClient supabaseClient = supabase.Supabase.instance.client;
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static const String bucketName = 'bookworm-pdfs';

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

      final supabaseUser = supabaseClient.auth.currentUser;
      if (supabaseUser == null) {
        print('Sin sesión en Supabase, usando Firebase Storage');
        return await _subirAFirebaseStorage(archivo, nombreLibro, nombrePDF, firebaseUser);
      }

      return await _subirASupabaseStorage(archivo, nombreLibro, nombrePDF, supabaseUser);
    } catch (e) {
      print('Error al subir PDF: $e');
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        return await _subirAFirebaseStorage(archivo, nombreLibro, nombrePDF, firebaseUser);
      }
      throw Exception('Error al subir PDF: $e');
    }
  }

  static Future<String> _subirASupabaseStorage(
    File archivo,
    String nombreLibro,
    String nombrePDF,
    supabase.User supabaseUser,
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

    await supabaseClient.storage.from(bucketName).uploadBinary(
      rutaArchivo,
      bytes,
      fileOptions: const supabase.FileOptions(
        contentType: 'application/pdf',
        cacheControl: '3600',
      ),
    );

    final urlPublica = supabaseClient.storage.from(bucketName).getPublicUrl(rutaArchivo);
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