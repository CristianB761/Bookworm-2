import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'diseno.dart';
import 'API/modelos.dart';
import 'API/ollama_service.dart';

class DetallesLibro extends StatefulWidget {
  final Libro libroObjeto;
  const DetallesLibro({super.key, required this.libroObjeto});

  @override
  State<DetallesLibro> createState() => _DetallesLibroState();
}

class _DetallesLibroState extends State<DetallesLibro> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OllamaService _ollamaService = OllamaService();
  bool _estaCargando = false;
  bool _esFavorito = false;
  bool _estaGuardado = false;
  bool _cargandoOfertas = false;
  bool _mostrarDescripcion = false;
  String? _descripcionOllama;
  bool _cargandoDescripcion = false;

  @override
  void initState() {
    super.initState();
    _verificarEstadoLibro();
    if (widget.libroObjeto.precio != null && widget.libroObjeto.precio! > 0) {
      _buscarOfertasReales();
    }
    _cargarDescripcionCache();
  }

  Future<void> _cargarDescripcionCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'desc_${widget.libroObjeto.id}';
      final cached = prefs.getString(key);
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _descripcionOllama = cached;
        });
      }
    } catch (e) {
    }
  }

  Future<void> _guardarDescripcionCache(String descripcion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'desc_${widget.libroObjeto.id}';
      await prefs.setString(key, descripcion);
    } catch (e) {
    }
  }

  Future<void> _verificarEstadoLibro() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      final favoritoDoc = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(widget.libroObjeto.id)
          .get();

      if (favoritoDoc.exists) {
        final data = favoritoDoc.data();
        if (data != null) {
          setState(() {
            _esFavorito = data['favorito'] == true;
            _estaGuardado = true;
          });
        }
      }
    } catch (e) {
    }
  }

  Future<void> _buscarOfertasReales() async {
    if (_cargandoOfertas) return;
    
    setState(() => _cargandoOfertas = true);
    
    try {
      if (widget.libroObjeto.isbn != null) {
        final ofertasISBN = await _buscarPorISBN(widget.libroObjeto.isbn!);
        if (ofertasISBN.isNotEmpty) {
          return;
        }
      }
      
      final query = '${widget.libroObjeto.titulo} ${widget.libroObjeto.autores.isNotEmpty ? widget.libroObjeto.autores.first : ''}';
      await _buscarPorTitulo(query);
      // Ofertas encontradas
    } catch (e) {
    } finally {
      setState(() => _cargandoOfertas = false);
    }
  }

  Future<List<OfertaTienda>> _buscarPorISBN(String isbn) async {
    final List<OfertaTienda> ofertas = [];

    try {
      final openLibUrl = Uri.parse('https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data');
      final openLibResponse = await http.get(openLibUrl);

      if (openLibResponse.statusCode == 200) {
        final openLibData = json.decode(openLibResponse.body);
        final key = 'ISBN:$isbn';
        if (openLibData[key] != null) {
          ofertas.add(OfertaTienda(
            tienda: 'Open Library',
            precio: 0.0,
            moneda: 'EUR',
            url: openLibData[key]['url'] ?? 'https://openlibrary.org',
          ));
        }
      }
    } catch (e) {
    }

    return ofertas;
  }

  Future<List<OfertaTienda>> _buscarPorTitulo(String query) async {
    final List<OfertaTienda> ofertas = [];

    try {
      final openLibUrl = Uri.parse('https://openlibrary.org/api/books?bibkeys=ISBN:${Uri.encodeComponent(query)}&format=json&jscmd=data');
      final openLibResponse = await http.get(openLibUrl);

      if (openLibResponse.statusCode == 200) {
        final openLibData = json.decode(openLibResponse.body);
        if (openLibData.values.isNotEmpty) {
          final firstBook = openLibData.values.first;
          ofertas.add(OfertaTienda(
            tienda: 'Open Library',
            precio: 0.0,
            moneda: 'EUR',
            url: firstBook['url'] ?? 'https://openlibrary.org',
          ));
        }
      }
    } catch (e) {
    }

    return ofertas;
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

  Future<void> _abrirURLEnApp(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
    } else {
      _mostrarError('No se puede abrir el enlace');
    }
  }

  void _abrirBusquedaTiendas() {
    final busqueda = widget.libroObjeto.titulo;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.libroObjeto.esAudiolibro ? 'Buscar audiolibro' : 'Buscar en tiendas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColores.texto,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '"${widget.libroObjeto.titulo}"',
              style: TextStyle(
                fontSize: 14,
                color: AppColores.textoClaro,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            if (!widget.libroObjeto.esAudiolibro) ...[
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
                  final url = 'https://www.amazon.es/s?k=${Uri.encodeComponent(busqueda)}&i=stripbooks';
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
                  final url = 'https://www.casadellibro.com/busqueda-libros?q=${Uri.encodeComponent(busqueda)}';
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
                  final url = 'https://www.fnac.es/ia?Search=${Uri.encodeComponent(busqueda)}';
                  _abrirURL(url);
                },
              ),
            ],
            
            if (widget.libroObjeto.esAudiolibro) ...[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF7991C),
                  child: Icon(Icons.headset, color: Colors.white),
                ),
                title: const Text('Audible'),
                subtitle: const Text('Audiolibros con suscripción'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  final url = 'https://www.audible.es/search?keywords=${Uri.encodeComponent(busqueda)}';
                  _abrirURL(url);
                },
              ),
              
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF00A8FF),
                  child: Icon(Icons.volume_up, color: Colors.white),
                ),
                title: const Text('Storytel'),
                subtitle: const Text('Streaming de audiolibros'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  final url = 'https://www.storytel.com/es/es/search?q=${Uri.encodeComponent(busqueda)}';
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

  Future<void> _guardarLibro({bool? favorito}) async {
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
          .doc(widget.libroObjeto.id);

      final docSnapshot = await docRef.get();
      bool nuevoEstadoFavorito = favorito ?? false;

      if (docSnapshot.exists) {
        if (favorito != null) {
          await docRef.update({'favorito': favorito});
          nuevoEstadoFavorito = favorito;
          setState(() {
            _esFavorito = favorito;
            _estaGuardado = true;
          });
        }
      } else if (favorito == null) {
        await docRef.delete();
        setState(() {
          _estaGuardado = false;
          _esFavorito = false;
        });
        _mostrarExito('"${widget.libroObjeto.titulo}" eliminado de la biblioteca');
        return;
      } else {
        final datosLibro = widget.libroObjeto.toMap();
        datosLibro['fechaGuardado'] = FieldValue.serverTimestamp();
        datosLibro['estado'] = 'guardado';
        datosLibro['libroId'] = widget.libroObjeto.id;
        datosLibro['favorito'] = nuevoEstadoFavorito;
        await docRef.set(datosLibro);
        
        setState(() {
          _estaGuardado = true;
          _esFavorito = favorito;
        });
      }

      if (favorito != null) {
        _mostrarExito(favorito 
            ? '"${widget.libroObjeto.titulo}" añadido a favoritos' 
            : '"${widget.libroObjeto.titulo}" quitado de favoritos');
      } else {
        _mostrarExito('"${widget.libroObjeto.titulo}" guardado en la biblioteca');
      }
    } catch (e) {
      _mostrarError('Error al guardar libro: $e');
    }
  }

  Future<void> _iniciarLectura() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        _mostrarError('Debes iniciar sesión para empezar a leer');
        return;
      }

      setState(() { _estaCargando = true; });

      final libroGuardadoRef = _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(widget.libroObjeto.id);

      final libroGuardadoSnap = await libroGuardadoRef.get();
      if (libroGuardadoSnap.exists) {
        await libroGuardadoRef.update({'estado': 'leyendo'});
      } else {
        final datosLibro = widget.libroObjeto.toMap();
        datosLibro['fechaGuardado'] = FieldValue.serverTimestamp();
        datosLibro['estado'] = 'leyendo';
        datosLibro['libroId'] = widget.libroObjeto.id;
        datosLibro['favorito'] = false;
        await libroGuardadoRef.set(datosLibro);
      }

      final progresoExistenteQuery = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuario.uid)
          .where('libroId', isEqualTo: widget.libroObjeto.id)
          .limit(1)
          .get();

      if (progresoExistenteQuery.docs.isEmpty) {
        final nuevoProgresoId = _firestore.collection('progreso_lectura').doc().id;
        final nuevoProgresoData = {
          'id': nuevoProgresoId,
          'usuarioId': usuario.uid,
          'libroId': widget.libroObjeto.id,
          'tituloLibro': widget.libroObjeto.titulo,
          'autoresLibro': widget.libroObjeto.autores,
          'miniaturaLibro': widget.libroObjeto.urlMiniatura,
          'estado': 'leyendo',
          'paginaActual': 0,
          'paginasTotales': widget.libroObjeto.numeroPaginas ?? 0,
          'fechaInicio': FieldValue.serverTimestamp(),
          'calificacion': 0.0,
        };

        await _firestore.collection('progreso_lectura').doc(nuevoProgresoId).set(nuevoProgresoData);
        
        final mapLocal = Map<String, dynamic>.from(nuevoProgresoData);
        mapLocal['fechaInicio'] = Timestamp.now();

        _mostrarExito('Comenzaste a leer "${widget.libroObjeto.titulo}"');
      } else {
        _mostrarExito('Continuando la lectura de "${widget.libroObjeto.titulo}"');
      }
      
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/perfil',
          arguments: {
            'seccionIndex': 1,
          },
        );
      }
    } catch (e) {
      _mostrarError('Error al iniciar lectura: $e');
    } finally {
      if (mounted) {
        setState(() { _estaCargando = false; });
      }
    }
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

  Widget _construirEncabezado() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: widget.libroObjeto.urlMiniatura != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.libroObjeto.urlMiniatura!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            widget.libroObjeto.esAudiolibro ? Icons.headset : Icons.book,
                            size: 50,
                            color: AppColores.primario,
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Icon(
                      widget.libroObjeto.esAudiolibro ? Icons.headset : Icons.book,
                      size: 50,
                      color: AppColores.primario,
                    ),
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.libroObjeto.titulo,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (widget.libroObjeto.autores.isNotEmpty)
                  Text(
                    'Por ${widget.libroObjeto.autores.join(', ')}',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                if (widget.libroObjeto.fechaPublicacion != null)
                  Text(
                    'Publicado: ${widget.libroObjeto.fechaPublicacion}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                if (widget.libroObjeto.numeroPaginas != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${widget.libroObjeto.numeroPaginas} páginas',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                ],
                if (widget.libroObjeto.calificacionPromedio != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.libroObjeto.calificacionPromedio!.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${widget.libroObjeto.numeroCalificaciones ?? 0} reseñas)',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (widget.libroObjeto.esAudiolibro)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColores.secundario.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.headset, size: 14, color: AppColores.secundario),
                            const SizedBox(width: 4),
                            Text(
                              'Audiolibro',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColores.secundario,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!widget.libroObjeto.esAudiolibro)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColores.primario.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book, size: 14, color: AppColores.primario),
                            const SizedBox(width: 4),
                            Text(
                              'Libro',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColores.primario,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.libroObjeto.isbn10 != null || widget.libroObjeto.isbn13 != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              'ISBN: ${widget.libroObjeto.isbn13 ?? widget.libroObjeto.isbn10}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionCompra() {
    final bool tieneUrl = widget.libroObjeto.urlLectura != null;
    final bool esAudiolibro = widget.libroObjeto.esAudiolibro;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tieneUrl) ...[
          const SizedBox(height: 24),
          Text(
            'Acceso Gratuito',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_open, color: Colors.green, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              esAudiolibro ? 'Audiolibro Gratuito' : 'Libro Gratuito',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              esAudiolibro 
                                ? 'Este audiolibro está disponible para escuchar gratis'
                                : 'Este libro está disponible para leer gratis',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _estaCargando ? null : () {
                      _abrirURLEnApp(widget.libroObjeto.urlLectura!);
                      _iniciarLectura();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: Icon(esAudiolibro ? Icons.headset : Icons.public),
                    label: Text(esAudiolibro ? 'Escuchar Gratis' : 'Leer Gratis'),
                  ),
                ],
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 24),
        Text(
          esAudiolibro ? 'Plataformas de Audiolibros' : 'Disponibilidad en Tiendas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                 Row(
                  children: [
                    Icon(esAudiolibro ? Icons.headset : Icons.store, color: AppColores.primario, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            esAudiolibro ? 'Buscar en plataformas' : 'Buscar en tiendas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColores.primario,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            esAudiolibro 
                              ? 'Encuentra este audiolibro en Audible, Storytel, y más.'
                              : 'Encuentra este libro en Amazon, Fnac, y más.',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : const Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _abrirBusquedaTiendas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.primario,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.search),
                  label: Text(esAudiolibro ? 'Buscar Audiolibro' : 'Buscar en Tiendas'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generarDescripcionOllama() async {
    if (_descripcionOllama != null) return;
    setState(() => _cargandoDescripcion = true);
    try {
      final descripcion = await _ollamaService.generarDescripcionLibro(
        titulo: widget.libroObjeto.titulo,
        autores: widget.libroObjeto.autores,
        categorias: widget.libroObjeto.categorias,
        anoPublicacion: widget.libroObjeto.fechaPublicacion != null
            ? int.tryParse(widget.libroObjeto.fechaPublicacion!.split('-')[0])
            : null,
        numeroPaginas: widget.libroObjeto.numeroPaginas,
        esAudiolibro: widget.libroObjeto.esAudiolibro,
      );
      if (mounted) {
        final descFinal = descripcion ?? 'No se pudo generar la descripción.';
        setState(() {
          _descripcionOllama = descFinal;
          _cargandoDescripcion = false;
        });
        if (descFinal != 'No se pudo generar la descripción.' && !descFinal.startsWith('Error al generar')) {
          await _guardarDescripcionCache(descFinal);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _descripcionOllama = 'Error al generar descripción: $e';
          _cargandoDescripcion = false;
        });
      }
    }
  }

  Widget _construirDescripcion() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Descripción',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            if (_mostrarDescripcion) {
              setState(() => _mostrarDescripcion = false);
            } else {
              setState(() => _mostrarDescripcion = true);
              if (_descripcionOllama == null) {
                _generarDescripcionOllama();
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColores.primario,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(_mostrarDescripcion ? 'Ocultar' : 'Mostrar'),
        ),
        if (_mostrarDescripcion) ...[
          const SizedBox(height: 16),
          _cargandoDescripcion
              ? const Center(child: CircularProgressIndicator())
              : _descripcionOllama != null
                  ? Text(
                      _descripcionOllama!,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white70 : const Color(0xFF616161),
                        height: 1.5,
                      ),
                    )
                  : const SizedBox.shrink(),
        ],
      ],
    );
  }

  Widget _construirCategorias() {
    if (widget.libroObjeto.categorias.isEmpty) {
      return Container();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Categorías',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.libroObjeto.categorias.map((categoria) {
            return Chip(
              label: Text(categoria),
              backgroundColor: AppColores.primario.withOpacity(0.1),
              labelStyle: TextStyle(color: AppColores.primario),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _construirBotonesAccion() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _estaCargando ? null : _iniciarLectura,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.primario,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              icon: Icon(widget.libroObjeto.esAudiolibro ? Icons.play_circle_filled : Icons.menu_book, size: 24),
              label: Text(
                widget.libroObjeto.esAudiolibro ? 'Empezar a Escuchar' : 'Empezar a Leer',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Añadir a tu biblioteca:',
                style: EstilosApp.cuerpoMedio(context),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _guardarLibro(favorito: !_esFavorito),
                icon: Icon(
                  _esFavorito ? Icons.favorite : Icons.favorite_border,
                  color: _esFavorito ? Colors.red : AppColores.primario,
                  size: 32,
                ),
                tooltip: _esFavorito ? 'Quitar de favoritos' : 'Añadir a favoritos',
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => _guardarLibro(),
                icon: Icon(
                  _estaGuardado ? Icons.bookmark : Icons.bookmark_border,
                  color: _estaGuardado ? AppColores.secundario : AppColores.primario,
                  size: 32,
                ),
                tooltip: _estaGuardado ? 'Quitar de la biblioteca' : 'Guardar en la biblioteca',
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Detalles del Libro', style: EstilosApp.tituloGrande(context)),
        backgroundColor: AppColores.primario,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _construirEncabezado(),
            _construirDescripcion(),
            _construirCategorias(),
            _construirSeccionCompra(),
            _construirBotonesAccion(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}