import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';
import 'traductor_service.dart';

class GoogleBooksService {
  static const String _urlBase = 'https://www.googleapis.com/books/v1';
  final TraductorService _traductorService = TraductorService();
  final String? _apiKey;

  GoogleBooksService({String? apiKey}) : _apiKey = apiKey;

  Future<List<Libro>> buscarLibros(String consulta, {String? genero, int limite = 20, String pais = 'ES'}) async {
    try {
      String query = Uri.encodeComponent(consulta);
      if (genero != null && genero != 'Todos los géneros') {
        query += '+subject:${Uri.encodeComponent(genero)}';
      }

      String url = '$_urlBase/volumes?q=$query&maxResults=$limite&country=$pais';
      url += '&langRestrict=es'; 
      url += '&projection=lite'; 
      
      if (_apiKey != null && _apiKey.isNotEmpty) {
        url += '&key=$_apiKey';
      }

      final respuesta = await http.get(Uri.parse(url));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final List<dynamic> items = datos['items'] ?? [];
        return items.map((item) => _mapearLibro(item)).toList();
      } else {
        print('Error en Google Books: ${respuesta.statusCode} - ${respuesta.body}');
        return [];
      }
    } catch (e) {
      print('Error de conexión con Google Books: $e');
      return [];
    }
  }

  Future<Libro?> obtenerDetalles(String id) async {
    try {
      final idLimpio = id.replaceFirst('google_', '');
      String url = '$_urlBase/volumes/$idLimpio?country=ES&projection=full';
      url += '&langRestrict=es'; 
      if (_apiKey != null && _apiKey.isNotEmpty) {
        url += '&key=$_apiKey';
      }
      
      final respuesta = await http.get(Uri.parse(url));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        return _mapearLibro(datos);
      }
      return null;
    } catch (e) {
      print('Error obteniendo detalles en Google Books: $e');
      return null;
    }
  }

  Libro _mapearLibro(Map<String, dynamic> json) {
    final info = json['volumeInfo'] ?? {};
    final imagenes = info['imageLinks'] ?? {};
    final ventaInfo = json['saleInfo'] ?? {};
    final identificadores = info['industryIdentifiers'] ?? [];
    
    double? precio;
    String? moneda;
    String? isbn10;
    String? isbn13;
    String? urlCompra;
    List<OfertaTienda> ofertas = [];

    // VERIFICAR MÚLTIPLES PRECIOS
    if (ventaInfo['saleability'] == 'FOR_SALE') {
      // Intentar precio de lista primero
      precio = (ventaInfo['listPrice']?['amount'] as num?)?.toDouble();
      moneda = ventaInfo['listPrice']?['currencyCode'];
      
      // Si no hay precio de lista, intentar precio minorista
      if (precio == null && ventaInfo['retailPrice'] != null) {
        precio = (ventaInfo['retailPrice']?['amount'] as num?)?.toDouble();
        moneda = ventaInfo['retailPrice']?['currencyCode'];
      }
      
      urlCompra = ventaInfo['buyLink'];
      
      // Verificar si es un eBook o libro físico
      bool esEbook = ventaInfo['isEbook'] == true;
      String tipo = esEbook ? 'eBook' : 'Libro físico';
      
      if (urlCompra != null && precio != null) {
        ofertas.add(OfertaTienda(
          tienda: 'Google Play Books ($tipo)',
          precio: precio,
          moneda: moneda ?? '€',
          url: urlCompra,
        ));
      }
    }

    // Extraer ISBNs
    for (var id in identificadores) {
      if (id['type'] == 'ISBN_10') {
        isbn10 = id['identifier'];
      } else if (id['type'] == 'ISBN_13') {
        isbn13 = id['identifier'];
      }
    }

    return Libro(
      id: 'google_${json['id']}',
      titulo: info['title'] ?? 'Título no disponible',
      autores: List<String>.from(info['authors'] ?? []),
      descripcion: _limpiarHtml(info['description']),
      urlMiniatura: imagenes['thumbnail'] ?? imagenes['smallThumbnail'],
      fechaPublicacion: info['publishedDate'],
      numeroPaginas: info['pageCount'],
      categorias: List<String>.from(info['categories'] ?? []),
      calificacionPromedio: info['averageRating']?.toDouble(),
      numeroCalificaciones: info['ratingsCount'],
      urlLectura: info['previewLink'],
      precio: precio,
      moneda: moneda,
      isbn10: isbn10,
      isbn13: isbn13,
      urlCompra: urlCompra,
      ofertas: ofertas,
    );
  }

  String? _limpiarHtml(String? texto) {
    if (texto == null) return null;
    return texto.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }
}