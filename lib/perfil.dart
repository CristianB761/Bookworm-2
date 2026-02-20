import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'diseño.dart';
import 'componentes.dart';
import '../servicio/servicio_firestore.dart';
import '../modelos/datos_usuario.dart';
import '../modelos/progreso_lectura.dart';
import 'graficos_estadisticas.dart';
import 'sincronizacion_offline.dart';
import '../API/open_library.dart';
import '../API/modelos.dart';

class Perfil extends StatefulWidget {
  const Perfil({super.key});

  @override
  State<Perfil> createState() => _PerfilState();
}

class _PerfilState extends State<Perfil> {
  int _seccionSeleccionada = 0;
  DatosUsuario? _datosUsuario;
  bool _estaCargando = true;
  final ServicioFirestore _servicioFirestore = ServicioFirestore();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Imagen seleccionada para subir
  File? _imagenSeleccionada;
  bool _subiendoImagen = false;
  
  // Libros guardados
  List<Map<String, dynamic>> _librosGuardados = [];
  bool _cargandoLibros = false;
  
  // Progresos de lectura
  List<ProgresoLectura> _progresosLectura = [];
  bool _cargandoProgresos = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final usuario = _auth.currentUser;
    if (usuario == null) {
      if (mounted) setState(() => _estaCargando = false);
      return;
    }

    try {
      final datos = await _servicioFirestore.obtenerDatosUsuario(usuario.uid);
      if (mounted) {
        setState(() {
          _datosUsuario = datos;
          _estaCargando = false;
        });
      }
      
      // Cargar libros guardados y progresos
      await _cargarLibrosGuardados();
      await _cargarProgresosLectura();
    } catch (e) {
      print('Error cargando datos del usuario: $e');
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  Future<void> _cargarLibrosGuardados() async {
    if (!mounted) return;
    
    setState(() => _cargandoLibros = true);
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;
      
      final snapshot = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .orderBy('fechaGuardado', descending: true)
          .get();
      
      if (mounted) {
        setState(() {
          _librosGuardados = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
      }
    } catch (e) {
      print('Error cargando libros guardados: $e');
    } finally {
      if (mounted) {
        setState(() => _cargandoLibros = false);
      }
    }
  }

  Future<void> _cargarProgresosLectura() async {
    if (!mounted) return;
    
    setState(() => _cargandoProgresos = true);
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;
      
      final snapshot = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuario.uid)
          .orderBy('fechaInicio', descending: true)
          .get();
      
      if (mounted) {
        setState(() {
          _progresosLectura = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ProgresoLectura.fromMap(data);
          }).toList();
        });
      }
    } catch (e) {
      print('Error cargando progresos: $e');
    } finally {
      if (mounted) {
        setState(() => _cargandoProgresos = false);
      }
    }
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar imagen'),
        content: const Text('Elige una fuente para la imagen'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Galería'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Cámara'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (source == null) return;

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null && mounted) {
        setState(() {
          _imagenSeleccionada = File(pickedFile.path);
        });
      }
    } catch (e) {
      _mostrarError('Error al seleccionar imagen: $e');
    }
  }

  Future<String?> _subirImagenAFirebase(File imagen) async {
    try {
      setState(() => _subiendoImagen = true);

      final usuario = _auth.currentUser;
      if (usuario == null) {
        _mostrarError('Usuario no autenticado');
        return null;
      }

      final nombreArchivo = '${usuario.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('imagenes_perfil/$nombreArchivo');
      
      final UploadTask uploadTask = ref.putFile(
        imagen,
        SettableMetadata(
          contentType: 'image/jpeg',
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String url = await snapshot.ref.getDownloadURL();
      
      print('Imagen subida exitosamente. URL: $url');
      return url;
      
    } catch (e) {
      print('Error subiendo imagen: $e');
      _mostrarError('Error al subir imagen: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() => _subiendoImagen = false);
      }
    }
  }

  void _mostrarDialogoEditarPerfil() {
    final nombreCtrl = TextEditingController(text: _datosUsuario?.nombre ?? '');
    final biografiaCtrl = TextEditingController(text: _datosUsuario?.biografia ?? '');

    File? imagenTemp = _imagenSeleccionada;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar Perfil'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColores.primario.withOpacity(0.1),
                            backgroundImage: _obtenerImagenPerfil(imagenTemp),
                            child: _obtenerIconoPerfil(imagenTemp),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () async {
                                await _seleccionarImagen();
                                if (_imagenSeleccionada != null && mounted) {
                                  setStateDialog(() {
                                    imagenTemp = _imagenSeleccionada;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColores.primario,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: biografiaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Biografía',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _imagenSeleccionada = null);
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _subiendoImagen ? null : () async {
                    _guardarCambiosPerfil(
                      nombreCtrl.text.trim(),
                      biografiaCtrl.text.trim(),
                      imagenTemp,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.primario,
                  ),
                  child: _subiendoImagen
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  ImageProvider? _obtenerImagenPerfil(File? imagenTemp) {
    if (imagenTemp != null) {
      return FileImage(imagenTemp);
    } else if (_datosUsuario?.urlImagenPerfil != null &&
        _datosUsuario!.urlImagenPerfil!.isNotEmpty) {
      return NetworkImage(_datosUsuario!.urlImagenPerfil!);
    }
    return null;
  }

  Widget? _obtenerIconoPerfil(File? imagenTemp) {
    if (imagenTemp == null &&
        (_datosUsuario?.urlImagenPerfil == null ||
            _datosUsuario!.urlImagenPerfil!.isEmpty)) {
      return const Icon(Icons.person, size: 50, color: AppColores.primario);
    }
    return null;
  }

  Future<void> _guardarCambiosPerfil(
    String nombre,
    String biografia,
    File? imagenTemp,
  ) async {
    try {
      String? nuevaUrl = _datosUsuario?.urlImagenPerfil;

      if (imagenTemp != null) {
        nuevaUrl = await _subirImagenAFirebase(imagenTemp);
        if (nuevaUrl == null) return;
      }

      final Map<String, dynamic> datosActualizados = {
        'nombre': nombre,
        'biografia': biografia,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      };

      if (nuevaUrl != null) {
        datosActualizados['urlImagenPerfil'] = nuevaUrl;
      }

      await _servicioFirestore.actualizarDatosUsuario(
        _auth.currentUser!.uid,
        datosActualizados,
      );

      await _cargarDatosUsuario();
      
      if (mounted) {
        setState(() => _imagenSeleccionada = null);
        Navigator.pop(context);
        _mostrarExito('Perfil actualizado correctamente');
      }
    } catch (e) {
      _mostrarError('Error al actualizar perfil: $e');
    }
  }

  void _mostrarDialogoActualizarProgreso(ProgresoLectura progreso) {
    final paginaCtrl = TextEditingController(text: progreso.paginaActual.toString());
    final paginasTotalesCtrl = TextEditingController(text: progreso.paginasTotales.toString());
    double? calificacion = progreso.calificacion;
    final resenaCtrl = TextEditingController(text: progreso.resena ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Actualizar Progreso'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progreso.tituloLibro,
                    style: EstilosApp.tituloPequeno,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: paginaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Página actual',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: paginasTotalesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Páginas totales',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  const Text('Calificación', style: EstilosApp.cuerpoGrande),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          (calificacion ?? 0) >= (index + 1) ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        ),
                        onPressed: () {
                          setStateDialog(() {
                            calificacion = (index + 1).toDouble();
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: resenaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reseña (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final paginaActual = int.tryParse(paginaCtrl.text) ?? 0;
                  final paginasTotales = int.tryParse(paginasTotalesCtrl.text) ?? 0;
                  
                  String estado = 'leyendo';
                  if (paginaActual >= paginasTotales && paginasTotales > 0) {
                    estado = 'completado';
                  }

                  try {
                    await _servicioFirestore.actualizarEstadoLectura(
                      progresoId: progreso.id,
                      estado: estado,
                      paginaActual: paginaActual,
                      fechaCompletado: estado == 'completado' ? DateTime.now() : null,
                    );

                    if (calificacion != null || resenaCtrl.text.isNotEmpty) {
                      await _firestore
                          .collection('progreso_lectura')
                          .doc(progreso.id)
                          .update({
                            'calificacion': calificacion ?? progreso.calificacion,
                            'resena': resenaCtrl.text,
                          });
                    }

                    if (estado == 'completado') {
                      await _firestore
                          .collection('usuarios')
                          .doc(_auth.currentUser!.uid)
                          .collection('libros_guardados')
                          .doc(progreso.libroId)
                          .update({'estado': 'completado'});
                    }

                    Navigator.pop(context);
                    _mostrarExito('Progreso actualizado');

                    await _cargarProgresosLectura();
                    await _cargarLibrosGuardados();
                  } catch (e) {
                    _mostrarError('Error actualizando progreso: $e');
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _eliminarCuenta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text('¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer.'),
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      await _firestore.collection('usuarios').doc(usuario.uid).delete();
      
      final librosSnapshot = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .get();
      
      for (final doc in librosSnapshot.docs) {
        await doc.reference.delete();
      }

      final progresosSnapshot = await _firestore
          .collection('progreso_lectura')
          .where('usuarioId', isEqualTo: usuario.uid)
          .get();
      
      for (final doc in progresosSnapshot.docs) {
        await doc.reference.delete();
      }

      final clubsSnapshot = await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('mis_clubs')
          .get();
      
      for (final doc in clubsSnapshot.docs) {
        await doc.reference.delete();
      }

      await usuario.delete();

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
        _mostrarExito('Cuenta eliminada exitosamente');
      }
    } catch (e) {
      _mostrarError('Error eliminando cuenta: $e');
    }
  }

  Future<void> _cerrarSesion() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Widget _construirEncabezadoPerfil() {
    if (_estaCargando) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mi Perfil', style: EstilosApp.tituloMedio),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _mostrarDialogoEditarPerfil,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColores.primario,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 6),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _eliminarCuenta,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.delete, size: 16),
                        SizedBox(width: 6),
                        Text('Eliminar'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColores.primario.withOpacity(0.1),
                backgroundImage: _datosUsuario?.urlImagenPerfil != null &&
                        _datosUsuario!.urlImagenPerfil!.isNotEmpty
                    ? NetworkImage(_datosUsuario!.urlImagenPerfil!)
                    : null,
                child: _datosUsuario?.urlImagenPerfil == null ||
                        _datosUsuario!.urlImagenPerfil!.isEmpty
                    ? const Icon(Icons.person, size: 40, color: AppColores.primario)
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _datosUsuario?.nombre ?? 'Usuario',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_datosUsuario?.correo ?? '', style: EstilosApp.cuerpoMedio),
                    const SizedBox(height: 8),
                    Text(
                      '${_datosUsuario?.estadisticas?['librosLeidos'] ?? 0} libros leídos',
                      style: TextStyle(color: AppColores.secundario),
                    ),
                    if (_datosUsuario?.biografia != null && _datosUsuario!.biografia!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _datosUsuario!.biografia!,
                          style: EstilosApp.cuerpoPequeno,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirSelectorSeccion() {
    final secciones = [
      {'texto': 'Información', 'icono': Icons.person},
      {'texto': 'Progreso', 'icono': Icons.trending_up},
      {'texto': 'Estadísticas', 'icono': Icons.bar_chart},
      {'texto': 'Preferencias', 'icono': Icons.tune},
      {'texto': 'Configuración', 'icono': Icons.settings},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EstilosApp.tarjeta,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: secciones.asMap().entries.map((entry) {
            final index = entry.key;
            final seccion = entry.value;
            return Padding(
              padding: EdgeInsets.only(right: index < secciones.length - 1 ? 8 : 0),
              child: BotonSeccion(
                texto: seccion['texto'] as String,
                estaSeleccionado: _seccionSeleccionada == index,
                icono: seccion['icono'] as IconData,
                alPresionar: () => setState(() => _seccionSeleccionada = index),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _construirContenidoSeccion() {
    switch (_seccionSeleccionada) {
      case 0:
        return _construirSeccionInformacion();
      case 1:
        return _construirSeccionProgreso();
      case 2:
        return _construirSeccionEstadisticas();
      case 3:
        return _construirSeccionPreferencias();
      case 4:
        return _construirSeccionConfiguracion();
      default:
        return Container();
    }
  }

  Widget _construirSeccionInformacion() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información Personal',
            style: EstilosApp.tituloMedio,
          ),
          const SizedBox(height: 16),
          _construirItemInformacion(
            icono: Icons.person,
            titulo: 'Nombre',
            valor: _datosUsuario?.nombre ?? 'No especificado',
          ),
          const SizedBox(height: 12),
          _construirItemInformacion(
            icono: Icons.email,
            titulo: 'Correo electrónico',
            valor: _datosUsuario?.correo ?? 'No especificado',
          ),
          const SizedBox(height: 12),
          _construirItemInformacion(
            icono: Icons.calendar_today,
            titulo: 'Miembro desde',
            valor: _datosUsuario?.fechaCreacion != null
                ? '${_datosUsuario!.fechaCreacion.day}/${_datosUsuario!.fechaCreacion.month}/${_datosUsuario!.fechaCreacion.year}'
                : 'No disponible',
          ),
          const SizedBox(height: 12),
          if (_datosUsuario?.biografia != null && _datosUsuario!.biografia!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Biografía', style: EstilosApp.tituloPequeno),
                const SizedBox(height: 8),
                Text(
                  _datosUsuario!.biografia!,
                  style: EstilosApp.cuerpoMedio,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _construirSeccionProgreso() {
    if (_cargandoProgresos) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_progresosLectura.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta,
        child: const EstadoVacio(
          icono: Icons.book,
          titulo: 'No tienes lecturas en progreso',
          descripcion: 'Empieza a leer un libro para ver tu progreso aquí',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progreso de Lectura',
            style: EstilosApp.tituloMedio,
          ),
          const SizedBox(height: 16),
          ..._progresosLectura.map((progreso) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: EstilosApp.tarjetaPlana,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (progreso.miniaturaLibro != null && progreso.miniaturaLibro!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            progreso.miniaturaLibro!,
                            width: 60,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.book, size: 30, color: Colors.grey),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          width: 60,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.book, size: 30, color: Colors.grey),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              progreso.tituloLibro,
                              style: EstilosApp.tituloPequeno,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              progreso.autoresLibro.join(', '),
                              style: EstilosApp.cuerpoPequeno,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progreso.porcentajeProgreso / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progreso.estado == 'completado' 
                                  ? AppColores.secundario 
                                  : AppColores.primario
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${progreso.paginaActual}/${progreso.paginasTotales} páginas',
                                  style: EstilosApp.cuerpoPequeno,
                                ),
                                Text(
                                  '${progreso.porcentajeProgreso.toStringAsFixed(1)}%',
                                  style: EstilosApp.cuerpoPequeno,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _mostrarDialogoActualizarProgreso(progreso),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColores.primario,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Actualizar Progreso'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _construirSeccionEstadisticas() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estadísticas de Lectura',
            style: EstilosApp.tituloMedio,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _construirEstadisticaItem(
                valor: '${_datosUsuario?.estadisticas?['librosLeidos'] ?? 0}',
                titulo: 'Libros leídos',
                icono: Icons.book,
              ),
              _construirEstadisticaItem(
                valor: '${_datosUsuario?.estadisticas?['paginasTotales'] ?? 0}',
                titulo: 'Páginas totales',
                icono: Icons.article,
              ),
              _construirEstadisticaItem(
                valor: '${_datosUsuario?.estadisticas?['rachaActual'] ?? 0}',
                titulo: 'Días racha',
                icono: Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/graficos',
                arguments: {
                  'datosEstadisticas': _datosUsuario?.estadisticas ?? {},
                },
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppColores.primario,
            ),
            child: const Text('Ver Gráficos Detallados'),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionPreferencias() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferencias de Lectura',
            style: EstilosApp.tituloMedio,
          ),
          const SizedBox(height: 16),
          ElementoConfiguracion(
            titulo: 'Géneros Favoritos',
            subtitulo: _datosUsuario?.generosFavoritos?.isNotEmpty == true
                ? _datosUsuario!.generosFavoritos!.join(', ')
                : 'No especificados',
            icono: Icons.category,
            alPresionar: () => _mostrarDialogoGenerosFavoritos(),
          ),
          ElementoConfiguracion(
            titulo: 'Notificaciones',
            subtitulo: 'Recibir recordatorios de lectura',
            icono: Icons.notifications,
            tieneSwitch: true,
            valorSwitch: _datosUsuario?.preferencias?['notificaciones'] ?? true,
            alCambiarSwitch: (valor) async {
              if (_datosUsuario != null) {
                await _servicioFirestore.actualizarDatosUsuario(
                  _datosUsuario!.uid,
                  {'preferencias.notificaciones': valor},
                );
                await _cargarDatosUsuario();
              }
            },
          ),
          ElementoConfiguracion(
            titulo: 'Objetivo Mensual',
            subtitulo: '${_datosUsuario?.preferencias?['libros_por_mes'] ?? 1} libros por mes',
            icono: Icons.flag,
            alPresionar: () => _mostrarDialogoObjetivoMensual(),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionConfiguracion() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuración',
            style: EstilosApp.tituloMedio,
          ),
          const SizedBox(height: 16),
          ElementoConfiguracion(
            titulo: 'Sincronización',
            subtitulo: 'Gestionar datos offline',
            icono: Icons.sync,
            alPresionar: () => Navigator.pushNamed(context, '/sincronizacion'),
          ),
          ElementoConfiguracion(
            titulo: 'Privacidad',
            subtitulo: 'Configurar privacidad de tu perfil',
            icono: Icons.security,
            alPresionar: () => _mostrarDialogoPrivacidad(),
          ),
          ElementoConfiguracion(
            titulo: 'Ayuda y Soporte',
            subtitulo: 'Contactar soporte técnico',
            icono: Icons.help,
            alPresionar: () => _mostrarDialogoAyuda(),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionLibrosGuardados() {
    if (_cargandoLibros) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_librosGuardados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta,
        child: const EstadoVacio(
          icono: Icons.bookmark_border,
          titulo: 'No tienes libros guardados',
          descripcion: 'Guarda libros que te interesen para leer después',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Libros Guardados',
            style: EstilosApp.tituloMedio,
          ),
          const SizedBox(height: 16),
          ..._librosGuardados.map((libro) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: EstilosApp.tarjetaPlana,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (libro['urlMiniatura'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        libro['urlMiniatura'],
                        width: 60,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.book, size: 30, color: Colors.grey),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: 60,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.book, size: 30, color: Colors.grey),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          libro['titulo'] ?? 'Sin título',
                          style: EstilosApp.tituloPequeno,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (libro['autores'] != null && libro['autores'].isNotEmpty)
                          Text(
                            libro['autores'].join(', '),
                            style: EstilosApp.cuerpoPequeno,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _obtenerColorEstado(libro['estado']),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _obtenerTextoEstado(libro['estado']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: AppColores.primario),
                        onPressed: libro['estado'] == 'guardado' 
                          ? () => _iniciarProgresoLectura(libro)
                          : null,
                        tooltip: 'Comenzar a leer',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _eliminarLibroGuardado(libro['libroId']),
                        tooltip: 'Eliminar',
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _iniciarProgresoLectura(Map<String, dynamic> libro) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      final progresoId = _firestore.collection('progreso_lectura').doc().id;
      
      await _firestore
          .collection('progreso_lectura')
          .doc(progresoId)
          .set({
            'id': progresoId,
            'usuarioId': usuario.uid,
            'libroId': libro['libroId'],
            'tituloLibro': libro['titulo'],
            'autoresLibro': libro['autores'] ?? [],
            'miniaturaLibro': libro['urlMiniatura'],
            'estado': 'leyendo',
            'paginaActual': 0,
            'paginasTotales': libro['numeroPaginas'] ?? 0,
            'fechaInicio': FieldValue.serverTimestamp(),
            'calificacion': 0.0,
          });

      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(libro['libroId'])
          .update({'estado': 'leyendo'});

      _mostrarExito('Progreso iniciado para "${libro['titulo']}"');
      
      await _cargarProgresosLectura();
      await _cargarLibrosGuardados();
    } catch (e) {
      _mostrarError('Error al iniciar progreso: $e');
    }
  }

  Future<void> _eliminarLibroGuardado(String libroId) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(libroId)
          .delete();

      await _cargarLibrosGuardados();
      
      _mostrarExito('Libro eliminado de tu biblioteca');
    } catch (e) {
      _mostrarError('Error eliminando libro: $e');
    }
  }

  Color _obtenerColorEstado(String estado) {
    switch (estado) {
      case 'leyendo':
        return AppColores.primario;
      case 'completado':
        return AppColores.secundario;
      default:
        return Colors.grey;
    }
  }

  String _obtenerTextoEstado(String estado) {
    switch (estado) {
      case 'guardado':
        return 'Guardado';
      case 'leyendo':
        return 'Leyendo';
      case 'completado':
        return 'Completado';
      default:
        return 'Guardado';
    }
  }

  Widget _construirItemInformacion({
    required IconData icono,
    required String titulo,
    required String valor,
  }) {
    return Row(
      children: [
        Icon(icono, color: AppColores.primario, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: EstilosApp.cuerpoPequeno.copyWith(color: Colors.grey)),
              const SizedBox(height: 4),
              Text(valor, style: EstilosApp.cuerpoMedio),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirEstadisticaItem({
    required String valor,
    required String titulo,
    required IconData icono,
  }) {
    return Column(
      children: [
        Icon(icono, size: 32, color: AppColores.primario),
        const SizedBox(height: 8),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColores.primario,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: EstilosApp.cuerpoPequeno,
        ),
      ],
    );
  }

  void _mostrarDialogoGenerosFavoritos() {
    final generosSeleccionados = List<String>.from(_datosUsuario?.generosFavoritos ?? []);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Géneros Favoritos'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: DatosApp.generos
                      .where((genero) => genero != 'Todos los géneros')
                      .map((genero) {
                    return CheckboxListTile(
                      title: Text(genero),
                      value: generosSeleccionados.contains(genero),
                      onChanged: (valor) {
                        setStateDialog(() {
                          if (valor == true) {
                            generosSeleccionados.add(genero);
                          } else {
                            generosSeleccionados.remove(genero);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_datosUsuario != null) {
                    await _servicioFirestore.actualizarDatosUsuario(
                      _datosUsuario!.uid,
                      {'generosFavoritos': generosSeleccionados},
                    );
                    await _cargarDatosUsuario();
                  }
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarDialogoObjetivoMensual() {
    int objetivoActual = _datosUsuario?.preferencias?['libros_por_mes'] ?? 1;
    final objetivoCtrl = TextEditingController(text: objetivoActual.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Objetivo Mensual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Cuántos libros quieres leer por mes?'),
            const SizedBox(height: 16),
            TextFormField(
              controller: objetivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Libros por mes',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevoObjetivo = int.tryParse(objetivoCtrl.text) ?? 1;
              if (_datosUsuario != null) {
                await _servicioFirestore.actualizarDatosUsuario(
                  _datosUsuario!.uid,
                  {'preferencias.libros_por_mes': nuevoObjetivo},
                );
                await _cargarDatosUsuario();
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoPrivacidad() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacidad'),
        content: const SingleChildScrollView(
          child: Text(
            'Configura quién puede ver tu perfil y actividad:\n\n'
            '• Perfil público: Todos pueden ver tu perfil\n'
            '• Perfil privado: Solo tus amigos pueden ver tu perfil\n'
            '• Actividad pública: Todos pueden ver tu actividad\n'
            '• Actividad privada: Solo tú puedes ver tu actividad\n\n'
            'Para cambiar estas configuraciones, contacta al soporte técnico.',
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

  void _mostrarDialogoAyuda() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayuda y Soporte'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Necesitas ayuda?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Email: soporte@bookworm.com'),
              Text('Teléfono: +1 234 567 8900'),
              SizedBox(height: 16),
              Text('Horario de atención: Lunes a Viernes, 9:00 - 18:00'),
              SizedBox(height: 16),
              Text('Preguntas frecuentes:'),
              Text('- ¿Cómo guardar libros?'),
              Text('- ¿Cómo iniciar progreso de lectura?'),
              Text('- ¿Cómo editar mi perfil?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: const Text('BookWorm', style: EstilosApp.tituloGrande),
        backgroundColor: AppColores.primario,
        automaticallyImplyLeading: false,
        actions: const [BotonesBarraApp(rutaActual: '/perfil')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _construirEncabezadoPerfil(),
            const SizedBox(height: 20),
            _construirSelectorSeccion(),
            const SizedBox(height: 20),
            _construirContenidoSeccion(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: EstilosApp.tarjeta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mi Biblioteca',
                    style: EstilosApp.tituloMedio,
                  ),
                  const SizedBox(height: 16),
                  _construirSeccionLibrosGuardados(),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cerrarSesion,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cerrar sesión'),
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