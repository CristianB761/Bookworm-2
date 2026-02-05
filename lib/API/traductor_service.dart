import 'dart:convert';
import 'package:http/http.dart' as http;

class TraductorService {
  
  Future<String?> traducirTexto(String texto, {String from = 'en', String to = 'es'}) async {
    try {
      if (texto.length < 3) return texto;
      
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?'
        'client=gtx&'
        'sl=auto&'
        'tl=$to&'
        'dt=t&'
        'q=${Uri.encodeComponent(texto)}'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[0] != null && data[0] is List) {
          String traduccion = '';
          for (var segment in data[0]) {
            if (segment[0] != null) {
              traduccion += segment[0];
            }
          }
          return traduccion.trim();
        }
      }
      return null;
    } catch (e) {
      print('Error traducción Google: $e');
      return null;
    }
  }
  
  // Métodos públicos (quita el guión bajo)
  bool esTextoEspanol(String texto) {
    if (texto.length < 10) return false;
    
    final palabrasEspanol = [
      'el', 'la', 'los', 'las', 'del', 'de', 'que', 'y', 'en', 'un',
      'una', 'unos', 'unas', 'por', 'con', 'para', 'como', 'más', 'pero',
      'su', 'al', 'lo', 'como', 'o', 'este', 'esta', 'estos', 'estas',
      'le', 'les', 'se', 'me', 'te', 'nos', 'os', 'mi', 'tu', 'nuestro',
      'vuestro', 'sus', 'entre', 'hasta', 'desde', 'hacia', 'sobre',
      'bajo', 'ante', 'bajo', 'contra', 'durante', 'mediante', 'excepto',
      'salvo', 'según', 'sin', 'so', 'tras', 'cual', 'cuales', 'quien',
      'quienes', 'cuyo', 'cuya', 'cuyos', 'cuyas', 'cuando', 'donde',
      'como', 'porque', 'aunque', 'si', 'que', 'este', 'ese', 'aquel',
      'esta', 'esa', 'aquella', 'esto', 'eso', 'aquello', 'aquí', 'allí',
      'ahí', 'allá', 'acá', 'ahora', 'luego', 'entonces', 'ayer', 'hoy',
      'mañana', 'siempre', 'nunca', 'jamás', 'también', 'tampoco',
      'quizás', 'acaso', 'tal', 'vez', 'así', 'bien', 'mal', 'despacio',
      'rápido', 'mucho', 'poco', 'bastante', 'demasiado', 'muy', 'casi',
      'solo', 'solamente', 'justo', 'recién', 'apenas', 'recién'
    ];
    
    final textoLower = texto.toLowerCase();
    int countEspanol = 0;
    int palabrasTotales = 0;
    
    final palabrasTexto = textoLower.split(RegExp(r'\W+'));
    palabrasTotales = palabrasTexto.length;
    
    if (palabrasTotales == 0) return false;
    
    for (var palabra in palabrasTexto) {
      if (palabra.length > 1 && palabrasEspanol.contains(palabra)) {
        countEspanol++;
      }
    }
    
    // Si más del 25% de las palabras son españolas comunes
    return (countEspanol / palabrasTotales) > 0.25;
  }
  
  bool esTextoIngles(String texto) {
    if (texto.length < 10) return false;
    
    final palabrasIngles = [
      'the', 'and', 'of', 'to', 'in', 'is', 'that', 'for', 'it', 'with',
      'as', 'was', 'on', 'at', 'be', 'this', 'have', 'from', 'or', 'by',
      'but', 'not', 'what', 'all', 'were', 'we', 'when', 'your', 'can',
      'said', 'there', 'use', 'each', 'which', 'she', 'do', 'how', 'their',
      'if', 'will', 'up', 'other', 'about', 'out', 'many', 'then', 'them',
      'these', 'so', 'some', 'her', 'would', 'make', 'like', 'him', 'into',
      'time', 'has', 'look', 'two', 'more', 'write', 'go', 'see', 'number',
      'no', 'way', 'could', 'people', 'my', 'than', 'first', 'water',
      'been', 'call', 'who', 'oil', 'its', 'now', 'find', 'long', 'down',
      'day', 'did', 'get', 'come', 'made', 'may', 'part'
    ];
    
    final textoLower = texto.toLowerCase();
    int countIngles = 0;
    int palabrasTotales = 0;
    
    // Contar palabras del texto
    final palabrasTexto = textoLower.split(RegExp(r'\W+'));
    palabrasTotales = palabrasTexto.length;
    
    if (palabrasTotales == 0) return false;
    
    // Verificar palabras inglesas
    for (var palabra in palabrasTexto) {
      if (palabra.length > 2 && palabrasIngles.contains(palabra)) {
        countIngles++;
      }
    }
    
    // Si más del 20% de las palabras son inglesas comunes
    return (countIngles / palabrasTotales) > 0.2;
  }
  
  // Mejorar texto automáticamente
  Future<String> mejorarTexto(String texto) async {
    if (texto.length < 20) return texto;
    
    // Si ya está en español, dejarlo como está
    if (esTextoEspanol(texto)) {
      return texto;
    }
    
    // Si está en inglés, intentar traducir
    if (esTextoIngles(texto)) {
      final traducido = await traducirTexto(texto);
      if (traducido != null && traducido.isNotEmpty) {
        return traducido;
      }
    }
    
    return texto;
  }
}