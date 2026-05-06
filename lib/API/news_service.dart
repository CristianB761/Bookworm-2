import 'dart:convert';
import 'package:http/http.dart' as http;

class NoticiaLibro {
  final String titulo;
  final String descripcion;
  final String url;
  final String urlImagen;
  final DateTime fechaPublicacion;
  final String fuente;
  final String autor;

  NoticiaLibro({
    required this.titulo,
    required this.descripcion,
    required this.url,
    required this.urlImagen,
    required this.fechaPublicacion,
    required this.fuente,
    required this.autor,
  });

  factory NoticiaLibro.fromJson(Map<String, dynamic> json) {
    return NoticiaLibro(
      titulo: json['title']?.toString() ?? 'Sin título',
      descripcion: json['description']?.toString() ?? 'Sin descripción',
      url: json['url']?.toString() ?? '',
      urlImagen: json['urlToImage']?.toString() ?? '',
      fechaPublicacion: DateTime.tryParse(json['publishedAt']?.toString() ?? '') ?? DateTime.now(),
      fuente: json['source'] != null && json['source']['name'] != null 
          ? json['source']['name'].toString() 
          : 'Fuente desconocida',
      autor: json['author']?.toString() ?? 'Autor desconocido',
    );
  }
}

class NewsService {
  static const String _apiKey = 'c8b33be89a2744d49aa1526a6a31c932';
  static const String _baseUrl = 'https://newsapi.org/v2';

  Future<List<NoticiaLibro>> obtenerNoticiasLibros({int limite = 10, int pagina = 1}) async {
    try {
      final List<String> queries = [
        'libros literatura',
        'novedades literarias',
        'escritores publicaciones',
        'reseñas libros',
        'autores entrevistas'
      ];

      List<NoticiaLibro> todasNoticias = [];

      for (String query in queries) {
        final Uri url = Uri.parse(
          '$_baseUrl/everything?q=${Uri.encodeComponent(query)}&language=es&sortBy=publishedAt&pageSize=5&page=$pagina&apiKey=$_apiKey'
        );

        final http.Response respuesta = await http.get(url);

        if (respuesta.statusCode == 200) {
          final Map<String, dynamic> datos = json.decode(respuesta.body);
          
          if (datos['status'] == 'ok') {
            final List<dynamic> articulos = datos['articles'] ?? [];
            
            for (var articulo in articulos) {
              if (_esNoticiaValida(articulo)) {
                todasNoticias.add(NoticiaLibro.fromJson(articulo));
              }
            }
          }
        }
        
        await Future.delayed(const Duration(milliseconds: 100));
      }

      todasNoticias.sort((a, b) => b.fechaPublicacion.compareTo(a.fechaPublicacion));
      
      final List<String> idsUnicos = [];
      final List<NoticiaLibro> noticiasUnicas = [];
      
      for (var noticia in todasNoticias) {
        final String id = noticia.url;
        if (!idsUnicos.contains(id)) {
          idsUnicos.add(id);
          noticiasUnicas.add(noticia);
        }
      }
      
      return noticiasUnicas.take(limite).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<NoticiaLibro>> obtenerNoticiasPorAutor(String nombreAutor, {int limite = 5, int pagina = 1}) async {
    if (nombreAutor.isEmpty) return [];
    
    try {
      final String query = '$nombreAutor escritor libros';
      
      final Uri url = Uri.parse(
        '$_baseUrl/everything?q=${Uri.encodeComponent(query)}&language=es&sortBy=publishedAt&pageSize=$limite&page=$pagina&apiKey=$_apiKey'
      );

      final http.Response respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final Map<String, dynamic> datos = json.decode(respuesta.body);
        
        if (datos['status'] == 'ok') {
          final List<dynamic> articulos = datos['articles'] ?? [];
          
          return articulos
              .where((a) => _esNoticiaValida(a as Map<String, dynamic>))
              .map((a) => NoticiaLibro.fromJson(a))
              .take(limite)
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<NoticiaLibro>> obtenerNoticiasDestacadas({int limite = 5, int pagina = 1}) async {
    try {
      final Uri url = Uri.parse(
        '$_baseUrl/top-headlines?q=books&language=es&pageSize=$limite&page=$pagina&apiKey=$_apiKey'
      );

      final http.Response respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final Map<String, dynamic> datos = json.decode(respuesta.body);
        
        if (datos['status'] == 'ok') {
          final List<dynamic> articulos = datos['articles'] ?? [];
          
          return articulos
              .where((a) => _esNoticiaValida(a as Map<String, dynamic>))
              .map((a) => NoticiaLibro.fromJson(a))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<NoticiaLibro>> buscarNoticiasPorCategoria(String categoria, {int limite = 5, int pagina = 1}) async {
    if (categoria.isEmpty) return [];
    
    final Map<String, String> categoriasQuery = {
      'ficcion': 'ficción novela literaria',
      'no-ficcion': 'ensayo divulgación',
      'ciencia-ficcion': 'ciencia ficción fantasía',
      'poesia': 'poesía poemas',
      'infantil': 'literatura infantil cuentos',
      'juvenil': 'juvenil young adult',
      'historia': 'historia libros',
      'biografia': 'biografía memorias',
      'autoayuda': 'autoayuda desarrollo personal',
    };
    
    final String query = categoriasQuery[categoria] ?? '$categoria libros';
    
    try {
      final Uri url = Uri.parse(
        '$_baseUrl/everything?q=${Uri.encodeComponent(query)}&language=es&sortBy=relevancy&pageSize=$limite&page=$pagina&apiKey=$_apiKey'
      );

      final http.Response respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final Map<String, dynamic> datos = json.decode(respuesta.body);
        
        if (datos['status'] == 'ok') {
          final List<dynamic> articulos = datos['articles'] ?? [];
          
          return articulos
              .where((a) => _esNoticiaValida(a as Map<String, dynamic>))
              .map((a) => NoticiaLibro.fromJson(a))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  bool _esNoticiaValida(Map<String, dynamic> articulo) {
    try {
      final String titulo = articulo['title']?.toString() ?? '';
      final String descripcion = articulo['description']?.toString() ?? '';
      final String url = articulo['url']?.toString() ?? '';
      
      if (titulo.contains('[Removed]') || descripcion.contains('[Removed]')) {
        return false;
      }
      
      if (titulo.length < 10) {
        return false;
      }
      
      if (url.isEmpty) {
        return false;
      }
      
      final List<String> palabrasNoDeseadas = [
        'video', 'foto', 'galería', 'gallery', 'watch', 'listen',
        'podcast', 'spotify', 'youtube', 'instagram', 'facebook'
      ];
      
      final String tituloLower = titulo.toLowerCase();
      for (String palabra in palabrasNoDeseadas) {
        if (tituloLower.contains(palabra)) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> verificarApiKey() async {
    try {
      final Uri url = Uri.parse(
        '$_baseUrl/top-headlines?country=us&pageSize=1&apiKey=$_apiKey'
      );
      
      final http.Response respuesta = await http.get(url);
      
      if (respuesta.statusCode == 200) {
        final Map<String, dynamic> datos = json.decode(respuesta.body);
        return datos['status'] == 'ok';
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}