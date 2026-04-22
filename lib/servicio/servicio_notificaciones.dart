import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Notificacion {
  final String id;
  final String clubId;
  final String clubNombre;
  final String usuarioNombre;
  final String mensaje;
  final DateTime timestamp;
  final String usuarioId;

  Notificacion({
    required this.id,
    required this.clubId,
    required this.clubNombre,
    required this.usuarioNombre,
    required this.mensaje,
    required this.timestamp,
    required this.usuarioId,
  });
}

class ServicioNotificaciones extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Notificacion> _notificaciones = [];
  int _contadorNoLeidosTotal = 0;
  final Map<String, int> _contadoresPorClub = {};

  List<Notificacion> get notificaciones => _notificaciones;
  int get contadorNoLeidosTotal => _contadorNoLeidosTotal;
  Map<String, int> get contadoresPorClub => _contadoresPorClub;

  void inicializarEscuchadores() {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    // Escuchar todos los clubs del usuario
    _firestore
        .collection('usuarios')
        .doc(usuario.uid)
        .collection('mis_clubs')
        .snapshots()
        .listen((snapshot) {
      for (var clubDoc in snapshot.docs) {
        final clubId = clubDoc.id;
        final clubData = clubDoc.data();

        // Escuchar mensajes del club
        _escucharMensajesDelClub(clubId, clubData['nombre'] ?? clubId, usuario.uid);
      }
    });
  }

  void _escucharMensajesDelClub(String clubId, String clubNombre, String usuarioId) {
    _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('mensajes')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _procesarMensajesdel(snapshot, clubId, clubNombre, usuarioId);
    });
  }

  void _procesarMensajesdel(
    QuerySnapshot snapshot,
    String clubId,
    String clubNombre,
    String usuarioId,
  ) {
    int contadorNoLeidos = 0;
    final notificacionesDelClub = <Notificacion>[];

    for (var doc in snapshot.docs) {
      final datos = doc.data() as Map<String, dynamic>;
      final leidoPor = List<String>.from(datos['leidoPor'] ?? []);
      final esDelUsuarioActual = datos['usuarioId'] == usuarioId;

      // Solo mostrar notificaciones de otros usuarios
      if (!esDelUsuarioActual && !leidoPor.contains(usuarioId)) {
        contadorNoLeidos++;
        notificacionesDelClub.add(
          Notificacion(
            id: doc.id,
            clubId: clubId,
            clubNombre: clubNombre,
            usuarioNombre: datos['usuarioNombre'] ?? 'Usuario',
            mensaje: datos['texto'] ?? '',
            timestamp: (datos['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            usuarioId: datos['usuarioId'] ?? '',
          ),
        );
      }
    }

    // Actualizar contadores
    _contadoresPorClub[clubId] = contadorNoLeidos;
    _actualizarContadorTotal();

    // Actualizar notificaciones (mantener máximo 10 más recientes)
    _notificaciones = _notificaciones
        .where((n) => n.clubId != clubId)
        .toList();
    _notificaciones.addAll(notificacionesDelClub.take(5));
    _notificaciones.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    notifyListeners();
  }

  void _actualizarContadorTotal() {
    _contadorNoLeidosTotal = _contadoresPorClub.values.fold(0, (sum, count) => sum + count);
  }

  Future<void> marcarComoLeido(String clubId, String mensajeId) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    try {
      await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('mensajes')
          .doc(mensajeId)
          .update({
        'leidoPor': FieldValue.arrayUnion([usuario.uid]),
      });

      // Remover la notificación de la lista
      _notificaciones.removeWhere((n) => n.id == mensajeId && n.clubId == clubId);
      notifyListeners();
    } catch (e) {
    }
  }

  Future<void> marcarClubComoLeido(String clubId) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    try {
      final batch = _firestore.batch();

      final mensajes = await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('mensajes')
          .where('leidoPor', arrayContains: usuario.uid, isNotEqualTo: null)
          .get();

      // Actualizar todos los mensajes no leídos del club
      for (var doc in mensajes.docs) {
        batch.update(doc.reference, {
          'leidoPor': FieldValue.arrayUnion([usuario.uid]),
        });
      }

      await batch.commit();

      // Remover notificaciones del club
      _notificaciones.removeWhere((n) => n.clubId == clubId);
      _contadoresPorClub[clubId] = 0;
      _actualizarContadorTotal();
      notifyListeners();
    } catch (e) {
    }
  }

  void limpiarNotificacionesClub(String clubId) {
    _notificaciones.removeWhere((n) => n.clubId == clubId);
    _contadoresPorClub[clubId] = 0;
    _actualizarContadorTotal();
    notifyListeners();
  }
}
