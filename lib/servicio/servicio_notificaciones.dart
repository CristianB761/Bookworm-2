import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum TipoNotificacion {
  mensajeClub,
  nuevoSeguidor,
  nuevaPublicacion,
  comentarioPublicacion,
  meGustaPublicacion,
  mencion,
  recordatorioLectura,
}

extension TipoNotificacionExtension on TipoNotificacion {
  String get value {
    switch (this) {
      case TipoNotificacion.mensajeClub:
        return 'mensajeClub';
      case TipoNotificacion.nuevoSeguidor:
        return 'nuevoSeguidor';
      case TipoNotificacion.nuevaPublicacion:
        return 'nuevaPublicacion';
      case TipoNotificacion.comentarioPublicacion:
        return 'comentarioPublicacion';
      case TipoNotificacion.meGustaPublicacion:
        return 'meGustaPublicacion';
      case TipoNotificacion.mencion:
        return 'mencion';
      case TipoNotificacion.recordatorioLectura:
        return 'recordatorioLectura';
    }
  }

  static TipoNotificacion fromString(String value) {
    switch (value) {
      case 'mensajeClub':
        return TipoNotificacion.mensajeClub;
      case 'nuevoSeguidor':
        return TipoNotificacion.nuevoSeguidor;
      case 'nuevaPublicacion':
        return TipoNotificacion.nuevaPublicacion;
      case 'comentarioPublicacion':
        return TipoNotificacion.comentarioPublicacion;
      case 'meGustaPublicacion':
        return TipoNotificacion.meGustaPublicacion;
      case 'mencion':
        return TipoNotificacion.mencion;
      case 'recordatorioLectura':
        return TipoNotificacion.recordatorioLectura;
      default:
        return TipoNotificacion.mensajeClub;
    }
  }
}

class Notificacion {
  final String id;
  final TipoNotificacion tipo;
  final String? clubId;
  final String? clubNombre;
  final String? publicacionId;
  final String? publicacionTexto;
  final String? usuarioOrigenId;
  final String usuarioOrigenNombre;
  final String? usuarioOrigenFoto;
  final String mensaje;
  final DateTime timestamp;
  final bool leido;

  Notificacion({
    required this.id,
    required this.tipo,
    this.clubId,
    this.clubNombre,
    this.publicacionId,
    this.publicacionTexto,
    this.usuarioOrigenId,
    required this.usuarioOrigenNombre,
    this.usuarioOrigenFoto,
    required this.mensaje,
    required this.timestamp,
    this.leido = false,
  });

  factory Notificacion.fromMap(Map<String, dynamic> map, String id) {
    return Notificacion(
      id: id,
      tipo: TipoNotificacionExtension.fromString(map['tipo'] ?? 'mensajeClub'),
      clubId: map['clubId'],
      clubNombre: map['clubNombre'],
      publicacionId: map['publicacionId'],
      publicacionTexto: map['publicacionTexto'],
      usuarioOrigenId: map['usuarioOrigenId'],
      usuarioOrigenNombre: map['usuarioOrigenNombre'] ?? 'Usuario',
      usuarioOrigenFoto: map['usuarioOrigenFoto'],
      mensaje: map['mensaje'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      leido: map['leido'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo.value,
      'clubId': clubId,
      'clubNombre': clubNombre,
      'publicacionId': publicacionId,
      'publicacionTexto': publicacionTexto,
      'usuarioOrigenId': usuarioOrigenId,
      'usuarioOrigenNombre': usuarioOrigenNombre,
      'usuarioOrigenFoto': usuarioOrigenFoto,
      'mensaje': mensaje,
      'timestamp': Timestamp.fromDate(timestamp),
      'leido': leido,
    };
  }
}

class ServicioNotificaciones extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Notificacion> _notificaciones = [];
  int _contadorNoLeidos = 0;

  List<Notificacion> get notificaciones => _notificaciones;
  int get contadorNoLeidosTotal => _contadorNoLeidos;

  void inicializarEscuchadores() {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    _firestore
        .collection('notificaciones')
        .where('usuarioId', isEqualTo: usuario.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _notificaciones = snapshot.docs
          .map((doc) => Notificacion.fromMap(doc.data(), doc.id))
          .toList();
      _actualizarContador();
      notifyListeners();
    });
  }

  void _actualizarContador() {
    _contadorNoLeidos = _notificaciones.where((n) => !n.leido).length;
  }

  Future<void> marcarComoLeido(String notificacionId) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    await _firestore
        .collection('notificaciones')
        .doc(notificacionId)
        .update({'leido': true});

    final index = _notificaciones.indexWhere((n) => n.id == notificacionId);
    if (index != -1) {
      _notificaciones[index] = Notificacion(
        id: _notificaciones[index].id,
        tipo: _notificaciones[index].tipo,
        clubId: _notificaciones[index].clubId,
        clubNombre: _notificaciones[index].clubNombre,
        publicacionId: _notificaciones[index].publicacionId,
        publicacionTexto: _notificaciones[index].publicacionTexto,
        usuarioOrigenId: _notificaciones[index].usuarioOrigenId,
        usuarioOrigenNombre: _notificaciones[index].usuarioOrigenNombre,
        usuarioOrigenFoto: _notificaciones[index].usuarioOrigenFoto,
        mensaje: _notificaciones[index].mensaje,
        timestamp: _notificaciones[index].timestamp,
        leido: true,
      );
    }
    _actualizarContador();
    notifyListeners();
  }

  Future<void> marcarTodasComoLeidas() async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    final batch = _firestore.batch();
    for (final notif in _notificaciones.where((n) => !n.leido)) {
      batch.update(
        _firestore.collection('notificaciones').doc(notif.id),
        {'leido': true},
      );
    }
    await batch.commit();

    for (var i = 0; i < _notificaciones.length; i++) {
      _notificaciones[i] = Notificacion(
        id: _notificaciones[i].id,
        tipo: _notificaciones[i].tipo,
        clubId: _notificaciones[i].clubId,
        clubNombre: _notificaciones[i].clubNombre,
        publicacionId: _notificaciones[i].publicacionId,
        publicacionTexto: _notificaciones[i].publicacionTexto,
        usuarioOrigenId: _notificaciones[i].usuarioOrigenId,
        usuarioOrigenNombre: _notificaciones[i].usuarioOrigenNombre,
        usuarioOrigenFoto: _notificaciones[i].usuarioOrigenFoto,
        mensaje: _notificaciones[i].mensaje,
        timestamp: _notificaciones[i].timestamp,
        leido: true,
      );
    }
    _actualizarContador();
    notifyListeners();
  }

  Future<void> eliminarNotificacion(String notificacionId) async {
    await _firestore.collection('notificaciones').doc(notificacionId).delete();
    _notificaciones.removeWhere((n) => n.id == notificacionId);
    _actualizarContador();
    notifyListeners();
  }

  Future<void> eliminarTodasNotificaciones() async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    final batch = _firestore.batch();
    for (final notif in _notificaciones) {
      batch.delete(_firestore.collection('notificaciones').doc(notif.id));
    }
    await batch.commit();
    _notificaciones.clear();
    _actualizarContador();
    notifyListeners();
  }
}