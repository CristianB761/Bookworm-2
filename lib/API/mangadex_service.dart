import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';

class MangaDexService {
  static const String _urlBase = 'https://api.mangadex.org';

  Future<List<Manga>> buscarManga(String consulta, {int limite = 20}) async {
    try {
      if (consulta.isEmpty) return [];
      
      // 🔥 CORRECCIÓN: Usar el endpoint correcto de búsqueda
      final encodedQuery = Uri.encodeComponent(consulta);
      
      // Método 1: Búsqueda por título usando el endpoint de búsqueda
      String url = '$_urlBase/manga?limit=$limite&includes[]=cover_art&includes[]=author&includes[]=artist&order[followedCount]=desc';
      
      // Añadir filtro de título si hay consulta
      if (consulta.isNotEmpty) {
        url += '&title=$encodedQuery';
      }
      
      print('🔍 Buscando: $consulta');
      print('📡 URL: $url');
      
      final respuesta = await http.get(Uri.parse(url));
      print('📊 Status code: ${respuesta.statusCode}');

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final mangasJson = (datos['data'] as List?) ?? [];
        
        print('📚 Mangas encontrados (raw): ${mangasJson.length}');

        final mangas = <Manga>[];
        for (final mangaJson in mangasJson) {
          final manga = _mapearManga(mangaJson);
          // Verificar que el título coincida (filtro adicional)
          if (consulta.isEmpty || 
              manga.titulo.toLowerCase().contains(consulta.toLowerCase())) {
            mangas.add(manga);
          }
        }
        
        print('📚 Mangas después de filtrar: ${mangas.length}');
        return mangas.take(limite).toList();
      } else if (respuesta.statusCode == 404) {
        // Si el endpoint de título falla, usar búsqueda general
        print('⚠️ 404, intentando búsqueda general...');
        return await _buscarGeneral(consulta, limite);
      } else {
        print('❌ Error HTTP: ${respuesta.statusCode}');
        print('📝 Respuesta: ${respuesta.body}');
        return [];
      }
    } catch (e) {
      print('❌ Excepción: $e');
      return [];
    }
  }

  // Método alternativo de búsqueda
  Future<List<Manga>> _buscarGeneral(String consulta, int limite) async {
    try {
      // Usar búsqueda por texto completo
      final url = Uri.parse('$_urlBase/manga?limit=$limite&includes[]=cover_art&includes[]=author&includes[]=artist&order[followedCount]=desc');
      
      final respuesta = await http.get(url);
      
      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final mangasJson = (datos['data'] as List?) ?? [];
        
        // Filtrar manualmente por coincidencia en título
        final mangasFiltrados = mangasJson.where((manga) {
          final attrs = manga['attributes'] as Map<String, dynamic>?;
          final title = attrs?['title'] as Map<String, dynamic>?;
          final titleEn = title?['en']?.toString().toLowerCase() ?? '';
          final titleJa = title?['ja']?.toString().toLowerCase() ?? '';
          final queryLower = consulta.toLowerCase();
          return titleEn.contains(queryLower) || titleJa.contains(queryLower);
        }).toList();
        
        print('📚 Búsqueda general encontró: ${mangasFiltrados.length} mangas');
        
        return mangasFiltrados.take(limite).map((m) => _mapearManga(m)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Error en búsqueda general: $e');
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

    // Obtener título en varios idiomas
    final title = attributes['title'] as Map<String, dynamic>?;
    String tituloTexto = title?['es'] ?? 
                         title?['en'] ?? 
                         title?['ja'] ?? 
                         'Título no disponible';
    
    // Si el título es demasiado largo, usar versión más corta
    if (tituloTexto.length > 100 && title?['en'] != null) {
      tituloTexto = title!['en'];
    }

    // Descripción
    final description = attributes['description'] as Map<String, dynamic>?;
    String sinopsis = description?['es'] ?? description?['en'] ?? '';

    // Estado
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

    // Calificaciones
    final rating = attributes['rating'] as Map<String, dynamic>?;
    final calificacion = rating?['average'] as num?;

    // Autores
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

    // Portada
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

    // Géneros
    final tags = attributes['tags'] as List? ?? [];
    final generos = <String>[];

    for (final tag in tags) {
      final tagAttributes = tag['attributes'] as Map<String, dynamic>?;
      final name = tagAttributes?['name'] as Map<String, dynamic>?;
      final nombre = name?['es'] ?? name?['en'];
      if (nombre != null) {
        generos.add(nombre);
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
    );
  }
}