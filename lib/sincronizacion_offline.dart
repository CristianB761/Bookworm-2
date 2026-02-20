import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'diseño.dart';
import 'componentes.dart';
import '../modelos/progreso_lectura.dart';

class SincronizacionOffline {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  late Box _cajaLocal;

  Future<void> inicializar() async {
    await Hive.initFlutter();
    _cajaLocal = await Hive.openBox('datos_offline');
    await _verificarConexionYSincronizar();
  }

  Future<bool> tieneConexion() async {
    try {
      final resultado = await _connectivity.checkConnectivity();
      return resultado != ConnectivityResult.none;
    } catch (e) {
      print('Error verificando conexión: $e');
      return false;
    }
  }

  Future<void> guardarLocalmente<T>(String clave, T datos) async {
    try {
      await _cajaLocal.put(clave, datos);
    } catch (e) {
      print('Error guardando localmente: $e');
    }
  }

  Future<T?> obtenerLocalmente<T>(String clave) async {
    try {
      return _cajaLocal.get(clave);
    } catch (e) {
      print('Error obteniendo localmente: $e');
      return null;
    }
  }

  Future<void> guardarProgresoOffline(ProgresoLectura progreso) async {
    try {
      final tieneInternet = await tieneConexion();
      
      if (tieneInternet) {
        await _firestore
            .collection('progreso_lectura')
            .doc(progreso.id)
            .set(progreso.toMap());
        print('Progreso guardado en línea: ${progreso.tituloLibro}');
      } else {
        final progresosPendientes = await obtenerLocalmente<List<Map<String, dynamic>>>('progresos_pendientes') ?? [];
        progresosPendientes.add(progreso.toMap());
        await guardarLocalmente('progresos_pendientes', progresosPendientes);
        
        final misProgresos = await obtenerLocalmente<List<Map<String, dynamic>>>('mis_progresos') ?? [];
        misProgresos.add(progreso.toMap());
        await guardarLocalmente('mis_progresos', misProgresos);
        
        print('Progreso guardado offline: ${progreso.tituloLibro}');
      }
    } catch (e) {
      print('Error guardando progreso: $e');
      rethrow;
    }
  }

  Future<void> guardarMensajeOffline(Map<String, dynamic> mensaje) async {
    try {
      final tieneInternet = await tieneConexion();
      
      if (tieneInternet) {
        await _firestore
            .collection('clubs')
            .doc(mensaje['clubId'])
            .collection('mensajes')
            .add(mensaje);
        print('Mensaje enviado en línea');
      } else {
        final mensajesPendientes = await obtenerLocalmente<List<Map<String, dynamic>>>('mensajes_pendientes') ?? [];
        mensajesPendientes.add(mensaje);
        await guardarLocalmente('mensajes_pendientes', mensajesPendientes);
        print('Mensaje guardado offline');
      }
    } catch (e) {
      print('Error guardando mensaje: $e');
      rethrow;
    }
  }

  Future<void> sincronizarDatosPendientes() async {
    try {
      final tieneInternet = await tieneConexion();
      if (!tieneInternet) {
        print('Sin conexión a internet para sincronizar');
        return;
      }

      // Sincronizar progresos pendientes
      final progresosPendientes = await obtenerLocalmente<List<Map<String, dynamic>>>('progresos_pendientes') ?? [];
      if (progresosPendientes.isNotEmpty) {
        print('Sincronizando ${progresosPendientes.length} progresos pendientes...');
        
        for (final progresoData in progresosPendientes) {
          try {
            final progreso = ProgresoLectura.fromMap(progresoData);
            await _firestore
                .collection('progreso_lectura')
                .doc(progreso.id)
                .set(progreso.toMap());
            print('Progreso sincronizado: ${progreso.tituloLibro}');
          } catch (e) {
            print('Error sincronizando progreso: $e');
          }
        }
        await guardarLocalmente('progresos_pendientes', []);
      }

      // Sincronizar mensajes pendientes
      final mensajesPendientes = await obtenerLocalmente<List<Map<String, dynamic>>>('mensajes_pendientes') ?? [];
      if (mensajesPendientes.isNotEmpty) {
        print('Sincronizando ${mensajesPendientes.length} mensajes pendientes...');
        
        for (final mensaje in mensajesPendientes) {
          try {
            await _firestore
                .collection('clubs')
                .doc(mensaje['clubId'])
                .collection('mensajes')
                .add(mensaje);
            print('Mensaje sincronizado');
          } catch (e) {
            print('Error sincronizando mensaje: $e');
          }
        }
        await guardarLocalmente('mensajes_pendientes', []);
      }

      print('Sincronización completada exitosamente');
    } catch (e) {
      print('Error en sincronización: $e');
      rethrow;
    }
  }

  Future<List<ProgresoLectura>> obtenerProgresosOffline() async {
    try {
      final tieneInternet = await tieneConexion();
      
      if (tieneInternet) {
        final usuario = _auth.currentUser;
        if (usuario == null) return [];
        
        final snapshot = await _firestore
            .collection('progreso_lectura')
            .where('usuarioId', isEqualTo: usuario.uid)
            .orderBy('fechaInicio', descending: true)
            .get();
        
        final progresos = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ProgresoLectura.fromMap(data);
        }).toList();
        
        await guardarLocalmente(
          'mis_progresos',
          progresos.map((p) => p.toMap()).toList()
        );
        
        return progresos;
      } else {
        final progresosData = await obtenerLocalmente<List<Map<String, dynamic>>>('mis_progresos');
        if (progresosData == null) return [];
        
        return progresosData.map((data) => ProgresoLectura.fromMap(data)).toList();
      }
    } catch (e) {
      print('Error obteniendo progresos: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerMensajesOffline(String clubId) async {
    try {
      final tieneInternet = await tieneConexion();
      
      if (tieneInternet) {
        final snapshot = await _firestore
            .collection('clubs')
            .doc(clubId)
            .collection('mensajes')
            .orderBy('timestamp', descending: false)
            .get();
        
        final mensajes = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        
        await guardarLocalmente('mensajes_$clubId', mensajes);
        
        return mensajes;
      } else {
        final mensajes = await obtenerLocalmente<List<Map<String, dynamic>>>('mensajes_$clubId');
        return mensajes ?? [];
      }
    } catch (e) {
      print('Error obteniendo mensajes: $e');
      return [];
    }
  }

  Future<void> _verificarConexionYSincronizar() async {
    try {
      _connectivity.onConnectivityChanged.listen((resultado) async {
        if (resultado != ConnectivityResult.none) {
          print('Conexión detectada, sincronizando...');
          await sincronizarDatosPendientes();
        }
      });
    } catch (e) {
      print('Error en listener de conectividad: $e');
    }
  }

  Future<void> limpiarCache() async {
    try {
      await _cajaLocal.clear();
      print('Cache limpiado exitosamente');
    } catch (e) {
      print('Error limpiando cache: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> obtenerEstadoSincronizacion() async {
    final progresosPendientes = await obtenerLocalmente<List<Map<String, dynamic>>>('progresos_pendientes') ?? [];
    final mensajesPendientes = await obtenerLocalmente<List<Map<String, dynamic>>>('mensajes_pendientes') ?? [];
    final tieneConexion = await this.tieneConexion();
    
    return {
      'tieneConexion': tieneConexion,
      'progresosPendientes': progresosPendientes.length,
      'mensajesPendientes': mensajesPendientes.length,
      'totalPendientes': progresosPendientes.length + mensajesPendientes.length,
    };
  }
}

class PantallaSincronizacion extends StatefulWidget {
  const PantallaSincronizacion({super.key});

  @override
  State<PantallaSincronizacion> createState() => _PantallaSincronizacionState();
}

class _PantallaSincronizacionState extends State<PantallaSincronizacion> {
  final SincronizacionOffline _sincronizacion = SincronizacionOffline();
  bool _estaSincronizando = false;
  bool _tieneConexion = true;
  int _progresosPendientes = 0;
  int _mensajesPendientes = 0;
  bool _guardadoAutomatico = true;
  bool _sincronizacionSegundoPlano = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await _sincronizacion.inicializar();
    await _actualizarEstado();
  }

  Future<void> _actualizarEstado() async {
    try {
      final estado = await _sincronizacion.obtenerEstadoSincronizacion();
      if (mounted) {
        setState(() {
          _tieneConexion = estado['tieneConexion'];
          _progresosPendientes = estado['progresosPendientes'];
          _mensajesPendientes = estado['mensajesPendientes'];
        });
      }
    } catch (e) {
      print('Error actualizando estado: $e');
    }
  }

  Future<void> _sincronizarManual() async {
    if (_estaSincronizando) return;
    
    setState(() => _estaSincronizando = true);
    try {
      await _sincronizacion.sincronizarDatosPendientes();
      await _actualizarEstado();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Datos sincronizados exitosamente'),
            backgroundColor: AppColores.secundario,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sincronizando: $e'),
            backgroundColor: AppColores.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _estaSincronizando = false);
      }
    }
  }

  Future<void> _limpiarCache() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar caché'),
        content: const Text('¿Estás seguro de que quieres limpiar el caché? Esta acción eliminará todos los datos guardados localmente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _sincronizacion.limpiarCache();
      await _actualizarEstado();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Caché limpiado exitosamente'),
            backgroundColor: AppColores.secundario,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error limpiando caché: $e'),
            backgroundColor: AppColores.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización'),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Estado de conexión
            Container(
              padding: const EdgeInsets.all(24),
              decoration: EstilosApp.tarjeta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _tieneConexion ? Icons.wifi : Icons.wifi_off,
                        color: _tieneConexion ? AppColores.secundario : AppColores.error,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tieneConexion ? 'Conectado' : 'Sin conexión',
                              style: EstilosApp.tituloPequeno,
                            ),
                            Text(
                              _tieneConexion 
                                ? 'Los cambios se guardan automáticamente'
                                : 'Los cambios se guardarán cuando reconectes',
                              style: EstilosApp.cuerpoMedio,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Datos pendientes
                  if (_progresosPendientes > 0 || _mensajesPendientes > 0)
                    Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sync_problem, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              '${_progresosPendientes + _mensajesPendientes} datos pendientes',
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_progresosPendientes > 0)
                          Text(
                            '• ${_progresosPendientes} progresos de lectura',
                            style: EstilosApp.cuerpoPequeno,
                          ),
                        if (_mensajesPendientes > 0)
                          Text(
                            '• ${_mensajesPendientes} mensajes de club',
                            style: EstilosApp.cuerpoPequeno,
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  
                  // Botón de sincronización
                  ElevatedButton(
                    onPressed: _tieneConexion && !_estaSincronizando && (_progresosPendientes > 0 || _mensajesPendientes > 0)
                        ? _sincronizarManual
                        : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: _tieneConexion ? AppColores.primario : Colors.grey,
                    ),
                    child: _estaSincronizando
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(width: 12),
                              Text('Sincronizando...'),
                            ],
                          )
                        : const Text('Sincronizar ahora'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Configuración
            Container(
              padding: const EdgeInsets.all(24),
              decoration: EstilosApp.tarjeta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configuración Offline',
                    style: EstilosApp.tituloMedio,
                  ),
                  const SizedBox(height: 16),
                  ElementoConfiguracion(
                    titulo: 'Guardado automático',
                    subtitulo: 'Guarda cambios localmente sin conexión',
                    icono: Icons.save,
                    tieneSwitch: true,
                    valorSwitch: _guardadoAutomatico,
                    alCambiarSwitch: (valor) {
                      setState(() {
                        _guardadoAutomatico = valor;
                      });
                    },
                  ),
                  ElementoConfiguracion(
                    titulo: 'Sincronización en segundo plano',
                    subtitulo: 'Sincroniza automáticamente al reconectar',
                    icono: Icons.sync,
                    tieneSwitch: true,
                    valorSwitch: _sincronizacionSegundoPlano,
                    alCambiarSwitch: (valor) {
                      setState(() {
                        _sincronizacionSegundoPlano = valor;
                      });
                    },
                  ),
                  ElementoConfiguracion(
                    titulo: 'Limpiar caché',
                    subtitulo: 'Liberar espacio de almacenamiento',
                    icono: Icons.cleaning_services,
                    alPresionar: _limpiarCache,
                  ),
                ],
              ),
            ),
            
            // Información adicional
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColores.primario.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Cómo funciona el modo offline?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColores.primario,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Los progresos de lectura se guardan localmente\n'
                    '• Los mensajes en clubs se almacenan temporalmente\n'
                    '• Al recuperar la conexión, todo se sincroniza automáticamente\n'
                    '• Tus datos están seguros incluso sin internet',
                    style: EstilosApp.cuerpoPequeno,
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