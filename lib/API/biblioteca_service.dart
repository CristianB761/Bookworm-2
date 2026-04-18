import 'ollama_service.dart';
import 'gutendex_service.dart';
import 'internet_archive_service.dart';
import 'open_library.dart';
import 'librivox_service.dart';
import 'modelos.dart';

class BibliotecaServiceUnificado {
  final GutendexService _gutendexService;
  final InternetArchiveService _archiveService;
  final OpenLibraryService _openLibraryService;
  final LibriVoxService _librivoxService;

  BibliotecaServiceUnificado()
    : _gutendexService = GutendexService(),
      _archiveService = InternetArchiveService(),
      _openLibraryService = OpenLibraryService(),
      _librivoxService = LibriVoxService() {
      }

  Future<List<Libro>> buscarLibros(String consulta, {String? genero, int limite = 20}) async {
    final List<Libro> todosLibros = [];

    final futures = [
      _gutendexService.buscarLibros(consulta, genero: genero, limite: limite),
      _archiveService.buscarLibros(consulta, genero: genero, limite: limite),
      _openLibraryService.buscarLibros(consulta, genero: genero, limite: limite),
      _librivoxService.buscarLibros(consulta, genero: genero, limite: limite),
    ];

    try {
      final resultados = await Future.wait(futures);
      for (var libros in resultados) {
        todosLibros.addAll(libros);
      }
    } catch (e) {
      print('Error en búsqueda unificada: $e');
    }

    return todosLibros;
  }

  Future<Libro?> obtenerDetalles(String id) async {
    Libro? libro;

    try {
      if (id.startsWith('guten_')) {
        libro = await _gutendexService.obtenerDetalles(id);
      } else if (id.startsWith('ia_')) {
        libro = await _archiveService.obtenerDetalles(id);
      } else if (id.startsWith('ol_')) {
        libro = await _openLibraryService.obtenerDetalles(id);
      } else if (id.startsWith('librivox_')) {
        libro = await _librivoxService.obtenerDetalles(id);
      }
    } catch (e) {
      print('Error obteniendo detalles unificados: $e');
    }

    return libro;
  }
  
  Future<List<Libro>> obtenerLibrosPopulares({int limite = 20}) async {
    final List<Libro> todosLibros = [];
    
    try {
      final libros = await _gutendexService.obtenerLibrosPopulares(limite: limite);
      todosLibros.addAll(libros);
    } catch (e) {
      print('Error obteniendo populares: $e');
    }
    
    return todosLibros.take(limite).toList();
  }
}