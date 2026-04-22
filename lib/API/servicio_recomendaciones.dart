
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'modelos.dart';
import 'biblioteca_service.dart';

class ServicioRecomendaciones {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BibliotecaServiceUnificado _bibliotecaService = BibliotecaServiceUnificado();

  Future<List<Recomendacion>> obtenerRecomendacionesPersonalizadas({
    int limite = 20,
  }) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return [];

    final List<Recomendacion> todasRecomendaciones = [];
    
    final perfilUsuario = await _obtenerPerfilRecomendaciones(usuario.uid);
    final librosGuardados = await _obtenerLibrosGuardados(usuario.uid);
    
    if (librosGuardados.isEmpty) {
      return await _obtenerRecomendacionesPorDefecto(limite);
    }
    
    final Map<String, int> frecuenciasGeneros = {};
    final Map<String, int> frecuenciasAutores = {};
    final List<String> idsLibrosLeidos = [];
    
    for (final libro in librosGuardados) {
      idsLibrosLeidos.add(libro.id);
      
      for (final categoria in libro.categorias) {
        frecuenciasGeneros[categoria] = (frecuenciasGeneros[categoria] ?? 0) + 2;
      }
      
      for (final autor in libro.autores) {
        frecuenciasAutores[autor] = (frecuenciasAutores[autor] ?? 0) + 2;
      }
      
      if (libro.calificacionPromedio != null && libro.calificacionPromedio! > 4.0) {
        for (final categoria in libro.categorias) {
          frecuenciasGeneros[categoria] = (frecuenciasGeneros[categoria] ?? 0) + 1;
        }
      }
    }
    
    if (perfilUsuario.generosFavoritos.isNotEmpty) {
      for (final genero in perfilUsuario.generosFavoritos) {
        frecuenciasGeneros[genero] = (frecuenciasGeneros[genero] ?? 0) + 3;
      }
    }
    
    final generosEntries = frecuenciasGeneros.entries
        .where((e) => e.value > 0)
        .toList();
    generosEntries.sort((a, b) => b.value.compareTo(a.value));
    final List<String> generosTop = generosEntries
        .take(5)
        .map((e) => e.key)
        .toList();
    
    final autoresEntries = frecuenciasAutores.entries
        .where((e) => e.value > 0)
        .toList();
    autoresEntries.sort((a, b) => b.value.compareTo(a.value));
    final List<String> autoresTop = autoresEntries
        .take(3)
        .map((e) => e.key)
        .toList();
    
    final List<Future<List<Libro>>> futures = [];
    
    if (generosTop.isNotEmpty) {
      for (final genero in generosTop) {
        futures.add(_bibliotecaService.buscarLibros(
          genero,
          genero: genero,
          limite: 10,
        ));
      }
    }
    
    if (autoresTop.isNotEmpty) {
      for (final autor in autoresTop) {
        futures.add(_bibliotecaService.buscarLibros(
          autor,
          limite: 8,
        ));
      }
    }
    
    if (generosTop.isEmpty && autoresTop.isEmpty) {
      futures.add(_bibliotecaService.obtenerLibrosPopulares(limite: 30));
    }
    
    try {
      final resultados = await Future.wait(futures);
      final Map<String, Libro> librosUnicos = {};
      
      for (final libros in resultados) {
        for (final libro in libros) {
          if (!idsLibrosLeidos.contains(libro.id)) {
            if (!librosUnicos.containsKey(libro.id)) {
              librosUnicos[libro.id] = libro;
            }
          }
        }
      }
      
      List<Libro> librosRecomendados = librosUnicos.values.toList();
      
      librosRecomendados = await _calcularPuntuacionesRelevancia(
        librosRecomendados,
        generosTop,
        autoresTop,
        frecuenciasGeneros,
        perfilUsuario,
      );
      
      librosRecomendados.sort((a, b) => b.puntuacionRecomendacion.compareTo(a.puntuacionRecomendacion));
      
      todasRecomendaciones.addAll(librosRecomendados.take(limite).map((libro) => Recomendacion(
        libro: libro,
        tipo: RecomendacionTipo.basadaEnGenero,
        puntuacion: libro.puntuacionRecomendacion,
        razon: _generarRazonRecomendacion(libro, generosTop, autoresTop),
      )));
    } catch (e) {
    }
    
    final recomendacionesTendencias = await _obtenerRecomendacionesTendencias(
      idsLibrosLeidos,
      limite ~/ 2,
    );
    todasRecomendaciones.addAll(recomendacionesTendencias);
    
    final recomendacionesNuevos = await _obtenerRecomendacionesNuevosLanzamientos(
      idsLibrosLeidos,
      limite ~/ 3,
    );
    todasRecomendaciones.addAll(recomendacionesNuevos);
    
    todasRecomendaciones.sort((a, b) => b.puntuacion.compareTo(a.puntuacion));
    
    return todasRecomendaciones.take(limite).toList();
  }
  
  Future<List<Recomendacion>> obtenerRecomendacionesPorLibro(
    Libro libroReferencia, {
    int limite = 10,
  }) async {
    final List<Recomendacion> recomendaciones = [];
    
    final Map<String, int> frecuencias = {};
    
    for (final categoria in libroReferencia.categorias) {
      frecuencias[categoria] = (frecuencias[categoria] ?? 0) + 3;
    }
    
    for (final autor in libroReferencia.autores) {
      frecuencias[autor] = (frecuencias[autor] ?? 0) + 2;
    }
    
    final List<String> terminosBusqueda = [];
    if (libroReferencia.categorias.isNotEmpty) {
      terminosBusqueda.add(libroReferencia.categorias.first);
    }
    if (libroReferencia.autores.isNotEmpty) {
      terminosBusqueda.add(libroReferencia.autores.first);
    }
    if (terminosBusqueda.isEmpty) {
      terminosBusqueda.add(libroReferencia.titulo.split(' ').first);
    }
    
    final Map<String, Libro> librosUnicos = {};
    
    for (final termino in terminosBusqueda.take(2)) {
      final resultados = await _bibliotecaService.buscarLibros(
        termino,
        limite: limite * 2,
      );
      
      for (final libro in resultados) {
        if (libro.id != libroReferencia.id) {
          librosUnicos[libro.id] = libro;
        }
      }
    }
    
    List<Libro> librosRecomendados = librosUnicos.values.toList();
    
    for (final libro in librosRecomendados) {
      double puntuacion = 0;
      
      for (final categoria in libro.categorias) {
        puntuacion += (frecuencias[categoria] ?? 0).toDouble();
      }
      
      for (final autor in libro.autores) {
        puntuacion += (frecuencias[autor] ?? 0).toDouble();
      }
      
      final similitudTitulo = _calcularSimilitudCadenas(
        libroReferencia.titulo.toLowerCase(),
        libro.titulo.toLowerCase(),
      );
      puntuacion += similitudTitulo * 10;
      
      libro.puntuacionRecomendacion = puntuacion;
    }
    
    librosRecomendados.sort((a, b) => b.puntuacionRecomendacion.compareTo(a.puntuacionRecomendacion));
    
    recomendaciones.addAll(librosRecomendados.take(limite).map((libro) => Recomendacion(
      libro: libro,
      tipo: RecomendacionTipo.similares,
      puntuacion: libro.puntuacionRecomendacion,
      razon: _generarRazonRecomendacionPorSimilitud(libro, libroReferencia),
    )));
    
    return recomendaciones;
  }
  
  Future<List<Recomendacion>> obtenerRecomendacionesParaTi({
    int limite = 20,
  }) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return [];
    
    final progresos = await _firestore
        .collection('progreso_lectura')
        .where('usuarioId', isEqualTo: usuario.uid)
        .where('estado', isEqualTo: 'completado')
        .get();
    
    final Map<String, int> generosCompletados = {};
    final Map<String, int> autoresCompletados = {};
    double promedioCalificaciones = 0;
    int totalCalificaciones = 0;
    
    for (final doc in progresos.docs) {
      final data = doc.data();
      final calificacion = (data['calificacion'] as num?)?.toDouble() ?? 0;
      if (calificacion > 0) {
        promedioCalificaciones += calificacion;
        totalCalificaciones++;
      }
      
      final categorias = List<String>.from(data['categorias'] ?? []);
      for (final categoria in categorias) {
        generosCompletados[categoria] = (generosCompletados[categoria] ?? 0) + 1;
      }
      
      final autores = List<String>.from(data['autoresLibro'] ?? []);
      for (final autor in autores) {
        autoresCompletados[autor] = (autoresCompletados[autor] ?? 0) + 1;
      }
    }
    
    promedioCalificaciones = totalCalificaciones > 0 
        ? promedioCalificaciones / totalCalificaciones 
        : 0;
    
    final generosEntries = generosCompletados.entries.toList();
    generosEntries.sort((a, b) => b.value.compareTo(a.value));
    final List<String> generosTop = generosEntries
        .take(3)
        .map((e) => e.key)
        .toList();
    
    final autoresEntries = autoresCompletados.entries.toList();
    autoresEntries.sort((a, b) => b.value.compareTo(a.value));
    final List<String> autoresTop = autoresEntries
        .take(2)
        .map((e) => e.key)
        .toList();
    
    final List<Future<List<Libro>>> futures = [];
    
    if (generosTop.isNotEmpty) {
      for (final genero in generosTop) {
        futures.add(_bibliotecaService.buscarLibros(
          genero,
          genero: genero,
          limite: 15,
        ));
      }
    }
    
    if (autoresTop.isNotEmpty) {
      for (final autor in autoresTop) {
        futures.add(_bibliotecaService.buscarLibros(
          autor,
          limite: 10,
        ));
      }
    }
    
    final librosYaLeidos = await _obtenerIdsLibrosLeidos(usuario.uid);
    
    final Map<String, Libro> librosUnicos = {};
    
    try {
      final resultados = await Future.wait(futures);
      for (final libros in resultados) {
        for (final libro in libros) {
          if (!librosYaLeidos.contains(libro.id)) {
            librosUnicos[libro.id] = libro;
          }
        }
      }
    } catch (e) {
    }
    
    List<Libro> librosRecomendados = librosUnicos.values.toList();
    
    for (final libro in librosRecomendados) {
      double puntuacion = 0;
      
      for (final genero in libro.categorias) {
        puntuacion += (generosCompletados[genero] ?? 0).toDouble();
      }
      
      for (final autor in libro.autores) {
        puntuacion += (autoresCompletados[autor] ?? 0).toDouble();
      }
      
      if (promedioCalificaciones > 4.0 && libro.calificacionPromedio != null) {
        puntuacion += libro.calificacionPromedio! * 2;
      }
      
      libro.puntuacionRecomendacion = puntuacion;
    }
    
    librosRecomendados.sort((a, b) => b.puntuacionRecomendacion.compareTo(a.puntuacionRecomendacion));
    
    return librosRecomendados.take(limite).map((libro) => Recomendacion(
      libro: libro,
      tipo: RecomendacionTipo.paraTi,
      puntuacion: libro.puntuacionRecomendacion,
      razon: _generarRazonBasadaEnHistorial(libro, generosTop, autoresTop),
    )).toList();
  }
  
  Future<List<Recomendacion>> _obtenerRecomendacionesTendencias(
    List<String> idsExcluidos,
    int limite,
  ) async {
    final recomendaciones = <Recomendacion>[];
    
    try {
      final librosPopulares = await _bibliotecaService.obtenerLibrosPopulares(limite: 30);
      
      int indice = 0;
      for (final libro in librosPopulares) {
        if (!idsExcluidos.contains(libro.id) && indice < limite) {
          recomendaciones.add(Recomendacion(
            libro: libro,
            tipo: RecomendacionTipo.tendencia,
            puntuacion: (50 - indice).toDouble(),
            razon: 'Libro popular entre los lectores',
          ));
          indice++;
        }
      }
    } catch (e) {
    }
    
    return recomendaciones;
  }
  
  Future<List<Recomendacion>> _obtenerRecomendacionesNuevosLanzamientos(
    List<String> idsExcluidos,
    int limite,
  ) async {
    final recomendaciones = <Recomendacion>[];
    
    try {
      final resultados = await _bibliotecaService.buscarLibros(
        'nuevos libros',
        limite: 20,
      );
      
      int indice = 0;
      for (final libro in resultados) {
        if (!idsExcluidos.contains(libro.id) && indice < limite) {
          recomendaciones.add(Recomendacion(
            libro: libro,
            tipo: RecomendacionTipo.nuevo,
            puntuacion: (40 - indice).toDouble(),
            razon: 'Nuevo lanzamiento que podría interesarte',
          ));
          indice++;
        }
      }
    } catch (e) {
    }
    
    return recomendaciones;
  }
  
  Future<List<Recomendacion>> _obtenerRecomendacionesPorDefecto(int limite) async {
    final recomendaciones = <Recomendacion>[];
    
    try {
      final librosPopulares = await _bibliotecaService.obtenerLibrosPopulares(limite: limite);
      
      for (int i = 0; i < librosPopulares.length; i++) {
        recomendaciones.add(Recomendacion(
          libro: librosPopulares[i],
          tipo: RecomendacionTipo.tendencia,
          puntuacion: (100 - i).toDouble(),
          razon: 'Libro popular recomendado para ti',
        ));
      }
    } catch (e) {
    }
    
    return recomendaciones;
  }
  
  Future<List<Libro>> _calcularPuntuacionesRelevancia(
    List<Libro> libros,
    List<String> generosTop,
    List<String> autoresTop,
    Map<String, int> frecuenciasGeneros,
    PerfilRecomendaciones perfil,
  ) async {
    for (final libro in libros) {
      double puntuacion = 0;
      
      for (final genero in libro.categorias) {
        puntuacion += (frecuenciasGeneros[genero] ?? 0).toDouble();
        if (generosTop.contains(genero)) {
          puntuacion += 5;
        }
      }
      
      for (final autor in libro.autores) {
        if (autoresTop.contains(autor)) {
          puntuacion += 8;
        }
      }
      
      if (libro.calificacionPromedio != null) {
        puntuacion += libro.calificacionPromedio! * 2;
      }
      
      if (libro.precio == 0.0) {
        puntuacion += 3;
      }
      
      libro.puntuacionRecomendacion = puntuacion;
    }
    
    return libros;
  }
  
  Future<PerfilRecomendaciones> _obtenerPerfilRecomendaciones(String uid) async {
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    final data = doc.data() ?? {};
    
    Map<String, double> preferencias = {};
    final prefsRaw = data['preferencias'] ?? {};
    if (prefsRaw is Map) {
      prefsRaw.forEach((key, value) {
        if (value is int) {
          preferencias[key.toString()] = value.toDouble();
        } else if (value is double) {
          preferencias[key.toString()] = value;
        } else if (value is bool) {
          preferencias[key.toString()] = value ? 1.0 : 0.0;
        } else if (value is num) {
          preferencias[key.toString()] = value.toDouble();
        } else {
          preferencias[key.toString()] = 0.0;
        }
      });
    }
    
    return PerfilRecomendaciones(
      uid: uid,
      generosFavoritos: List<String>.from(data['generosFavoritos'] ?? []),
      preferencias: preferencias,
      nivelLector: data['nivelLector']?.toString() ?? 'intermedio',
      formatosPreferidos: List<String>.from(data['formatosPreferidos'] ?? ['libro', 'audio']),
    );
  }
  
  Future<List<Libro>> _obtenerLibrosGuardados(String uid) async {
    final List<Libro> libros = [];
    
    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .doc(uid)
          .collection('libros_guardados')
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final libro = Libro(
          id: data['id']?.toString() ?? doc.id,
          titulo: data['titulo']?.toString() ?? 'Sin título',
          autores: List<String>.from(data['autores'] ?? []),
          descripcion: data['descripcion']?.toString(),
          urlMiniatura: data['urlMiniatura']?.toString(),
          fechaPublicacion: data['fechaPublicacion']?.toString(),
          numeroPaginas: data['numeroPaginas'] is int ? data['numeroPaginas'] : null,
          categorias: List<String>.from(data['categorias'] ?? []),
          calificacionPromedio: (data['calificacionPromedio'] as num?)?.toDouble(),
          numeroCalificaciones: data['numeroCalificaciones'] is int ? data['numeroCalificaciones'] : null,
          urlLectura: data['urlLectura']?.toString(),
          esAudiolibro: data['esAudiolibro'] == true,
          precio: (data['precio'] as num?)?.toDouble(),
        );
        libros.add(libro);
      }
    } catch (e) {
    }
    
    return libros;
  }
  
  Future<Set<String>> _obtenerIdsLibrosLeidos(String uid) async {
    final Set<String> ids = {};
    
    try {
      final snapshot = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: uid)
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final libroId = data['libroId']?.toString();
        if (libroId != null && libroId.isNotEmpty) {
          ids.add(libroId);
        }
      }
    } catch (e) {
    }
    
    final librosGuardados = await _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('libros_guardados')
        .get();
    
    for (final doc in librosGuardados.docs) {
      ids.add(doc.id);
    }
    
    return ids;
  }
  
  String _generarRazonRecomendacion(Libro libro, List<String> generosTop, List<String> autoresTop) {
    for (final autor in libro.autores) {
      if (autoresTop.contains(autor)) {
        return 'Porque te gusta leer libros de $autor';
      }
    }
    
    for (final genero in libro.categorias) {
      if (generosTop.contains(genero)) {
        return 'Recomendado por tu interés en $genero';
      }
    }
    
    if (libro.calificacionPromedio != null && libro.calificacionPromedio! > 4.0) {
      return 'Altamente valorado por otros lectores';
    }
    
    if (libro.precio == 0.0) {
      return 'Libro gratuito disponible';
    }
    
    return 'Basado en tus gustos literarios';
  }
  
  String _generarRazonBasadaEnHistorial(Libro libro, List<String> generosTop, List<String> autoresTop) {
    for (final autor in libro.autores) {
      if (autoresTop.contains(autor)) {
        return 'Ya has leído otros libros de $autor y te gustaron';
      }
    }
    
    for (final genero in libro.categorias) {
      if (generosTop.contains(genero)) {
        return 'Sueles leer libros del género $genero';
      }
    }
    
    return 'Basado en tu historial de lectura';
  }
  
  String _generarRazonRecomendacionPorSimilitud(Libro libro, Libro referencia) {
    for (final autor in libro.autores) {
      if (referencia.autores.contains(autor)) {
        return 'Del mismo autor: ${referencia.titulo}';
      }
    }
    
    for (final genero in libro.categorias) {
      if (referencia.categorias.contains(genero)) {
        return 'Similar a ${referencia.titulo} por género';
      }
    }
    
    return 'Libros similares a ${referencia.titulo}';
  }
  
  double _calcularSimilitudCadenas(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    
    final Set<String> palabrasA = a.split(' ').toSet();
    final Set<String> palabrasB = b.split(' ').toSet();
    
    final interseccion = palabrasA.intersection(palabrasB).length;
    final union = palabrasA.union(palabrasB).length;
    
    return union > 0 ? interseccion / union : 0;
  }
}

class Recomendacion {
  final Libro libro;
  final RecomendacionTipo tipo;
  final double puntuacion;
  final String razon;

  Recomendacion({
    required this.libro,
    required this.tipo,
    required this.puntuacion,
    required this.razon,
  });
}

enum RecomendacionTipo {
  basadaEnGenero,
  similares,
  paraTi,
  tendencia,
  nuevo,
}

class PerfilRecomendaciones {
  final String uid;
  final List<String> generosFavoritos;
  final Map<String, double> preferencias;
  final String nivelLector;
  final List<String> formatosPreferidos;

  PerfilRecomendaciones({
    required this.uid,
    required this.generosFavoritos,
    required this.preferencias,
    required this.nivelLector,
    required this.formatosPreferidos,
  });
}