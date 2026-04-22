import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
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
import 'detalles_manga.dart';
import 'public_domain.dart';
import 'API/modelos.dart';
import 'historial.dart';
import 'desafios.dart';
import 'theme_provider.dart';
import 'servicio/servicio_notificaciones.dart';
import 'mensajes_directos.dart';
import 'pantalla_recomendaciones.dart';
import 'recomendaciones_widget.dart';
import 'noticias.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ServicioNotificaciones()),
      ],
      child: const AppBookWorm(),
    ),
  );
}

class AppBookWorm extends StatelessWidget {
  const AppBookWorm({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'BookWorm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColores.primario,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColores.primario,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFfffafa),
        cardColor: const Color(0xFFf5f5f5),
        dividerColor: const Color(0xFFDDDDDD),
        hintColor: const Color(0xFF666666),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColores.primario,
          foregroundColor: Color(0xFFfffafa),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: EstilosApp.botonPrimario(context),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF333333)),
          bodyMedium: TextStyle(color: Color(0xFF333333)),
          bodySmall: TextStyle(color: Color(0xFF666666)),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColores.primario,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColores.primario,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1e1e1e),
        dividerColor: const Color(0xFF444444),
        hintColor: const Color(0xFFAAAAAA),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColores.primario,
          foregroundColor: Color(0xFFfffafa),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: EstilosApp.botonPrimario(context),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF5F5F5)),
          bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
          bodySmall: TextStyle(color: Color(0xFFAAAAAA)),
        ),
      ),
      themeMode: themeProvider.themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => StreamBuilder<firebase_auth.User?>(
              stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasData) {
                  return const PaginaInicio();
                }
                return const Autenticacion();
              },
            ),
        '/home': (context) => const PaginaInicio(),
        '/search': (context) => const Buscar(),
        '/clubs': (context) => const Clubs(),
        '/perfil': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, dynamic> && args.containsKey('userId')) {
            return Perfil(userId: args['userId']);
          }
          return const Perfil();
        },
        '/recomendaciones': (context) => const PantallaRecomendaciones(),
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
        '/detalles_manga': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Manga) {
            return DetallesManga(mangaObjeto: args);
          }
          return const Scaffold(body: Center(child: Text('Error: Manga no encontrado')));
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
        '/mensajes_directos': (context) => const MensajesDirectos(),
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
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ServicioNotificaciones>(context, listen: false).inicializarEscuchadores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.esModoOscuro;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          child: const Text('BookWorm', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFfffafa))),
        ),
        automaticallyImplyLeading: false,
        actions: [
          const BotonNotificaciones(),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/mensajes_directos'),
            tooltip: 'Mensajes',
          ),
          TextButton(
            onPressed: () => themeProvider.alternarTema(),
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.hovered)) return const Color(0xFFdcdcdc);
                return const Color(0xFFfffafa);
              }),
              backgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.hovered)) return const Color(0xFF008080);
                return const Color(0xFF20b2aa);
              }),
              shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
            child: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 18),
          ),
          const BotonesBarraApp(rutaActual: '/home'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              constraints: const BoxConstraints(minHeight: 180),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColores.primario, AppColores.secundario],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Bienvenido de vuelta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFf8f8ff))),
                        const SizedBox(height: 8),
                        const Text('Continúa tu aventura literaria', style: TextStyle(fontSize: 14, color: Color(0xFFf8f8ff))),
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
                  const Icon(Icons.menu_book_rounded, size: 80, color: Color(0xFFf8f8ff)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1e1e1e) : const Color(0xFFf5f5f5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acceso rápido',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFfffafa) : const Color(0xFF121212),
                    ),
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
                          } else if (accion['etiqueta'] == 'Recomendaciones') {
                            Navigator.pushNamed(context, '/recomendaciones');
                          } else if (accion['etiqueta'] == 'Clubs') {
                            Navigator.pushNamed(context, '/clubs');
                          } else if (accion['etiqueta'] == 'Historial') {
                            Navigator.pushNamed(context, '/historial');
                          } else if (accion['etiqueta'] == 'Desafíos') {
                            Navigator.pushNamed(context, '/desafios');
                          } else if (accion['etiqueta'] == 'Favoritos') {
                            Navigator.pushNamed(context, '/perfil', arguments: {'seccionIndex': 0});
                          } else if (accion['etiqueta'] == 'Configuración') {
                            Navigator.pushNamed(context, '/perfil', arguments: {'seccionIndex': 4});
                          } else if (accion['etiqueta'] == 'Ayuda') {
                            _mostrarDialogoAyuda();
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF121212) : const Color(0xFFfffafa),
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColores.primario,
                                ),
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
                        onPressed: () => setState(() => _mostrarTodosAccesosRapidos = !_mostrarTodosAccesosRapidos),
                        style: ButtonStyle(
                          foregroundColor: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.hovered)) {
                              return const Color(0xFF008080);
                            }
                            return const Color(0xFF20b2aa);
                          }),
                          backgroundColor: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.hovered)) {
                              return isDark ? const Color(0xFF121212) : const Color(0xFFfffafa);
                            }
                            return Colors.transparent;
                          }),
                          overlayColor: MaterialStateProperty.all(Colors.transparent),
                          shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                        ),
                        child: Text(
                          _mostrarTodosAccesosRapidos ? 'Ver menos' : 'Ver más',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const NoticiasWidget(),
             const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 280,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1e1e1e) : const Color(0xFFf5f5f5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Mis lecturas actuales',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFfffafa) : const Color(0xFF121212),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _auth.currentUser == null
                              ? Center(
                                  child: Text(
                                    'Inicia sesión para ver tus lecturas',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF696969),
                                    ),
                                  ),
                                )
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
                                            style: const TextStyle(color: Color(0xFFb22222), fontSize: 12),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      );
                                    }
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return Center(
                                        child: Text(
                                          'No tienes lecturas en progreso',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF696969),
                                          ),
                                        ),
                                      );
                                    }
                                    return ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: snapshot.data!.docs.length,
                                      separatorBuilder: (context, index) => Divider(
                                        color: Theme.of(context).dividerColor,
                                        height: 16,
                                      ),
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
                                                child: Text(titulo, style: const TextStyle(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1e1e1e) : const Color(0xFFf5f5f5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Libros leídos',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFfffafa) : const Color(0xFF121212),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/perfil', arguments: {'seccionIndex': 1, 'filtroEstado': 'completado'}),
                              style: ButtonStyle(
                                foregroundColor: MaterialStateProperty.resolveWith((states) {
                                  if (states.contains(MaterialState.hovered)) {
                                    return const Color(0xFF008080);
                                  }
                                  return const Color(0xFF20b2aa);
                                }),
                                backgroundColor: MaterialStateProperty.resolveWith((states) {
                                  if (states.contains(MaterialState.hovered)) {
                                    return isDark ? const Color(0xFF121212) : const Color(0xFFfffafa);
                                  }
                                  return Colors.transparent;
                                }),
                                overlayColor: MaterialStateProperty.all(Colors.transparent),
                                shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                              ),
                              child: const Text(
                                'Ver todos',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _auth.currentUser == null
                              ? Center(
                                  child: Text(
                                    'Inicia sesión',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF696969),
                                    ),
                                  ),
                                )
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
                                            style: const TextStyle(color: Color(0xFFB22222), fontSize: 10),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      );
                                    }
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.emoji_events_outlined, size: 40, color: Color(0xFF696969)),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Aún no has completado libros',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF696969),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: snapshot.data!.docs.length,
                                      separatorBuilder: (context, index) => Divider(
                                        color: Theme.of(context).dividerColor,
                                        height: 1,
                                      ),
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
                                              : Icon(Icons.book, size: 40, color: AppColores.primario),
                                          title: Text(titulo, style: const TextStyle(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          subtitle: Text('Leído el $fecha', style: const TextStyle(fontSize: 14)),
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
            const RecomendacionesWidget(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoAyuda() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayuda'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Necesitas ayuda?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Preguntas frecuentes:'),
              Text('- ¿Cómo guardar libros?'),
              Text('- ¿Cómo iniciar progreso de lectura?'),
              Text('- ¿Cómo editar mi perfil?'),
              Text('- ¿Cómo subir un PDF o audio de un libro?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}