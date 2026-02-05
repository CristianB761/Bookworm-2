import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';
import 'traductor_service.dart';

class OpenLibraryService {
  static const String _urlBase = 'https://openlibrary.org';
  final TraductorService _traductorService = TraductorService();

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
      print('Error en OpenLibrary: $e');
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
      print('Error en OpenLibrary sin filtro: $e');
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
        return await _mejorarDescripcionEspanol(libro);
      }
      return null;
    } catch (e) {
      print('Error obteniendo detalles en OpenLibrary: $e');
      return null;
    }
  }

  Libro _mapearLibroDesdeDoc(Map<String, dynamic> doc) {
    String? urlMiniatura;
    if (doc['cover_i'] != null) {
      urlMiniatura = 'https://covers.openlibrary.org/b/id/${doc['cover_i']}-M.jpg';
    }

    final languages = doc['language'] as List?;
    final idiomas = languages != null ? List<String>.from(languages) : [];

    String? descripcionOriginal = _limpiarHtml(doc['first_sentence'] ?? doc['description']);
    String descripcion = descripcionOriginal ?? '';
    
    if (descripcion.isEmpty || _esTextoIngles(descripcion)) {
      final idiomasStr = idiomas.isNotEmpty ? ' Idiomas: ${idiomas.join(", ")}.' : '';
      final fechaStr = doc['first_publish_year'] != null ? ' Publicado en ${doc['first_publish_year']}.' : '';
      final autoresStr = doc['author_name'] != null && (doc['author_name'] as List).isNotEmpty 
          ? ' Autor: ${(doc['author_name'] as List).first}.' 
          : '';
      
      descripcion = 'Libro "${doc['title'] ?? ''}" disponible en Open Library.$autoresStr$fechaStr$idiomasStr '
                    'Catálogo bibliográfico abierto con información de obras publicadas.';
    }

    return Libro(
      id: doc['key'] ?? '',
      titulo: doc['title'] ?? 'Título no disponible',
      autores: List<String>.from(doc['author_name'] ?? []),
      descripcion: descripcion,
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

    final languages = json['languages'] as List?;
    final idiomas = languages != null 
        ? languages.map((l) => l['key']?.toString().split('/').last ?? '').toList()
        : [];

    String? descripcionOriginal = _limpiarHtml(json['description']);
    String descripcion = descripcionOriginal ?? '';
    
    if (descripcion.isEmpty || _esTextoIngles(descripcion)) {
      final idiomasStr = idiomas.isNotEmpty ? ' Disponible en ${idiomas.length} idioma(s).' : '';
      final fechaStr = json['publish_date'] ?? json['first_publish_date'];
      final fechaStrFormatted = fechaStr != null ? ' Publicación: $fechaStr.' : '';
      final paginasStr = json['number_of_pages'] != null ? ' ${json['number_of_pages']} páginas.' : '';
      
      descripcion = 'Obra "${json['title'] ?? ''}" registrada en Open Library.$fechaStrFormatted$paginasStr$idiomasStr '
                    'Base de datos colaborativa de información bibliográfica.';
    }

    return Libro(
      id: json['key'] ?? '',
      titulo: json['title'] ?? 'Título no disponible',
      autores: _extraerAutores(json),
      descripcion: descripcion,
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

  String? _limpiarHtml(dynamic texto) {
    if (texto == null) return null;
    String clean;
    if (texto is Map) {
      clean = texto['value'] ?? '';
    } else {
      clean = texto.toString();
    }
    return clean.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  bool _esTextoIngles(String texto) {
    final palabrasIngles = ['the', 'and', 'of', 'to', 'in', 'is', 'that', 'for', 'it', 'with', 'as', 'was'];
    final textoLower = texto.toLowerCase();
    int countIngles = 0;
    
    for (var palabra in palabrasIngles) {
      final regex = RegExp(r'\b' + palabra + r'\b');
      if (regex.hasMatch(textoLower)) {
        countIngles++;
      }
      if (countIngles >= 2) return true;
    }
    
    return false;
  }

  Future<Libro> _mejorarDescripcionEspanol(Libro libro) async {
    if (libro.descripcion == null || libro.descripcion!.isEmpty) {
      return libro;
    }
    
    final descripcion = libro.descripcion!;
    
    if (_esTextoIngles(descripcion)) {
      final autoresStr = libro.autores.isNotEmpty ? ' de ${libro.autores.join(", ")}' : '';
      final fechaStr = libro.fechaPublicacion != null ? ' (${libro.fechaPublicacion})' : '';
      final paginasStr = libro.numeroPaginas != null ? ' ${libro.numeroPaginas} páginas.' : '';
      final categoriasStr = libro.categorias.isNotEmpty ? ' Categorías: ${libro.categorias.join(", ")}.' : '';
      
      final nuevaDescripcion = 'Libro "${libro.titulo}"$autoresStr$fechaStr.$paginasStr$categoriasStr '
                               'Información bibliográfica proporcionada por Open Library, '
                               'una base de datos abierta de catálogo bibliográfico.';
      
      return libro.copyWith(descripcion: nuevaDescripcion);
    }
    
    return libro;
  }
}