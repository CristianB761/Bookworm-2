import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'diseno.dart';
import 'componentes.dart';
import 'API/modelos.dart';
import 'API/biblioteca_service.dart';

class PublicDomain extends StatefulWidget {
  const PublicDomain({super.key});

  @override
  State<PublicDomain> createState() => _PublicDomainState();
}

class _PublicDomainState extends State<PublicDomain> {
  final BibliotecaServiceUnificado _servicioBiblioteca = BibliotecaServiceUnificado(apiKey: 'AIzaSyCiPj-QLleEc1jMnNMPuuSvM6Z7Q4zNvXA');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Libro> _libros = [];
  bool _estaCargando = true;
  String _tipoRecomendacion = 'Populares';

  @override
  void initState() {
    super.initState();
    _cargarRecomendaciones();
  }

  Future<void> _cargarRecomendaciones() async {
    setState(() => _estaCargando = true);
    try {
      final usuario = _auth.currentUser;
      List<Libro> librosRecomendados = [];
      Set<String> generosParaBuscar = {};

      if (usuario != null) {
        final docUsuario = await _firestore.collection('usuarios').doc(usuario.uid).get();
        final datosUsuario = docUsuario.data();
        
        if (datosUsuario != null && datosUsuario['generosFavoritos'] != null) {
          final favoritos = List<String>.from(datosUsuario['generosFavoritos']);
          generosParaBuscar.addAll(favoritos);
        }

        final historialSnapshot = await _firestore
            .collection('usuarios')
            .doc(usuario.uid)
            .collection('historial')
            .orderBy('fechaVisto', descending: true)
            .limit(20)
            .get();

        for (var doc in historialSnapshot.docs) {
          final data = doc.data();
          if (data['categorias'] != null) {
            final cats = List<String>.from(data['categorias']);
            generosParaBuscar.addAll(cats);
          }
        }
      }

      final generosLista = generosParaBuscar
          .where((g) => g.isNotEmpty && g != 'Todos los géneros')
          .toList();

      if (generosLista.isNotEmpty) {
        _tipoRecomendacion = 'Basado en tus gustos';
        generosLista.shuffle();
        final generosTop = generosLista.take(3).toList();

        for (var genero in generosTop) {
          String termino = _traducirGenero(genero);
          final resultados = await _servicioBiblioteca.buscarLibros(termino, genero: termino, limite: 10);
          librosRecomendados.addAll(resultados);
        }
        
        final ids = <String>{};
        librosRecomendados.retainWhere((x) => ids.add(x.id));
        librosRecomendados.shuffle();
      }

      if (librosRecomendados.isEmpty) {
        _tipoRecomendacion = 'Populares';
        librosRecomendados = await _servicioBiblioteca.obtenerLibrosPopulares(limite: 30);
      }

      if (mounted) setState(() => _libros = librosRecomendados);
    } catch (e) {
      _mostrarError('Error al cargar recomendaciones: $e');
      _cargarLibrosPopulares();
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  String _traducirGenero(String genero) {
    final map = {
      'Ficción': 'Fiction',
      'Ciencia Ficción': 'Science Fiction',
      'Fantasía': 'Fantasy',
      'Misterio': 'Mystery',
      'Terror': 'Horror',
      'Romance': 'Romance',
      'Historia': 'History',
      'Biografía': 'Biography',
      'Aventura': 'Adventure',
      'Poesía': 'Poetry',
      'Infantil': 'Children',
      'Juvenil': 'Young Adult',
    };
    return map[genero] ?? genero;
  }

  Future<void> _cargarLibrosPopulares() async {
    if (!mounted) return;
    try {
      final resultados = await _servicioBiblioteca.obtenerLibrosPopulares(limite: 30);
      setState(() {
        _libros = resultados;
        _tipoRecomendacion = 'Populares';
      });
    } catch (e) {
      _mostrarError('Error al cargar libros: $e');
    }
  }

  Future<void> _guardarLibro(Libro libro) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        _mostrarError('Debes iniciar sesión para guardar libros');
        return;
      }

      final datosLibro = libro.toMap();
      datosLibro['fechaGuardado'] = FieldValue.serverTimestamp();
      datosLibro['estado'] = 'guardado';
      datosLibro['libroId'] = libro.id;

      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(libro.id)
          .set(datosLibro);

      _mostrarExito('"${libro.titulo}" guardado en tu biblioteca');
    } catch (e) {
      _mostrarError('Error al guardar libro: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColores.secundario),
    );
  }

  void _mostrarDetallesLibro(Libro libro) {
    Navigator.pushNamed(context, '/detalles_libro', arguments: libro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Biblioteca', style: EstilosApp.tituloGrande(context)),
        backgroundColor: AppColores.primario,
        actions: const [BotonesBarraApp(rutaActual: '/public_domain')],
      ),
      body: _estaCargando 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    _tipoRecomendacion,
                    style: EstilosApp.tituloMedio(context),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: _libros.length,
                    itemBuilder: (context, index) {
                      final libro = _libros[index];
                      return TarjetaLibro(
                        libro: libro,
                        alPresionar: () => _mostrarDetallesLibro(libro),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}