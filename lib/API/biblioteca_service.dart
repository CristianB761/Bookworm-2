import 'ollama_service.dart';  
import 'google_books_service.dart';
import 'gutendex_service.dart';
import 'internet_archive_service.dart';
import 'open_library.dart';
import 'librivox_service.dart';
import 'modelos.dart';

class BibliotecaServiceUnificado {
  final GoogleBooksService _googleService;
  final GutendexService _gutendexService;
  final InternetArchiveService _archiveService;
  final OpenLibraryService _openLibraryService;
  final LibriVoxService _librivoxService;
  final OllamaService _ollamaService; 
  
  bool _ollamaDisponible = false;
  
  BibliotecaServiceUnificado({required String apiKey}) 
    : _googleService = GoogleBooksService(apiKey: apiKey),
      _gutendexService = GutendexService(),
      _archiveService = InternetArchiveService(),
      _openLibraryService = OpenLibraryService(),
      _librivoxService = LibriVoxService(),
      _ollamaService = OllamaService() {
        _inicializarOllama();
      }
  
  Future<void> _inicializarOllama() async {
    _ollamaDisponible = await _ollamaService.verificarDisponibilidad();
    print('Ollama disponible: $_ollamaDisponible');
    if (!_ollamaDisponible) {
      print('ADVERTENCIA: Ollama no está disponible. Las descripciones no se generarán.');
    }
  }

  Future<List<Libro>> buscarLibros(String consulta, {String? genero, int limite = 20}) async {
    final List<Libro> todosLibros = [];
    
    final futures = [
      _googleService.buscarLibros(consulta, genero: genero, limite: limite, pais: 'ES'),
      _gutendexService.buscarLibros(consulta, genero: genero, limite: limite),
      _archiveService.buscarLibros(consulta, genero: genero, limite: limite),
      _openLibraryService.buscarLibros(consulta, genero: genero, limite: limite),
      _librivoxService.buscarLibros(consulta, genero: genero, limite: limite),
    ];
    
    try {
      final resultados = await Future.wait(futures);
      
      for (var libros in resultados) {
        final librosConDescripcionIA = await Future.wait(
          libros.map((libro) => _generarDescripcionConOllama(libro))
        );
        todosLibros.addAll(librosConDescripcionIA);
      }
    } catch (e) {
      print('Error en búsqueda unificada: $e');
    }
    
    return todosLibros;
  }

  Future<Libro> _generarDescripcionConOllama(Libro libro) async {
    if (!_ollamaDisponible) {
      print('⚠️ Ollama no disponible para: ${libro.titulo}');
      // Devolver libro con descripción por defecto
      return libro.copyWith(
        descripcion: '"No se pudo generar descripción con IA. Verifica que Ollama esté ejecutándose en tu ordenador."'
      );
    }
    
    try {
      print('🤖 Generando descripción con IA para: ${libro.titulo}');
      
      final descripcionGenerada = await _ollamaService.generarDescripcionLibro(
        titulo: libro.titulo,
        autores: libro.autores,
        descripcionOriginal: libro.descripcion,
        categorias: libro.categorias,
        anoPublicacion: libro.fechaPublicacion != null 
            ? int.tryParse(libro.fechaPublicacion!.split('-')[0]) 
            : null,
        numeroPaginas: libro.numeroPaginas,
        esAudiolibro: libro.esAudiolibro,
      );
      
      if (descripcionGenerada != null && descripcionGenerada.isNotEmpty) {
        print('✅ Descripción generada para: ${libro.titulo}');
        return libro.copyWith(descripcion: descripcionGenerada);
      } else {
        print('⚠️ No se pudo generar descripción para: ${libro.titulo}');
        return libro.copyWith(
          descripcion: '📖 "${libro.titulo}" - Una obra que vale la pena descubrir. Consulta más detalles en la biblioteca.'
        );
      }
    } catch (e) {
      print('❌ Error generando descripción para ${libro.titulo}: $e');
      return libro.copyWith(
        descripcion: '📚 "${libro.titulo}" - Descripción no disponible temporalmente.'
      );
    }
  }

  Future<Libro?> obtenerDetalles(String id) async {
    Libro? libro;
    
    try {
      if (id.startsWith('google_')) {
        libro = await _googleService.obtenerDetalles(id);
      } else if (id.startsWith('guten_')) {
        libro = await _gutendexService.obtenerDetalles(id);
      } else if (id.startsWith('ia_')) {
        libro = await _archiveService.obtenerDetalles(id);
      } else if (id.startsWith('ol_')) {
        libro = await _openLibraryService.obtenerDetalles(id);
      } else if (id.startsWith('librivox_')) {
        libro = await _librivoxService.obtenerDetalles(id);
      }
      
      if (libro != null) {
        // 🔥 Generar descripción con Ollama también para detalles
        return await _generarDescripcionConOllama(libro);
      }
    } catch (e) {
      print('Error obteniendo detalles unificados: $e');
    }
    
    return null;
  }
  
  Future<List<Libro>> obtenerLibrosPopulares({int limite = 20}) async {
    final List<Libro> todosLibros = [];
    
    try {
      final libros = await _gutendexService.obtenerLibrosPopulares(limite: limite);
      
      // 🔥 Generar descripción con Ollama para cada libro popular
      final librosConDescripcionIA = await Future.wait(
        libros.map((libro) => _generarDescripcionConOllama(libro))
      );
      todosLibros.addAll(librosConDescripcionIA);
      
    } catch (e) {
      print('Error obteniendo populares: $e');
    }
    
    return todosLibros.take(limite).toList();
  }
}