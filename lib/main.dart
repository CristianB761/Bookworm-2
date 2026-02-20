import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'autenticación.dart';
import 'buscar.dart';
import 'clubs.dart';
import 'perfil.dart';
import 'diseño.dart';
import 'componentes.dart';
import 'chat_clubs.dart';
import 'graficos_estadisticas.dart';
import 'sincronizacion_offline.dart';
import 'detalles_libro.dart';
import '../API/modelos.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 74, 111, 165)),
        scaffoldBackgroundColor: AppColores.fondo,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 74, 111, 165),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: EstilosApp.botonPrimario),
      ),
      routes: {
        '/': (context) => const Autenticacion(),
        '/home': (context) => const PaginaInicio(),
        '/search': (context) => const Buscar(),
        '/clubs': (context) => const Clubs(),
        '/perfil': (context) => const Perfil(),
        '/chat_club': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ChatClub(
            clubId: args['clubId'],
            clubNombre: args['clubNombre'],
          );
        },
        '/graficos': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return GraficosEstadisticas(
            datosEstadisticas: args['datosEstadisticas'],
          );
        },
        '/sincronizacion': (context) => const PantallaSincronizacion(),
        '/detalles_libro': (context) {
          final libro = ModalRoute.of(context)!.settings.arguments as Libro;
          return DetallesLibro(libro: libro);
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
        actions: const [BotonesBarraApp(rutaActual: '/home')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: 180,
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
                    itemCount: _mostrarTodosAccesosRapidos ? DatosApp.accionesRapidas.length : 4,
                    itemBuilder: (BuildContext context, int index) {
                      return Container(
                        decoration: EstilosApp.tarjetaPlana,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              DatosApp.accionesRapidas[index]['icono'],
                              size: 32,
                              color: AppColores.primario,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DatosApp.accionesRapidas[index]['etiqueta'],
                              style: EstilosApp.cuerpoPequeno,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
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
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Mis lecturas actuales',
                          style: EstilosApp.tituloPequeno,
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: Center(
                            child: Text(
                              'No tienes lecturas en progreso',
                              style: EstilosApp.cuerpoMedio,
                            ),
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
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Actividad reciente',
                          style: EstilosApp.tituloPequeno,
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: Center(
                            child: Text(
                              'No hay actividad reciente',
                              style: EstilosApp.cuerpoMedio,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}