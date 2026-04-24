import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  static const String baseUrl = 'http://localhost:11434';
  final String model;

  OllamaService({this.model = 'phi3:mini'});

  Future<bool> verificarDisponibilidad() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> generarDescripcionLibro({
    required String titulo,
    List<String> autores = const [],
    String? descripcionOriginal,
    List<String> categorias = const [],
    int? anoPublicacion,
    int? numeroPaginas,
    bool esAudiolibro = false,
  }) async {
    try {
      final prompt = _construirPromptCompleto(
        titulo: titulo,
        autores: autores,
        categorias: categorias,
        anoPublicacion: anoPublicacion,
        numeroPaginas: numeroPaginas,
        esAudiolibro: esAudiolibro,
      );

      final response = await http.post(
        Uri.parse('$baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': model,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.8,
            'top_p': 0.9,
            'num_predict': 250,
          },
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final descripcion = data['response'] as String?;
        if (descripcion != null && descripcion.isNotEmpty) {
          return _limpiarDescripcion(descripcion);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> generarDescripcionManga({
    required String titulo,
    List<String> autores = const [],
    String? sinopsisOriginal,
    List<String> generos = const [],
    List<String> temas = const [],
    String? estado,
  }) async {
    try {
      final prompt = _construirPromptManga(
        titulo: titulo,
        autores: autores,
        generos: generos,
        temas: temas,
        estado: estado,
      );

      final response = await http.post(
        Uri.parse('$baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': model,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.8,
            'top_p': 0.9,
            'num_predict': 250,
          },
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final descripcion = data['response'] as String?;
        if (descripcion != null && descripcion.isNotEmpty) {
          return _limpiarDescripcion(descripcion);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _construirPromptCompleto({
    required String titulo,
    required List<String> autores,
    required List<String> categorias,
    int? anoPublicacion,
    int? numeroPaginas,
    bool esAudiolibro = false,
  }) {
    final tipo = esAudiolibro ? 'audiolibro' : 'libro';
    final autoresStr = autores.isNotEmpty ? autores.join(', ') : 'Autor desconocido';
    final categoriasStr = categorias.isNotEmpty ? '\nGéneros: ${categorias.take(3).join(", ")}' : '';
    final anoStr = anoPublicacion != null ? '\nAño de publicación: $anoPublicacion' : '';
    final paginasStr = numeroPaginas != null ? '\nNúmero de páginas: $numeroPaginas' : '';

    return '''Eres un experto crítico literario. Genera una descripción atractiva y profesional en español para el siguiente $tipo:

Título: "$titulo"
Autor(es): $autoresStr$categoriasStr$anoStr$paginasStr

Instrucciones IMPORTANTES:
1. Escribe EXACTAMENTE entre 100 y 200 palabras
2. Usa un tono profesional pero accesible para lectores generales
3. Describe la trama o el contenido de forma general sin spoilers
4. Si es un audiolibro, menciona la experiencia de audio
5. NO incluyas frases como "Aquí tienes..." o "Claro, aquí va..."
6. NO incluyas calificaciones numéricas ni estrellas
7. Comienza directamente con la descripción del libro
8. NO menciones el título del libro
9. NO menciones el nombre del autor
10. NO menciones la fecha de publicación
11. NO menciones el género o subgénero del libro
12. Solo menciona el nombre del protagonista principal, ningún otro personaje debe ser nombrado
13. Narra la historia de forma general, sin revelar eventos clave ni finales

Descripción:''';
  }

  String _construirPromptManga({
    required String titulo,
    required List<String> autores,
    required List<String> generos,
    required List<String> temas,
    String? estado,
  }) {
    final autoresStr = autores.isNotEmpty ? autores.join(', ') : 'Autor desconocido';
    final generosStr = generos.isNotEmpty ? '\nGéneros: ${generos.take(3).join(", ")}' : '';
    final temasStr = temas.isNotEmpty ? '\nTemas: ${temas.take(3).join(", ")}' : '';
    final estadoStr = estado != null ? '\nEstado: $estado' : '';

    return '''Eres un experto en manga y anime. Genera una descripción atractiva y profesional en español para el siguiente manga:

Título: "$titulo"
Autor(es): $autoresStr$generosStr$temasStr$estadoStr

Instrucciones IMPORTANTES:
1. Escribe EXACTAMENTE entre 100 y 200 palabras
2. Usa un tono profesional pero accesible para lectores de manga
3. Describe la trama de forma general sin spoilers
4. Si el manga tiene adaptación al anime, menciónala brevemente (si la hay)
5. NO incluyas frases como "Aquí tienes..." o "Claro, aquí va..."
6. NO incluyas calificaciones numéricas
7. Comienza directamente con la descripción del manga
8. NO menciones el título del manga
9. NO menciones el nombre del autor
10. NO menciones los géneros ni el estado
11. Solo menciona nombres de personajes principales (máximo 2)
12. Narra la historia de forma general, sin revelar eventos clave

Descripción:''';
  }

  String _limpiarDescripcion(String? descripcion) {
    if (descripcion == null) return '';

    var limpia = descripcion
        .replaceAll(RegExp(r'^(Aquí tienes|Claro|Por supuesto|Aquí está|Te presento)[\s\:]*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Descripción[\s\:]*', caseSensitive: false), '')
        .trim();

    if (limpia.isNotEmpty) {
      limpia = limpia[0].toUpperCase() + limpia.substring(1);
    }

    if (limpia.isNotEmpty && !'.!?'.contains(limpia[limpia.length - 1])) {
      limpia += '.';
    }

    return limpia;
  }
}