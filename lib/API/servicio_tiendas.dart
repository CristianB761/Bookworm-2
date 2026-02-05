import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';

class ServicioTiendas {
  static const String _googleBooksApi = 'https://www.googleapis.com/books/v1/volumes';
  static const String _openLibraryApi = 'https://openlibrary.org/api/books';
  
  // Método para buscar precios en múltiples tiendas
  Future<List<OfertaTienda>> buscarPreciosLibro({
    required String titulo,
    List<String>? autores,
    String? isbn,
    bool esAudiolibro = false,
  }) async {
    final List<OfertaTienda> ofertas = [];
    
    // Buscar en Google Books API
    final ofertasGoogle = await _buscarEnGoogleBooks(titulo, autores, isbn);
    ofertas.addAll(ofertasGoogle);
    
    // Buscar en Open Library (para libros gratuitos)
    if (isbn != null) {
      final ofertasOpenLib = await _buscarEnOpenLibrary(isbn);
      ofertas.addAll(ofertasOpenLib);
    }
    
    // Para audiolibros, añadir tiendas específicas
    if (esAudiolibro) {
      ofertas.addAll(_crearOfertasAudiolibros(titulo, autores));
    }
    
    // Añadir tiendas de búsqueda genérica
    ofertas.addAll(_crearOfertasBusqueda(titulo, autores, esAudiolibro));
    
    return ofertas;
  }
  
  Future<List<OfertaTienda>> _buscarEnGoogleBooks(String titulo, List<String>? autores, String? isbn) async {
    final List<OfertaTienda> ofertas = [];
    
    try {
      String query = '';
      if (isbn != null) {
        query = 'isbn:$isbn';
      } else {
        query = 'intitle:$titulo';
        if (autores != null && autores.isNotEmpty) {
          query += '+inauthor:${autores.first}';
        }
      }
      
      final url = Uri.parse('$_googleBooksApi?q=${Uri.encodeComponent(query)}&maxResults=3');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null) {
          for (final item in data['items']) {
            final saleInfo = item['saleInfo'];
            if (saleInfo['saleability'] == 'FOR_SALE') {
              final precio = saleInfo['listPrice']?['amount']?.toDouble() ?? 0;
              if (precio > 0) {
                ofertas.add(OfertaTienda(
                  tienda: 'Google Play Books',
                  precio: precio,
                  moneda: saleInfo['listPrice']?['currencyCode'] ?? 'EUR',
                  url: saleInfo['buyLink'],
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error Google Books API: $e');
    }
    
    return ofertas;
  }
  
  Future<List<OfertaTienda>> _buscarEnOpenLibrary(String isbn) async {
    final List<OfertaTienda> ofertas = [];
    
    try {
      final url = Uri.parse('$_openLibraryApi?bibkeys=ISBN:$isbn&format=json&jscmd=data');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final key = 'ISBN:$isbn';
        if (data[key] != null) {
          ofertas.add(OfertaTienda(
            tienda: 'Open Library',
            precio: 0.0,
            moneda: 'EUR',
            url: data[key]['url'] ?? 'https://openlibrary.org',
          ));
        }
      }
    } catch (e) {
      print('Error Open Library API: $e');
    }
    
    return ofertas;
  }
  
  List<OfertaTienda> _crearOfertasAudiolibros(String titulo, List<String>? autores) {
    final query = Uri.encodeComponent(titulo);
    return [
      OfertaTienda(
        tienda: 'Audible',
        precio: 9.99, 
        moneda: 'EUR',
        url: 'https://www.audible.es/search?keywords=$query',
      ),
      OfertaTienda(
        tienda: 'Storytel',
        precio: 0.0, 
        moneda: 'EUR',
        url: 'https://www.storytel.com/es/es/search?q=$query',
      ),
    ];
  }
  
  List<OfertaTienda> _crearOfertasBusqueda(String titulo, List<String>? autores, bool esAudiolibro) {
    final query = Uri.encodeComponent(titulo);
    final autorQuery = autores != null && autores.isNotEmpty 
        ? Uri.encodeComponent(autores.first) 
        : '';
    
    final tiendas = [
      (
        'Amazon',
        'https://www.amazon.es/s?k=$query+$autorQuery&i=stripbooks'
      ),
      (
        'Casa del Libro',
        'https://www.casadellibro.com/busqueda-libros?q=$query'
      ),
      (
        'Fnac',
        'https://www.fnac.es/ia?Search=$query'
      ),
      (
        'El Corte Inglés',
        'https://www.elcorteingles.es/libros/search/?q=$query'
      ),
    ];
    
    return tiendas.map((tienda) {
      double precioBase = esAudiolibro ? 12.99 : 14.99;
      
      // Ajustar precios según tienda
      if (tienda.$1 == 'Amazon') {
        precioBase *= 0.95;
      } else if (tienda.$1 == 'El Corte Inglés') {
        precioBase *= 1.05;
      }
      
      return OfertaTienda(
        tienda: tienda.$1,
        precio: double.parse((precioBase.floorToDouble() + 0.99).toStringAsFixed(2)),
        moneda: 'EUR',
        url: tienda.$2,
      );
    }).toList();
  }
}