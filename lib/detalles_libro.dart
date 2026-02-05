import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'diseno.dart';
import 'API/modelos.dart';
import 'modelos/progreso_lectura.dart';

class DetallesLibro extends StatefulWidget {
  final Libro libroObjeto;
  const DetallesLibro({super.key, required this.libroObjeto});

  @override
  State<DetallesLibro> createState() => _DetallesLibroState();
}

class _DetallesLibroState extends State<DetallesLibro> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _estaCargando = false;
  bool _esFavorito = false;
  bool _estaGuardado = false;
  List<OfertaTienda> _ofertasReales = [];
  bool _cargandoOfertas = false;

  @override
  void initState() {
    super.initState();
    _verificarEstadoLibro();
    if (widget.libroObjeto.precio != null && widget.libroObjeto.precio! > 0) {
      _buscarOfertasReales();
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
      print('Error verificando estado del libro: $e');
    }
  }

  Future<void> _buscarOfertasReales() async {
    if (_cargandoOfertas) return;
    
    setState(() => _cargandoOfertas = true);
    
    try {
      if (widget.libroObjeto.isbn != null) {
        final ofertasISBN = await _buscarPorISBN(widget.libroObjeto.isbn!);
        if (ofertasISBN.isNotEmpty) {
          setState(() => _ofertasReales = ofertasISBN);
          return;
        }
      }
      
      final query = '${widget.libroObjeto.titulo} ${widget.libroObjeto.autores.isNotEmpty ? widget.libroObjeto.autores.first : ''}';
      final ofertasTitulo = await _buscarPorTitulo(query);
      if (ofertasTitulo.isNotEmpty) {
        setState(() => _ofertasReales = ofertasTitulo);
      }
    } catch (e) {
      print('Error buscando ofertas reales: $e');
    } finally {
      setState(() => _cargandoOfertas = false);
    }
  }

  Future<List<OfertaTienda>> _buscarPorISBN(String isbn) async {
    final List<OfertaTienda> ofertas = [];
    
    try {
      final googleUrl = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn');
      final googleResponse = await http.get(googleUrl);
      
      if (googleResponse.statusCode == 200) {
        final googleData = json.decode(googleResponse.body);
        if (googleData['items'] != null && googleData['items'].isNotEmpty) {
          final item = googleData['items'][0];
          final saleInfo = item['saleInfo'];
          if (saleInfo['saleability'] == 'FOR_SALE') {
            final precio = saleInfo['listPrice']?['amount']?.toDouble() ?? 0;
            if (precio > 0) {
              ofertas.add(OfertaTienda(
                tienda: 'Google Play Books',
                precio: precio,
                moneda: saleInfo['listPrice']?['currencyCode'] ?? 'EUR',
                url: saleInfo['buyLink'],
              ));
            }
          }
        }
      }
    } catch (e) {
      print('Error Google Books API: $e');
    }
    
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
      print('Error Open Library API: $e');
    }
    
    return ofertas;
  }

  Future<List<OfertaTienda>> _buscarPorTitulo(String query) async {
    final List<OfertaTienda> ofertas = [];
    
    try {
      final googleUrl = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(query)}&maxResults=5');
      final googleResponse = await http.get(googleUrl);
      
      if (googleResponse.statusCode == 200) {
        final googleData = json.decode(googleResponse.body);
        if (googleData['items'] != null && googleData['items'].isNotEmpty) {
          for (final item in googleData['items']) {
            final saleInfo = item['saleInfo'];
            if (saleInfo['saleability'] == 'FOR_SALE') {
              final precio = saleInfo['listPrice']?['amount']?.toDouble() ?? 0;
              if (precio > 0) {
                ofertas.add(OfertaTienda(
                  tienda: 'Google Play Books',
                  precio: precio,
                  moneda: saleInfo['listPrice']?['currencyCode'] ?? 'EUR',
                  url: saleInfo['buyLink'],
                ));
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error buscando por título: $e');
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

  void _mostrarOpcionesLectura() {
    final bool esGratuito = widget.libroObjeto.precio == 0.0;
    final bool esAudiolibro = widget.libroObjeto.esAudiolibro;
    
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
              '¿Cómo quieres ${esAudiolibro ? 'escuchar' : 'leer'} "${widget.libroObjeto.titulo}"?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColores.texto,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            if (widget.libroObjeto.urlLectura != null && esGratuito)
              ListTile(
                leading: const Icon(Icons.public, color: Colors.green, size: 28),
                title: const Text('Leer online gratis'),
                subtitle: Text(esAudiolibro ? 'Escuchar audiolibro completo' : 'Leer libro completo'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  _abrirURLEnApp(widget.libroObjeto.urlLectura!);
                },
              ),
            
            if (widget.libroObjeto.precio != null && widget.libroObjeto.precio! > 0)
              ListTile(
                leading: const Icon(Icons.shopping_cart, color: AppColores.secundario, size: 28),
                title: const Text('Comprar libro'),
                subtitle: const Text('Ver todas las tiendas disponibles'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarSeleccionTienda();
                },
              ),
            
            if (esAudiolibro)
              ListTile(
                leading: const Icon(Icons.headset, color: Color(0xFFF7991C), size: 28),
                title: const Text('Plataformas de audiolibros'),
                subtitle: const Text('Audible, Storytel y más'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarPlataformasAudiolibros();
                },
              ),
            
            ListTile(
              leading: const Icon(Icons.store, color: Colors.blue, size: 28),
              title: Text(esAudiolibro ? 'Buscar audiolibro' : 'Buscar en tiendas'),
              subtitle: Text(esAudiolibro ? 'Audible, Storytel...' : 'Amazon, Fnac, Casa del Libro...'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                _abrirBusquedaTiendas();
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

  void _mostrarSeleccionTienda() {
    final ofertas = _ofertasReales.isNotEmpty 
        ? _ofertasReales 
        : widget.libroObjeto.ofertasConSimuladas;
    
    if (ofertas.isEmpty) {
      _abrirBusquedaTiendas();
      return;
    }
    
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
            const Text(
              'Selecciona una tienda',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColores.texto,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Te redirigiremos a la tienda seleccionada',
              style: TextStyle(
                fontSize: 14,
                color: AppColores.textoClaro,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...ofertas.map((oferta) => ListTile(
                    leading: _iconoTienda(oferta.tienda),
                    title: Text(oferta.tienda),
                    subtitle: const Text('Ir a la tienda'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      if (oferta.url != null && oferta.url!.isNotEmpty) {
                        _abrirURL(oferta.url!);
                      }
                    },
                  )).toList(),
                ],
              ),
            ),
            
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

  void _abrirBusquedaTiendas() {
    final busqueda = widget.libroObjeto.titulo;
    
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
              style: const TextStyle(
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

  void _mostrarPlataformasAudiolibros() {
    final busqueda = widget.libroObjeto.titulo;
    
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
            const Text(
              'Plataformas de audiolibros',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColores.texto,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '"${widget.libroObjeto.titulo}"',
              style: const TextStyle(
                fontSize: 14,
                color: AppColores.textoClaro,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF7991C),
                child: Icon(Icons.headset, color: Colors.white),
              ),
              title: const Text('Audible'),
              subtitle: const Text('Amazon - Suscripción mensual'),
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
              subtitle: const Text('Streaming ilimitado'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                final url = 'https://www.storytel.com/es/es/search?q=${Uri.encodeComponent(busqueda)}';
                _abrirURL(url);
              },
            ),
            
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
          if (favorito != null) {
            _esFavorito = favorito;
          }
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

      ProgresoLectura? progreso;
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
        progreso = ProgresoLectura.fromMap(mapLocal);

        _mostrarExito('Comenzaste a leer "${widget.libroObjeto.titulo}"');
      } else {
        final data = progresoExistenteQuery.docs.first.data();
        data['id'] = progresoExistenteQuery.docs.first.id;
        progreso = ProgresoLectura.fromMap(data);
        _mostrarExito('Continuando la lectura de "${widget.libroObjeto.titulo}"');
      }

      setState(() { _estaGuardado = true; });
      
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColores.primario.withOpacity(0.1),
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
              color: const Color(0xFFEEEEEE),
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (widget.libroObjeto.autores.isNotEmpty)
                  Text(
                    'Por ${widget.libroObjeto.autores.join(', ')}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                if (widget.libroObjeto.fechaPublicacion != null)
                  Text(
                    'Publicado: ${widget.libroObjeto.fechaPublicacion}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black45,
                    ),
                  ),
                if (widget.libroObjeto.numeroPaginas != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${widget.libroObjeto.numeroPaginas} páginas',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black45,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${widget.libroObjeto.numeroCalificaciones ?? 0} reseñas)',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tieneUrl) ...[
          const SizedBox(height: 24),
          const Text(
            'Acceso Gratuito',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
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
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF757575),
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
            color: Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
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
                            style: const TextStyle(
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
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF757575),
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

  Widget _construirTiendaAudiolibro(String nombre, String url, IconData icono, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icono, color: Colors.white),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Haz clic para buscar este audiolibro'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _abrirURL(url);
        },
      ),
    );
  }

  Widget _construirTarjetaTienda(OfertaTienda oferta) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: InkWell(
        onTap: oferta.url != null && oferta.url!.isNotEmpty ? () {
          _abrirURL(oferta.url!);
        } : null,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: _iconoTienda(oferta.tienda),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                oferta.tienda,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColores.primario),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconoTienda(String tienda) {
    Map<String, Map<String, dynamic>> iconosTiendas = {
      'Amazon': {
        'icono': Icons.shopping_bag,
        'color': const Color(0xFFFF9900),
      },
      'Casa del Libro': {
        'icono': Icons.store,
        'color': const Color(0xFFE2001A),
      },
      'Fnac': {
        'icono': Icons.shopping_cart,
        'color': const Color(0xFF0D5FA6),
      },
      'Google Play Books': {
        'icono': Icons.play_circle_filled,
        'color': Colors.green,
      },
      'Audible': {
        'icono': Icons.headset,
        'color': const Color(0xFFF7991C),
      },
      'Storytel': {
        'icono': Icons.volume_up,
        'color': const Color(0xFF00A8FF),
      },
      'Open Library': {
        'icono': Icons.library_books,
        'color': Colors.purple,
      },
      'Project Gutenberg': {
        'icono': Icons.public,
        'color': Colors.teal,
      },
      'El Corte Inglés': {
        'icono': Icons.shopping_basket,
        'color': Colors.pink,
      },
    };

    final datosTienda = iconosTiendas[tienda] ?? {
      'icono': Icons.store,
      'color': const Color(0xFF9E9E9E),
    };

    return CircleAvatar(
      backgroundColor: datosTienda['color'] as Color,
      radius: 24,
      child: Icon(
        datosTienda['icono'] as IconData,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  String _calcularDiferenciaPrecio(double precioTienda, double precioBase) {
    final diferencia = precioTienda - precioBase;
    if (diferencia == 0) return 'Mismo precio';
    if (diferencia < 0) return '${diferencia.abs().toStringAsFixed(2)}€ más barato';
    return '${diferencia.toStringAsFixed(2)}€ más caro';
  }

  Color _obtenerColorDiferencia(double precioTienda, double precioBase) {
    final diferencia = precioTienda - precioBase;
    if (diferencia < 0) return Colors.green;
    if (diferencia > 0) return Colors.red;
    return const Color(0xFF9E9E9E);
  }

  Widget _construirDescripcion() {
    if (widget.libroObjeto.descripcion == null || widget.libroObjeto.descripcion!.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Descripción',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Text(
            widget.libroObjeto.descripcion!,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF616161),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirCategorias() {
    if (widget.libroObjeto.categorias.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Categorías',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF424242),
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
              const Text(
                'Añadir a tu biblioteca:',
                style: EstilosApp.cuerpoMedio,
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
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: const Text('Detalles del Libro', style: EstilosApp.tituloGrande),
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