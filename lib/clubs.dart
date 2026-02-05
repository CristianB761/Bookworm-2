import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'diseno.dart';
import 'componentes.dart';
import 'servicio/servicio_firestore.dart';

class Clubs extends StatefulWidget {
  const Clubs({super.key});

  @override
  State<Clubs> createState() => _ClubsState();
}

class _ClubsState extends State<Clubs> {
  final TextEditingController _controladorBusqueda = TextEditingController();
  final ServicioFirestore _servicioFirestore = ServicioFirestore();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _seccionSeleccionada = 0;
  
  List<Map<String, dynamic>> _misClubs = [];
  List<Map<String, dynamic>> _clubsRecomendados = [];
  bool _cargandoClubs = true;

  @override
  void initState() {
    super.initState();
    _cargarClubs();
    _servicioFirestore.corregirNombreUsuarioAuth();
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  Future<void> _cargarClubs() async {
    setState(() => _cargandoClubs = true);
    
    try {
      if (_seccionSeleccionada == 0) {
        _clubsRecomendados = await _servicioFirestore.obtenerClubsRecomendados();
      } else {
        _misClubs = await _servicioFirestore.obtenerClubsUsuario();
      }
    } catch (e) {
      print('Error cargando clubs: $e');
    } finally {
      setState(() => _cargandoClubs = false);
    }
  }

  Future<void> _realizarBusqueda() async {
    final texto = _controladorBusqueda.text.trim();
    if (texto.isEmpty) {
      _cargarClubs();
      return;
    }
    
    setState(() => _cargandoClubs = true);
    try {
      final resultados = await _servicioFirestore.buscarClubs(texto);
      setState(() {
        _clubsRecomendados = resultados;
        _seccionSeleccionada = 0;
      });
    } catch (e) {
      print('Error buscando: $e');
    } finally {
      setState(() => _cargandoClubs = false);
    }
  }

  void _mostrarCrearClub() {
    final controladorNombre = TextEditingController();
    final controladorDescripcion = TextEditingController();
    String? generoDialogo; 
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Crear Nuevo Club', style: EstilosApp.tituloMedio),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Completa la información del club', style: EstilosApp.cuerpoMedio),
                const SizedBox(height: 20),
                TextFormField(
                  controller: controladorNombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del club', 
                    prefixIcon: Icon(Icons.group, color: AppColores.primario)
                  ),
                  maxLength: 50,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controladorDescripcion,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    prefixIcon: Icon(Icons.description, color: AppColores.primario)
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 16),
                const Text('Género del club', style: EstilosApp.cuerpoGrande),
                const SizedBox(height: 10),
                FiltroDesplegable(
                  valor: generoDialogo,
                  items: DatosApp.generos,
                  hint: 'Selecciona un género',
                  alCambiar: (valor) {
                    setStateDialog(() {
                      generoDialogo = valor;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancelar')
            ),
            ElevatedButton(
              onPressed: controladorNombre.text.trim().isEmpty || generoDialogo == null ? null : () async {
                Navigator.pop(context);
                await _crearClub(
                  controladorNombre.text.trim(),
                  controladorDescripcion.text.trim(),
                  generoDialogo!,
                );
              },
              style: EstilosApp.botonPrimario,
              child: const Text('Crear Club'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearClub(String nombre, String descripcion, String genero) async {
    try {
      await _servicioFirestore.crearClub({
        'nombre': nombre,
        'descripcion': descripcion,
        'genero': genero,
      });

      await _cargarClubs();

      setState(() {
        _seccionSeleccionada = 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Club "$nombre" creado exitosamente'),
            backgroundColor: AppColores.secundario,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creando club: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _eliminarClub(String clubId, String nombreClub) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Club'),
        content: Text('¿Estás seguro de que quieres eliminar el club "$nombreClub"?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _servicioFirestore.eliminarClub(clubId);
      await _cargarClubs();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club eliminado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _unirseAClub(String clubId, String clubNombre) async {
    try {
      await _servicioFirestore.unirseAClub(clubId);
      
      await _cargarClubs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Te has unido al club "$clubNombre"'),
            backgroundColor: AppColores.secundario,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uniéndose al club: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _construirTarjetaClub(Map<String, dynamic> club) {
    final rol = club['rol'] ?? 'miembro';
    final rawNombre = club['nombre']?.toString().trim() ?? 'Club sin nombre';
    final nombre = rawNombre.isEmpty ? 'Club sin nombre' : rawNombre;
    
    final inicial = nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : 'C';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: EstilosApp.tarjetaPlana,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColores.primario.withOpacity(0.1),
            child: Text(
              inicial,
              style: TextStyle(color: AppColores.primario, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        style: EstilosApp.tituloPequeno,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_seccionSeleccionada == 1 && rol == 'creador') ...[
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _eliminarClub(club['id'], nombre),
                        tooltip: 'Eliminar club',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColores.primario.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        club['genero'] ?? 'General',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColores.primario,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (club['descripcion'] != null && club['descripcion'].toString().isNotEmpty)
                  Text(
                    club['descripcion'].toString(),
                    style: EstilosApp.cuerpoMedio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.people, size: 14, color: Color(0xFF9E9E9E)),
                    const SizedBox(width: 4),
                    Text(
                      '${club['miembrosCount'] ?? 0}',
                      style: EstilosApp.cuerpoPequeno,
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.person, size: 14, color: Color(0xFF9E9E9E)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Por: ${club['creadorNombre'] ?? 'Usuario'}',
                        style: EstilosApp.cuerpoPequeno,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_seccionSeleccionada == 0)
                  ElevatedButton(
                    onPressed: () => _unirseAClub(club['id'], nombre),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                      backgroundColor: AppColores.secundario,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Unirse'),
                  )
                else
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        '/chat_club',
                        arguments: {
                          'clubId': club['id'],
                          'clubNombre': nombre,
                          'rolUsuario': rol,
                        },
                      );
                      _cargarClubs();
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                      backgroundColor: AppColores.primario,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Chat'),
                  ),
              ],
            ),
          ),
        ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: const Text('BookWorm', style: EstilosApp.tituloGrande),
        backgroundColor: AppColores.primario,
        automaticallyImplyLeading: false,
        actions: const [BotonesBarraApp(rutaActual: '/clubs')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: EstilosApp.tarjeta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Clubs de lectura', style: EstilosApp.tituloMedio),
                      ElevatedButton(
                        onPressed: _mostrarCrearClub,
                        style: EstilosApp.botonPrimario,
                        child: const Row(children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 4),
                          Text('Crear club', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Descubre y únete a clubs con intereses similares', 
                    style: EstilosApp.cuerpoMedio
                  ),
                  const SizedBox(height: 20),
                  BarraBusquedaPersonalizada(
                    controlador: _controladorBusqueda,
                    textoHint: 'Buscar clubs...',
                    alBuscar: _realizarBusqueda,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: EstilosApp.tarjeta,
              child: Row(children: [
                Expanded(child: BotonSeccion(
                  texto: 'Descubrir clubs',
                  estaSeleccionado: _seccionSeleccionada == 0,
                  icono: Icons.explore,
                  alPresionar: () {
                    setState(() => _seccionSeleccionada = 0);
                    _cargarClubs();
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: BotonSeccion(
                  texto: 'Mis clubs',
                  estaSeleccionado: _seccionSeleccionada == 1,
                  icono: Icons.group,
                  alPresionar: () {
                    setState(() => _seccionSeleccionada = 1);
                    _cargarClubs();
                  },
                )),
              ]),
            ),
            const SizedBox(height: 20),

            _seccionSeleccionada == 0 ? _construirDescubrirClubs() : _construirMisClubs(),
          ],
        ),
      ),
    );
  }

  Widget _construirDescubrirClubs() {
    if (_cargandoClubs) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_clubsRecomendados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta,
        child: const EstadoVacio(
          icono: Icons.group,
          titulo: 'No se encontraron clubs',
          descripcion: 'Sé el primero en crear un club',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Clubs recomendados', style: EstilosApp.tituloMedio),
          const SizedBox(height: 8),
          Text(
            'Explora clubs basados en tus intereses',
            style: EstilosApp.cuerpoMedio,
          ),
          const SizedBox(height: 20),
          ..._clubsRecomendados.map(_construirTarjetaClub),
        ],
      ),
    );
  }

  Widget _construirMisClubs() {
    if (_cargandoClubs) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_misClubs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta,
        child: const EstadoVacio(
          icono: Icons.group_add,
          titulo: 'No tienes clubs activos',
          descripcion: 'Únete a un club o crea uno nuevo',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mis clubs activos', style: EstilosApp.tituloMedio),
          const SizedBox(height: 8),
          Text(
            'Gestiona tus clubs de lectura actuales',
            style: EstilosApp.cuerpoMedio,
          ),
          const SizedBox(height: 20),
          ..._misClubs.map(_construirTarjetaClub),
        ],
      ),
    );
  }
}
