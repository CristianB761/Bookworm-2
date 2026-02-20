import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'diseño.dart';
import 'componentes.dart';
import '../API/modelos.dart';
import '../API/open_library.dart';

class DetallesLibro extends StatefulWidget {
  final Libro libro;

  const DetallesLibro({super.key, required this.libro});

  @override
  State<DetallesLibro> createState() => _DetallesLibroState();
}

class _DetallesLibroState extends State<DetallesLibro> {
  late Libro _libroDetallado;
  bool _cargandoDetalles = false;
  bool _libroGuardado = false;
  final OpenLibrary _openLibrary = OpenLibrary();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _libroDetallado = widget.libro;
    _verificarSiLibroEstaGuardado();
    _cargarDetallesCompletos();
  }

  Future<void> _verificarSiLibroEstaGuardado() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      final doc = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(widget.libro.id)
          .get();

      if (mounted) {
        setState(() {
          _libroGuardado = doc.exists;
        });
      }
    } catch (e) {
      print('Error verificando libro guardado: $e');
    }
  }

  Future<void> _cargarDetallesCompletos() async {
    setState(() => _cargandoDetalles = true);
    try {
      final detalles = await _openLibrary.obtenerDetallesLibro(widget.libro.id);
      if (detalles != null && mounted) {
        setState(() {
          _libroDetallado = detalles;
        });
      }
    } catch (e) {
      print('Error cargando detalles: $e');
    } finally {
      setState(() => _cargandoDetalles = false);
    }
  }

  Future<void> _guardarLibro() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        _mostrarError('Debes iniciar sesión para guardar libros');
        return;
      }

      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(_libroDetallado.id)
          .set({
            'libroId': _libroDetallado.id,
            'titulo': _libroDetallado.titulo,
            'autores': _libroDetallado.autores,
            'descripcion': _libroDetallado.descripcion,
            'urlMiniatura': _libroDetallado.urlMiniatura,
            'fechaPublicacion': _libroDetallado.fechaPublicacion,
            'numeroPaginas': _libroDetallado.numeroPaginas,
            'categorias': _libroDetallado.categorias,
            'fechaGuardado': FieldValue.serverTimestamp(),
            'estado': 'guardado',
          });

      setState(() {
        _libroGuardado = true;
      });

      _mostrarExito('"${_libroDetallado.titulo}" guardado en tu biblioteca');
    } catch (e) {
      _mostrarError('Error al guardar libro: $e');
    }
  }

  Future<void> _iniciarProgresoLectura() async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        _mostrarError('Debes iniciar sesión para iniciar progreso');
        return;
      }

      final progresoId = _firestore.collection('progreso_lectura').doc().id;
      
      await _firestore
          .collection('progreso_lectura')
          .doc(progresoId)
          .set({
            'id': progresoId,
            'usuarioId': usuario.uid,
            'libroId': _libroDetallado.id,
            'tituloLibro': _libroDetallado.titulo,
            'autoresLibro': _libroDetallado.autores,
            'miniaturaLibro': _libroDetallado.urlMiniatura,
            'estado': 'leyendo',
            'paginaActual': 0,
            'paginasTotales': _libroDetallado.numeroPaginas ?? 0,
            'fechaInicio': FieldValue.serverTimestamp(),
            'calificacion': 0.0,
          });

      // Actualizar el libro guardado si existe
      if (_libroGuardado) {
        await _firestore
            .collection('usuarios')
            .doc(usuario.uid)
            .collection('libros_guardados')
            .doc(_libroDetallado.id)
            .update({'estado': 'leyendo'});
      }

      _mostrarExito('Progreso iniciado para "${_libroDetallado.titulo}"');
    } catch (e) {
      _mostrarError('Error al iniciar progreso: $e');
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

  Widget _construirItemInfo({required IconData icono, required String texto}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icono, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _libroDetallado.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColores.primario,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portada del libro
            Center(
              child: Container(
                width: 200,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _libroDetallado.urlMiniatura != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _libroDetallado.urlMiniatura!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.book,
                              size: 60,
                              color: Colors.grey,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.book,
                        size: 60,
                        color: Colors.grey,
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Título y autores
            Text(
              _libroDetallado.titulo,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (_libroDetallado.autores.isNotEmpty)
              Text(
                'Por ${_libroDetallado.autores.join(', ')}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 16),

            // Calificación
            if (_libroDetallado.calificacionPromedio != null)
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    '${_libroDetallado.calificacionPromedio!.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${_libroDetallado.numeroCalificaciones ?? 0} calificaciones)',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Información adicional
            if (_libroDetallado.fechaPublicacion != null)
              _construirItemInfo(
                icono: Icons.calendar_today,
                texto: 'Publicado: ${_libroDetallado.fechaPublicacion}',
              ),

            if (_libroDetallado.numeroPaginas != null)
              _construirItemInfo(
                icono: Icons.article,
                texto: '${_libroDetallado.numeroPaginas} páginas',
              ),

            if (_libroDetallado.categorias.isNotEmpty)
              _construirItemInfo(
                icono: Icons.category,
                texto: 'Categorías: ${_libroDetallado.categorias.join(', ')}',
              ),
            const SizedBox(height: 24),

            // Descripción
            if (_libroDetallado.descripcion != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _libroDetallado.descripcion!,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 32),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _libroGuardado ? null : _guardarLibro,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _libroGuardado ? Colors.grey : AppColores.primario,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_libroGuardado ? Icons.check : Icons.bookmark_add),
                        const SizedBox(width: 8),
                        Text(_libroGuardado ? 'Ya guardado' : 'Guardar Libro'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _iniciarProgresoLectura,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColores.primario),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow),
                        SizedBox(width: 8),
                        Text('Comenzar a Leer'),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_cargandoDetalles)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}