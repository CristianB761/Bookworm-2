import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OllamaService {
  // Para Windows, usar localhost directamente
  static String get baseUrl {
    // Windows desktop
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'http://localhost:11434';
    }
    
    // Android emulador
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Intentar localhost primero, luego la IP
      return 'http://10.0.2.2:11434';
    }
    
    // iOS emulador
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://localhost:11434';
    }
    
    // Fallback
    return 'http://localhost:11434';
  }
  
  final String model;
  
  OllamaService({this.model = 'phi3:mini'});
  
  Future<bool> verificarDisponibilidad() async {
    try {
      print('🔍 Verificando Ollama en: $baseUrl');
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final modelos = data['models'] as List?;
        print('✅ Ollama conectado. Modelos disponibles: ${modelos?.length ?? 0}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Ollama no disponible: $e');
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
      
      print('🤖 Enviando a Ollama: ${titulo.substring(0, titulo.length > 30 ? 30 : titulo.length)}...');
      
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
          print('✅ Descripción generada (${descripcion.length} caracteres)');
          return _limpiarDescripcion(descripcion);
        }
      }
      
      print('❌ Error: ${response.statusCode}');
      return null;
      
    } catch (e) {
      print('❌ Excepción: $e');
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

Descripción:''';
  }
  
  String _limpiarDescripcion(String? descripcion) {
    if (descripcion == null) return '';
    
    // Eliminar frases comunes del prompt
    var limpia = descripcion
        .replaceAll(RegExp(r'^(Aquí tienes|Claro|Por supuesto|Aquí está|Te presento)[\s\:]*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Descripción[\s\:]*', caseSensitive: false), '')
        .trim();
    
    // Capitalizar primera letra
    if (limpia.isNotEmpty) {
      limpia = limpia[0].toUpperCase() + limpia.substring(1);
    }
    
    // Asegurar que termina con punto
    if (limpia.isNotEmpty && !'.!?'.contains(limpia[limpia.length - 1])) {
      limpia += '.';
    }
    
    return limpia;
  }
}