import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';
// ELIMINAR: import 'traductor_service.dart';

class GutendexService {
  static const String _urlBase = 'https://gutendex.com/books';
  // ELIMINAR: final TraductorService _traductorService = TraductorService();

  Future<List<Libro>> buscarLibros(String consulta, {String? genero, int limite = 20}) async {
    try {
      String url = '$_urlBase/?search=${Uri.encodeComponent(consulta)}';
      
      if (genero != null && genero != 'Todos los géneros') {
        url += '&topic=${Uri.encodeComponent(genero)}';
      }

      final respuesta = await http.get(Uri.parse(url));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final results = datos['results'] as List?;
        if (results == null) return [];
        final libros = results.take(limite).map((book) => _mapearLibro(book)).toList();
        
        return libros; // 🔥 Ya no filtramos por idioma
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Libro>> obtenerLibrosPopulares({int limite = 20}) async {
    try {
      final respuesta = await http.get(Uri.parse(_urlBase));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final results = datos['results'] as List?;
        if (results == null) return [];
        final libros = results.take(limite).map((book) => _mapearLibro(book)).toList();
        
        return libros;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Libro?> obtenerDetalles(String id) async {
    try {
      final idLimpio = id.replaceFirst('guten_', '');
      final respuesta = await http.get(Uri.parse('$_urlBase/$idLimpio'));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        return _mapearLibro(datos);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Libro _mapearLibro(Map<String, dynamic> json) {
    final formats = json['formats'] as Map<String, dynamic>? ?? {};
    
    String? urlLectura = formats['text/html'] ?? 
                        formats['text/html; charset=utf-8'] ??
                        formats['application/epub+zip'] ??
                        formats['application/x-mobipocket-ebook'] ??
                        formats['text/plain; charset=utf-8'] ??
                        formats['text/plain'];

    return Libro(
      id: 'guten_${json['id']}',
      titulo: json['title'] ?? 'Título no disponible',
      autores: (json['authors'] as List?)?.map((a) => a['name'] as String).toList() ?? [],
      descripcion: null, // 🔥 No usar descripción de Gutendex
      urlMiniatura: formats['image/jpeg'],
      categorias: List<String>.from(json['bookshelves'] ?? []),
      numeroCalificaciones: json['download_count'],
      urlLectura: urlLectura,
      precio: 0.0,
      moneda: 'EUR',
    );
  }
}