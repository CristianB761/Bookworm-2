import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';

class OpenLibraryService {
  static const String _urlBase = 'https://openlibrary.org';

  Future<List<Libro>> buscarLibros(String consulta, {String? genero, int limite = 20}) async {
    try {
      String urlBusqueda = '$_urlBase/search.json?q=${Uri.encodeComponent(consulta)}&limit=$limite';
      
      urlBusqueda += '&language=spa';
      
      if (genero != null && genero != 'Todos los géneros') {
        urlBusqueda += '&subject=${Uri.encodeComponent(genero)}';
      }

      final respuesta = await http.get(Uri.parse(urlBusqueda));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final docs = datos['docs'] as List?;
        if (docs == null) return [];
        final libros = docs.map((doc) => _mapearLibroDesdeDoc(doc)).toList();
        
        if (libros.length < 5 && consulta.isNotEmpty) {
          return await _buscarSinFiltroIdioma(consulta, genero: genero, limite: limite);
        }
        
        return libros;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Libro>> _buscarSinFiltroIdioma(String consulta, {String? genero, int limite = 20}) async {
    try {
      String urlBusqueda = '$_urlBase/search.json?q=${Uri.encodeComponent(consulta)}&limit=$limite';
      
      if (genero != null && genero != 'Todos los géneros') {
        urlBusqueda += '&subject=${Uri.encodeComponent(genero)}';
      }

      final respuesta = await http.get(Uri.parse(urlBusqueda));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final docs = datos['docs'] as List?;
        if (docs == null) return [];
        return docs.map((doc) => _mapearLibroDesdeDoc(doc)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Libro?> obtenerDetalles(String id) async {
    try {
      final idLimpio = id.contains('/') ? id : '/books/$id';
      final url = Uri.parse('$_urlBase$idLimpio.json');
      final respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final libro = _mapearLibroDesdeJson(datos);
        return libro;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Libro _mapearLibroDesdeDoc(Map<String, dynamic> doc) {
    String? urlMiniatura;
    if (doc['cover_i'] != null) {
      urlMiniatura = 'https://covers.openlibrary.org/b/id/${doc['cover_i']}-M.jpg';
    }

    return Libro(
      id: doc['key'] ?? '',
      titulo: doc['title'] ?? 'Título no disponible',
      autores: List<String>.from(doc['author_name'] ?? []),
      descripcion: null,
      urlMiniatura: urlMiniatura,
      fechaPublicacion: doc['first_publish_year']?.toString(),
      numeroPaginas: doc['number_of_pages_median'],
      categorias: List<String>.from(doc['subject']?.take(5) ?? []),
      calificacionPromedio: doc['ratings_average']?.toDouble(),
      numeroCalificaciones: doc['ratings_count'],
      precio: 0.0,
      moneda: 'EUR',
    );
  }

  Libro _mapearLibroDesdeJson(Map<String, dynamic> json) {
    String? urlMiniatura;
    if (json['covers'] != null && json['covers'].isNotEmpty) {
      urlMiniatura = 'https://covers.openlibrary.org/b/id/${json['covers'][0]}-M.jpg';
    }

    return Libro(
      id: json['key'] ?? '',
      titulo: json['title'] ?? 'Título no disponible',
      autores: _extraerAutores(json),
      descripcion: null,
      urlMiniatura: urlMiniatura,
      fechaPublicacion: json['publish_date'] ?? json['first_publish_date'],
      numeroPaginas: json['number_of_pages'],
      categorias: List<String>.from(json['subjects']?.take(5) ?? []),
      calificacionPromedio: json['ratings']?['average']?.toDouble(),
      numeroCalificaciones: json['ratings']?['count'],
      precio: 0.0,
      moneda: 'EUR',
    );
  }

  List<String> _extraerAutores(Map<String, dynamic> json) {
    final autores = json['authors'] as List?;
    if (autores == null) return [];
    return autores.map<String>((a) => a['name'] ?? 'Autor desconocido').toList();
  }
}