import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'autenticacion.dart';
import 'buscar.dart';
import 'clubs.dart';
import 'perfil.dart';
import 'diseno.dart';
import 'componentes.dart';
import 'chat_clubs.dart';
import 'graficos_estadisticas.dart';
import 'sincronizacion_offline.dart';
import 'detalles_libro.dart';
import 'public_domain.dart';
import 'API/modelos.dart';
import 'historial.dart';
import 'desafios.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AppBookWorm());
}

class AppBookWorm extends StatelessWidget {
  const AppBookWorm({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookWorm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColores.primario,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColores.primario),
        scaffoldBackgroundColor: AppColores.fondo,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColores.primario,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: EstilosApp.botonPrimario),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const Autenticacion(),
        '/home': (context) => const PaginaInicio(),
        '/search': (context) => const Buscar(),
        '/clubs': (context) => const Clubs(),
        '/perfil': (context) => const Perfil(),
        '/chat_club': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return ChatClub(
              clubId: args['clubId'],
              clubNombre: args['clubNombre'],
              rolUsuario: args['rolUsuario'],
            );
          }
          return const Scaffold(body: Center(child: Text('Error: Datos del club no encontrados')));
        },
        '/graficos': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return GraficosEstadisticas(
              datosEstadisticas: args['datosEstadisticas'],
            );
          }
          return const Scaffold(body: Center(child: Text('Error: Datos de estadísticas no encontrados')));
        },
        '/historial': (context) => const Historial(),
        '/desafios': (context) => const Desafios(),
        '/sincronizacion': (context) => const PantallaSincronizacion(),
        '/public_domain': (context) => const PublicDomain(),
        '/detalles_libro': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Libro) {
            return DetallesLibro(libroObjeto: args);
          }
          return const Scaffold(body: Center(child: Text('Error: Libro no encontrado')));
        },
        '/lector': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return Scaffold(
              appBar: AppBar(title: const Text('Lector')),
              body: const Center(child: Text('El lector de libros estará disponible pronto')),
            );
          }
          return const Scaffold(body: Center(child: Text('Error: Datos de lectura no encontrados')));
        },
      },
    );
  }
}

class PaginaInicio extends StatefulWidget {
  const PaginaInicio({super.key});

  @override
  State<PaginaInicio> createState() => _PaginaInicioState();
}

class _PaginaInicioState extends State<PaginaInicio> {
  bool _mostrarTodosAccesosRapidos = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Libro> _librosAleatorios = [];
  bool _cargandoAleatorios = false;

  @override
  void initState() {
    super.initState();
    _cargarLibrosAleatorios();
  }

  Future<void> _cargarLibrosAleatorios() async {
    if (!mounted) return;
    setState(() => _cargandoAleatorios = true);

    try {
      final temas = ['ficcion', 'misterio', 'fantasia', 'historia', 'ciencia', 'romance', 'aventura', 'tecnologia'];
      final tema = temas[Random().nextInt(temas.length)];
      
      final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=subject:$tema&maxResults=10&langRestrict=es&orderBy=newest');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null) {
          final List<Libro> libros = [];
          for (var item in data['items']) {
            final volumeInfo = item['volumeInfo'];
            libros.add(Libro(
              id: item['id'],
              titulo: volumeInfo['title'] ?? 'Sin título',
              autores: List<String>.from(volumeInfo['authors'] ?? ['Desconocido']),
              descripcion: volumeInfo['description'],
              urlMiniatura: volumeInfo['imageLinks']?['thumbnail']?.toString().replaceAll('http:', 'https:'),
              fechaPublicacion: volumeInfo['publishedDate'],
              numeroPaginas: volumeInfo['pageCount'],
              categorias: List<String>.from(volumeInfo['categories'] ?? []),
              urlLectura: volumeInfo['previewLink'],
            ));
          }
          if (mounted) {
            setState(() => _librosAleatorios = libros);
          }
        }
      }
    } catch (e) {
      print('Error cargando libros aleatorios: $e');
    } finally {
      if (mounted) setState(() => _cargandoAleatorios = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
          child: const Text('BookWorm', style: EstilosApp.tituloGrande),
        ),
        automaticallyImplyLeading: false,
        actions: const [BotonesBarraApp(rutaActual: '/home')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              constraints: const BoxConstraints(minHeight: 180),
              decoration: EstilosApp.decoracionGradiente,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Bienvenido de vuelta',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Continúa tu aventura literaria',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            BotonAccionRapida(
                              texto: 'Buscar libros',
                              icono: Icons.search,
                              alPresionar: () => Navigator.pushNamed(context, '/search'),
                            ),
                            const SizedBox(width: 12),
                            BotonAccionRapida(
                              texto: 'Ver progreso',
                              icono: Icons.trending_up,
                              alPresionar: () => Navigator.pushNamed(context, '/perfil'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.menu_book_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: EstilosApp.tarjeta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Acceso rápido',
                    style: EstilosApp.tituloMedio,
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _mostrarTodosAccesosRapidos || DatosApp.accionesRapidas.length <= 4
                        ? DatosApp.accionesRapidas.length
                        : 4,
                    itemBuilder: (BuildContext context, int index) {
                      final accion = DatosApp.accionesRapidas[index];
                      return InkWell(
                        onTap: () {
                          if (accion['etiqueta'] == 'Buscar') {
                            Navigator.pushNamed(context, '/search');
                          } else if (accion['etiqueta'] == 'Libros Recomendados') {
                            Navigator.pushNamed(context, '/public_domain');
                          } else if (accion['etiqueta'] == 'Clubs') {
                            Navigator.pushNamed(context, '/clubs');
                          } else if (accion['etiqueta'] == 'Historial') {
                            Navigator.pushNamed(context, '/historial');
                          } else if (accion['etiqueta'] == 'Desafíos') {
                            Navigator.pushNamed(context, '/desafios');
                          } else if (['Favoritos', 'Configuración'].contains(accion['etiqueta'])) {
                            Navigator.pushNamed(context, '/perfil');
                          }
                        },
                        child: Container(
                          decoration: EstilosApp.tarjetaPlana,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                accion['icono'] as IconData,
                                size: 32,
                                color: AppColores.primario,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                accion['etiqueta'] as String,
                                style: EstilosApp.cuerpoPequeno,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (DatosApp.accionesRapidas.length > 4)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _mostrarTodosAccesosRapidos = !_mostrarTodosAccesosRapidos;
                        });
                      },
                      child: Text(
                        _mostrarTodosAccesosRapidos ? 'Ver menos' : 'Ver más',
                        style: const TextStyle(
                          color: AppColores.primario,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 280,
                    padding: const EdgeInsets.all(24),
                    decoration: EstilosApp.tarjeta,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Mis lecturas actuales',
                          style: EstilosApp.tituloPequeno,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _auth.currentUser == null
                              ? const Center(child: Text('Inicia sesión para ver tus lecturas', style: EstilosApp.cuerpoMedio))
                              : StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('progreso_lectura')
                                .where('usuarioId', isEqualTo: _auth.currentUser?.uid)
                                .where('estado', isEqualTo: 'leyendo')
                                .orderBy('fechaInicio', descending: true)
                                .limit(5)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SelectableText(
                                      'Error: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.red, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No tienes lecturas en progreso',
                                    style: EstilosApp.cuerpoMedio,
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: snapshot.data!.docs.length,
                                separatorBuilder: (context, index) => const Divider(height: 16),
                                itemBuilder: (context, index) {
                                  final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                                  final titulo = data['tituloLibro'] ?? 'Sin título';
                                  final paginaActual = data['paginaActual'] ?? 0;
                                  final paginasTotales = data['paginasTotales'] ?? 1;
                                  final porcentaje = paginasTotales > 0 
                                      ? (paginaActual / paginasTotales * 100).clamp(0.0, 100.0) 
                                      : 0.0;

                                  return InkWell(
                                    onTap: () => Navigator.pushNamed(context, '/perfil', arguments: {'seccionIndex': 1}),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(titulo, style: EstilosApp.cuerpoMedio, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ),
                                        Text(
                                          '${porcentaje.toStringAsFixed(0)}%',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColores.primario),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 280,
                    padding: const EdgeInsets.all(24),
                    decoration: EstilosApp.tarjeta,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Libros leídos',
                              style: EstilosApp.tituloPequeno,
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/perfil', arguments: {'seccionIndex': 1, 'filtroEstado': 'completado'}),
                              child: const Text('Ver todos'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _auth.currentUser == null
                              ? const Center(child: Text('Inicia sesión', style: EstilosApp.cuerpoPequeno))
                              : StreamBuilder<QuerySnapshot>(
                                  stream: _firestore
                                      .collection('progreso_lectura')
                                      .where('usuarioId', isEqualTo: _auth.currentUser?.uid)
                                      .where('estado', isEqualTo: 'completado')
                                      .orderBy('fechaCompletado', descending: true)
                                      .limit(10)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: SelectableText(
                                            'Error: ${snapshot.error}',
                                            style: const TextStyle(color: Colors.red, fontSize: 10),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      );
                                    }

                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }

                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.emoji_events_outlined, size: 40, color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text(
                                              'Aún no has completado libros',
                                              style: EstilosApp.cuerpoPequeno,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: snapshot.data!.docs.length,
                                      separatorBuilder: (context, index) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                                        final titulo = data['tituloLibro'] ?? 'Sin título';
                                        final miniatura = data['miniaturaLibro'];
                                        final fechaTs = data['fechaCompletado'] as Timestamp?;
                                        final fecha = fechaTs != null 
                                            ? '${fechaTs.toDate().day}/${fechaTs.toDate().month}/${fechaTs.toDate().year}' 
                                            : '';

                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                          leading: miniatura != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Image.network(miniatura, width: 40, height: 60, fit: BoxFit.cover),
                                                )
                                              : const Icon(Icons.book, size: 40, color: AppColores.primario),
                                          title: Text(titulo, style: EstilosApp.cuerpoMedio, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          subtitle: Text('Leído el $fecha', style: EstilosApp.cuerpoPequeno),
                                          onTap: () => Navigator.pushNamed(context, '/perfil', arguments: {'seccionIndex': 1, 'filtroEstado': 'completado'}),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: EstilosApp.tarjeta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Descubre algo nuevo',
                    style: EstilosApp.tituloMedio,
                  ),
                  const SizedBox(height: 16),
                  if (_cargandoAleatorios)
                    const Center(child: CircularProgressIndicator())
                  else if (_librosAleatorios.isEmpty)
                    const Center(child: Text('No se encontraron sugerencias', style: EstilosApp.cuerpoMedio))
                  else
                    SizedBox(
                      height: 240,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _librosAleatorios.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final libro = _librosAleatorios[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/detalles_libro',
                                arguments: libro,
                              );
                            },
                            child: SizedBox(
                              width: 140,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: libro.urlMiniatura != null
                                            ? Image.network(
                                                libro.urlMiniatura!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (context, error, stackTrace) => 
                                                    Container(color: Colors.grey[200], child: const Icon(Icons.book, color: Colors.grey, size: 40)),
                                              )
                                            : Container(color: Colors.grey[200], child: const Icon(Icons.book, color: Colors.grey, size: 40)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    libro.titulo,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    libro.autores.isNotEmpty ? libro.autores.first : 'Desconocido',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}