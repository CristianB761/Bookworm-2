import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'diseno.dart';
import 'componentes.dart';
import 'API/modelos.dart';
import 'API/open_library.dart';
import 'API/gutendex_service.dart';
import 'API/librivox_service.dart';
import 'API/google_books_service.dart';
import 'API/internet_archive_service.dart';

class Buscar extends StatefulWidget {
  const Buscar({super.key});

  @override
  State<Buscar> createState() => _BuscarState();
}

class _BuscarState extends State<Buscar> {
  final TextEditingController _controladorBusqueda = TextEditingController();
  final OpenLibraryService _servicioOpenLibrary = OpenLibraryService();
  final GutendexService _servicioGutendex = GutendexService();
  final LibriVoxService _servicioLibriVox = LibriVoxService();
  final GoogleBooksService _servicioGoogleBooks = GoogleBooksService(apiKey: 'AIzaSyDGyQmEOJsYJfoOMYbr5DIns3adtE13jFM');
  final InternetArchiveService _servicioInternetArchive = InternetArchiveService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _formatoSeleccionado = 'Todos los formatos';
  String? _generoSeleccionado = 'Todos los géneros';
  
  List<Libro> _resultadosBusqueda = [];
  bool _estaCargando = false;
  bool _haBuscado = false;
  
  final Map<String, List<Libro>> _cacheBusquedas = {};
  final Map<String, DateTime> _cacheTiempos = {};
  final Duration _cacheDuracion = const Duration(minutes: 5);
  
  Set<String> _librosGuardadosIds = {};
  Set<String> _librosFavoritosIds = {};

  @override
  void initState() {
    super.initState();
    _generoSeleccionado = DatosApp.generos.isNotEmpty ? DatosApp.generos.first : null;
    _formatoSeleccionado = 'Todos los formatos';
    _escucharCambiosBiblioteca();
  }

  void _escucharCambiosBiblioteca() {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    _firestore
        .collection('usuarios')
        .doc(usuario.uid)
        .collection('libros_guardados')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _librosGuardadosIds = snapshot.docs.map((doc) => doc.id).toSet();
          _librosFavoritosIds = snapshot.docs
              .where((doc) => doc.data()['favorito'] == true)
              .map((doc) => doc.id)
              .toSet();
        });
      }
    });
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  Future<void> _abrirURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      _mostrarError('No se puede abrir el enlace');
    }
  }

  Future<void> _guardarLibro(Libro libro, {bool? favorito}) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        _mostrarError('Debes iniciar sesión para guardar libros');
        return;
      }

      final docRef = _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(libro.id);

      final docSnapshot = await docRef.get();

      if (favorito != null) {
        if (docSnapshot.exists) {
          await docRef.update({'favorito': favorito});
        } else {
          final datosLibro = libro.toMap();
          datosLibro['fechaGuardado'] = FieldValue.serverTimestamp();
          datosLibro['estado'] = 'guardado';
          datosLibro['libroId'] = libro.id;
          datosLibro['favorito'] = favorito;
          await docRef.set(datosLibro);
        }
        _mostrarExito(favorito 
            ? '"${libro.titulo}" añadido a favoritos' 
            : '"${libro.titulo}" quitado de favoritos');
      } else {
        if (docSnapshot.exists) {
          await docRef.delete();
          _mostrarExito('"${libro.titulo}" eliminado de la biblioteca');
        } else {
          final datosLibro = libro.toMap();
          datosLibro['fechaGuardado'] = FieldValue.serverTimestamp();
          datosLibro['estado'] = 'guardado';
          datosLibro['libroId'] = libro.id;
          datosLibro['favorito'] = false;
          await docRef.set(datosLibro);
          _mostrarExito('"${libro.titulo}" guardado en la biblioteca');
        }
      }
    } catch (e) {
      _mostrarError('Error al guardar libro: $e');
    }
  }

  Future<void> _realizarBusqueda() async {
    bool tieneFiltros = (_generoSeleccionado != null && _generoSeleccionado != 'Todos los géneros') || 
                       (_formatoSeleccionado != null && _formatoSeleccionado != 'Todos los formatos');
    
    if (_controladorBusqueda.text.isEmpty && !tieneFiltros) {
      _mostrarError('Ingresa un término de búsqueda o selecciona un filtro');
      return;
    }
    
    setState(() {
      _estaCargando = true;
      _haBuscado = true;
    });

    try {
      String consultaBusqueda = _controladorBusqueda.text;
      if (consultaBusqueda.isEmpty && 
          (_generoSeleccionado == null || _generoSeleccionado == 'Todos los géneros') &&
          (_formatoSeleccionado == null || _formatoSeleccionado == 'Todos los formatos')) {
        consultaBusqueda = 'libros populares';
      }
      
      final cacheKey = '$consultaBusqueda|$_generoSeleccionado|$_formatoSeleccionado';
      
      if (_cacheBusquedas.containsKey(cacheKey)) {
        final cacheTime = _cacheTiempos[cacheKey];
        if (cacheTime != null && DateTime.now().difference(cacheTime) < _cacheDuracion) {
          setState(() {
            _resultadosBusqueda = _cacheBusquedas[cacheKey]!;
            _estaCargando = false;
          });
          return;
        }
      }
      
      List<Future<List<Libro>>> busquedas = [];
      
      if (_formatoSeleccionado == 'Todos los formatos' || _formatoSeleccionado == 'Libros') {
        busquedas.add(_servicioOpenLibrary.buscarLibros(
          consultaBusqueda,
          genero: _generoSeleccionado == 'Todos los géneros' ? null : _generoSeleccionado,
          limite: 20,
        ));
        
        busquedas.add(_servicioGutendex.buscarLibros(
          consultaBusqueda,
          genero: _generoSeleccionado == 'Todos los géneros' ? null : _generoSeleccionado,
          limite: 20,
        ));
        
        busquedas.add(_servicioInternetArchive.buscarLibros(
          consultaBusqueda,
          genero: _generoSeleccionado == 'Todos los géneros' ? null : _generoSeleccionado,
          limite: 15,
        ));
        
        if (consultaBusqueda.isNotEmpty && 
            !consultaBusqueda.toLowerCase().contains('populares') &&
            !consultaBusqueda.toLowerCase().contains('fiction')) {
          busquedas.add(_buscarEnGoogleBooksSeguro(consultaBusqueda));
        }
      }
      
      if (_formatoSeleccionado == 'Todos los formatos' || _formatoSeleccionado == 'Audiolibros') {
        busquedas.add(_servicioLibriVox.buscarLibros(
          consultaBusqueda,
          genero: _generoSeleccionado == 'Todos los géneros' ? null : _generoSeleccionado,
          limite: 15,
        ));
      }

      final listasResultados = await Future.wait(busquedas);
      List<Libro> resultados = [];
      
      for (var lista in listasResultados) {
        for (var libro in lista) {
          if (!_esLibroDuplicado(libro, resultados)) {
            resultados.add(_procesarLibroConPrecio(libro));
          }
        }
      }
      
      if (_formatoSeleccionado != null && _formatoSeleccionado != 'Todos los formatos') {
        if (_formatoSeleccionado == 'Audiolibros') {
          resultados = resultados.where((libro) => libro.esAudiolibro).toList();
        } else if (_formatoSeleccionado == 'Libros') {
          resultados = resultados.where((libro) => !libro.esAudiolibro).toList();
        }
      }
      
      resultados.sort((a, b) {
        final precioA = a.precio ?? double.infinity;
        final precioB = b.precio ?? double.infinity;
        
        if (precioA == 0.0 && precioB > 0) return -1;
        if (precioB == 0.0 && precioA > 0) return 1;
        return precioA.compareTo(precioB);
      });
      
      _cacheBusquedas[cacheKey] = resultados;
      _cacheTiempos[cacheKey] = DateTime.now();
      
      setState(() {
        _resultadosBusqueda = resultados;
      });
    } catch (e) {
      _mostrarError('Error al buscar: $e');
      setState(() {
        _resultadosBusqueda = [];
      });
    } finally {
      setState(() {
        _estaCargando = false;
      });
    }
  }

  Future<List<Libro>> _buscarEnGoogleBooksSeguro(String consulta) async {
    try {
      return await _servicioGoogleBooks.buscarLibros(
        consulta,
        genero: _generoSeleccionado == 'Todos los géneros' ? null : _generoSeleccionado,
        limite: 3,
        pais: 'ES',
      );
    } catch (e) {
      print('Google Books no disponible: $e');
      return [];
    }
  }

  Libro _procesarLibroConPrecio(Libro libro) {
    if (libro.precio != null && libro.precio! > 0 && libro.ofertas.isNotEmpty) {
      return libro;
    }
    
    double precioCalculado = _calcularPrecioRealista(libro);
    String moneda = 'EUR';
    
    bool esGratuito = precioCalculado == 0.0 || 
                     libro.id.startsWith('guten_') || 
                     libro.id.startsWith('ia_') ||
                     (libro.urlLectura != null && libro.urlLectura!.contains('gutenberg'));
    
    if (esGratuito) {
      precioCalculado = 0.0;
    }
    
    return libro.copyWith(
      precio: precioCalculado,
      moneda: moneda,
    );
  }

  double _calcularPrecioRealista(Libro libro) {
    double precioBase = 12.99;
    final tituloLower = libro.titulo.toLowerCase();
    
    if (libro.id.startsWith('guten_') || 
        libro.id.startsWith('ia_') || 
        libro.id.startsWith('ol_') ||
        (libro.urlLectura != null && (
          libro.urlLectura!.contains('gutenberg') ||
          libro.urlLectura!.contains('archive.org')
        ))) {
      return 0.0;
    }
    
    if (tituloLower.contains('harry potter')) {
      precioBase = 19.99;
    } else if (tituloLower.contains('señor de los anillos') || 
               tituloLower.contains('tolkien')) {
      precioBase = 17.99;
    } else if (tituloLower.contains('juego de tronos') || 
               tituloLower.contains('george martin')) {
      precioBase = 18.99;
    } else if (tituloLower.contains('código da vinci') || 
               tituloLower.contains('dan brown')) {
      precioBase = 16.99;
    } else if (tituloLower.contains('it') || 
               tituloLower.contains('stephen king')) {
      precioBase = 15.99;
    }
    
    if (libro.categorias.isNotEmpty) {
      final categoriasLower = libro.categorias.map((c) => c.toLowerCase()).toList();
      
      if (categoriasLower.any((c) => c.contains('ciencia ficción') || c.contains('fantasía'))) {
        precioBase = 15.99;
      } else if (categoriasLower.any((c) => c.contains('biografía') || c.contains('historia'))) {
        precioBase = 16.99;
      } else if (categoriasLower.any((c) => c.contains('autoayuda') || c.contains('desarrollo'))) {
        precioBase = 17.99;
      } else if (categoriasLower.any((c) => c.contains('infantil') || c.contains('juvenil'))) {
        precioBase = 9.99;
      } else if (categoriasLower.any((c) => c.contains('educativo') || c.contains('técnico'))) {
        precioBase = 24.99;
      } else if (categoriasLower.any((c) => c.contains('romance'))) {
        precioBase = 12.99;
      } else if (categoriasLower.any((c) => c.contains('terror') || c.contains('misterio'))) {
        precioBase = 13.99;
      }
    }
    
    if (libro.autores.isNotEmpty) {
      final autorLower = libro.autores.first.toLowerCase();
      if (autorLower.contains('rowling')) {
        precioBase = 19.99;
      } else if (autorLower.contains('tolkien')) {
        precioBase = 17.99;
      } else if (autorLower.contains('martin')) {
        precioBase = 18.99;
      } else if (autorLower.contains('king')) {
        precioBase = 15.99;
      } else if (autorLower.contains('brown')) {
        precioBase = 16.99;
      } else if (autorLower.contains('coelho')) {
        precioBase = 14.99;
      } else if (autorLower.contains('cervantes')) {
        precioBase = 9.99;
      }
    }
    
    if (libro.numeroPaginas != null) {
      if (libro.numeroPaginas! < 100) {
        precioBase -= 3.0;
      } else if (libro.numeroPaginas! > 400) {
        precioBase += 3.0;
      }
    }
    
    if (libro.fechaPublicacion != null) {
      final anoMatch = RegExp(r'\d{4}').firstMatch(libro.fechaPublicacion!);
      if (anoMatch != null) {
        final ano = int.tryParse(anoMatch.group(0)!);
        if (ano != null) {
          if (ano < 1950) {
            precioBase = 9.99;
          } else if (ano >= 2020) {
            precioBase += 2.0;
          }
        }
      }
    }
    
    if (libro.calificacionPromedio != null) {
      if (libro.calificacionPromedio! > 4.5) {
        precioBase += 1.5;
      } else if (libro.calificacionPromedio! > 4.0) {
        precioBase += 1.0;
      }
    }
    
    if (libro.esAudiolibro) {
      precioBase += 5.0;
    }
    
    precioBase = precioBase.clamp(0.0, 35.0);
    
    precioBase = (precioBase.floorToDouble() + 0.99);
    
    return double.parse(precioBase.toStringAsFixed(2));
  }

  bool _esLibroDuplicado(Libro libro, List<Libro> listaExistente) {
    final tituloLibro = libro.titulo.toLowerCase().trim();
    
    for (var existente in listaExistente) {
      final tituloExistente = existente.titulo.toLowerCase().trim();
      
      if (_sonTitulosSimilares(tituloLibro, tituloExistente)) {
        return true;
      }
    }
    
    return false;
  }

  bool _sonTitulosSimilares(String titulo1, String titulo2) {
    if (titulo1 == titulo2) return true;
    
    String limpiarTexto(String texto) {
      return texto
          .replaceAll(RegExp(r'\b(el|la|los|las|un|una|unos|unas|the|a|an)\b'), '')
          .replaceAll(RegExp(r'[^\w\sáéíóúñ]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    
    final limpio1 = limpiarTexto(titulo1);
    final limpio2 = limpiarTexto(titulo2);
    
    return limpio1 == limpio2 || 
           limpio1.contains(limpio2) || 
           limpio2.contains(limpio1);
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColores.secundario,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _guardarEnHistorial(Libro libro) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;

    try {
      final datosLibro = libro.toMap();
      datosLibro['fechaVisto'] = FieldValue.serverTimestamp();
      
      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('historial')
          .doc(libro.id)
          .set(datosLibro);
    } catch (e) {
      print('Error al guardar en historial: $e');
    }
  }

  void _mostrarDetallesLibro(Libro libro) {
    _guardarEnHistorial(libro);
    Navigator.pushNamed(
      context,
      '/detalles_libro',
      arguments: libro,
    );
  }

  void _mostrarOpcionesLibro(Libro libro) {
    final bool esGratuito = libro.precio == 0.0 && libro.urlLectura != null;
    final bool esDePago = libro.precio != null && libro.precio! > 0;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              libro.titulo.length > 30 ? '${libro.titulo.substring(0, 30)}...' : libro.titulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColores.texto,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            if (esGratuito)
              ListTile(
                leading: const Icon(Icons.lock_open, color: Colors.green, size: 28),
                title: const Text('Leer gratis'),
                subtitle: const Text('Abrir libro gratuito'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  _abrirURL(libro.urlLectura!);
                },
              ),
            
            if (esDePago)
              ListTile(
                leading: const Icon(Icons.shopping_cart, color: AppColores.secundario, size: 28),
                title: const Text('Buscar en tiendas'),
                subtitle: const Text('Ver disponibilidad en tiendas'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  _buscarEnTiendas(libro);
                },
              ),
            
            ListTile(
              leading: const Icon(Icons.info, color: AppColores.primario, size: 28),
              title: const Text('Ver detalles completos'),
              subtitle: const Text('Información completa del libro'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                _mostrarDetallesLibro(libro);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.bookmark_add, color: Colors.amber, size: 28),
              title: const Text('Guardar libro'),
              subtitle: const Text('Añadir a mi biblioteca'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                _guardarLibro(libro);
              },
            ),
            
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColores.textoClaro,
              ),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  void _buscarEnTiendas(Libro libro) {
    final query = libro.titulo;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Buscar en tiendas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColores.texto,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '"${libro.titulo.length > 25 ? '${libro.titulo.substring(0, 25)}...' : libro.titulo}"',
              style: TextStyle(
                fontSize: 14,
                color: AppColores.textoClaro,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFF9900),
                child: Icon(Icons.shopping_bag, color: Colors.white),
              ),
              title: const Text('Amazon'),
              subtitle: const Text('Buscar en Amazon'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                final url = 'https://www.amazon.es/s?k=${Uri.encodeComponent(query)}&i=stripbooks';
                _abrirURL(url);
              },
            ),
            
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE2001A),
                child: Icon(Icons.store, color: Colors.white),
              ),
              title: const Text('Casa del Libro'),
              subtitle: const Text('Librería española'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                final url = 'https://www.casadellibro.com/busqueda-libros?q=${Uri.encodeComponent(query)}';
                _abrirURL(url);
              },
            ),
            
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF0D5FA6),
                child: Icon(Icons.shopping_cart, color: Colors.white),
              ),
              title: const Text('Fnac'),
              subtitle: const Text('Tienda de cultura'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                final url = 'https://www.fnac.es/ia?Search=${Uri.encodeComponent(query)}';
                _abrirURL(url);
              },
            ),
            
            if (libro.esAudiolibro) ...[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF7991C),
                  child: Icon(Icons.headset, color: Colors.white),
                ),
                title: const Text('Audible'),
                subtitle: const Text('Audiolibros'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  final url = 'https://www.audible.es/search?keywords=${Uri.encodeComponent(query)}';
                  _abrirURL(url);
                },
              ),
            ],
            
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionResultados() {
    if (_estaCargando) {
      return const IndicadorCarga(mensaje: 'Buscando libros...');
    }

    if (!_haBuscado) {
      return const EstadoVacio(
        icono: Icons.search,
        titulo: 'Busca tu próximo libro favorito',
        descripcion: 'Ingresa un título, autor, o selecciona un género/formato',
      );
    }

    if (_resultadosBusqueda.isEmpty) {
      return const EstadoVacio(
        icono: Icons.search_off,
        titulo: 'No se encontraron libros',
        descripcion: 'Intenta con otros términos de búsqueda',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_resultadosBusqueda.length} resultados encontrados',
              style: EstilosApp.cuerpoMedio(context),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColores.secundario.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatoSeleccionado ?? 'Todos',
                style: TextStyle(
                  color: AppColores.secundario,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14,
            childAspectRatio: 0.7,
          ),
          itemCount: _resultadosBusqueda.length,
          itemBuilder: (context, index) {
            return _construirTarjetaMosaico(_resultadosBusqueda[index]);
          },
        ),
      ],
    );
  }

  Widget _construirTarjetaMosaico(Libro libro) {
    bool esGratuito = libro.precio == 0.0;
    bool tienePrecio = libro.precio != null && libro.precio! > 0;
    bool esAudiolibro = libro.esAudiolibro;
    bool esGuardado = _librosGuardadosIds.contains(libro.id);
    bool esFavorito = _librosFavoritosIds.contains(libro.id);

    return GestureDetector(
      onTap: () => _mostrarDetallesLibro(libro),
      onLongPress: () => _mostrarOpcionesLibro(libro),
      child: Container(
        decoration: EstilosApp.tarjetaPlana(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del libro
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      color: const Color(0xFFEEEEEE),
                    ),
                    child: libro.urlMiniatura != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            child: Image.network(
                              libro.urlMiniatura!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.book, size: 40, color: Color(0xFF9E9E9E)),
                                );
                              },
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.book, size: 40, color: Color(0xFF9E9E9E)),
                          ),
                  ),
                  // Badge de tipo (Libro/Audiolibro)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: esAudiolibro ? const Color(0xFFF7991C) : AppColores.primario,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        esAudiolibro ? Icons.headset : Icons.menu_book,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Contenido
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    libro.titulo,
                    style: EstilosApp.tituloPequeno(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Autor
                  if (libro.autores.isNotEmpty)
                    Text(
                      libro.autores.join(', '),
                      style: EstilosApp.cuerpoPequeno(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  // Rating
                  if (libro.calificacionPromedio != null)
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          libro.calificacionPromedio!.toStringAsFixed(1),
                          style: EstilosApp.cuerpoPequeno(context),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // Precio / Gratis
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: esGratuito
                          ? Colors.green.withOpacity(0.1)
                          : AppColores.secundario.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      esGratuito ? 'Gratis' : (tienePrecio ? 'Comprar' : 'Leer'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: esGratuito ? Colors.green : AppColores.secundario,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          esFavorito ? Icons.favorite : Icons.favorite_border,
                          color: esFavorito ? Colors.red : AppColores.primario,
                          size: 18,
                        ),
                        onPressed: () => _guardarLibro(libro, favorito: !esFavorito),
                        tooltip: esFavorito ? 'Quitar de favoritos' : 'Añadir a favoritos',
                        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: Icon(
                          esGuardado ? Icons.bookmark : Icons.bookmark_add,
                          color: esGuardado ? AppColores.secundario : AppColores.primario,
                          size: 18,
                        ),
                        onPressed: () => _guardarLibro(libro),
                        tooltip: esGuardado ? 'Quitar de biblioteca' : 'Guardar libro',
                        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('BookWorm', style: EstilosApp.tituloGrande(context)),
        backgroundColor: AppColores.primario,
        automaticallyImplyLeading: false,
        actions: [
          const BotonNotificaciones(),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.esModoOscuro ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white,
                ),
                onPressed: () => themeProvider.alternarTema(),
                tooltip: themeProvider.esModoOscuro ? 'Modo claro' : 'Modo oscuro',
              );
            },
          ),
          const BotonesBarraApp(rutaActual: '/search'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: EstilosApp.tarjeta(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Encuentra tu próximo libro', style: EstilosApp.tituloMedio(context)),
                  const SizedBox(height: 8),
                  Text('Busca entre miles de libros y audiolibros', style: EstilosApp.cuerpoMedio(context)),
                  const SizedBox(height: 20),
                  BarraBusquedaPersonalizada(
                    controlador: _controladorBusqueda,
                    textoHint: 'Ej: Harry Potter, Stephen King o buscar por filtros',
                    alBuscar: _realizarBusqueda,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FiltroDesplegable(
                          valor: _formatoSeleccionado,
                          items: const ['Todos los formatos', 'Libros', 'Audiolibros'],
                          hint: 'Formato',
                          alCambiar: (valor) {
                            if (valor != null) {
                              setState(() {
                                _formatoSeleccionado = valor;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FiltroDesplegable(
                          valor: _generoSeleccionado,
                          items: DatosApp.generos,
                          hint: 'Género',
                          alCambiar: (valor) {
                            if (valor != null) {
                              setState(() {
                                _generoSeleccionado = valor;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: EstilosApp.tarjeta(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resultados de búsqueda', style: EstilosApp.tituloMedio(context)),
                  const SizedBox(height: 16),
                  _seccionResultados(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}