import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'diseno.dart';
import 'componentes.dart';
import 'servicio/servicio_firestore.dart';
import 'modelos/datos_usuario.dart';
import 'modelos/progreso_lectura.dart';
import 'API/modelos.dart';
import 'theme_provider.dart';
import 'lector_pdf.dart';
import 'subir_pdf_dialog.dart';
import 'subir_audio_dialog.dart';
import 'reproductor_audio.dart';
import 'chat_messages_screen.dart';
import 'API/firebase_storage_service.dart';

class Perfil extends StatefulWidget {
  final String? userId;
  const Perfil({super.key, this.userId});

  @override
  State<Perfil> createState() => _PerfilState();
}

class _PerfilState extends State<Perfil> {
  int _seccionSeleccionada = 0;
  String _filtroProgreso = 'todos';
  bool _isInit = true;
  DatosUsuario? _datosUsuario;
  bool _estaCargando = true;
  final ServicioFirestore _servicioFirestore = ServicioFirestore();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  File? _imagenSeleccionada;
  bool _subiendoImagen = false;
  
  List<Map<String, dynamic>> _librosGuardados = [];
  List<Map<String, dynamic>> _librosFavoritos = [];
  List<Map<String, dynamic>> _todosLosLibrosUsuario = [];
  bool _cargandoLibros = false;
  
  List<ProgresoLectura> _progresosLectura = [];
  bool _cargandoProgresos = false;

  bool _esMiPerfil = true;
  bool _loEstoySiguiendo = false;
  bool _cargandoFollow = false;

  int _numeroSeguidores = 0;
  int _numeroSiguiendo = 0;

  final TextEditingController _nombreLibroController = TextEditingController();
  String? _mensajeError;

  @override
  void initState() {
    super.initState();
    _cargandoLibros = true;
    _cargandoProgresos = true;
    _cargarDatosUsuario();
    _escucharCambiosBiblioteca();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        if (args.containsKey('seccionIndex')) {
          _seccionSeleccionada = args['seccionIndex'];
        }
        if (args.containsKey('filtroEstado')) {
          _filtroProgreso = args['filtroEstado'];
        }
        if (args.containsKey('userId')) {
          final uidRecibido = args['userId'] as String;
          final uidActual = _auth.currentUser?.uid;
          if (uidRecibido != uidActual) {
            _esMiPerfil = false;
          }
        }
      }
      _isInit = false;
    }
  }

  String get _uidPerfil {
    if (widget.userId != null && widget.userId != _auth.currentUser?.uid) {
      return widget.userId!;
    }
    return _auth.currentUser?.uid ?? '';
  }

  Future<void> _cargarDatosUsuario() async {
    final uid = _uidPerfil;
    if (uid.isEmpty) {
      if (mounted) setState(() => _estaCargando = false);
      return;
    }

    _esMiPerfil = (uid == _auth.currentUser?.uid);

    try {
      final datos = await _servicioFirestore.obtenerDatosUsuario(uid);
      
      final seguidores = await _servicioFirestore.obtenerNumeroSeguidores(uid);
      final siguiendo = await _servicioFirestore.obtenerNumeroSiguiendo(uid);
      
      if (!_esMiPerfil) {
        final siguiendoStatus = await _servicioFirestore.estaSiguiendo(uid);
        if (mounted) setState(() => _loEstoySiguiendo = siguiendoStatus);
      }
      
      if (mounted) {
        setState(() {
          _datosUsuario = datos;
          _numeroSeguidores = seguidores;
          _numeroSiguiendo = siguiendo;
          _estaCargando = false;
        });
      }
    } catch (e) {
      print('Error cargando datos del usuario: $e');
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  void _escucharCambiosBiblioteca() {
    final uid = _uidPerfil;
    if (uid.isEmpty) return;

    _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('libros_guardados')
        .orderBy('fechaGuardado', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final todosLosLibros = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        setState(() {
          _todosLosLibrosUsuario = todosLosLibros;
          _librosFavoritos = todosLosLibros.where((l) => l['favorito'] == true).toList();
          _librosGuardados = todosLosLibros.where((l) => l['favorito'] != true && (l['estado'] == 'guardado' || l['estado'] == 'leyendo' || l['estado'] == null)).toList();
          _cargandoLibros = false;
        });
      }
    }, onError: (error) {
      print('Error escuchando libros guardados: $error');
      if (mounted) setState(() => _cargandoLibros = false);
    });

    _firestore
        .collection('progreso_lectura')
        .where('usuarioId', isEqualTo: uid)
        .orderBy('fechaInicio', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _progresosLectura = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ProgresoLectura.fromMap(data);
          }).toList();
          _cargandoProgresos = false;
        });
      }
    }, onError: (error) {
      print('Error escuchando progresos: $error');
      if (mounted) setState(() => _cargandoProgresos = false);
    });
  }

  void _iniciarConversacion() async {
    final otroUsuarioId = _uidPerfil;
    final otroUsuarioNombre = _datosUsuario?.nombre ?? 'Usuario';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatMessagesScreen(
          otroUsuarioId: otroUsuarioId,
          otroUsuarioNombre: otroUsuarioNombre,
        ),
      ),
    );
  }

  void _mostrarDialogoSubirPDF() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo Libro con PDF'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa el nombre del libro que vas a subir:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nombreLibroController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del libro',
                    hintText: 'Ej: El Hobbit, La Odisea, etc',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.book),
                    errorText: _mensajeError,
                  ),
                  maxLines: 1,
                  onChanged: (value) {
                    if (_mensajeError != null) {
                      setState(() {
                        _mensajeError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Después podrás seleccionar el PDF de tu dispositivo. El archivo se subirá a Firebase Storage.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
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
              onPressed: () {
                final nombreLibro = _nombreLibroController.text.trim();
                
                if (nombreLibro.isEmpty) {
                  setState(() {
                    _mensajeError = 'Por favor ingresa un nombre';
                  });
                  return;
                }

                Navigator.pop(context);
                
                final libroId = '${nombreLibro.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
                
                _subirPDF(libroId, nombreLibro);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.primario,
              ),
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoSubirAudio() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo Audiolibro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa el nombre del audiolibro que vas a subir:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nombreLibroController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del audiolibro',
                    hintText: 'Ej: El Hobbit, La Odisea, etc',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.book),
                    errorText: _mensajeError,
                  ),
                  maxLines: 1,
                  onChanged: (value) {
                    if (_mensajeError != null) {
                      setState(() {
                        _mensajeError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Después podrás seleccionar el archivo de audio de tu dispositivo. El archivo se subirá a Firebase Storage.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
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
              onPressed: () {
                final nombreLibro = _nombreLibroController.text.trim();
                
                if (nombreLibro.isEmpty) {
                  setState(() {
                    _mensajeError = 'Por favor ingresa un nombre';
                  });
                  return;
                }

                Navigator.pop(context);
                
                final libroId = '${nombreLibro.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
                
                _subirAudio(libroId, nombreLibro);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.primario,
              ),
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _subirPDF(String libroId, String tituloLibro) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        _mostrarError('Debes iniciar sesión');
        return;
      }

      FilePickerResult? resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (resultado == null || resultado.files.single.path == null) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SubirPDFDialog(
          libroId: libroId,
          tituloLibro: tituloLibro,
          onPDFSubido: () {
            _cargarDatosUsuario();
          },
        ),
      );
    } catch (e) {
      _mostrarError('Error al seleccionar PDF: $e');
    }
  }

  Future<void> _subirAudio(String libroId, String tituloLibro) async {
    try {
      final usuario = _auth.currentUser;
      if (usuario == null) {
        _mostrarError('Debes iniciar sesión');
        return;
      }

      FilePickerResult? resultado = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (resultado == null || resultado.files.single.path == null) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SubirAudioDialog(
          libroId: libroId,
          tituloLibro: tituloLibro,
          onAudioSubido: () {
            _cargarDatosUsuario();
          },
        ),
      );
    } catch (e) {
      _mostrarError('Error al seleccionar audio: $e');
    }
  }

  void _abrirPDF(String pdfUrl, String titulo) {
    if (pdfUrl.isEmpty) {
      _mostrarError('No hay PDF disponible para este libro.');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LectorPDF(
          titulo: titulo,
          pdfUrl: pdfUrl,
        ),
      ),
    );
  }

  void _reproducirAudio(String audioUrl, String titulo, List<String> autores) {
    if (audioUrl.isEmpty) {
      _mostrarError('No hay audio disponible para este audiolibro.');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReproductorAudio(
          titulo: titulo,
          audioUrl: audioUrl,
          autores: autores.isNotEmpty ? autores.join(', ') : null,
        ),
      ),
    );
  }

  Future<void> _eliminarPDFSubido(String libroId, String pdfUrl) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar PDF'),
        content: const Text('¿Estás seguro de que quieres eliminar este PDF? Esta acción no se puede deshacer.'),
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
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      await FirebaseStorageService.eliminarArchivo(pdfUrl);

      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(libroId)
          .delete();

      _mostrarExito('PDF eliminado exitosamente');
      _cargarDatosUsuario();
    } catch (e) {
      _mostrarError('Error al eliminar PDF: $e');
    }
  }

  Future<void> _eliminarAudioSubido(String libroId, String audioUrl) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Audiolibro'),
        content: const Text('¿Estás seguro de que quieres eliminar este audiolibro? Esta acción no se puede deshacer.'),
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
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      await FirebaseStorageService.eliminarArchivo(audioUrl);

      await _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(libroId)
          .delete();

      _mostrarExito('Audiolibro eliminado exitosamente');
      _cargarDatosUsuario();
    } catch (e) {
      _mostrarError('Error al eliminar audiolibro: $e');
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
                    await _guardarCambiosPerfil(
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
      setState(() => _subiendoImagen = true);

      String? imagenUrl;

      if (imagenTemp != null) {
        imagenUrl = await FirebaseStorageService.subirImagenPerfil(
          imagen: imagenTemp,
          userId: _auth.currentUser!.uid,
        );
      }

      final Map<String, dynamic> datosActualizados = {
        'nombre': nombre,
        'biografia': biografia,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
        if (imagenUrl != null) 'urlImagenPerfil': imagenUrl,
      };

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
    } finally {
      if (mounted) setState(() => _subiendoImagen = false);
    }
  }

  Future<void> _eliminarProgreso(String progresoId, String libroId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar del progreso'),
        content: const Text('¿Seguro que quieres quitar este libro de tu progreso? Se perderán las páginas leídas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final usuario = _auth.currentUser;
      if (usuario == null) return;

      await _firestore.collection('progreso_lectura').doc(progresoId).delete();

      if (mounted) {
        setState(() {
          _progresosLectura.removeWhere((progreso) => progreso.id == progresoId);
        });
      }

      final libroGuardadoRef = _firestore
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(libroId);
      final doc = await libroGuardadoRef.get();
      if (doc.exists) {
        await libroGuardadoRef.update({'estado': 'guardado'});
      }
      _mostrarExito('Libro quitado de tu progreso');
    } catch (e) {
      _mostrarError('Error al quitar el libro del progreso: $e');
    }
  }

  void _mostrarDialogoActualizarProgreso(ProgresoLectura progreso) {
    final libroMap = _todosLosLibrosUsuario.firstWhere(
      (l) => l['libroId'] == progreso.libroId || l['id'] == progreso.libroId,
      orElse: () => {},
    );
    final bool esAudiolibro = libroMap['esAudiolibro'] == true;

    final paginaCtrl = TextEditingController(text: progreso.paginaActual.toString());
    final paginasTotalesCtrl = TextEditingController(text: progreso.paginasTotales.toString());
    double? calificacion = progreso.calificacion;
    final resenaCtrl = TextEditingController(text: progreso.resena ?? '');
    final tiempoCtrl = TextEditingController();

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
                    style: EstilosApp.tituloPequeno(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: paginaCtrl,
                    decoration: InputDecoration(
                      labelText: esAudiolibro ? 'Minuto actual' : 'Página actual',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: paginasTotalesCtrl,
                    decoration: InputDecoration(
                      labelText: esAudiolibro ? 'Duración total (min)' : 'Páginas totales',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: tiempoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tiempo leído ahora (min)',
                      border: OutlineInputBorder(),
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Text('Calificación', style: EstilosApp.cuerpoGrande(context)),
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
                  final tiempoLeido = int.tryParse(tiempoCtrl.text) ?? 0;
                  
                  final now = DateTime.now();
                  final fechaKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

                  String estado = 'leyendo';
                  if (paginaActual >= paginasTotales && paginasTotales > 0) {
                    estado = 'completado';
                  }

                  try {
                    await _firestore.collection('progreso_lectura').doc(progreso.id).update({
                      'paginasTotales': paginasTotales,
                    });

                    await _servicioFirestore.actualizarEstadoLectura(
                      progresoId: progreso.id,
                      estado: estado,
                      paginaActual: paginaActual,
                      fechaCompletado: estado == 'completado' ? DateTime.now() : null,
                    );

                    if (tiempoLeido > 0) {
                      int rachaActual = _datosUsuario?.estadisticas['rachaActual'] ?? 0;
                      dynamic ultimaFechaRaw = _datosUsuario?.estadisticas['ultimaFechaLectura'];
                      DateTime? ultimaFecha;
                      
                      if (ultimaFechaRaw is Timestamp) {
                        ultimaFecha = ultimaFechaRaw.toDate();
                      }

                      final hoy = DateTime(now.year, now.month, now.day);
                      final ayer = hoy.subtract(const Duration(days: 1));
                      DateTime? ultimaFechaDia;
                      
                      if (ultimaFecha != null) {
                        ultimaFechaDia = DateTime(ultimaFecha.year, ultimaFecha.month, ultimaFecha.day);
                      }

                      if (ultimaFechaDia == null || ultimaFechaDia.isBefore(ayer)) {
                        rachaActual = 1;
                      } else if (ultimaFechaDia.isAtSameMomentAs(ayer)) {
                        rachaActual++;
                      }

                      await _firestore.collection('usuarios').doc(_auth.currentUser!.uid).update({
                        'estadisticas.tiempoLectura': FieldValue.increment(tiempoLeido),
                        'estadisticas.lecturaDiaria.$fechaKey': FieldValue.increment(tiempoLeido),
                        'estadisticas.rachaActual': rachaActual,
                        'estadisticas.ultimaFechaLectura': FieldValue.serverTimestamp(),
                      });
                      if (mounted && _datosUsuario != null) {
                        setState(() {
                          _datosUsuario!.estadisticas['tiempoLectura'] = (_datosUsuario!.estadisticas['tiempoLectura'] ?? 0) + tiempoLeido;
                          
                          Map<String, dynamic> lecturaDiaria = Map<String, dynamic>.from(_datosUsuario!.estadisticas['lecturaDiaria'] ?? {});
                          lecturaDiaria[fechaKey] = (lecturaDiaria[fechaKey] ?? 0) + tiempoLeido;
                          _datosUsuario!.estadisticas['lecturaDiaria'] = lecturaDiaria;
                          
                          _datosUsuario!.estadisticas['rachaActual'] = rachaActual;
                          _datosUsuario!.estadisticas['ultimaFechaLectura'] = Timestamp.now();
                        });
                      }
                    }

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

                    if (mounted) {
                      setState(() {
                        final index = _progresosLectura.indexWhere((p) => p.id == progreso.id);
                        if (index != -1) {
                          final datosActualizados = _progresosLectura[index].toMap();
                          datosActualizados['id'] = progreso.id;
                          datosActualizados['paginaActual'] = paginaActual;
                          datosActualizados['paginasTotales'] = paginasTotales;
                          datosActualizados['estado'] = estado;
                          if (calificacion != null) datosActualizados['calificacion'] = calificacion;
                          if (resenaCtrl.text.isNotEmpty) datosActualizados['resena'] = resenaCtrl.text;
                          
                          _progresosLectura[index] = ProgresoLectura.fromMap(datosActualizados);
                        }
                      });

                      Navigator.pop(context);
                      _mostrarExito('Progreso actualizado');
                    }
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

  Future<void> _toggleSeguir() async {
    if (_cargandoFollow) return;
    setState(() => _cargandoFollow = true);

    try {
      final uidObjetivo = _uidPerfil;
      if (_loEstoySiguiendo) {
        await _servicioFirestore.dejarDeSeguirUsuario(uidObjetivo);
        setState(() {
          _loEstoySiguiendo = false;
          _numeroSeguidores--;
        });
      } else {
        await _servicioFirestore.seguirUsuario(uidObjetivo);
        setState(() {
          _loEstoySiguiendo = true;
          _numeroSeguidores++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoFollow = false);
    }
  }

  void _mostrarListaUsuarios(String tipo) async {
    final uid = _uidPerfil;
    if (uid.isEmpty) return;

    List<DatosUsuario> usuarios = [];
    String titulo = '';

    if (tipo == 'seguidores') {
      titulo = 'Seguidores';
      usuarios = await _servicioFirestore.obtenerSeguidores(uid);
    } else {
      titulo = 'Siguiendo';
      usuarios = await _servicioFirestore.obtenerSiguiendo(uid);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                child: Text(
                  titulo,
                  style: EstilosApp.tituloMedio(context),
                ),
              ),
              Expanded(
                child: usuarios.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tipo == 'seguidores'
                                  ? 'No tienes seguidores aún'
                                  : 'No sigues a nadie aún',
                              style: EstilosApp.cuerpoMedio(context),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: usuarios.length,
                        itemBuilder: (context, index) {
                          final usuario = usuarios[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColores.primario.withOpacity(0.1),
                              backgroundImage: usuario.urlImagenPerfil != null &&
                                      usuario.urlImagenPerfil!.isNotEmpty
                                  ? NetworkImage(usuario.urlImagenPerfil!)
                                  : null,
                              child: usuario.urlImagenPerfil == null ||
                                      usuario.urlImagenPerfil!.isEmpty
                                  ? const Icon(Icons.person, color: AppColores.primario)
                                  : null,
                            ),
                            title: Text(
                              usuario.nombre,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              usuario.biografia?.isNotEmpty == true
                                  ? usuario.biografia!
                                  : 'Sin biografía',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(
                                  context,
                                  '/perfil',
                                  arguments: {'userId': usuario.uid},
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColores.primario,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Ver perfil'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColores.primario,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: EstilosApp.cuerpoPequeno(context),
          ),
        ],
      ),
    );
  }

  Widget _construirEncabezadoPerfil() {
    if (_estaCargando) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta(context),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final int librosLeidos = _progresosLectura.where((p) => p.estado == 'completado').length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_esMiPerfil ? 'Mi Perfil' : _datosUsuario?.nombre ?? 'Perfil', style: EstilosApp.tituloMedio(context)),
              Row(
                children: [
                  if (!_esMiPerfil)
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: AppColores.primario, size: 28),
                      onPressed: _iniciarConversacion,
                      tooltip: 'Enviar mensaje',
                    ),
                  if (_esMiPerfil)
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
                    )
                  else
                    ElevatedButton(
                      onPressed: _cargandoFollow ? null : _toggleSeguir,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _loEstoySiguiendo ? Colors.grey[300] : AppColores.primario,
                        foregroundColor: _loEstoySiguiendo ? Colors.black87 : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _cargandoFollow
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_loEstoySiguiendo ? Icons.check : Icons.person_add, size: 16),
                                const SizedBox(width: 6),
                                Text(_loEstoySiguiendo ? 'Siguiendo' : 'Seguir'),
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
                    Text(_datosUsuario?.correo ?? '', style: EstilosApp.cuerpoMedio(context)),
                    const SizedBox(height: 8),
                    Text(
                      '$librosLeidos libros leídos',
                      style: TextStyle(color: AppColores.secundario),
                    ),
                    if (_datosUsuario?.biografia != null && _datosUsuario!.biografia!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _datosUsuario!.biografia!,
                          style: EstilosApp.cuerpoPequeno(context),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Seguidores', _numeroSeguidores, () => _mostrarListaUsuarios('seguidores')),
              _buildStatColumn('Siguiendo', _numeroSiguiendo, () => _mostrarListaUsuarios('siguiendo')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirSelectorSeccion() {
    final todasLasSecciones = [
      {'texto': 'Información', 'icono': Icons.person},
      {'texto': 'Progreso', 'icono': Icons.trending_up},
      {'texto': 'Estadísticas', 'icono': Icons.bar_chart},
      {'texto': 'Preferencias', 'icono': Icons.tune},
      {'texto': 'Configuración', 'icono': Icons.settings},
    ];

    final secciones = _esMiPerfil
        ? todasLasSecciones
        : todasLasSecciones.sublist(0, 3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EstilosApp.tarjeta(context),
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
    final librosConPDF = _todosLosLibrosUsuario.where((libro) {
      return libro['urlPDFSubido'] != null && libro['urlPDFSubido'].toString().isNotEmpty;
    }).toList();

    final librosConAudio = _todosLosLibrosUsuario.where((libro) {
      return libro['urlAudioSubido'] != null && libro['urlAudioSubido'].toString().isNotEmpty;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mis PDFs', style: EstilosApp.tituloMedio(context)),
              if (_esMiPerfil)
                ElevatedButton.icon(
                  onPressed: _mostrarDialogoSubirPDF,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Subir PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.primario,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Libros que has subido en formato PDF. Puedes leerlos desde la app.',
            style: EstilosApp.cuerpoMedio(context),
          ),
          const SizedBox(height: 16),
          _construirListaPDFsSubidos(librosConPDF),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mis Audiolibros', style: EstilosApp.tituloMedio(context)),
              if (_esMiPerfil)
                ElevatedButton.icon(
                  onPressed: _mostrarDialogoSubirAudio,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Subir Audio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.primario,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Audiolibros que has subido. Puedes escucharlos desde la app.',
            style: EstilosApp.cuerpoMedio(context),
          ),
          const SizedBox(height: 16),
          _construirListaAudiosSubidos(librosConAudio),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          Text(
            'Información Personal',
            style: EstilosApp.tituloMedio(context),
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
                Text('Biografía', style: EstilosApp.tituloPequeno(context)),
                const SizedBox(height: 8),
                Text(
                  _datosUsuario!.biografia!,
                  style: EstilosApp.cuerpoMedio(context),
                ),
              ],
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Mis Libros Favoritos',
            style: EstilosApp.tituloMedio(context),
          ),
          const SizedBox(height: 16),
          _construirListaLibros(libros: _librosFavoritos, esFavoritos: true),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Mis Libros Guardados',
            style: EstilosApp.tituloMedio(context),
          ),
          const SizedBox(height: 16),
          _construirListaLibros(libros: _librosGuardados, esFavoritos: false),
        ],
      ),
    );
  }

  Widget _construirListaPDFsSubidos(List<Map<String, dynamic>> librosConPDF) {
    if (librosConPDF.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjetaPlana(context),
        child: Column(
          children: [
            const Icon(Icons.picture_as_pdf, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No tienes PDFs subidos',
              style: EstilosApp.tituloPequeno(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Sube tus libros en formato PDF para leerlos desde la app',
              style: EstilosApp.cuerpoPequeno(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: librosConPDF.map((libroMap) {
        final pdfUrl = libroMap['urlPDFSubido'].toString();
        final titulo = libroMap['titulo'] ?? 'Sin título';
        final autores = List<String>.from(libroMap['autores'] ?? []);
        final miniatura = libroMap['urlMiniatura'];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: EstilosApp.tarjetaPlana(context),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: miniatura != null && miniatura.isNotEmpty
                    ? Image.network(
                        miniatura,
                        width: 50,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 70,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.picture_as_pdf, size: 30, color: Colors.red),
                          );
                        },
                      )
                    : Container(
                        width: 50,
                        height: 70,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.picture_as_pdf, size: 30, color: Colors.red),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: EstilosApp.tituloPequeno(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (autores.isNotEmpty)
                      Text(
                        autores.join(', '),
                        style: EstilosApp.cuerpoPequeno(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf, size: 12, color: Colors.red),
                          SizedBox(width: 4),
                          Text('PDF en Firebase Storage', style: TextStyle(fontSize: 10, color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, color: AppColores.primario),
                    onPressed: () => _abrirPDF(pdfUrl, titulo),
                    tooltip: 'Leer PDF',
                  ),
                  if (_esMiPerfil)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _eliminarPDFSubido(libroMap['id'], pdfUrl),
                      tooltip: 'Eliminar PDF',
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _construirListaAudiosSubidos(List<Map<String, dynamic>> librosConAudio) {
    if (librosConAudio.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjetaPlana(context),
        child: Column(
          children: [
            const Icon(Icons.audiotrack, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No tienes audiolibros subidos',
              style: EstilosApp.tituloPequeno(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Sube tus audiolibros para escucharlos desde la app',
              style: EstilosApp.cuerpoPequeno(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: librosConAudio.map((libroMap) {
        final audioUrl = libroMap['urlAudioSubido'].toString();
        final titulo = libroMap['titulo'] ?? 'Sin título';
        final autores = List<String>.from(libroMap['autores'] ?? []);
        final miniatura = libroMap['urlMiniatura'];
        final tipoAudio = libroMap['tipoAudio'] ?? 'mp3';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: EstilosApp.tarjetaPlana(context),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: miniatura != null && miniatura.isNotEmpty
                    ? Image.network(
                        miniatura,
                        width: 50,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 70,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.audiotrack, size: 30, color: AppColores.primario),
                          );
                        },
                      )
                    : Container(
                        width: 50,
                        height: 70,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.audiotrack, size: 30, color: AppColores.primario),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: EstilosApp.tituloPequeno(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (autores.isNotEmpty)
                      Text(
                        autores.join(', '),
                        style: EstilosApp.cuerpoPequeno(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColores.primario.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.audiotrack, size: 12, color: AppColores.primario),
                          const SizedBox(width: 4),
                          Text('Audio ($tipoAudio) en Firebase Storage', style: TextStyle(fontSize: 10, color: AppColores.primario)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: AppColores.primario),
                    onPressed: () => _reproducirAudio(audioUrl, titulo, autores),
                    tooltip: 'Reproducir',
                  ),
                  if (_esMiPerfil)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _eliminarAudioSubido(libroMap['id'], audioUrl),
                      tooltip: 'Eliminar Audio',
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _construirListaLibros({required List<Map<String, dynamic>> libros, required bool esFavoritos}) {
    if (_cargandoLibros) {
      return const Center(child: CircularProgressIndicator());
    }

    if (libros.isEmpty) {
      return EstadoVacio(
        icono: esFavoritos ? Icons.favorite_border : Icons.bookmark_border,
        titulo: esFavoritos ? 'No tienes favoritos' : 'No tienes libros guardados',
        descripcion: esFavoritos 
            ? 'Añade libros a tus favoritos para verlos aquí' 
            : 'Guarda libros que te interesen para leer después',
      );
    }

    return Column(
      children: libros.map((libroMap) {
        final libro = Libro(
          id: libroMap['id'] ?? '',
          titulo: libroMap['titulo'] ?? 'Sin título',
          autores: List<String>.from(libroMap['autores'] ?? []),
          descripcion: libroMap['descripcion'],
          urlMiniatura: libroMap['urlMiniatura'],
          fechaPublicacion: libroMap['fechaPublicacion'],
          numeroPaginas: libroMap['numeroPaginas'],
          categorias: List<String>.from(libroMap['categorias'] ?? []),
          urlLectura: libroMap['urlLectura'],
          esAudiolibro: libroMap['esAudiolibro'] ?? false,
          urlPDFSubido: libroMap['urlPDFSubido'],
          urlAudioSubido: libroMap['urlAudioSubido'],
          tipoAudio: libroMap['tipoAudio'],
        );
        
        final bool tienePDFSubido = libro.tienePDFSubido;
        final bool tieneAudioSubido = libro.tieneAudioSubido;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: EstilosApp.tarjetaPlana(context),
          child: InkWell(
            onTap: () => _mostrarDetallesLibro(libro),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (libro.urlMiniatura != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      libro.urlMiniatura!,
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 90,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.book, size: 30, color: const Color(0xFF9E9E9E)),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.book, size: 30, color: const Color(0xFF9E9E9E)),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libro.titulo,
                        style: EstilosApp.tituloPequeno(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (libro.autores.isNotEmpty)
                        Text(
                          libro.autores.join(', '),
                          style: EstilosApp.cuerpoPequeno(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _obtenerColorEstado(libroMap['estado']),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _obtenerTextoEstado(libroMap['estado']),
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                          if (esFavoritos)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.favorite, size: 12, color: Colors.red),
                                  SizedBox(width: 4),
                                  Text('Favorito', style: TextStyle(fontSize: 10, color: Colors.red)),
                                ],
                              ),
                            ),
                          if (tienePDFSubido)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.picture_as_pdf, size: 12, color: Colors.red),
                                  SizedBox(width: 4),
                                  Text('PDF', style: TextStyle(fontSize: 10, color: Colors.red)),
                                ],
                              ),
                            ),
                          if (tieneAudioSubido)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColores.primario.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.audiotrack, size: 12, color: AppColores.primario),
                                  SizedBox(width: 4),
                                  Text('Audio', style: TextStyle(fontSize: 10, color: AppColores.primario)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (libro.urlLectura != null && !tieneAudioSubido && !libro.esAudiolibro)
                      IconButton(
                        icon: const Icon(Icons.open_in_browser, size: 20, color: AppColores.secundario),
                        onPressed: () => _abrirUrlLectura(libro.urlLectura),
                        tooltip: 'Leer Online',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    if (tienePDFSubido)
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
                        onPressed: () => _abrirPDF(libro.urlPDFSubido!, libro.titulo),
                        tooltip: 'Leer PDF',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    if (tieneAudioSubido)
                      IconButton(
                        icon: const Icon(Icons.play_arrow, size: 20, color: AppColores.primario),
                        onPressed: () => _reproducirAudio(libro.urlAudioSubido!, libro.titulo, libro.autores),
                        tooltip: 'Escuchar',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    if (!tienePDFSubido && !tieneAudioSubido && _esMiPerfil && libroMap['estado'] != 'completado' && !libro.esAudiolibro)
                      IconButton(
                        icon: const Icon(Icons.upload_file, size: 20, color: AppColores.primario),
                        onPressed: () => _subirPDF(libroMap['libroId'] ?? libroMap['id'], libro.titulo),
                        tooltip: 'Subir PDF',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    if (!tieneAudioSubido && _esMiPerfil && libroMap['estado'] != 'completado' && libro.esAudiolibro)
                      IconButton(
                        icon: const Icon(Icons.upload_file, size: 20, color: AppColores.primario),
                        onPressed: () => _subirAudio(libroMap['libroId'] ?? libroMap['id'], libro.titulo),
                        tooltip: 'Subir Audio',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _eliminarLibroGuardado(libroMap['id']),
                      tooltip: 'Eliminar',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _construirSeccionProgreso() {
    if (_cargandoProgresos) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: EstilosApp.tarjeta(context),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    List<ProgresoLectura> listaFiltrada = _progresosLectura;
    if (_filtroProgreso != 'todos') {
      listaFiltrada = _progresosLectura.where((p) => p.estado == _filtroProgreso).toList();
    }

    final now = DateTime.now();
    final fechaKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    int minutosHoy = 0;
    if (_datosUsuario?.estadisticas['lecturaDiaria'] != null) {
      final diario = _datosUsuario!.estadisticas['lecturaDiaria'];
      if (diario is Map) {
        minutosHoy = int.tryParse(diario[fechaKey]?.toString() ?? '0') ?? 0;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mi Progreso',
            style: EstilosApp.tituloMedio(context),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColores.primario.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColores.primario.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: AppColores.primario, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tiempo de Lectura', style: TextStyle(fontWeight: FontWeight.bold, color: AppColores.primario)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Hoy: $minutosHoy min', style: EstilosApp.cuerpoMedio(context).copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text('Meta diaria: ${_datosUsuario?.preferencias['minutos_lectura_diaria'] ?? 30} min', style: EstilosApp.cuerpoPequeno(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _construirChipFiltro('Todos', 'todos'),
                const SizedBox(width: 8),
                _construirChipFiltro('Leyendo', 'leyendo'),
                const SizedBox(width: 8),
                _construirChipFiltro('Completados', 'completado'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (listaFiltrada.isEmpty)
            EstadoVacio(
              icono: Icons.book,
              titulo: _filtroProgreso == 'completado' 
                  ? 'No has completado libros aún' 
                  : (_filtroProgreso == 'leyendo' 
                      ? 'No estás leyendo nada actualmente' 
                      : 'No tienes lecturas en progreso'),
              descripcion: 'Empieza a leer un libro para ver tu progreso aquí',
            )
          else
            ...listaFiltrada.map((progreso) {
            final libroMap = _todosLosLibrosUsuario.firstWhere(
              (l) => l['libroId'] == progreso.libroId || l['id'] == progreso.libroId,
              orElse: () => {},
            );
            final bool esAudiolibro = libroMap['esAudiolibro'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: EstilosApp.tarjetaPlana(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Libro libro;
                      if (libroMap.isNotEmpty) {
                        libro = Libro(
                          id: libroMap['id'] ?? '',
                          titulo: libroMap['titulo'] ?? 'Sin título',
                          autores: List<String>.from(libroMap['autores'] ?? []),
                          descripcion: libroMap['descripcion'],
                          urlMiniatura: libroMap['urlMiniatura'],
                          fechaPublicacion: libroMap['fechaPublicacion'],
                          numeroPaginas: libroMap['numeroPaginas'],
                          categorias: List<String>.from(libroMap['categorias'] ?? []),
                          urlLectura: libroMap['urlLectura'],
                          esAudiolibro: libroMap['esAudiolibro'] ?? false,
                          urlPDFSubido: libroMap['urlPDFSubido'],
                          urlAudioSubido: libroMap['urlAudioSubido'],
                          tipoAudio: libroMap['tipoAudio'],
                        );
                      } else {
                        libro = Libro(
                          id: progreso.libroId,
                          titulo: progreso.tituloLibro,
                          autores: progreso.autoresLibro,
                          urlMiniatura: progreso.miniaturaLibro,
                          numeroPaginas: progreso.paginasTotales,
                        );
                      }
                      _mostrarDetallesLibro(libro);
                    },
                    child: Row(
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
                                  color: const Color(0xFFEEEEEE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.book, size: 30, color: Color(0xFF9E9E9E)),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          width: 60,
                          height: 90,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.book, size: 30, color: Color(0xFF9E9E9E)),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              progreso.tituloLibro,
                              style: EstilosApp.tituloPequeno(context),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              progreso.autoresLibro.join(', '),
                              style: EstilosApp.cuerpoPequeno(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progreso.porcentajeProgreso / 100,
                              backgroundColor: const Color(0xFFEEEEEE),
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
                                  esAudiolibro 
                                      ? '${progreso.paginaActual}/${progreso.paginasTotales} min'
                                      : '${progreso.paginaActual}/${progreso.paginasTotales} páginas',
                                  style: EstilosApp.cuerpoPequeno(context),
                                ),
                                Text(
                                  '${progreso.porcentajeProgreso.toStringAsFixed(1)}%',
                                  style: EstilosApp.cuerpoPequeno(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    ),
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
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _eliminarProgreso(progreso.id, progreso.libroId),
                        tooltip: 'Quitar del progreso',
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _construirChipFiltro(String label, String valor) {
    final isSelected = _filtroProgreso == valor;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _filtroProgreso = valor;
          });
        }
      },
      selectedColor: AppColores.primario.withOpacity(0.2),
      backgroundColor: Colors.grey[100],
      labelStyle: TextStyle(
        color: isSelected ? AppColores.primario : Colors.black54,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _construirSeccionEstadisticas() {
    final int librosLeidos = _progresosLectura.where((p) => p.estado == 'completado').length;
    final int paginasLeidas = _progresosLectura.fold(0, (sum, p) => sum + p.paginaActual);

    final Map<String, int> conteoGeneros = {};
    
    for (final libro in _todosLosLibrosUsuario) {
      if (libro['categorias'] != null) {
        final categorias = List<dynamic>.from(libro['categorias']);
        for (final c in categorias) {
          final categoria = c.toString();
          conteoGeneros[categoria] = (conteoGeneros[categoria] ?? 0) + 1;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadísticas de Lectura',
            style: EstilosApp.tituloMedio(context),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _construirEstadisticaItem(
                valor: '$librosLeidos',
                titulo: 'Libros leídos',
                icono: Icons.book,
              ),
              _construirEstadisticaItem(
                valor: '$paginasLeidas',
                titulo: 'Páginas totales',
                icono: Icons.article,
              ),
              _construirEstadisticaItem(
                valor: '${_datosUsuario?.estadisticas['rachaActual'] ?? 0}',
                titulo: 'Días racha',
                icono: Icons.trending_up,
              ),
            ],
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final estadisticasActualizadas = Map<String, dynamic>.from(_datosUsuario?.estadisticas ?? {});
              estadisticasActualizadas['librosLeidos'] = librosLeidos;
              estadisticasActualizadas['paginasTotales'] = paginasLeidas;
              estadisticasActualizadas['generos'] = conteoGeneros;
              estadisticasActualizadas['objetivoMensual'] = _datosUsuario?.preferencias['libros_por_mes'] ?? 1;
              estadisticasActualizadas['librosEnProgreso'] = _progresosLectura.where((p) => p.estado == 'leyendo').length;

              final Map<String, int> librosPorMes = {};
              final now = DateTime.now();
              final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
              
              for (int i = 5; i >= 0; i--) {
                final mesDate = DateTime(now.year, now.month - i, 1);
                librosPorMes[meses[mesDate.month - 1]] = 0;
              }

              for (final progreso in _progresosLectura) {
                if (progreso.estado == 'completado') {
                  final map = progreso.toMap();
                  final fechaRaw = map['fechaCompletado'];
                  DateTime? fecha;
                  if (fechaRaw is Timestamp) fecha = fechaRaw.toDate();
                  else if (fechaRaw is String) fecha = DateTime.tryParse(fechaRaw);
                  else if (fechaRaw is DateTime) fecha = fechaRaw;
                  
                  if (fecha != null && now.difference(fecha).inDays < 200) {
                    final key = meses[fecha.month - 1];
                    if (librosPorMes.containsKey(key)) {
                      librosPorMes[key] = (librosPorMes[key] ?? 0) + 1;
                    }
                  }
                }
              }
              estadisticasActualizadas['librosPorMes'] = librosPorMes;

              estadisticasActualizadas['progreso'] = {
                'Leyendo': _progresosLectura.where((p) => p.estado == 'leyendo').length,
                'Completado': _progresosLectura.where((p) => p.estado == 'completado').length,
                'Por Leer': _librosGuardados.where((l) => l['estado'] == 'guardado').length,
              };

              Navigator.pushNamed(
                context,
                '/graficos',
                arguments: {
                  'datosEstadisticas': estadisticasActualizadas,
                  'tipoGraficoGeneros': 'circular',
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
      decoration: EstilosApp.tarjeta(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferencias de Lectura',
            style: EstilosApp.tituloMedio(context),
          ),
          const SizedBox(height: 16),
          ElementoConfiguracion(
            titulo: 'Géneros Favoritos',
            subtitulo: _datosUsuario?.generosFavoritos.isNotEmpty == true
                ? _datosUsuario!.generosFavoritos.join(', ')
                : 'Ej: Ficción, Misterio, Terror...',
            icono: Icons.category,
            alPresionar: () => _mostrarDialogoGenerosFavoritos(),
          ),
          ElementoConfiguracion(
            titulo: 'Notificaciones',
            subtitulo: 'Recibir recordatorios de lectura',
            icono: Icons.notifications,
            tieneSwitch: true,
            valorSwitch: _datosUsuario?.preferencias['notificaciones'] ?? true,
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
            subtitulo: '${_datosUsuario?.preferencias['libros_por_mes'] ?? 1} libros por mes',
            icono: Icons.flag,
            alPresionar: () => _mostrarDialogoObjetivoMensual(),
          ),
          ElementoConfiguracion(
            titulo: 'Meta de Lectura Diaria',
            subtitulo: '${_datosUsuario?.preferencias['minutos_lectura_diaria'] ?? 30} minutos al día',
            icono: Icons.timer,
            alPresionar: () => _mostrarDialogoMetaLectura(),
          ),
        ],
      ),
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
                onPressed: () {
                  setStateDialog(() {
                    generosSeleccionados.clear();
                  });
                },
                child: const Text('Limpiar'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
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
                  if (context.mounted) Navigator.pop(context);
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
    int objetivoActual = _datosUsuario?.preferencias['libros_por_mes'] ?? 1;
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
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoMetaLectura() {
    int metaActual = _datosUsuario?.preferencias['minutos_lectura_diaria'] ?? 30;
    final metaCtrl = TextEditingController(text: metaActual.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meta de Lectura Diaria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Cuántos minutos quieres leer al día?'),
            const SizedBox(height: 16),
            TextFormField(
              controller: metaCtrl,
              decoration: const InputDecoration(
                labelText: 'Minutos por día',
                border: OutlineInputBorder(),
                suffixText: 'min',
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
              final nuevaMeta = int.tryParse(metaCtrl.text) ?? 30;
              if (_datosUsuario != null) {
                await _servicioFirestore.actualizarDatosUsuario(
                  _datosUsuario!.uid,
                  {'preferencias.minutos_lectura_diaria': nuevaMeta},
                );
                await _cargarDatosUsuario();
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionConfiguracion() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: EstilosApp.tarjeta(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuración',
            style: EstilosApp.tituloMedio(context),
          ),
          const SizedBox(height: 16),
          ElementoConfiguracion(
            titulo: 'Modo oscuro',
            subtitulo: themeProvider.esModoOscuro ? 'Actualmente activado' : 'Actualmente desactivado',
            icono: themeProvider.esModoOscuro ? Icons.dark_mode : Icons.light_mode,
            tieneSwitch: true,
            valorSwitch: themeProvider.esModoOscuro,
            alCambiarSwitch: (_) => themeProvider.alternarTema(),
          ),
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
          ElementoConfiguracion(
            titulo: 'Cerrar sesión',
            subtitulo: 'Salir de tu cuenta actual',
            icono: Icons.logout,
            alPresionar: _cerrarSesion,
          ),
          ElementoConfiguracion(
            titulo: 'Eliminar cuenta',
            subtitulo: 'Acción irreversible',
            icono: Icons.delete_forever,
            alPresionar: _eliminarCuenta,
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoPrivacidad() {
    bool perfilPublico = _datosUsuario?.preferencias['perfil_publico'] ?? true;
    bool actividadPublica = _datosUsuario?.preferencias['actividad_publica'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Privacidad'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Controla quién puede ver tu información y actividad en la aplicación.',
                  style: EstilosApp.cuerpoMedio(context),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: Text(perfilPublico ? 'Perfil Público' : 'Perfil Privado'),
                  subtitle: Text(perfilPublico 
                      ? 'Todos pueden ver tu perfil' 
                      : 'Solo tú puedes ver tu perfil'),
                  value: perfilPublico,
                  activeColor: AppColores.primario,
                  onChanged: (val) => setStateDialog(() => perfilPublico = val),
                ),
                SwitchListTile(
                  title: Text(actividadPublica ? 'Actividad Pública' : 'Actividad Privada'),
                  subtitle: Text(actividadPublica 
                      ? 'Tu progreso es visible en clubs' 
                      : 'Tu progreso es privado'),
                  value: actividadPublica,
                  activeColor: AppColores.primario,
                  onChanged: (val) => setStateDialog(() => actividadPublica = val),
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
                if (_datosUsuario != null) {
                  await _servicioFirestore.actualizarDatosUsuario(
                    _datosUsuario!.uid,
                    {
                      'preferencias.perfil_publico': perfilPublico,
                      'preferencias.actividad_publica': actividadPublica,
                    },
                  );
                  await _cargarDatosUsuario();
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  _mostrarExito('Configuración de privacidad guardada');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColores.primario),
              child: const Text('Guardar'),
            ),
          ],
        ),
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
              const SizedBox(height: 8),
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
        return const Color(0xFF9E9E9E);
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
              Text(titulo, style: EstilosApp.cuerpoPequeno(context).copyWith(color: const Color(0xFF9E9E9E))),
              const SizedBox(height: 4),
              Text(valor, style: EstilosApp.cuerpoMedio(context)),
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
          style: EstilosApp.cuerpoPequeno(context),
        ),
      ],
    );
  }

  void _mostrarDetallesLibro(Libro libro) {
    Navigator.pushNamed(
      context,
      '/detalles_libro',
      arguments: libro,
    );
  }

  Future<void> _abrirUrlLectura(String? urlLectura) async {
    if (urlLectura == null) return;
    
    final url = Uri.parse(urlLectura);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _mostrarError('No se pudo abrir el enlace de lectura');
      }
    } catch (e) {
      _mostrarError('Error al abrir el libro: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('BookWorm', style: EstilosApp.tituloGrande(context)),
        backgroundColor: AppColores.primario,
        automaticallyImplyLeading: false,
        actions: [
          const BotonNotificaciones(),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.esModoOscuro ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white,
                ),
                onPressed: () => themeProvider.alternarTema(),
                tooltip: themeProvider.esModoOscuro ? 'Modo claro' : 'Modo oscuro',
              );
            },
          ),
          const BotonesBarraApp(rutaActual: '/perfil'),
        ],
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}