import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelos/datos_usuario.dart';
import '../modelos/progreso_lectura.dart';

class ServicioFirestore {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> crearUsuario(DatosUsuario datosUsuario) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(datosUsuario.uid)
          .set(datosUsuario.toMap());
      print('Usuario creado en Firestore: ${datosUsuario.uid}');
    } catch (e) {
      print('Error al crear usuario: $e');
      throw Exception('Error al crear usuario: $e');
    }
  }

  Future<DatosUsuario?> obtenerDatosUsuario(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        print('Usuario obtenido de Firestore: ${doc.data()}');
        return DatosUsuario.fromMap(doc.data()!);
      }
      print('⚠️ Usuario no encontrado en Firestore');
      return null;
    } catch (e) {
      print('Error al obtener usuario: $e');
      throw Exception('Error al obtener usuario: $e');
    }
  }

  Future<void> actualizarEstadisticasUsuario(String uid, Map<String, dynamic> nuevasEstadisticas) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(uid)
          .update({'estadisticas': nuevasEstadisticas});
      print('Estadísticas actualizadas');
    } catch (e) {
      print('Error al actualizar stats: $e');
      throw Exception('Error al actualizar stats: $e');
    }
  }

  Future<void> actualizarDatosUsuario(String uid, Map<String, dynamic> nuevosDatos) async {
    try {
      await _firestore
          .collection('usuarios')
          .doc(uid)
          .update(nuevosDatos);
      print('Datos del usuario actualizados');
    } catch (e) {
      print('Error al actualizar datos del usuario: $e');
      throw Exception('Error al actualizar datos del usuario: $e');
    }
  }

  Future<void> guardarProgresoLectura(ProgresoLectura progreso) async {
    try {
      await _firestore
          .collection('progreso_lectura')
          .doc(progreso.id)
          .set(progreso.toMap());
      print('Progreso guardado: ${progreso.tituloLibro}');
    } catch (e) {
      print('Error al guardar progreso: $e');
      throw Exception('Error al guardar progreso: $e');
    }
  }

  Stream<List<ProgresoLectura>> obtenerProgresoLecturaUsuario(String usuarioId) {
    return _firestore
        .collection('progreso_lectura')
        .where('usuarioId', isEqualTo: usuarioId)
        .orderBy('fechaInicio', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProgresoLectura.fromMap(doc.data()))
            .toList());
  }

  Future<List<ProgresoLectura>> obtenerLibrosCompletados(String usuarioId) async {
    try {
      final snapshot = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuarioId)
          .where('estado', isEqualTo: 'completado')
          .get();
     
      return snapshot.docs
          .map((doc) => ProgresoLectura.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error al obtener libros completados: $e');
      throw Exception('Error al obtener libros completados: $e');
    }
  }

  Future<void> actualizarEstadoLectura({
    required String progresoId,
    required String estado,
    int? paginaActual,
    DateTime? fechaCompletado,
  }) async {
    try {
      final datosActualizacion = <String, dynamic>{'estado': estado};
      
      if (paginaActual != null) {
        datosActualizacion['paginaActual'] = paginaActual;
      }
      
      if (fechaCompletado != null) {
        datosActualizacion['fechaCompletado'] = Timestamp.fromDate(fechaCompletado);
      }

      await _firestore
          .collection('progreso_lectura')
          .doc(progresoId)
          .update(datosActualizacion);
      print('Estado de lectura actualizado: $estado');
    } catch (e) {
      print('Error al actualizar estado: $e');
      throw Exception('Error al actualizar estado: $e');
    }
  }

  Future<ProgresoLectura?> obtenerProgresoLibro(String usuarioId, String libroId) async {
    try {
      final snapshot = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuarioId)
          .where('libroId', isEqualTo: libroId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ProgresoLectura.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error al verificar progreso: $e');
      return null;
    }
  }

  Future<List<ProgresoLectura>> obtenerLibrosEnProgreso(String usuarioId) async {
    try {
      final snapshot = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuarioId)
          .where('estado', isEqualTo: 'leyendo')
          .get();

      return snapshot.docs
          .map((doc) => ProgresoLectura.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error al obtener libros en progreso: $e');
      return [];
    }
  }

  Future<void> sincronizarDatosCompletos() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      final batch = _firestore.batch();

      final usuarioDoc = await _firestore.collection('usuarios').doc(usuario.uid).get();
      
      if (usuarioDoc.exists) {
        print('Datos de usuario sincronizados');
      }

      final progresosSnapshot = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuario.uid)
          .where('needsSync', isEqualTo: true)
          .get();

      for (final doc in progresosSnapshot.docs) {
        batch.update(doc.reference, {'needsSync': false});
      }

      await batch.commit();
      print('Sincronización completa exitosa');

    } catch (e) {
      print('Error en sincronización completa: $e');
      throw Exception('Error sincronizando datos: $e');
    }
  }

  Future<Map<String, dynamic>> obtenerResumenDiario() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return {};

      final hoy = DateTime.now();
      final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);
      final finDia = inicioDia.add(const Duration(days: 1));

      final progresosHoy = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuario.uid)
          .where('fechaInicio', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
          .where('fechaInicio', isLessThan: Timestamp.fromDate(finDia))
          .get();

      final completadosHoy = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuario.uid)
          .where('estado', isEqualTo: 'completado')
          .where('fechaCompletado', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
          .where('fechaCompletado', isLessThan: Timestamp.fromDate(finDia))
          .get();

      return {
        'progresosHoy': progresosHoy.docs.length,
        'completadosHoy': completadosHoy.docs.length,
        'paginasLeidasHoy': progresosHoy.docs.fold(0, (sum, doc) {
          final data = doc.data();
          final paginaActual = data['paginaActual'];
          
          if (paginaActual == null) {
            return sum;
          } else if (paginaActual is int) {
            return sum + paginaActual;
          } else if (paginaActual is double) {
            return sum + paginaActual.toInt();
          } else if (paginaActual is String) {
            return sum + (int.tryParse(paginaActual) ?? 0);
          } else {
            return sum;
          }
        }),
        'metaDiariaAlcanzada': completadosHoy.docs.isNotEmpty,
      };
    } catch (e) {
      print('Error obteniendo resumen diario: $e');
      return {};
    }
  }

  Future<void> crearClub(Map<String, dynamic> datosClub) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      final clubId = _firestore.collection('clubs').doc().id;
      
      await _firestore.collection('clubs').doc(clubId).set({
        'id': clubId,
        'nombre': datosClub['nombre'],
        'descripcion': datosClub['descripcion'] ?? '',
        'genero': datosClub['genero'],
        'creadorId': usuario.uid,
        'creadorNombre': usuario.displayName ?? 'Usuario',
        'fechaCreacion': FieldValue.serverTimestamp(),
        'miembros': [usuario.uid],
        'miembrosCount': 1,
        'libroActual': datosClub['libroActual'] ?? null,
        'estado': 'activo',
        'ultimaActividad': FieldValue.serverTimestamp(),
      });

      await _firestore
        .collection('usuarios')
        .doc(usuario.uid)
        .collection('mis_clubs')
        .doc(clubId)
        .set({
      'clubId': clubId,
      'nombre': datosClub['nombre'],
      'genero': datosClub['genero'],
      'fechaUnion': FieldValue.serverTimestamp(),
      'rol': 'creador',
      'notificaciones': true,
      });

      print('Club creado exitosamente: $clubId');
    } catch (e) {
      print('Error creando club: $e');
      throw Exception('Error creando club: $e');
    }
  }

  Future<void> actualizarInfoClub({
    required String clubId,
    required String nombre,
    required String descripcion,
    required String genero,
  }) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'nombre': nombre,
        'descripcion': descripcion,
        'genero': genero,
        'ultimaActividad': FieldValue.serverTimestamp(),
      });

      final clubSnapshot = await _firestore.collection('clubs').doc(clubId).get();
      final miembros = clubSnapshot.data()?['miembros'] as List<dynamic>? ?? [];

      for (final miembroId in miembros) {
        await _firestore
            .collection('usuarios')
            .doc(miembroId.toString())
            .collection('mis_clubs')
            .doc(clubId)
            .update({
          'nombre': nombre,
          'genero': genero,
        });
      }

      print('Información del club actualizada: $clubId');
    } catch (e) {
      print('Error actualizando club: $e');
      throw Exception('Error actualizando club: $e');
    }
  }

  Future<void> unirseAClub(String clubId) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) throw Exception('Club no encontrado');
      
      final clubData = clubDoc.data()!;

      await _firestore.collection('clubs').doc(clubId).update({
        'miembros': FieldValue.arrayUnion([usuario.uid]),
        'miembrosCount': FieldValue.increment(1),
        'ultimaActividad': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('mis_clubs')
          .doc(clubId)
          .set({
        'clubId': clubId,
        'nombre': clubData['nombre'],
        'genero': clubData['genero'],
        'fechaUnion': FieldValue.serverTimestamp(),
        'rol': 'miembro',
        'notificaciones': true,
      });

      print('Usuario unido al club: $clubId');
    } catch (e) {
      print('Error uniéndose al club: $e');
      throw Exception('Error uniéndose al club: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obtenerClubsUsuario() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return [];

      final snapshot = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('mis_clubs')
          .orderBy('fechaUnion', descending: true)
          .get();

      final clubsCompletos = await Future.wait(
        snapshot.docs.map((doc) async {
          final clubData = doc.data();
          final clubDetalle = await _firestore
              .collection('clubs')
              .doc(clubData['clubId'])
              .get();
          
          if (clubDetalle.exists) {
            return {
              ...clubData,
              ...clubDetalle.data()!,
            };
          }
          return clubData;
        }),
      );

      return clubsCompletos.where((club) => club != null).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      print('Error obteniendo clubs del usuario: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerClubsRecomendados() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return [];

      final snapshot = await _firestore
          .collection('clubs')
          .where('estado', isEqualTo: 'activo')
          .where('privacidad', isEqualTo: 'publico')
          .orderBy('miembrosCount', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error obteniendo clubs recomendados: $e');
      return [];
    }
  }
}
