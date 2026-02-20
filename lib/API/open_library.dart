import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';

class OpenLibrary {
  static const String _urlBase = 'https://openlibrary.org';

  Future<List<Libro>> buscarLibros({
    required String consulta,
    String? genero,
    int limite = 20,
  }) async {
    try {
      String urlBusqueda = '$_urlBase/search.json?q=$consulta&limit=$limite';
      
      if (genero != null && genero != 'Todos los géneros') {
        urlBusqueda += '&subject=$genero';
      }

      final respuesta = await http.get(Uri.parse(urlBusqueda));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final docs = datos['docs'] as List?;
        
        if (docs == null) return [];
        
        return docs.map((doc) => _libroDeDocOpenLibrary(doc)).toList();
      } else {
        throw Exception('Error al buscar libros: ${respuesta.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Libro?> obtenerDetallesLibro(String idLibro) async {
    try {
      final url = Uri.parse('$_urlBase/books/$idLibro.json');
      final respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        return _libroDeJsonOpenLibrary(datos);
      } else {
        throw Exception('Error al obtener detalles del libro: ${respuesta.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Libro>> obtenerLibrosPorGenero(String genero, {int limite = 20}) async {
    try {
      final url = Uri.parse(
        '$_urlBase/subjects/${genero.toLowerCase()}.json?limit=$limite'
      );

      final respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final works = datos['works'] as List?;
        
        if (works == null) return [];
        
        return works.map((work) => _libroDeWorkOpenLibrary(work)).toList();
      } else {
        throw Exception('Error al buscar por género: ${respuesta.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Libro?> buscarPorISBN(String isbn) async {
    try {
      final url = Uri.parse('$_urlBase/isbn/$isbn.json');
      final respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        return _libroDeJsonOpenLibrary(datos);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Libro _libroDeDocOpenLibrary(Map<String, dynamic> doc) {
    String? urlMiniatura;
    if (doc['cover_i'] != null) {
      urlMiniatura = 'https://covers.openlibrary.org/b/id/${doc['cover_i']}-M.jpg';
    }

    List<String> autores = [];
    if (doc['author_name'] != null) {
      autores = List<String>.from(doc['author_name']);
    }

    List<String> categorias = [];
    if (doc['subject'] != null) {
      categorias = List<String>.from(doc['subject'].take(5));
    }

    return Libro(
      id: doc['key'] ?? '',
      titulo: doc['title'] ?? 'Título no disponible',
      autores: autores,
      descripcion: _truncarDescripcion(doc['first_sentence'] ?? doc['description']),
      urlMiniatura: urlMiniatura,
      fechaPublicacion: doc['first_publish_year']?.toString(),
      numeroPaginas: doc['number_of_pages_median'],
      categorias: categorias,
      calificacionPromedio: doc['ratings_average']?.toDouble(),
      numeroCalificaciones: doc['ratings_count'],
    );
  }

  Libro _libroDeJsonOpenLibrary(Map<String, dynamic> json) {
    return Libro(
      id: json['key'] ?? '',
      titulo: json['title'] ?? 'Título no disponible',
      autores: _extraerAutores(json),
      descripcion: _truncarDescripcion(json['description']),
      urlMiniatura: _obtenerUrlPortada(json),
      fechaPublicacion: _extraerFechaPublicacion(json),
      numeroPaginas: json['number_of_pages'],
      categorias: _extraerTemas(json),
      calificacionPromedio: json['ratings']?['average']?.toDouble(),
      numeroCalificaciones: json['ratings']?['count'],
    );
  }

  Libro _libroDeWorkOpenLibrary(Map<String, dynamic> work) {
    return Libro(
      id: work['key'] ?? '',
      titulo: work['title'] ?? 'Título no disponible',
      autores: _extraerAutoresDesdeWork(work),
      descripcion: _truncarDescripcion(work['description']),
      urlMiniatura: _obtenerUrlPortadaDesdeWork(work),
      fechaPublicacion: work['first_publish_date']?.toString().substring(0, 4),
      categorias: _extraerTemasDesdeWork(work),
      calificacionPromedio: work['rating']?.toDouble(),
    );
  }

  List<String> _extraerAutores(Map<String, dynamic> json) {
    if (json['authors'] != null) {
      final autores = json['authors'] as List;
      return autores.map<String>((autor) {
        return autor['name'] ?? 'Autor desconocido';
      }).toList();
    }
    return [];
  }

  List<String> _extraerAutoresDesdeWork(Map<String, dynamic> work) {
    if (work['authors'] != null) {
      final autores = work['authors'] as List;
      return autores.map<String>((autor) {
        return autor['name'] ?? 'Autor desconocido';
      }).toList();
    }
    return [];
  }

  String? _obtenerUrlPortada(Map<String, dynamic> json) {
    if (json['covers'] != null && json['covers'].isNotEmpty) {
      final idPortada = json['covers'][0];
      return 'https://covers.openlibrary.org/b/id/$idPortada-M.jpg';
    }
    return null;
  }

  String? _obtenerUrlPortadaDesdeWork(Map<String, dynamic> work) {
    if (work['cover_id'] != null) {
      return 'https://covers.openlibrary.org/b/id/${work['cover_id']}-M.jpg';
    }
    return null;
  }

  String? _extraerFechaPublicacion(Map<String, dynamic> json) {
    if (json['publish_date'] != null) {
      return json['publish_date'];
    } else if (json['first_publish_date'] != null) {
      return json['first_publish_date'];
    }
    return null;
  }

  List<String> _extraerTemas(Map<String, dynamic> json) {
    if (json['subjects'] != null) {
      return List<String>.from(json['subjects'].take(5));
    }
    return [];
  }

  List<String> _extraerTemasDesdeWork(Map<String, dynamic> work) {
    if (work['subject'] != null) {
      return List<String>.from(work['subject'].take(5));
    }
    return [];
  }

  String? _truncarDescripcion(dynamic descripcion) {
    if (descripcion == null) return null;
    
    String textoDesc;
    if (descripcion is String) {
      textoDesc = descripcion;
    } else if (descripcion is Map) {
      textoDesc = descripcion['value'] ?? '';
    } else {
      textoDesc = descripcion.toString();
    }
    
    if (textoDesc.length > 200) {
      return '${textoDesc.substring(0, 200)}...';
    }
    return textoDesc;
  }
}
