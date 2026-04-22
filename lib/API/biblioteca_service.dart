
import 'gutendex_service.dart';
import 'internet_archive_service.dart';
import 'open_library.dart';
import 'librivox_service.dart';
import 'mangadex_service.dart';
import 'anilist_service.dart';
import 'modelos.dart';

class BibliotecaServiceUnificado {
  final GutendexService _gutendexService;
  final InternetArchiveService _archiveService;
  final OpenLibraryService _openLibraryService;
  final LibriVoxService _librivoxService;
  final MangaDexService _mangaDexService;
  final AniListService _aniListService;

  BibliotecaServiceUnificado()
    : _gutendexService = GutendexService(),
      _archiveService = InternetArchiveService(),
      _openLibraryService = OpenLibraryService(),
      _librivoxService = LibriVoxService(),
      _mangaDexService = MangaDexService(),
      _aniListService = AniListService();

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
      // Error en búsqueda unificada
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
      // Error obteniendo detalles
    }

    return libro;
  }
  
  Future<List<Libro>> obtenerLibrosPopulares({int limite = 20}) async {
    final List<Libro> todosLibros = [];

    try {
      final libros = await _gutendexService.obtenerLibrosPopulares(limite: limite);
      todosLibros.addAll(libros);
    } catch (e) {
      // Error obteniendo populares
    }

    return todosLibros.take(limite).toList();
  }

  Future<List<Manga>> buscarManga(String consulta, {int limite = 20}) async {
    try {
      print('📚 Servicio: Buscando manga "$consulta"');
      final mangas = await _mangaDexService.buscarManga(consulta, limite: limite);
      print('📚 Servicio: Encontrados ${mangas.length} mangas');

      // Enriquecer con datos de AniList en paralelo
      final mangasEnriquecidas = await Future.wait(
        mangas.map((m) => _aniListService.enriquecerMangaConAniList(m)),
        eagerError: false,
      );

      return mangasEnriquecidas;
    } catch (e) {
      print('❌ Error en servicio: $e');
      return [];
    }
  }

  Future<Manga?> obtenerDetallesManga(String id) async {
    try {
      final manga = await _mangaDexService.obtenerDetalles(id);
      if (manga != null) {
        return await _aniListService.enriquecerMangaConAniList(manga);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Manga>> obtenerMangasPopulares({int limite = 20}) async {
    try {
      final mangas = await _mangaDexService.obtenerPopulares(limite: limite);

      // Enriquecer con datos de AniList
      final mangasEnriquecidas = await Future.wait(
        mangas.map((m) => _aniListService.enriquecerMangaConAniList(m)),
        eagerError: false,
      );

      return mangasEnriquecidas;
    } catch (e) {
      return [];
    }
  }
}