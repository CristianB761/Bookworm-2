import 'package:cloud_firestore/cloud_firestore.dart';

class ProgresoLectura {
  final String id;
  final String usuarioId;
  final String libroId;
  final String tituloLibro;
  final List<String> autoresLibro;
  final String? miniaturaLibro;
  final String estado; 
  final int paginaActual;
  final int paginasTotales;
  final DateTime fechaInicio;
  final DateTime? fechaCompletado;
  final double calificacion;
  final String? resena;

  ProgresoLectura({
    required this.id,
    required this.usuarioId,
    required this.libroId,
    required this.tituloLibro,
    required this.autoresLibro,
    this.miniaturaLibro,
    required this.estado,
    required this.paginaActual,
    required this.paginasTotales,
    required this.fechaInicio,
    this.fechaCompletado,
    this.calificacion = 0.0,
    this.resena,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuarioId': usuarioId,
      'libroId': libroId,
      'tituloLibro': tituloLibro,
      'autoresLibro': autoresLibro,
      'miniaturaLibro': miniaturaLibro,
      'estado': estado,
      'paginaActual': paginaActual,
      'paginasTotales': paginasTotales,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaCompletado': fechaCompletado != null ? Timestamp.fromDate(fechaCompletado!) : null,
      'calificacion': calificacion,
      'resena': resena,
    };
  }

  factory ProgresoLectura.fromMap(Map<String, dynamic> map) {
    return ProgresoLectura(
      id: map['id'] ?? '',
      usuarioId: map['usuarioId'] ?? '',
      libroId: map['libroId'] ?? '',
      tituloLibro: map['tituloLibro'] ?? '',
      autoresLibro: List<String>.from(map['autoresLibro'] ?? []),
      miniaturaLibro: map['miniaturaLibro'],
      estado: map['estado'] ?? 'por_leer',
      paginaActual: map['paginaActual'] ?? 0,
      paginasTotales: map['paginasTotales'] ?? 0,
      fechaInicio: (map['fechaInicio'] as Timestamp).toDate(),
      fechaCompletado: map['fechaCompletado'] != null
          ? (map['fechaCompletado'] as Timestamp).toDate()
          : null,
      calificacion: (map['calificacion'] ?? 0.0).toDouble(),
      resena: map['resena'],
    );
  }


  double get porcentajeProgreso {
    if (paginasTotales == 0) return 0.0;
    return (paginaActual / paginasTotales * 100).clamp(0.0, 100.0);
  }

  bool get estaCompletado => estado == 'completado';
}
