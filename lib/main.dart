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
import 'recuperar_contraseña.dart'; 

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
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        cardColor: const Color(0xFFF5F5F5),
        dividerColor: const Color(0xFFDDDDDD),
        hintColor: const Color(0xFF666666),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColores.primario,
          foregroundColor: Color(0xFFFAFAFA),
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
        cardColor: const Color(0xFF1E1E1E),
        dividerColor: const Color(0xFF444444),
        hintColor: const Color(0xFFAAAAAA),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColores.primario,
          foregroundColor: Color(0xFFFAFAFA),
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
        // NUEVA RUTA PARA RECUPERAR CONTRASEÑA
        '/recuperar-contrasena': (context) {
          final uri = ModalRoute.of(context)?.settings.arguments as String?;
          if (uri != null && uri.contains('mode=resetPassword')) {
            final oobCode = Uri.parse(uri).queryParameters['oobCode'];
            if (oobCode != null) {
              return RecuperarContrasena(oobCode: oobCode);
            }
          }
          return const Scaffold(body: Center(child: Text('Enlace inválido')));
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
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_auth.currentUser != null) {
        Provider.of<ServicioNotificaciones>(context, listen: false).inicializarEscuchadores();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_auth.currentUser != null) {
      Provider.of<ServicioNotificaciones>(context, listen: false).inicializarEscuchadores();
    }
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
          child: const Text('BookWorm', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFAFAFA))),
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
                if (states.contains(MaterialState.hovered)) return const Color(0xFFDCDCDC);
                return const Color(0xFFFAFAFA);
              }),
              backgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.hovered)) return const Color(0xFF008080);
                return const Color(0xFF20B2AA);
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
                        const Text('Bienvenido de vuelta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFF8F8FF))),
                        const SizedBox(height: 8),
                        const Text('Continúa tu aventura literaria', style: TextStyle(fontSize: 14, color: Color(0xFFF8F8FF))),
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
                  const Icon(Icons.menu_book_rounded, size: 80, color: Color(0xFFF8F8FF)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ... el resto de tu código de PaginaInicio se mantiene igual ...
            // (He recortado por espacio, pero mantén todo el código existente)
            
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
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
                      color: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF121212),
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
                            color: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
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
                            return const Color(0xFF20B2AA);
                          }),
                          backgroundColor: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.hovered)) {
                              return isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
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