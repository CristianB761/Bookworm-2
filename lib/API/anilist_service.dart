import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';

class AniListService {
  static const String _url = 'https://graphql.anilist.co';

  Future<Manga> enriquecerMangaConAniList(Manga manga) async {
    try {
      final datosAniList = await _buscarMangaEnAniList(manga.titulo);
      if (datosAniList == null) return manga;

      return manga.copyWith(
        calificacionAniList:
            _toDouble(datosAniList['meanScore']),
        popularidad:
            _toDouble(datosAniList['popularity']),
        generos: (datosAniList['genres'] as List?)
            ?.map((g) => g.toString())
            .toList() ??
            manga.generos,
        adaptacionAnime: _obtenerAdaptacionAnime(datosAniList),
        urlAniList: 'https://anilist.co/manga/${datosAniList['id']}',
        fechaPublicacion: _obtenerFechaPublicacion(datosAniList),
      );
    } catch (e) {
      return manga;
    }
  }

  Future<Map<String, dynamic>?> _buscarMangaEnAniList(
      String titulo) async {
    try {
      final query = '''
        query {
          Media(search: "${_escaparComillas(titulo)}", type: MANGA) {
            id
            title {
              english
              romaji
            }
            meanScore
            popularity
            genres
            status
            startDate {
              year
              month
              day
            }
            relations {
              edges {
                relationType
                node {
                  id
                  title {
                    english
                    romaji
                  }
                  type
                }
              }
            }
          }
        }
      ''';

      final respuesta = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'query': query}),
      );

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final media = datos['data']?['Media'];
        if (media != null) {
          return media;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String? _obtenerAdaptacionAnime(Map<String, dynamic> anilistData) {
    final relations = anilistData['relations'] as Map<String, dynamic>?;
    if (relations == null) return null;

    final edges = relations['edges'] as List?;
    if (edges == null) return null;

    for (final edge in edges) {
      final relationType = edge['relationType'] as String?;
      if (relationType == 'ADAPTATION') {
        final node = edge['node'] as Map<String, dynamic>?;
        if (node != null && node['type'] == 'ANIME') {
          final title = node['title'] as Map<String, dynamic>?;
          return title?['english'] ?? title?['romaji'] ?? 'Adaptación anime';
        }
      }
    }

    return null;
  }

  String? _obtenerFechaPublicacion(Map<String, dynamic> anilistData) {
    final startDate = anilistData['startDate'] as Map<String, dynamic>?;
    if (startDate != null) {
      final year = startDate['year'];
      if (year != null) {
        return year.toString();
      }
    }
    return null;
  }

  String _escaparComillas(String texto) {
    return texto.replaceAll('"', '\\"');
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}