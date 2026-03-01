import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';
import 'traductor_service.dart';

class LibriVoxService {
  static const String _urlBase = 'https://librivox.org/api/feed/audiobooks';
  final TraductorService _traductorService = TraductorService();

  Future<List<Libro>> buscarLibros(String consulta, {String? genero, int limite = 20}) async {
    try {
      final consultaCodificada = Uri.encodeComponent(consulta);
      String url = '$_urlBase?format=json';
      
      if (consulta.isNotEmpty && consulta.toLowerCase() != 'fiction') {
        url += '&title=%5E$consultaCodificada';
      } else if (consulta.toLowerCase() == 'fiction' && (genero == null || genero == 'Todos los géneros')) {
        url += '&limit=$limite';
      }
      
      if (genero != null && genero != 'Todos los géneros') {
        url += '&genre=${Uri.encodeComponent(_mapearGenero(genero))}';
      }
      
      if (consulta.isEmpty && (genero == null || genero == 'Todos los géneros')) {
        url += '&limit=$limite';
      }

      var respuesta = await http.get(Uri.parse(url));

      if (respuesta.statusCode == 500 && url.contains('&genre=')) {
        final nuevaUrl = url.split('&genre=')[0];
        respuesta = await http.get(Uri.parse(nuevaUrl));
      }

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final books = (datos is Map) ? datos['books'] : datos;

        if (books == null || books is! List || books.isEmpty) {
          if (url.contains('title=%5E')) {
            final urlSimple = url.replaceFirst('title=%5E', 'title=');
            final respuestaSimple = await http.get(Uri.parse(urlSimple));
            if (respuestaSimple.statusCode == 200) {
              final datosSimple = json.decode(respuestaSimple.body);
              final booksSimple = (datosSimple is Map) ? datosSimple['books'] : datosSimple;
              if (booksSimple != null && booksSimple is List && booksSimple.isNotEmpty) {
                return booksSimple.map<Libro>((book) => _mapearLibro(book as Map<String, dynamic>)).toList();
              }
            }
          }
          if (consulta.isNotEmpty && consulta.toLowerCase() != 'fiction') {
            return _buscarPorAutor(consulta);
          }
          return [];
        }
        return books.map<Libro>((book) => _mapearLibro(book as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error en LibriVox: $e');
      return [];
    }
  }

  Future<Libro?> obtenerDetalles(String id) async {
    return null; 
  }

  Future<List<Libro>> _buscarPorAutor(String consulta) async {
    try {
      final url = '$_urlBase?author=%5E${Uri.encodeComponent(consulta)}&format=json';
      final respuesta = await http.get(Uri.parse(url));
      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final books = (datos is Map) ? datos['books'] : datos;
        if (books != null && books is List) {
          return books.map<Libro>((book) => _mapearLibro(book as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {}
    return [];
  }

  String _mapearGenero(String genero) {
    final Map<String, String> mapa = {
      'Ficción': 'Fiction',
      'Ciencia Ficción': 'Science Fiction',
      'Fantasía': 'Fantasy',
      'Romance': 'Romance',
      'Misterio': 'Mystery',
      'Terror': 'Horror',
      'No Ficción': 'Non-fiction',
      'Biografía': 'Biography',
      'Historia': 'History',
      'Poesía': 'Poetry',
      'Drama': 'Drama',
      'Aventura': 'Adventure',
      'Infantil': 'Children',
      'Juvenil': 'Young Adult',
      'Autoayuda': 'Self-Help',
    };
    return mapa[genero] ?? genero;
  }

  Libro _mapearLibro(Map<String, dynamic> json) {
    List<String> autores = [];
    if (json['authors'] != null && json['authors'] is List) {
      autores = (json['authors'] as List).map<String>((a) {
        return '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
      }).toList();
    }

    final id = json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    return Libro(
      id: 'librivox_$id',
      titulo: json['title'] ?? 'Título no disponible',
      autores: autores,
      descripcion: _limpiarHtml(json['description']) ?? 'Audiolibro gratuito',
      urlLectura: json['url_librivox'],
      esAudiolibro: true,
      urlVistaPrevia: json['url_zip_file'],
      precio: 0.0,
      moneda: 'EUR',
    );
  }

  String? _limpiarHtml(String? texto) {
    if (texto == null) return null;
    return texto.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }
}
