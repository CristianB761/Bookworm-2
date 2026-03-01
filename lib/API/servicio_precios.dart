import 'modelos.dart';
import 'google_books_service.dart';

class ServicioPrecios {
  final GoogleBooksService _googleBooksService;
  
  ServicioPrecios({required String apiKey}) 
      : _googleBooksService = GoogleBooksService(apiKey: apiKey);

  Future<Libro> mejorarLibroConPrecios(Libro libroOriginal) async {
    try {
      List<String> paises = ['ES', 'US', 'MX', 'CO', 'AR'];
      
      for (String pais in paises) {
        if (libroOriginal.isbn != null) {
          final librosGoogle = await _googleBooksService.buscarLibros(
            'isbn:${libroOriginal.isbn}',
            limite: 1,
            pais: pais, 
          );
          
          if (librosGoogle.isNotEmpty && librosGoogle.first.precio != null) {
            final libroGoogle = librosGoogle.first;
            return _combinarLibros(libroOriginal, libroGoogle);
          }
        }
      }
      
      String query = libroOriginal.titulo;
      if (libroOriginal.autores.isNotEmpty) {
        query += ' ${libroOriginal.autores.first}';
      }
      
      for (String pais in paises) {
        final librosGoogle = await _googleBooksService.buscarLibros(
          query,
          limite: 2,
          pais: pais,
        );
        
        if (librosGoogle.isNotEmpty) {
          final libroSimilar = _encontrarLibroMasSimilar(libroOriginal, librosGoogle);
          if (libroSimilar.precio != null) {
            return _combinarLibros(libroOriginal, libroSimilar);
          }
        }
      }
      
      return libroOriginal;
    } catch (e) {
      print('Error mejorando libro con precios: $e');
      return libroOriginal;
    }
  }

  Libro _encontrarLibroMasSimilar(Libro original, List<Libro> candidatos) {
    Libro mejorCandidato = candidatos.first;
    double mejorSimilitud = 0;
    
    for (var candidato in candidatos) {
      final similitud = _calcularSimilitud(original, candidato);
      if (similitud > mejorSimilitud) {
        mejorSimilitud = similitud;
        mejorCandidato = candidato;
      }
    }
    
    return mejorCandidato;
  }

  double _calcularSimilitud(Libro libro1, Libro libro2) {
    double similitud = 0.0;
    
    final titulo1 = libro1.titulo.toLowerCase();
    final titulo2 = libro2.titulo.toLowerCase();
    
    if (titulo1 == titulo2) {
      similitud += 0.5;
    } else if (titulo1.contains(titulo2) || titulo2.contains(titulo1)) {
      similitud += 0.3;
    }
    
    if (libro1.autores.isNotEmpty && libro2.autores.isNotEmpty) {
      for (var autor1 in libro1.autores) {
        for (var autor2 in libro2.autores) {
          if (autor1.toLowerCase() == autor2.toLowerCase()) {
            similitud += 0.3;
            break;
          }
        }
      }
    }
    
    if (libro1.isbn != null && libro2.isbn != null && libro1.isbn == libro2.isbn) {
      similitud += 1.0;
    }
    
    return similitud;
  }

  Libro _combinarLibros(Libro original, Libro googleBook) {
    return original.copyWith(
      precio: googleBook.precio ?? original.precio,
      moneda: googleBook.moneda ?? original.moneda,
      urlCompra: googleBook.urlCompra ?? original.urlCompra,
      ofertas: googleBook.ofertas.isNotEmpty ? googleBook.ofertas : original.ofertas,
      isbn10: googleBook.isbn10 ?? original.isbn10,
      isbn13: googleBook.isbn13 ?? original.isbn13,
      calificacionPromedio: googleBook.calificacionPromedio ?? original.calificacionPromedio,
      numeroCalificaciones: googleBook.numeroCalificaciones ?? original.numeroCalificaciones,
      urlMiniatura: googleBook.urlMiniatura ?? original.urlMiniatura,
      descripcion: _obtenerMejorDescripcion(original.descripcion, googleBook.descripcion),
    );
  }

  String? _obtenerMejorDescripcion(String? desc1, String? desc2) {
    if (desc2 == null) return desc1;
    if (desc1 == null) return desc2;
    
    return desc2.length > desc1.length ? desc2 : desc1;
  }

  Future<List<Libro>> mejorarLibrosConPrecios(List<Libro> libros) async {
    final resultados = <Libro>[];
    
    for (int i = 0; i < libros.length; i++) {
      try {
        final libroMejorado = await mejorarLibroConPrecios(libros[i]);
        resultados.add(libroMejorado);
        
        if (i % 5 == 0 && i > 0) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        print('Error mejorando libro ${libros[i].titulo}: $e');
        resultados.add(libros[i]); 
      }
    }
    
    return resultados;
  }
}