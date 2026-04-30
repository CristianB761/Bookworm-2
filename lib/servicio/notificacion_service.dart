import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Enviar notificación de nuevo seguidor
  Future<void> enviarNotificacionNuevoSeguidor(String usuarioIdObjetivo, String seguidorId) async {
    final usuarioActual = _auth.currentUser;
    if (usuarioActual == null || usuarioActual.uid != seguidorId) return;

    final seguidorDoc = await _firestore.collection('usuarios').doc(seguidorId).get();
    final seguidorNombre = seguidorDoc.data()?['nombre'] ?? 'Usuario';
    final seguidorFoto = seguidorDoc.data()?['urlImagenPerfil'];

    await _firestore.collection('notificaciones').add({
      'usuarioId': usuarioIdObjetivo,
      'tipo': 'nuevoSeguidor',
      'usuarioOrigenId': seguidorId,
      'usuarioOrigenNombre': seguidorNombre,
      'usuarioOrigenFoto': seguidorFoto,
      'mensaje': '$seguidorNombre ha comenzado a seguirte',
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
    });
  }

  // Enviar notificación de nueva publicación
  Future<void> enviarNotificacionNuevaPublicacion(
    String usuarioIdDestino,
    String autorId,
    String autorNombre,
    String publicacionId,
    String publicacionTexto,
    [String? autorFoto]
  ) async {
    if (usuarioIdDestino == autorId) return;

    await _firestore.collection('notificaciones').add({
      'usuarioId': usuarioIdDestino,
      'tipo': 'nuevaPublicacion',
      'publicacionId': publicacionId,
      'publicacionTexto': publicacionTexto.length > 50 ? publicacionTexto.substring(0, 50) : publicacionTexto,
      'usuarioOrigenId': autorId,
      'usuarioOrigenNombre': autorNombre,
      'usuarioOrigenFoto': autorFoto,
      'mensaje': '$autorNombre ha publicado una nueva lectura',
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
    });
  }

  // Enviar notificación de mención
  Future<void> enviarNotificacionMencion(
    String usuarioIdMencionado,
    String autorId,
    String autorNombre,
    String publicacionId,
    String publicacionTexto,
    [String? autorFoto]
  ) async {
    await _firestore.collection('notificaciones').add({
      'usuarioId': usuarioIdMencionado,
      'tipo': 'mencion',
      'publicacionId': publicacionId,
      'publicacionTexto': publicacionTexto.length > 50 ? publicacionTexto.substring(0, 50) : publicacionTexto,
      'usuarioOrigenId': autorId,
      'usuarioOrigenNombre': autorNombre,
      'usuarioOrigenFoto': autorFoto,
      'mensaje': '$autorNombre te ha mencionado en una publicación',
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
    });
  }

  // Enviar notificación de comentario
  Future<void> enviarNotificacionComentario(
    String propietarioPublicacionId,
    String comentaristaId,
    String comentaristaNombre,
    String publicacionId,
    String comentarioTexto,
    [String? comentaristaFoto]
  ) async {
    if (propietarioPublicacionId == comentaristaId) return;

    await _firestore.collection('notificaciones').add({
      'usuarioId': propietarioPublicacionId,
      'tipo': 'comentarioPublicacion',
      'publicacionId': publicacionId,
      'publicacionTexto': comentarioTexto.length > 50 ? comentarioTexto.substring(0, 50) : comentarioTexto,
      'usuarioOrigenId': comentaristaId,
      'usuarioOrigenNombre': comentaristaNombre,
      'usuarioOrigenFoto': comentaristaFoto,
      'mensaje': '$comentaristaNombre ha comentado tu publicación',
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
    });
  }

  // Enviar notificación de "me gusta"
  Future<void> enviarNotificacionMeGusta(
    String propietarioPublicacionId,
    String usuarioIdQueDaLike,
    String usuarioNombre,
    String publicacionId,
    [String? usuarioFoto]
  ) async {
    if (propietarioPublicacionId == usuarioIdQueDaLike) return;

    await _firestore.collection('notificaciones').add({
      'usuarioId': propietarioPublicacionId,
      'tipo': 'meGustaPublicacion',
      'publicacionId': publicacionId,
      'usuarioOrigenId': usuarioIdQueDaLike,
      'usuarioOrigenNombre': usuarioNombre,
      'usuarioOrigenFoto': usuarioFoto,
      'mensaje': '$usuarioNombre ha dado "me gusta" a tu publicación',
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
    });
  }

  // Enviar notificación de recordatorio de lectura
  Future<void> enviarRecordatorioLectura(String usuarioId, String libroTitulo) async {
    await _firestore.collection('notificaciones').add({
      'usuarioId': usuarioId,
      'tipo': 'recordatorioLectura',
      'mensaje': '¡No olvides continuar la lectura de "$libroTitulo"! 📚',
      'timestamp': FieldValue.serverTimestamp(),
      'leido': false,
    });
  }
}