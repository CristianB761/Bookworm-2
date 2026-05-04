import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diseno.dart';
import 'API/modelos.dart';
import 'API/ollama_service.dart';
import 'API/biblioteca_service.dart';

class DetallesManga extends StatefulWidget {
  final Manga mangaObjeto;
  const DetallesManga({super.key, required this.mangaObjeto});

  @override
  State<DetallesManga> createState() => _DetallesMangaState();
}

class _DetallesMangaState extends State<DetallesManga> {
  late Manga _manga;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OllamaService _ollamaService = OllamaService();
  bool _esFavorito = false;
  bool _estaGuardado = false;
  bool _mostrarSinopsis = false;
  bool _cargandoSinopsis = false;
  String? _sinopsisGenerada;
  bool _cargandoLectura = false;
  bool _cargandoDatosCompletos = false;
  late SharedPreferences _prefs;
  Set<String> _favoritosLocales = {};

  @override
  void initState() {
    super.initState();
    _cargarSharedPreferences();
    _manga = widget.mangaObjeto;
    _verificarEstadoManga();
    _cargarSinopsisCache();
    if (_faltanDatosCompletos()) {
      _cargarDatosCompletosDesdeApi();
    }
  }

  Future<void> _cargarSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final lista = _prefs.getStringList('favoritos_manga_locales') ?? [];
    _favoritosLocales = lista.toSet();
    setState(() {});
  }

  Future<void> _guardarFavoritoLocal(String mangaId, bool esFavorito) async {
    if (esFavorito) {
      _favoritosLocales.add(mangaId);
    } else {
      _favoritosLocales.remove(mangaId);
    }
    await _prefs.setStringList('favoritos_manga_locales', _favoritosLocales.toList());
    setState(() {
      _esFavorito = esFavorito;
    });
  }

  bool _faltanDatosCompletos() {
    return _manga.generos.isEmpty &&
           _manga.adaptacionAnime == null &&
           _manga.urlMangaDex == null;
  }

  Future<void> _cargarDatosCompletosDesdeApi() async {
    if (_cargandoDatosCompletos) return;
    setState(() => _cargandoDatosCompletos = true);
    try {
      final servicio = BibliotecaServiceUnificado();
      final mangaCompleto = await servicio.obtenerDetallesManga(_manga.id);
      if (mangaCompleto != null && mounted) {
        setState(() {
          _manga = mangaCompleto;
          _cargandoDatosCompletos = false;
        });
        if (_sinopsisGenerada == null && _manga.sinopsis != null) {
          setState(() => _sinopsisGenerada = _manga.sinopsis);
        }
      } else {
        setState(() => _cargandoDatosCompletos = false);
      }
    } catch (e) {
      setState(() => _cargandoDatosCompletos = false);
    }
  }

  Future<void> _cargarSinopsisCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'sinopsis_manga_${_manga.id}';
      final cached = prefs.getString(key);
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _sinopsisGenerada = cached;
        });
      }
    } catch (e) {}
  }

  Future<void> _guardarSinopsisCache(String sinopsis) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'sinopsis_manga_${_manga.id}';
      await prefs.setString(key, sinopsis);
    } catch (e) {}
  }

  Future<void> _generarSinopsisOllama() async {
    if (_sinopsisGenerada != null) return;
    setState(() => _cargandoSinopsis = true);
    try {
      final sinopsis = await _ollamaService.generarDescripcionManga(
        titulo: _manga.titulo,
        autores: _manga.autores,
        sinopsisOriginal: _manga.sinopsis,
        generos: _manga.generos,
        temas: _manga.temas,
        estado: _manga.estado,
      );
      if (mounted) {
        final sinopsisFinal = sinopsis ?? 'No se pudo generar la sinopsis.';
        setState(() {
          _sinopsisGenerada = sinopsisFinal;
          _cargandoSinopsis = false;
        });
        if (sinopsisFinal != 'No se pudo generar la sinopsis.') {
          await _guardarSinopsisCache(sinopsisFinal);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sinopsisGenerada = 'Error al generar sinopsis: $e';
          _cargandoSinopsis = false;
        });
      }
    }
  }

  Future<void> _verificarEstadoManga() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      final mangaDoc = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('mangas_guardados')
          .doc(_manga.id)
          .get();

      if (mangaDoc.exists) {
        final data = mangaDoc.data()!;
        setState(() {
          _estaGuardado = data['guardado'] == true;
          _esFavorito = data['favorito'] == true;
        });
      } else {
        setState(() {
          _estaGuardado = false;
          _esFavorito = _favoritosLocales.contains(_manga.id);
        });
      }
    } catch (e) {}
  }

  Future<void> _toggleFavorito() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        _mostrarError('Debes iniciar sesión primero');
        return;
      }

      final nuevoEstado = !_esFavorito;
      final docRef = _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('mangas_guardados')
          .doc(_manga.id);

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        await docRef.update({'favorito': nuevoEstado});
        setState(() {
          _esFavorito = nuevoEstado;
        });
        _mostrarExito(nuevoEstado ? 'Añadido a favoritos' : 'Removido de favoritos');
      } else {
        await _guardarFavoritoLocal(_manga.id, nuevoEstado);
        _mostrarExito(nuevoEstado ? 'Añadido a favoritos (localmente)' : 'Removido de favoritos locales');
      }
    } catch (e) {
      _mostrarError('Error: $e');
    }
  }

  Future<void> _guardarManga() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        _mostrarError('Debes iniciar sesión primero');
        return;
      }

      final docRef = _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('mangas_guardados')
          .doc(_manga.id);

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final favoritoEnFirestore = data['favorito'] ?? false;

        await docRef.delete();

        if (favoritoEnFirestore) {
          await _guardarFavoritoLocal(_manga.id, true);
        }

        setState(() {
          _estaGuardado = false;
          if (!favoritoEnFirestore) {
            _esFavorito = _favoritosLocales.contains(_manga.id);
          }
        });
        _mostrarExito('"${_manga.titulo}" eliminado de tu biblioteca');
      } else {
        final teniaFavoritoLocal = _favoritosLocales.contains(_manga.id);
        final mangaData = {
          'id': _manga.id,
          'titulo': _manga.titulo,
          'urlPortada': _manga.urlPortada,
          'autores': _manga.autores,
          'guardado': true,
          'favorito': teniaFavoritoLocal,
          'fechaGuardado': FieldValue.serverTimestamp(),
          'generos': _manga.generos,
          'temas': _manga.temas,
          'adaptacionAnime': _manga.adaptacionAnime,
          'urlMangaDex': _manga.urlMangaDex,
          'urlAniList': _manga.urlAniList,
          'calificacionAniList': _manga.calificacionAniList,
          'calificacionMangaDex': _manga.calificacionMangaDex,
          'popularidad': _manga.popularidad,
          'numeroCapitulos': _manga.numeroCapitulos,
          'ultimoCapituloLanzado': _manga.ultimoCapituloLanzado,
          'estado': _manga.estado,
          'sinopsis': _manga.sinopsis,
          'fechaPublicacion': _manga.fechaPublicacion,
        };
        await docRef.set(mangaData);
        if (teniaFavoritoLocal) {
          await _guardarFavoritoLocal(_manga.id, false);
          setState(() {
            _esFavorito = true;
          });
        }
        setState(() {
          _estaGuardado = true;
        });
        _mostrarExito('"${_manga.titulo}" guardado en tu biblioteca');
      }
    } catch (e) {
      _mostrarError('Error: $e');
    }
  }

  Future<void> _iniciarLectura() async {
    final usuario = _auth.currentUser;
    if (usuario == null) {
      _mostrarError('Debes iniciar sesión para empezar a leer');
      return;
    }

    setState(() => _cargandoLectura = true);

    try {
      final mangaGuardadoRef = _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('mangas_guardados')
          .doc(_manga.id);

      final mangaGuardadoSnap = await mangaGuardadoRef.get();
      if (mangaGuardadoSnap.exists) {
        await mangaGuardadoRef.update({'estado': 'leyendo'});
      } else {
        final teniaFavoritoLocal = _favoritosLocales.contains(_manga.id);
        await mangaGuardadoRef.set({
          'id': _manga.id,
          'titulo': _manga.titulo,
          'urlPortada': _manga.urlPortada,
          'autores': _manga.autores,
          'favorito': teniaFavoritoLocal,
          'guardado': true,
          'estado': 'leyendo',
          'fechaGuardado': FieldValue.serverTimestamp(),
          'generos': _manga.generos,
          'temas': _manga.temas,
          'adaptacionAnime': _manga.adaptacionAnime,
          'urlMangaDex': _manga.urlMangaDex,
          'urlAniList': _manga.urlAniList,
          'calificacionAniList': _manga.calificacionAniList,
          'calificacionMangaDex': _manga.calificacionMangaDex,
          'popularidad': _manga.popularidad,
          'numeroCapitulos': _manga.numeroCapitulos,
          'ultimoCapituloLanzado': _manga.ultimoCapituloLanzado,
          'sinopsis': _manga.sinopsis,
          'fechaPublicacion': _manga.fechaPublicacion,
        });
        if (teniaFavoritoLocal) {
          await _guardarFavoritoLocal(_manga.id, false);
          setState(() {
            _esFavorito = true;
          });
        }
        setState(() {
          _estaGuardado = true;
        });
      }

      final progresoExistenteQuery = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuario.uid)
          .where('libroId', isEqualTo: _manga.id)
          .limit(1)
          .get();

      if (progresoExistenteQuery.docs.isEmpty) {
        final nuevoProgresoId = _firestore.collection('progreso_lectura').doc().id;
        final nuevoProgresoData = {
          'id': nuevoProgresoId,
          'usuarioId': usuario.uid,
          'libroId': _manga.id,
          'tituloLibro': _manga.titulo,
          'autoresLibro': _manga.autores,
          'miniaturaLibro': _manga.urlPortada,
          'estado': 'leyendo',
          'paginaActual': 0,
          'paginasTotales': 0,
          'fechaInicio': FieldValue.serverTimestamp(),
          'calificacion': 0.0,
        };
        await _firestore.collection('progreso_lectura').doc(nuevoProgresoId).set(nuevoProgresoData);
        _mostrarExito('Comenzaste a leer "${_manga.titulo}"');
      } else {
        _mostrarExito('Continuando la lectura de "${_manga.titulo}"');
      }

      if (mounted) {
        Navigator.pushNamed(context, '/perfil', arguments: {'seccionIndex': 1});
      }
    } catch (e) {
      _mostrarError('Error al iniciar lectura: $e');
    } finally {
      if (mounted) setState(() => _cargandoLectura = false);
    }
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColores.exito,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColores.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _abrirBusquedaTiendas() {
    final query = _manga.titulo;
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
              'Buscar en tiendas',
              style: EstilosApp.tituloMedio(context),
            ),
            const SizedBox(height: 10),
            Text(
              '"${_manga.titulo}"',
              style: EstilosApp.cuerpoMedio(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFF9900),
                child: Icon(Icons.shopping_bag, color: Colors.white),
              ),
              title: Text('Amazon', style: EstilosApp.cuerpoGrande(context)),
              subtitle: Text('Buscar en Amazon', style: EstilosApp.cuerpoMedio(context)),
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
              title: Text('Casa del Libro', style: EstilosApp.cuerpoGrande(context)),
              subtitle: Text('Librería española', style: EstilosApp.cuerpoMedio(context)),
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
              title: Text('Fnac', style: EstilosApp.cuerpoGrande(context)),
              subtitle: Text('Tienda de cultura', style: EstilosApp.cuerpoMedio(context)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                final url = 'https://www.fnac.es/ia?Search=${Uri.encodeComponent(query)}';
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

  void _abrirPlataformasAnime() {
    final query = Uri.encodeComponent(_manga.titulo);
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
              'Ver adaptación anime',
              style: EstilosApp.tituloMedio(context),
            ),
            const SizedBox(height: 10),
            Text(
              '"${_manga.titulo}"',
              style: EstilosApp.cuerpoMedio(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFF47521),
                child: const Icon(Icons.tv, color: Colors.white),
              ),
              title: Text('Crunchyroll', style: EstilosApp.cuerpoGrande(context)),
              subtitle: Text('Anime y manga en streaming', style: EstilosApp.cuerpoMedio(context)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                final url = 'https://www.crunchyroll.com/es/search?q=$query';
                _abrirURL(url);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE50914),
                child: const Icon(Icons.tv, color: Colors.white),
              ),
              title: Text('Netflix', style: EstilosApp.cuerpoGrande(context)),
              subtitle: Text('Plataforma de streaming', style: EstilosApp.cuerpoMedio(context)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                final url = 'https://www.netflix.com/es/search?q=$query';
                _abrirURL(url);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF00A8E1),
                child: const Icon(Icons.tv, color: Colors.white),
              ),
              title: Text('Amazon Prime Video', style: EstilosApp.cuerpoGrande(context)),
              subtitle: Text('Series y películas', style: EstilosApp.cuerpoMedio(context)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pop(context);
                final url = 'https://www.primevideo.com/search/ref=atv_nb_sr?phrase=$query';
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

  Future<void> _abrirURL(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _mostrarError('No se pudo abrir el enlace: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Detalles del Manga',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
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
                      color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F5F5) : const Color(0xFF2C2C2C),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _manga.urlPortada != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _manga.urlPortada!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.auto_stories,
                                    size: 50,
                                    color: AppColores.primario,
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.auto_stories,
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
                          _manga.titulo,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (_manga.autores.isNotEmpty)
                          Text(
                            'Por ${_manga.autores.join(', ')}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (_manga.fechaPublicacion != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Publicado: ${_manga.fechaPublicacion}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (_manga.calificacionAniList != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColores.primario.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 12, color: AppColores.acento),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(_manga.calificacionAniList! / 10).toStringAsFixed(1)}/10',
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyLarge?.color),
                                    ),
                                  ],
                                ),
                              ),
                            if (_manga.estado != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _manga.estado!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.green),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColores.primario.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_stories, size: 12, color: AppColores.acento),
                                  const SizedBox(width: 4),
                                  const Text('Manga', style: TextStyle(fontSize: 12, color: Colors.white)),
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
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sinopsis',
                    style: EstilosApp.tituloMedio(context),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_mostrarSinopsis) {
                        setState(() => _mostrarSinopsis = false);
                      } else {
                        setState(() => _mostrarSinopsis = true);
                        if (_sinopsisGenerada == null) {
                          _generarSinopsisOllama();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColores.primario,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(_mostrarSinopsis ? 'Ocultar' : 'Mostrar'),
                  ),
                  if (_mostrarSinopsis) ...[
                    const SizedBox(height: 16),
                    _cargandoSinopsis
                        ? const Center(child: CircularProgressIndicator())
                        : _sinopsisGenerada != null
                            ? Text(
                                _sinopsisGenerada!,
                                style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.5),
                              )
                            : const SizedBox.shrink(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_manga.generos.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Géneros',
                      style: EstilosApp.tituloMedio(context),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _manga.generos.map((genero) {
                        return Chip(
                          label: Text(genero),
                          backgroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFFEEEEEE) : const Color(0xFF2C2C2C),
                          labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 12),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            if (_manga.adaptacionAnime != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adaptación anime',
                      style: EstilosApp.tituloMedio(context),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFFAFAFA) : const Color(0xFF2C2C2C),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.tv, color: AppColores.acento, size: 32),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Ver adaptación anime', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColores.acento)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Encuentra este anime en Crunchyroll, Netflix, y más.',
                                        style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _abrirPlataformasAnime,
                              icon: const Icon(Icons.play_circle_filled),
                              label: const Text('Ver Anime'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColores.acento,
                                foregroundColor: Colors.black,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acceso Gratuito',
                    style: EstilosApp.tituloMedio(context),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFFAFAFA) : const Color(0xFF2C2C2C),
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
                                    const Text('Manga Gratuito', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Este Manga está disponible para leer gratis',
                                      style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_manga.urlMangaDex != null)
                            ElevatedButton.icon(
                              onPressed: () => _abrirURL(_manga.urlMangaDex!),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Leer Gratis'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disponibilidad en Tiendas',
                    style: EstilosApp.tituloMedio(context),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFFAFAFA) : const Color(0xFF2C2C2C),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.store, color: AppColores.primario, size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Buscar en tiendas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColores.primario)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Encuentra este manga en Amazon, Fnac, y más.',
                                      style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _abrirBusquedaTiendas,
                            icon: const Icon(Icons.search),
                            label: const Text('Buscar en Tiendas'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColores.primario,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cargandoLectura ? null : _iniciarLectura,
                icon: const Icon(Icons.menu_book),
                label: const Text('Empezar a Leer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.primario,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleFavorito,
                    icon: Icon(_esFavorito ? Icons.favorite : Icons.favorite_border),
                    label: Text(_esFavorito ? 'En favoritos' : 'Favorito'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F5F5) : const Color(0xFF2C2C2C),
                      foregroundColor: _esFavorito ? Colors.red : AppColores.textoClaro,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _guardarManga,
                    icon: Icon(_estaGuardado ? Icons.bookmark : Icons.bookmark_border),
                    label: Text(_estaGuardado ? 'Guardado' : 'Guardar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F5F5) : const Color(0xFF2C2C2C),
                      foregroundColor: _estaGuardado ? Colors.amber : AppColores.textoClaro,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}