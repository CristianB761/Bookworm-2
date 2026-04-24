import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';

class MangaDexService {
  static const String _urlBase = 'https://api.mangadex.org';

  Future<List<Manga>> buscarManga(String consulta, {int limite = 20}) async {
    try {
      if (consulta.isEmpty) return [];

      final encodedQuery = Uri.encodeComponent(consulta);

      String url = '$_urlBase/manga?limit=$limite&includes[]=cover_art&includes[]=author&includes[]=artist&order[followedCount]=desc';

      if (consulta.isNotEmpty) {
        url += '&title=$encodedQuery';
      }

      print('Buscando: $consulta');
      print('URL: $url');

      final respuesta = await http.get(Uri.parse(url));
      print('Status code: ${respuesta.statusCode}');

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final mangasJson = (datos['data'] as List?) ?? [];

        print('Mangas encontrados (raw): ${mangasJson.length}');

        final mangas = <Manga>[];
        for (final mangaJson in mangasJson) {
          final attributes = mangaJson['attributes'] as Map<String, dynamic>?;
          final titleMap = attributes?['title'] as Map<String, dynamic>?;
          final tituloEn = titleMap?['en']?.toString().toLowerCase() ?? '';
          final tituloJa = titleMap?['ja']?.toString().toLowerCase() ?? '';
          if (tituloEn.contains('doujinshi') || tituloJa.contains('doujinshi')) {
            continue;
          }

          final tags = attributes?['tags'] as List? ?? [];
          bool esDoujinshi = false;
          for (final tag in tags) {
            final tagAttr = tag['attributes'] as Map<String, dynamic>?;
            final nameMap = tagAttr?['name'] as Map<String, dynamic>?;
            final nombreTag = nameMap?['en']?.toString().toLowerCase() ?? '';
            if (nombreTag.contains('doujinshi')) {
              esDoujinshi = true;
              break;
            }
          }
          if (esDoujinshi) continue;

          final manga = _mapearManga(mangaJson);
          if (consulta.isEmpty || manga.titulo.toLowerCase().contains(consulta.toLowerCase())) {
            mangas.add(manga);
          }
        }

        print('Mangas después de filtrar: ${mangas.length}');
        return mangas.take(limite).toList();
      } else if (respuesta.statusCode == 404) {
        print('404, intentando búsqueda general...');
        return await _buscarGeneral(consulta, limite);
      } else {
        print('Error HTTP: ${respuesta.statusCode}');
        print('Respuesta: ${respuesta.body}');
        return [];
      }
    } catch (e) {
      print('Excepción: $e');
      return [];
    }
  }

  Future<List<Manga>> _buscarGeneral(String consulta, int limite) async {
    try {
      final url = Uri.parse('$_urlBase/manga?limit=$limite&includes[]=cover_art&includes[]=author&includes[]=artist&order[followedCount]=desc');

      final respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final mangasJson = (datos['data'] as List?) ?? [];

        final mangasFiltrados = mangasJson.where((manga) {
          final attrs = manga['attributes'] as Map<String, dynamic>?;
          final title = attrs?['title'] as Map<String, dynamic>?;
          final titleEn = title?['en']?.toString().toLowerCase() ?? '';
          final titleJa = title?['ja']?.toString().toLowerCase() ?? '';
          final queryLower = consulta.toLowerCase();
          if (titleEn.contains('doujinshi') || titleJa.contains('doujinshi')) return false;
          final tags = attrs?['tags'] as List? ?? [];
          for (final tag in tags) {
            final tagAttr = tag['attributes'] as Map<String, dynamic>?;
            final nameMap = tagAttr?['name'] as Map<String, dynamic>?;
            final nombreTag = nameMap?['en']?.toString().toLowerCase() ?? '';
            if (nombreTag.contains('doujinshi')) return false;
          }
          return titleEn.contains(queryLower) || titleJa.contains(queryLower);
        }).toList();

        print('Búsqueda general encontró: ${mangasFiltrados.length} mangas');

        return mangasFiltrados.take(limite).map((m) => _mapearManga(m)).toList();
      }
      return [];
    } catch (e) {
      print('Error en búsqueda general: $e');
      return [];
    }
  }

  Future<Manga?> obtenerDetalles(String id) async {
    try {
      final idLimpio = id.replaceFirst('mdex_', '');
      final url = Uri.parse(
        '$_urlBase/manga/$idLimpio?includes[]=author&includes[]=artist&includes[]=cover_art',
      );

      final respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        return _mapearManga(datos['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Manga>> obtenerPopulares({int limite = 20}) async {
    try {
      final url = Uri.parse(
        '$_urlBase/manga?limit=$limite&order[followedCount]=desc&includes[]=author&includes[]=artist&includes[]=cover_art',
      );

      final respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final mangasJson = (datos['data'] as List?) ?? [];

        final mangas = <Manga>[];
        for (final m in mangasJson) {
          final attrs = m['attributes'] as Map<String, dynamic>?;
          final titleMap = attrs?['title'] as Map<String, dynamic>?;
          final tituloEn = titleMap?['en']?.toString().toLowerCase() ?? '';
          if (tituloEn.contains('doujinshi')) continue;
          mangas.add(_mapearManga(m));
        }
        return mangas;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Manga _mapearManga(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};
    final relationships = json['relationships'] as List? ?? [];

    final title = attributes['title'] as Map<String, dynamic>?;
    String tituloTexto = title?['es'] ??
                         title?['en'] ??
                         title?['ja'] ??
                         'Título no disponible';

    if (tituloTexto.length > 100 && title?['en'] != null) {
      tituloTexto = title!['en'];
    }

    final description = attributes['description'] as Map<String, dynamic>?;
    String sinopsis = description?['es'] ?? description?['en'] ?? '';

    final status = attributes['status'] as String? ?? '';
    String estadoMapeado = '';
    switch (status) {
      case 'ongoing':
        estadoMapeado = 'En publicación';
        break;
      case 'completed':
        estadoMapeado = 'Finalizado';
        break;
      case 'hiatus':
        estadoMapeado = 'En pausa';
        break;
      default:
        estadoMapeado = status;
    }

    final rating = attributes['rating'] as Map<String, dynamic>?;
    final calificacion = rating?['average'] as num?;

    final autores = <String>[];
    for (final rel in relationships) {
      final relType = rel['type'] as String?;
      if (relType == 'author' || relType == 'artist') {
        final attrs = rel['attributes'] as Map<String, dynamic>?;
        final nombre = attrs?['name'] as String?;
        if (nombre != null && !autores.contains(nombre)) {
          autores.add(nombre);
        }
      }
    }

    String? urlPortada;
    for (final rel in relationships) {
      if (rel['type'] == 'cover_art') {
        final coverAttributes = rel['attributes'] as Map<String, dynamic>?;
        final fileName = coverAttributes?['fileName'] as String?;
        if (fileName != null && id.isNotEmpty) {
          urlPortada = 'https://uploads.mangadex.org/covers/$id/$fileName';
        }
        break;
      }
    }

    final tags = attributes['tags'] as List? ?? [];
    final generos = <String>[];

    final Map<String, String> traduccionGeneros = {
      'Action': 'Acción',
      'Adventure': 'Aventura',
      'Comedy': 'Comedia',
      'Drama': 'Drama',
      'Ecchi': 'Ecchi',
      'Fantasy': 'Fantasía',
      'Horror': 'Terror',
      'Mystery': 'Misterio',
      'Psychological': 'Psicológico',
      'Romance': 'Romance',
      'Sci-Fi': 'Ciencia Ficción',
      'Seinen': 'Seinen',
      'Shoujo': 'Shoujo',
      'Shoujo Ai': 'Shoujo Ai',
      'Shounen': 'Shōnen',
      'Shounen Ai': 'Shōnen Ai',
      'Slice of Life': 'Recuentos de la vida',
      'Sports': 'Deportes',
      'Supernatural': 'Sobrenatural',
      'Thriller': 'Suspense',
      'Tragedy': 'Tragedia',
      'Military': 'Militar',
      'Harem': 'Harem',
      'School': 'Escolar',
      'Martial Arts': 'Artes Marciales',
      'Mecha': 'Mecha',
      'Isekai': 'Isekai',
      'Demons': 'Demonios',
      'Historical': 'Histórico',
      'Samurai': 'Samurái',
      'Vampire': 'Vampiro',
      'Game': 'Juego',
      'Music': 'Música',
      'Parody': 'Parodia',
      'Political': 'Político',
      'Medical': 'Médico',
      'Super Power': 'Superpoderes',
      'Philosophical': 'Filosófico',
      'Magic': 'Magia',
      'Gender Bender': 'Cambio de género',
      'Gore': 'Gore',
      'Adult': 'Adulto',
    };

    for (final tag in tags) {
      final tagAttributes = tag['attributes'] as Map<String, dynamic>?;
      final name = tagAttributes?['name'] as Map<String, dynamic>?;
      final nombreIngles = name?['en'] as String?;
      if (nombreIngles != null) {
        final nombreTraducido = traduccionGeneros[nombreIngles] ?? nombreIngles;
        generos.add(nombreTraducido);
      }
    }

    final startDate = attributes['startDate'] as String?;
    String? fechaPublicacion;
    if (startDate != null && startDate.isNotEmpty) {
      final anioMatch = RegExp(r'^\d{4}').firstMatch(startDate);
      if (anioMatch != null) {
        fechaPublicacion = anioMatch.group(0);
      } else {
        fechaPublicacion = startDate.split('-')[0];
      }
    }

    return Manga(
      id: 'mdex_$id',
      titulo: tituloTexto,
      autores: autores,
      sinopsis: sinopsis.isNotEmpty ? sinopsis : null,
      urlPortada: urlPortada,
      calificacionMangaDex: calificacion?.toDouble(),
      numeroVotos: null,
      popularidad: null,
      estado: estadoMapeado,
      generos: generos.take(10).toList(),
      temas: [],
      ultimoCapituloLanzado: null,
      numeroCapitulos: null,
      adaptacionAnime: null,
      urlMangaDex: 'https://mangadex.org/title/$id',
      urlAniList: null,
      calificacionAniList: null,
      fechaPublicacion: fechaPublicacion,
    );
  }
}