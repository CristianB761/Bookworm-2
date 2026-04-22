import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';

class MangaDexService {
  static const String _urlBase = 'https://api.mangadex.org/v5';

  Future<List<Manga>> buscarManga(String consulta, {int limite = 20}) async {
    try {
      final url = Uri.parse(
        '$_urlBase/manga?title=${Uri.encodeComponent(consulta)}&limit=$limite&order[rating]=desc&includes[]=author&includes[]=artist&includes[]=cover_art',
      );

      final respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final mangasJson = (datos['data'] as List?) ?? [];

        final mangas = <Manga>[];
        for (final mangaJson in mangasJson) {
          final manga = _mapearManga(mangaJson);
          mangas.add(manga);
        }
        return mangas;
      }
      return [];
    } catch (e) {
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

        return mangasJson.map((m) => _mapearManga(m)).toList();
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

    final titulo = attributes['title'] as Map<String, dynamic>?;
    final tituloTexto = titulo?['en'] ?? 'Título no disponible';

    // Extraer descripción
    final description = attributes['description'] as Map<String, dynamic>?;
    final sinopsis = description?['en'] ?? '';

    // Estado
    final status = attributes['status'] as String? ?? '';
    String estadoMapeado = '';
    switch (status) {
      case 'ongoing':
        estadoMapeado = 'Serializing';
        break;
      case 'completed':
        estadoMapeado = 'Finished';
        break;
      case 'hiatus':
        estadoMapeado = 'Hiatus';
        break;
      default:
        estadoMapeado = status;
    }

    // Calificaciones
    final rating = attributes['rating'] as Map<String, dynamic>?;
    final calificacion = rating?['average'] as num?;

    // Autores
    final autores = <String>[];
    for (final rel in relationships) {
      final relType = rel['type'] as String?;
      if (relType == 'author' || relType == 'artist') {
        final attributes = rel['attributes'] as Map<String, dynamic>?;
        final nombre = attributes?['name'] as String?;
        if (nombre != null) {
          autores.add(nombre);
        }
      }
    }

    // Portada
    String? urlPortada;
    for (final rel in relationships) {
      if (rel['type'] == 'cover_art') {
        final coverAttributes = rel['attributes'] as Map<String, dynamic>?;
        final fileName = coverAttributes?['fileName'] as String?;
        if (fileName != null) {
          urlPortada = 'https://uploads.mangadex.org/covers/$id/$fileName';
        }
        break;
      }
    }

    // Géneros y temas
    final tags = attributes['tags'] as List? ?? [];
    final generos = <String>[];
    final temas = <String>[];

    for (final tag in tags) {
      final tagAttributes = tag['attributes'] as Map<String, dynamic>?;
      final name = tagAttributes?['name'] as Map<String, dynamic>?;
      final nombre = name?['en'] as String?;
      final group = tagAttributes?['group'] as String?;

      if (nombre != null) {
        if (group == 'genre') {
          generos.add(nombre);
        } else if (group == 'theme') {
          temas.add(nombre);
        }
      }
    }

    // Stats
    final statistics = attributes['statistics'] as Map<String, dynamic>?;
    final manga = statistics?['manga:0'] as Map<String, dynamic>?;
    final rating2 = manga?['rating'] as Map<String, dynamic>?;
    final numeroVotos = rating2?['distribution'] != null
        ? (rating2!['distribution'] as Map<String, dynamic>).values
            .fold<int>(0, (sum, count) => sum + (count as int))
        : null;

    return Manga(
      id: 'mdex_$id',
      titulo: tituloTexto,
      autores: autores,
      sinopsis: sinopsis.isNotEmpty ? sinopsis : null,
      urlPortada: urlPortada,
      calificacionMangaDex: calificacion?.toDouble(),
      numeroVotos: numeroVotos,
      estado: estadoMapeado,
      generos: generos.take(10).toList(),
      temas: temas.take(10).toList(),
      urlMangaDex: 'https://mangadex.org/title/$id',
    );
  }
}
