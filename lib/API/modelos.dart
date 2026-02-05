class OfertaTienda {
  final String tienda;
  final double precio;
  final String moneda;
  final String? url;

  OfertaTienda({
    required this.tienda,
    required this.precio,
    required this.moneda,
    this.url,
  });

  Map<String, dynamic> toMap() {
    return {
      'tienda': tienda,
      'precio': precio,
      'moneda': moneda,
      'url': url,
    };
  }

  factory OfertaTienda.fromMap(Map<String, dynamic> map) {
    return OfertaTienda(
      tienda: map['tienda'] ?? '',
      precio: (map['precio'] as num).toDouble(),
      moneda: map['moneda'] ?? '',
      url: map['url'],
    );
  }
}

class Libro {
  final String id;
  final String titulo;
  final List<String> autores;
  final String? descripcion;
  final String? urlMiniatura;
  final String? fechaPublicacion;
  final int? numeroPaginas;
  final List<String> categorias;
  final double? calificacionPromedio;
  final int? numeroCalificaciones;
  final String? urlLectura;
  final bool esAudiolibro;
  final String? urlVistaPrevia;
  final double? precio;
  final String? moneda;
  final List<OfertaTienda> ofertas;
  final String? isbn10;
  final String? isbn13;
  final String? urlCompra; 

  Libro({
    required this.id,
    required this.titulo,
    required this.autores,
    this.descripcion,
    this.urlMiniatura,
    this.fechaPublicacion,
    this.numeroPaginas,
    this.categorias = const [],
    this.calificacionPromedio,
    this.numeroCalificaciones,
    this.urlLectura,
    this.esAudiolibro = false,
    this.urlVistaPrevia,
    this.precio,
    this.moneda,
    this.ofertas = const [],
    this.isbn10,
    this.isbn13,
    this.urlCompra,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'autores': autores,
      'descripcion': descripcion,
      'urlMiniatura': urlMiniatura,
      'fechaPublicacion': fechaPublicacion,
      'numeroPaginas': numeroPaginas,
      'categorias': categorias,
      'calificacionPromedio': calificacionPromedio,
      'numeroCalificaciones': numeroCalificaciones,
      'urlLectura': urlLectura,
      'esAudiolibro': esAudiolibro,
      'urlVistaPrevia': urlVistaPrevia,
      'precio': precio,
      'moneda': moneda,
      'ofertas': ofertas.map((o) => o.toMap()).toList(),
      'isbn10': isbn10,
      'isbn13': isbn13,
      'urlCompra': urlCompra,
    };
  }

  factory Libro.fromJson(Map<String, dynamic> json) {
    final informacionVolumen = json['volumeInfo'] ?? {};
    final enlacesImagen = informacionVolumen['imageLinks'] ?? {};
    final ventaInfo = json['saleInfo'] ?? {};
    final identificadores = informacionVolumen['industryIdentifiers'] ?? [];

    double? precio;
    String? moneda;
    String? isbn10;
    String? isbn13;
    String? urlCompra;
    List<OfertaTienda> ofertas = [];

    if (ventaInfo['saleability'] == 'FOR_SALE') {
      precio = (ventaInfo['listPrice']?['amount'] as num?)?.toDouble();
      moneda = ventaInfo['listPrice']?['currencyCode'];
      urlCompra = ventaInfo['buyLink'];
      
      if (urlCompra != null && precio != null) {
        ofertas.add(OfertaTienda(
          tienda: 'Google Play Books',
          precio: precio,
          moneda: moneda ?? '€',
          url: urlCompra,
        ));
      }
    }

    for (var id in identificadores) {
      if (id['type'] == 'ISBN_10') {
        isbn10 = id['identifier'];
      } else if (id['type'] == 'ISBN_13') {
        isbn13 = id['identifier'];
      }
    }

    return Libro(
      id: json['id'] ?? '',
      titulo: informacionVolumen['title'] ?? 'Título no disponible',
      autores: List<String>.from(informacionVolumen['authors'] ?? []),
      descripcion: informacionVolumen['description'],
      urlMiniatura: enlacesImagen['thumbnail'] ?? enlacesImagen['smallThumbnail'],
      fechaPublicacion: informacionVolumen['publishedDate'],
      numeroPaginas: informacionVolumen['pageCount'],
      categorias: List<String>.from(informacionVolumen['categories'] ?? []),
      calificacionPromedio: informacionVolumen['averageRating']?.toDouble(),
      numeroCalificaciones: informacionVolumen['ratingsCount'],
      precio: precio,
      moneda: moneda,
      ofertas: ofertas,
      isbn10: isbn10,
      isbn13: isbn13,
      urlCompra: urlCompra,
    );
  }

  factory Libro.fromMap(Map<String, dynamic> map) {
    return Libro(
      id: map['id'] ?? '',
      titulo: map['titulo'] ?? '',
      autores: List<String>.from(map['autores'] ?? []),
      descripcion: map['descripcion'],
      urlMiniatura: map['urlMiniatura'],
      fechaPublicacion: map['fechaPublicacion'],
      numeroPaginas: map['numeroPaginas'],
      categorias: List<String>.from(map['categorias'] ?? []),
      calificacionPromedio: (map['calificacionPromedio'] as num?)?.toDouble(),
      numeroCalificaciones: map['numeroCalificaciones'],
      urlLectura: map['urlLectura'],
      esAudiolibro: map['esAudiolibro'] ?? false,
      urlVistaPrevia: map['urlVistaPrevia'],
      precio: (map['precio'] as num?)?.toDouble(),
      moneda: map['moneda'],
      ofertas: (map['ofertas'] as List<dynamic>?)
              ?.map((o) => OfertaTienda.fromMap(o as Map<String, dynamic>))
              .toList() ??
          const [],
      isbn10: map['isbn10'],
      isbn13: map['isbn13'],
      urlCompra: map['urlCompra'],
    );
  }

  Libro copyWith({
    String? id,
    String? titulo,
    List<String>? autores,
    String? descripcion,
    String? urlMiniatura,
    String? fechaPublicacion,
    int? numeroPaginas,
    List<String>? categorias,
    double? calificacionPromedio,
    int? numeroCalificaciones,
    String? urlLectura,
    bool? esAudiolibro,
    String? urlVistaPrevia,
    double? precio,
    String? moneda,
    List<OfertaTienda>? ofertas,
    String? isbn10,
    String? isbn13,
    String? urlCompra,
  }) {
    return Libro(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      autores: autores ?? this.autores,
      descripcion: descripcion ?? this.descripcion,
      urlMiniatura: urlMiniatura ?? this.urlMiniatura,
      fechaPublicacion: fechaPublicacion ?? this.fechaPublicacion,
      numeroPaginas: numeroPaginas ?? this.numeroPaginas,
      categorias: categorias ?? this.categorias,
      calificacionPromedio: calificacionPromedio ?? this.calificacionPromedio,
      numeroCalificaciones: numeroCalificaciones ?? this.numeroCalificaciones,
      urlLectura: urlLectura ?? this.urlLectura,
      esAudiolibro: esAudiolibro ?? this.esAudiolibro,
      urlVistaPrevia: urlVistaPrevia ?? this.urlVistaPrevia,
      precio: precio ?? this.precio,
      moneda: moneda ?? this.moneda,
      ofertas: ofertas ?? this.ofertas,
      isbn10: isbn10 ?? this.isbn10,
      isbn13: isbn13 ?? this.isbn13,
      urlCompra: urlCompra ?? this.urlCompra,
    );
  }

  String? get isbn => isbn13 ?? isbn10;

  List<OfertaTienda> get ofertasConSimuladas {
    if (ofertas.isNotEmpty) {
      return ofertas;
    }
    
    if (precio == 0.0) {
      return [
        OfertaTienda(
          tienda: 'Project Gutenberg',
          precio: 0.0,
          moneda: 'EUR',
          url: 'https://www.gutenberg.org/ebooks/${id.replaceFirst('guten_', '')}',
        ),
        OfertaTienda(
          tienda: 'Internet Archive',
          precio: 0.0,
          moneda: 'EUR',
          url: 'https://archive.org/details/${id.replaceFirst('ia_', '')}',
        ),
      ];
    }
    
    final busqueda = titulo;
    
    final tiendas = [
      (
        'Amazon',
        'https://www.amazon.es/s?k=${Uri.encodeComponent(busqueda)}&i=stripbooks'
      ),
      (
        'Casa del Libro',
        'https://www.casadellibro.com/busqueda-libros?q=${Uri.encodeComponent(busqueda)}'
      ),
      (
        'Fnac',
        'https://www.fnac.es/ia?Search=${Uri.encodeComponent(busqueda)}'
      ),
      (
        'El Corte Inglés',
        'https://www.elcorteingles.es/libros/search/?q=${Uri.encodeComponent(busqueda)}'
      ),
    ];
    
    if (esAudiolibro) {
      tiendas.addAll([
        (
          'Audible',
          'https://www.audible.es/search?keywords=${Uri.encodeComponent(busqueda)}'
        ),
        (
          'Storytel',
          'https://www.storytel.com/es/es/search?q=${Uri.encodeComponent(busqueda)}'
        ),
      ]);
    }
    
    List<OfertaTienda> ofertasSimuladas = [];
    
    for (final tienda in tiendas) {
      double precioTienda = precio ?? _calcularPrecioSimulado();
      
      if (tienda.$1 == 'Amazon') {
        precioTienda *= 0.95;
      } else if (tienda.$1 == 'Audible') {
        precioTienda = (precioTienda * 0.8).clamp(9.99, 29.99);
      } else if (tienda.$1 == 'Storytel') {
        precioTienda = 0.0;
      } else if (tienda.$1 == 'El Corte Inglés') {
        precioTienda *= 1.05;
      }
      
      precioTienda = (precioTienda.floorToDouble() + 0.99);
      
      ofertasSimuladas.add(OfertaTienda(
        tienda: tienda.$1,
        precio: double.parse(precioTienda.toStringAsFixed(2)),
        moneda: 'EUR',
        url: tienda.$2,
      ));
    }
    
    return ofertasSimuladas;
  }

  double _calcularPrecioSimulado() {
    double precioBase = 12.99;
    
    final tituloLower = titulo.toLowerCase();
    
    if (tituloLower.contains('harry potter') || 
        tituloLower.contains('señor de los anillos') ||
        tituloLower.contains('juego de tronos') ||
        tituloLower.contains('best seller') ||
        tituloLower.contains('éxito de ventas')) {
      precioBase = 18.99;
    }
    else if (autores.any((autor) => 
        autor.toLowerCase().contains('rowling') ||
        autor.toLowerCase().contains('tolkien') ||
        autor.toLowerCase().contains('martin') ||
        autor.toLowerCase().contains('king'))) {
      precioBase = 16.99;
    }
    else if (tituloLower.contains('clásico') || 
             tituloLower.contains('clasico') ||
             fechaPublicacion != null && 
             int.tryParse(fechaPublicacion!) != null && 
             int.parse(fechaPublicacion!) < 1900) {
      precioBase = 9.99;
    }
    else if (tituloLower.contains('programación') ||
             tituloLower.contains('informática') ||
             tituloLower.contains('ciencia') ||
             tituloLower.contains('tecnología') ||
             categorias.any((cat) => 
                 cat.toLowerCase().contains('informática') ||
                 cat.toLowerCase().contains('ciencia') ||
                 cat.toLowerCase().contains('tecnología'))) {
      precioBase = 24.99;
    }
    else if (esAudiolibro) {
      precioBase = 15.99;
    }
    else if (categorias.any((cat) => 
                 cat.toLowerCase().contains('infantil') ||
                 cat.toLowerCase().contains('niños') ||
                 cat.toLowerCase().contains('juvenil'))) {
      precioBase = 8.99;
    }
    else if (numeroPaginas != null && numeroPaginas! < 150) {
      precioBase = 7.99;
    }
    else if (numeroPaginas != null && numeroPaginas! > 500) {
      precioBase = 16.99;
    }
    
    if (calificacionPromedio != null && calificacionPromedio! > 4.0) {
      precioBase += 2.0;
    }
    
    return precioBase;
  }
}