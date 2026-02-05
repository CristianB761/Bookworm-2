import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';
import 'traductor_service.dart';

class GutendexService {
  static const String _urlBase = 'https://gutendex.com/books';
  final TraductorService _traductorService = TraductorService();

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
        
        return await _filtrarPorIdioma(libros);
      }
      return [];
    } catch (e) {
      print('Error en Gutendex: $e');
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
        
        return await _filtrarPorIdioma(libros);
      }
      return [];
    } catch (e) {
      print('Error obteniendo populares en Gutendex: $e');
      return [];
    }
  }

  Future<Libro?> obtenerDetalles(String id) async {
    try {
      final idLimpio = id.replaceFirst('guten_', '');
      final respuesta = await http.get(Uri.parse('$_urlBase/$idLimpio'));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        return await _mejorarDescripcionEspanol(_mapearLibro(datos));
      }
      return null;
    } catch (e) {
      print('Error obteniendo detalles en Gutendex: $e');
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

    String? rawDescripcion = json['description'];
    String descripcion;
    
    if (rawDescripcion != null && rawDescripcion.isNotEmpty) {
      descripcion = _limpiarHtml(rawDescripcion)!;
    } else {
      final subjects = (json['subjects'] as List?)?.join(', ') ?? '';
      final bookshelves = (json['bookshelves'] as List?)?.join(', ') ?? '';
      final languages = (json['languages'] as List?)?.join(', ') ?? '';
      
      descripcion = '';
      if (subjects.isNotEmpty) {
        descripcion += 'Temas: $subjects. ';
      }
      if (bookshelves.isNotEmpty) {
        descripcion += 'Colecciones: $bookshelves. ';
      }
      if (languages.isNotEmpty) {
        descripcion += 'Idiomas disponibles: $languages. ';
      }
      
      if (descripcion.isEmpty) {
        descripcion = 'Libro clásico de dominio público disponible gratuitamente en Project Gutenberg.';
      }
    }

    final languages = (json['languages'] as List?)?.map((l) => l.toString()).toList() ?? [];

    return Libro(
      id: 'guten_${json['id']}',
      titulo: json['title'] ?? 'Título no disponible',
      autores: (json['authors'] as List?)?.map((a) => a['name'] as String).toList() ?? [],
      descripcion: descripcion,
      urlMiniatura: formats['image/jpeg'],
      categorias: List<String>.from(json['bookshelves'] ?? []),
      numeroCalificaciones: json['download_count'],
      urlLectura: urlLectura,
      precio: 0.0,
      moneda: 'EUR',
    );
  }

  String? _limpiarHtml(String? texto) {
    if (texto == null) return null;
    return texto.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  Future<Libro> _mejorarDescripcionEspanol(Libro libro) async {
    if (libro.descripcion == null || libro.descripcion!.isEmpty) {
      return libro;
    }
    
    final descripcion = libro.descripcion!;
    
    if (_esTextoIngles(descripcion)) {
      final autoresStr = libro.autores.isNotEmpty ? ' de ${libro.autores.join(', ')}' : '';
      final categoriasStr = libro.categorias.isNotEmpty ? ' Género: ${libro.categorias.join(', ')}.' : '';
      
      final nuevaDescripcion = 'Este libro titulado "${libro.titulo}"$autoresStr '
          'es una obra clásica de dominio público disponible gratuitamente en Project Gutenberg.$categoriasStr '
          'Forma parte de la colección de literatura universal en formato digital.';
      
      return libro.copyWith(descripcion: nuevaDescripcion);
    }
    
    return libro;
  }

  bool _esTextoIngles(String texto) {
    final palabrasIngles = ['the', 'and', 'of', 'to', 'in', 'is', 'that', 'for', 'it', 'with', 'as', 'was', 'on'];
    final textoLower = texto.toLowerCase();
    int countIngles = 0;
    
    for (var palabra in palabrasIngles) {
      final regex = RegExp(r'\b' + palabra + r'\b');
      if (regex.hasMatch(textoLower)) {
        countIngles++;
      }
      if (countIngles >= 3) return true; // Si encuentra 3 palabras inglesas comunes
    }
    
    return false;
  }

  Future<List<Libro>> _filtrarPorIdioma(List<Libro> libros) async {
    final librosPriorizados = <Libro>[];
    final otrosLibros = <Libro>[];
    
    for (var libro in libros) {
      if (_tieneIndiciosEspanol(libro)) {
        librosPriorizados.add(libro);
      } else {
        otrosLibros.add(libro);
      }
    }
    
    return [...librosPriorizados, ...otrosLibros];
  }

  bool _tieneIndiciosEspanol(Libro libro) {
    final tituloLower = libro.titulo.toLowerCase();
    final autoresLower = libro.autores.join(' ').toLowerCase();
    
    final palabrasEspanol = [
      'el', 'la', 'los', 'las', 'del', 'de', 'que', 'y', 'en', 'un', 'una', 'unos', 'unas',
      'don', 'doña', 'señor', 'señora', 'novela', 'poesía', 'historia', 'español', 'española'
    ];
    
    for (var palabra in palabrasEspanol) {
      if (tituloLower.contains(palabra) || autoresLower.contains(palabra)) {
        return true;
      }
    }
    
    final autoresHispanos = [
      'cervantes', 'garcía', 'lorca', 'neruda', 'borges', 'cortázar', 'marquez',
      'vallarta', 'paz', 'fuentes', 'allende', 'vargas llosa', 'unamuno', 'góngora'
    ];
    
    for (var autor in autoresHispanos) {
      if (autoresLower.contains(autor)) {
        return true;
      }
    }
    
    return false;
  }
}