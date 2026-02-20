import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modelos/progreso_lectura.dart';

class ProgresoBackend {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ProgresoLectura _progresoFromDoc(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      
      if (data == null) {
        throw Exception('Documento sin datos: ${doc.id}');
      }
      
      final Map<String, dynamic> datosMap;
      
      if (data is Map<String, dynamic>) {
        datosMap = Map<String, dynamic>.from(data);
      } else if (data is Map) {
        datosMap = Map<String, dynamic>.from(data.cast<String, dynamic>());
      } else {
        throw Exception('Formato de datos inválido en documento: ${doc.id}');
      }
      
      datosMap['id'] = doc.id;
      
      return ProgresoLectura.fromMap(datosMap);
    } catch (e) {
      print('Error convirtiendo documento a ProgresoLectura: $e');
      rethrow;
    }
  }

  Future<ProgresoLectura> crearProgreso({
    required String libroId,
    required String tituloLibro,
    required List<String> autoresLibro,
    String? miniaturaLibro,
    int paginasTotales = 0,
    String estado = 'leyendo',
  }) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        throw Exception('Usuario no autenticado');
      }

      final docRef = _firestore.collection('progreso_lectura').doc();
      final progresoId = docRef.id;
      
      final progreso = ProgresoLectura(
        id: progresoId,
        usuarioId: usuario.uid,
        libroId: libroId,
        tituloLibro: tituloLibro,
        autoresLibro: autoresLibro,
        miniaturaLibro: miniaturaLibro,
        estado: estado,
        paginaActual: 0,
        paginasTotales: paginasTotales,
        fechaInicio: DateTime.now(),
      );

      await docRef.set(progreso.toMap());

      await _actualizarEstadisticasUsuario(usuario.uid);

      return progreso;
    } catch (e) {
      throw Exception('Error creando progreso: $e');
    }
  }

  Future<void> actualizarProgreso({
    required String progresoId,
    int? paginaActual,
    String? estado,
    double? calificacion,
    String? resena,
  }) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      final datosActualizacion = <String, dynamic>{};

      if (paginaActual != null) {
        datosActualizacion['paginaActual'] = paginaActual;
      }

      if (estado != null) {
        datosActualizacion['estado'] = estado;
        
        if (estado == 'completado') {
          datosActualizacion['fechaCompletado'] = FieldValue.serverTimestamp();
        }
      }

      if (calificacion != null) {
        datosActualizacion['calificacion'] = calificacion;
      }

      if (resena != null) {
        datosActualizacion['resena'] = resena;
      }

      await _firestore
          .collection('progreso_lectura')
          .doc(progresoId)
          .update(datosActualizacion);

      if (estado == 'completado') {
        await _actualizarEstadisticasUsuario(usuario.uid);
      }
    } catch (e) {
      throw Exception('Error actualizando progreso: $e');
    }
  }

  Future<List<ProgresoLectura>> obtenerProgresosUsuario({
    String? estado,
    int limite = 50,
  }) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return [];

      Query query = _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuario.uid)
          .orderBy('fechaInicio', descending: true)
          .limit(limite);

      if (estado != null) {
        query = query.where('estado', isEqualTo: estado);
      }

      final snapshot = await query.get();
      
      return snapshot.docs.map(_progresoFromDoc).toList();
    } catch (e) {
      print('Error obteniendo progresos: $e');
      throw Exception('Error obteniendo progresos: $e');
    }
  }

  Future<Map<String, dynamic>> obtenerEstadisticasUsuario() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return {};

      final progresos = await obtenerProgresosUsuario();

      final librosCompletados = progresos.where((p) => p.estaCompletado).length;
      final totalPaginas = progresos.fold(0, (sum, p) => sum + p.paginaActual);
      final rachaActual = await _calcularRachaActual(usuario.uid);
      
      final generosFavoritos = _calcularGenerosFavoritos(progresos);

      return {
        'librosLeidos': librosCompletados,
        'paginasTotales': totalPaginas,
        'rachaActual': rachaActual,
        'librosEnProgreso': progresos.where((p) => p.estado == 'leyendo').length,
        'generosFavoritos': generosFavoritos,
        'tiempoLecturaTotal': await _calcularTiempoLecturaTotal(usuario.uid),
      };
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      throw Exception('Error obteniendo estadísticas: $e');
    }
  }

  Future<void> _actualizarEstadisticasUsuario(String usuarioId) async {
    try {
      final estadisticas = await obtenerEstadisticasUsuario();
      
      await _firestore
          .collection('usuarios')
          .doc(usuarioId)
          .update({
            'estadisticas': estadisticas,
            'ultimaActualizacion': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error actualizando estadísticas: $e');
    }
  }

  Future<int> _calcularRachaActual(String usuarioId) async {
    try {
      final snapshot = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuarioId)
          .where('estado', isEqualTo: 'completado')
          .orderBy('fechaCompletado', descending: true)
          .limit(30)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      final hoy = DateTime.now();
      int racha = 0;

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          
          final fechaCompletado = (data['fechaCompletado'] as Timestamp?)?.toDate();
          if (fechaCompletado != null) {
            final diferencia = hoy.difference(fechaCompletado).inDays;
            if (diferencia <= racha + 1) {
              racha++;
            } else {
              break;
            }
          }
        } catch (e) {
          print('Error procesando documento para racha: $e');
          continue;
        }
      }

      return racha;
    } catch (e) {
      print('Error calculando racha: $e');
      return 0;
    }
  }

  Future<int> _calcularTiempoLecturaTotal(String usuarioId) async {
    try {
      final progresos = await obtenerProgresosUsuario();
      return progresos.length * 60;
    } catch (e) {
      return 0;
    }
  }

  List<String> _calcularGenerosFavoritos(List<ProgresoLectura> progresos) {
    return [];
  }

  Future<Map<String, dynamic>> obtenerRecomendaciones() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return {};

      final progresos = await obtenerProgresosUsuario();
      
      return {
        'basadasEnHistorial': [],
        'tendencias': [],
        'nuevosLanzamientos': [],
      };
    } catch (e) {
      print('Error obteniendo recomendaciones: $e');
      return {};
    }
  }

  Future<String> exportarDatosLectura() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) throw Exception('Usuario no autenticado');

      final progresos = await obtenerProgresosUsuario();
      final estadisticas = await obtenerEstadisticasUsuario();

      final datosExportar = {
        'usuario': usuario.email,
        'fechaExportacion': DateTime.now().toIso8601String(),
        'progresos': progresos.map((p) => p.toMap()).toList(),
        'estadisticas': estadisticas,
      };

      return jsonEncode(datosExportar);
    } catch (e) {
      throw Exception('Error exportando datos: $e');
    }
  }
}
