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
  });

  factory Libro.fromJson(Map<String, dynamic> json) {
  final informacionVolumen = json['volumeInfo'] ?? {};
  final enlacesImagen = informacionVolumen['imageLinks'] ?? {};

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
  );
}
}
