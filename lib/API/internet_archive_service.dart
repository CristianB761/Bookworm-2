import 'dart:convert';
import 'package:http/http.dart' as http;
import 'modelos.dart';
import 'traductor_service.dart'; 

class InternetArchiveService {
  static const String _urlBase = 'https://archive.org/advancedsearch.php';
  final TraductorService _traductorService = TraductorService();

  Future<List<Libro>> buscarLibros(String consulta, {String? genero, int limite = 20}) async {
    if (consulta.isEmpty) return [];
    
    try {
      String query = 'title:($consulta) AND mediatype:(texts)';
      
      query += ' AND (languageS:(spanish) OR languageS:(spa) OR language:(spanish) OR language:(spa))';
      
      if (genero != null && genero != 'Todos los géneros') {
        query += ' AND subject:(${Uri.encodeComponent(genero)})';
      }
      
      final fields = [
        'identifier',
        'title',
        'creator',
        'description',
        'date',
        'subject',
        'languageS',
        'language'
      ];
      
      final url = '$_urlBase?q=${Uri.encodeComponent(query)}'
                  '&rows=$limite'
                  '&output=json'
                  '&fl=${fields.join(",")}'
                  '&sort[]=downloads+desc';
      
      final respuesta = await http.get(Uri.parse(url));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final List<dynamic> docs = datos['response']?['docs'] ?? [];
        
        final libros = <Libro>[];
        for (var doc in docs) {
          try {
            final libro = await _mapearLibro(doc);
            libros.add(libro);
          } catch (e) {
            print('Error mapeando documento: $e');
            continue;
          }
        }
        
        if (libros.length < 5 && consulta.isNotEmpty) {
          return await _buscarSinFiltroIdioma(consulta, genero: genero, limite: limite);
        }
        
        return libros;
      }
      return [];
    } catch (e) {
      print('Error en Internet Archive: $e');
      return [];
    }
  }

  Future<List<Libro>> _buscarSinFiltroIdioma(String consulta, {String? genero, int limite = 20}) async {
    try {
      String query = 'title:($consulta) AND mediatype:(texts)';
      
      if (genero != null && genero != 'Todos los géneros') {
        query += ' AND subject:(${Uri.encodeComponent(genero)})';
      }
      
      final url = '$_urlBase?q=${Uri.encodeComponent(query)}'
                  '&rows=$limite'
                  '&output=json'
                  '&fl=identifier,title,creator,description,date,subject,languageS,language'
                  '&sort[]=downloads+desc';
      
      final respuesta = await http.get(Uri.parse(url));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final List<dynamic> docs = datos['response']?['docs'] ?? [];
        
        final libros = <Libro>[];
        for (var doc in docs) {
          try {
            final libro = await _mapearLibro(doc);
            libros.add(libro);
          } catch (e) {
            print('Error mapeando documento en búsqueda sin filtro: $e');
            continue;
          }
        }
        
        return libros;
      }
      return [];
    } catch (e) {
      print('Error en búsqueda sin filtro: $e');
      return [];
    }
  }

  Future<Libro?> obtenerDetalles(String id) async {
    try {
      final idLimpio = id.replaceFirst('ia_', '');
      final url = 'https://archive.org/metadata/$idLimpio';
      final respuesta = await http.get(Uri.parse(url));

      if (respuesta.statusCode == 200) {
        final datos = json.decode(respuesta.body);
        final metadata = datos['metadata'];
        if (metadata != null) {
          final libro = await _mapearLibro({...metadata, 'identifier': idLimpio});
          return await _mejorarDescripcionEspanol(libro);
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo detalles en Internet Archive: $e');
      return null;
    }
  }

  Future<Libro> _mapearLibro(Map<String, dynamic> doc) async {
    final identifier = doc['identifier']?.toString() ?? '';
    
    List<String> autores = [];
    final creator = doc['creator'];
    
    if (creator != null) {
      if (creator is List) {
        autores = creator.map((item) {
          if (item == null) return 'Autor desconocido';
          return item.toString();
        }).toList().cast<String>();
      } else if (creator is String) {
        autores = [creator];
      } else {
        autores = [creator.toString()];
      }
    }

    final idiomaRaw = doc['languageS'] ?? doc['language'];
    List<String> idiomas = [];

    if (idiomaRaw != null) {
      if (idiomaRaw is List) {
        idiomas = idiomaRaw.map((item) {
          if (item == null) return '';
          return item.toString();
        }).where((item) => item.isNotEmpty).toList().cast<String>();
      } else if (idiomaRaw is String) {
        idiomas = idiomaRaw.split(',').map((i) => i.trim()).where((i) => i.isNotEmpty).toList();
      } else {
        idiomas = [idiomaRaw.toString()];
      }
    }

    String? descripcionOriginal = _limpiarHtml(doc['description']);
    String descripcion = descripcionOriginal ?? '';
    
    if (descripcion.isEmpty || _traductorService.esTextoIngles(descripcion)) {
      final idiomasStr = idiomas.isNotEmpty ? ' Disponible en: ${idiomas.join(", ")}.' : '';
      final fechaRaw = doc['date'];
      String? fecha;
      
      if (fechaRaw != null) {
        if (fechaRaw is String) {
          fecha = fechaRaw.split('-')[0];
        } else {
          fecha = fechaRaw.toString().split('-')[0];
        }
      }
      
      final fechaStr = fecha != null && fecha.isNotEmpty ? ' Publicado originalmente en $fecha.' : '';
      
      descripcion = 'Documento digital disponible en Internet Archive.$fechaStr$idiomasStr '
                    'Forma parte de la biblioteca digital de acceso libre.';
    } else if (descripcionOriginal != null && _traductorService.esTextoIngles(descripcionOriginal)) {
      final traducido = await _traductorService.traducirTexto(descripcionOriginal);
      if (traducido != null && traducido.isNotEmpty) {
        descripcion = traducido;
      }
    }

    List<String> categorias = [];
    final subject = doc['subject'];
    
    if (subject != null) {
      if (subject is List) {
        categorias = subject.take(3).map((item) {
          if (item == null) return '';
          return item.toString();
        }).where((item) => item.isNotEmpty).toList().cast<String>();
      } else if (subject is String) {
        categorias = [subject];
      } else {
        categorias = [subject.toString()];
      }
    }

    return Libro(
      id: 'ia_$identifier',
      titulo: doc['title']?.toString() ?? 'Sin título',
      autores: autores,
      descripcion: descripcion,
      urlMiniatura: identifier.isNotEmpty ? 'https://archive.org/services/img/$identifier' : null,
      fechaPublicacion: _extraerFecha(doc['date']),
      categorias: categorias,
      urlLectura: identifier.isNotEmpty ? 'https://archive.org/details/$identifier' : null,
      precio: 0.0,
      moneda: 'EUR',
    );
  }

  String? _extraerFecha(dynamic fechaRaw) {
    if (fechaRaw == null) return null;
    
    if (fechaRaw is String) {
      return fechaRaw.split('-')[0];
    } else if (fechaRaw is DateTime) {
      return fechaRaw.year.toString();
    } else {
      final fechaStr = fechaRaw.toString();
      return fechaStr.split('-')[0];
    }
  }

  String? _limpiarHtml(dynamic texto) {
    if (texto == null) return null;
    
    String textoStr;
    if (texto is List) {
      textoStr = texto.map((item) => item?.toString() ?? '').join(' ');
    } else {
      textoStr = texto.toString();
    }
    
    if (textoStr.isEmpty) return null;
    
    return textoStr.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  Future<Libro> _mejorarDescripcionEspanol(Libro libro) async {
    if (libro.descripcion == null || libro.descripcion!.isEmpty) {
      return libro;
    }
    
    final descripcion = libro.descripcion!;
    
    if (_traductorService.esTextoIngles(descripcion)) {
      final autoresStr = libro.autores.isNotEmpty ? ' Autor(es): ${libro.autores.join(", ")}.' : '';
      final fechaStr = libro.fechaPublicacion != null ? ' Fecha: ${libro.fechaPublicacion}.' : '';
      final categoriasStr = libro.categorias.isNotEmpty ? ' Temas: ${libro.categorias.join(", ")}.' : '';
      
      final nuevaDescripcion = 'Documento digital "${libro.titulo}" disponible en Internet Archive.$autoresStr$fechaStr$categoriasStr '
                               'Acceso gratuito a este material de dominio público o con licencias abiertas.';
      
      return libro.copyWith(descripcion: nuevaDescripcion);
    }
    
    return libro;
  }
}