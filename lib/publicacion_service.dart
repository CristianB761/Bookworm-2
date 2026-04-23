import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'servicio/notificacion_service.dart';

class Publicacion {
  final String id;
  final String usuarioId;
  final String usuarioNombre;
  final String? usuarioFoto;
  final String texto;
  final List<String> imagenes;
  final DateTime timestamp;
  final int likes;
  final int comentarios;
  final List<String> usuariosLike;

  Publicacion({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    this.usuarioFoto,
    required this.texto,
    this.imagenes = const [],
    required this.timestamp,
    this.likes = 0,
    this.comentarios = 0,
    this.usuariosLike = const [],
  });

  factory Publicacion.fromMap(Map<String, dynamic> map, String id) {
    return Publicacion(
      id: id,
      usuarioId: map['usuarioId'] ?? '',
      usuarioNombre: map['usuarioNombre'] ?? 'Usuario',
      usuarioFoto: map['usuarioFoto'],
      texto: map['texto'] ?? '',
      imagenes: List<String>.from(map['imagenes'] ?? []),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: map['likes'] ?? 0,
      comentarios: map['comentarios'] ?? 0,
      usuariosLike: List<String>.from(map['usuariosLike'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'usuarioNombre': usuarioNombre,
      'usuarioFoto': usuarioFoto,
      'texto': texto,
      'imagenes': imagenes,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'comentarios': comentarios,
      'usuariosLike': usuariosLike,
    };
  }
}

class PublicacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificacionService _notificacionService = NotificacionService();

  Stream<List<Publicacion>> getPublicacionesFeed(String usuarioId) {
    return _firestore
        .collection('usuarios')
        .doc(usuarioId)
        .collection('siguiendo')
        .snapshots()
        .asyncMap((siguiendoSnapshot) async {
      final siguiendoIds = siguiendoSnapshot.docs.map((d) => d.id).toList();
      siguiendoIds.add(usuarioId);

      if (siguiendoIds.isEmpty) return [];

      final publicaciones = await _firestore
          .collection('publicaciones')
          .where('usuarioId', whereIn: siguiendoIds)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return publicaciones.docs
          .map((doc) => Publicacion.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> crearPublicacion(String texto, List<String> imagenes) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    final usuarioDoc = await _firestore.collection('usuarios').doc(usuario.uid).get();
    final usuarioNombre = usuarioDoc.data()?['nombre'] ?? 'Usuario';
    final usuarioFoto = usuarioDoc.data()?['urlImagenPerfil'];

    final publicacionRef = await _firestore.collection('publicaciones').add({
      'usuarioId': usuario.uid,
      'usuarioNombre': usuarioNombre,
      'usuarioFoto': usuarioFoto,
      'texto': texto,
      'imagenes': imagenes,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'comentarios': 0,
      'usuariosLike': [],
    });

    await _notificarSeguidores(usuario.uid, usuarioNombre, publicacionRef.id, texto, usuarioFoto);
  }

  Future<void> _notificarSeguidores(
    String usuarioId,
    String usuarioNombre,
    String publicacionId,
    String texto,
    String? usuarioFoto,
  ) async {
    final seguidores = await _firestore
        .collection('usuarios')
        .doc(usuarioId)
        .collection('seguidores')
        .get();

    for (final seguidor in seguidores.docs) {
      await _notificacionService.enviarNotificacionNuevaPublicacion(
        seguidor.id,
        usuarioId,
        usuarioNombre,
        publicacionId,
        texto,
        usuarioFoto,
      );
    }

    final menciones = RegExp(r'@(\w+)').allMatches(texto);
    for (final mencion in menciones) {
      final nombreMencionado = mencion.group(1);
      if (nombreMencionado != null) {
        final usuarioMencionado = await _firestore
            .collection('usuarios')
            .where('nombre', isEqualTo: nombreMencionado)
            .limit(1)
            .get();
        
        if (usuarioMencionado.docs.isNotEmpty) {
          await _notificacionService.enviarNotificacionMencion(
            usuarioMencionado.docs.first.id,
            usuarioId,
            usuarioNombre,
            publicacionId,
            texto,
            usuarioFoto,
          );
        }
      }
    }
  }

  Future<void> darLike(String publicacionId, String propietarioId) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    final publicacionRef = _firestore.collection('publicaciones').doc(publicacionId);
    final doc = await publicacionRef.get();
    final data = doc.data();
    final usuariosLike = List<String>.from(data?['usuariosLike'] ?? []);

    if (usuariosLike.contains(usuario.uid)) {
      await publicacionRef.update({
        'likes': FieldValue.increment(-1),
        'usuariosLike': FieldValue.arrayRemove([usuario.uid]),
      });
    } else {
      await publicacionRef.update({
        'likes': FieldValue.increment(1),
        'usuariosLike': FieldValue.arrayUnion([usuario.uid]),
      });

      final usuarioDoc = await _firestore.collection('usuarios').doc(usuario.uid).get();
      await _notificacionService.enviarNotificacionMeGusta(
        propietarioId,
        usuario.uid,
        usuarioDoc.data()?['nombre'] ?? 'Usuario',
        publicacionId,
        usuarioDoc.data()?['urlImagenPerfil'],
      );
    }
  }

  Future<void> agregarComentario(
    String publicacionId,
    String propietarioId,
    String comentario,
  ) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    final usuarioDoc = await _firestore.collection('usuarios').doc(usuario.uid).get();
    final comentariosRef = _firestore
        .collection('publicaciones')
        .doc(publicacionId)
        .collection('comentarios');

    await comentariosRef.add({
      'usuarioId': usuario.uid,
      'usuarioNombre': usuarioDoc.data()?['nombre'] ?? 'Usuario',
      'usuarioFoto': usuarioDoc.data()?['urlImagenPerfil'],
      'comentario': comentario,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore
        .collection('publicaciones')
        .doc(publicacionId)
        .update({'comentarios': FieldValue.increment(1)});

    await _notificacionService.enviarNotificacionComentario(
      propietarioId,
      usuario.uid,
      usuarioDoc.data()?['nombre'] ?? 'Usuario',
      publicacionId,
      comentario,
      usuarioDoc.data()?['urlImagenPerfil'],
    );
  }
}