import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'diseno.dart';
import 'API/firebase_storage_service.dart';

class SubirAudioDialog extends StatefulWidget {
  final String? libroId;
  final String? tituloLibro;
  final VoidCallback onAudioSubido;

  const SubirAudioDialog({
    super.key,
    this.libroId,
    this.tituloLibro,
    required this.onAudioSubido,
  });

  @override
  State<SubirAudioDialog> createState() => _SubirAudioDialogState();
}

class _SubirAudioDialogState extends State<SubirAudioDialog> {
  bool _subiendo = false;
  double _progresoSubida = 0;
  String? _mensajeError;
  File? _archivoSeleccionado;
  String? _nombreArchivo;
  Timer? _timer;
  
  final TextEditingController _nombreLibroController = TextEditingController();
  final TextEditingController _autorController = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _nombreLibroController.dispose();
    _autorController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarAudio() async {
    try {
      FilePickerResult? resultado = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (resultado != null && resultado.files.single.path != null) {
        final archivo = File(resultado.files.single.path!);
        final nombreCompleto = resultado.files.single.name;
        // Limpiar nombre del archivo: quitar extensión
        String nombreSinExtension = nombreCompleto;
        final extensiones = ['.mp3', '.m4a', '.wav', '.ogg', '.aac'];
        for (final ext in extensiones) {
          if (nombreSinExtension.toLowerCase().endsWith(ext)) {
            nombreSinExtension = nombreSinExtension.substring(0, nombreSinExtension.length - ext.length);
            break;
          }
        }
        
        setState(() {
          _archivoSeleccionado = archivo;
          _nombreArchivo = nombreCompleto;
          _mensajeError = null;
          // Auto-completar el nombre del libro si está vacío
          if (_nombreLibroController.text.trim().isEmpty) {
            _nombreLibroController.text = nombreSinExtension;
          }
        });
      }
    } catch (e) {
      setState(() {
        _mensajeError = 'Error al seleccionar archivo: $e';
      });
    }
  }

  Future<void> _subirAudio() async {
    final titulo = _nombreLibroController.text.trim();
    
    if (titulo.isEmpty && widget.tituloLibro == null) {
      setState(() {
        _mensajeError = 'Por favor ingresa el nombre del libro';
      });
      return;
    }
    
    if (_archivoSeleccionado == null) {
      setState(() {
        _mensajeError = 'Por favor, selecciona un archivo de audio primero';
      });
      return;
    }

    setState(() {
      _subiendo = true;
      _progresoSubida = 0;
      _mensajeError = null;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (mounted && _subiendo && _progresoSubida < 0.95) {
        setState(() {
          _progresoSubida = (_progresoSubida + 0.05).clamp(0.0, 0.95);
        });
      }
    });

    try {
      final usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) {
        throw Exception('Usuario no autenticado');
      }

      final nombreLibro = widget.tituloLibro ?? titulo;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final libroId = widget.libroId ?? 'audio_${nombreLibro.replaceAll(' ', '_')}_$timestamp';
      final nombreAudio = '${nombreLibro.replaceAll(' ', '_')}_$timestamp';

      final urlAudio = await FirebaseStorageService.subirAudio(
        archivo: _archivoSeleccionado!,
        nombreLibro: nombreLibro,
        nombreAudio: nombreAudio,
      );

      _timer?.cancel();
      if (mounted) {
        setState(() => _progresoSubida = 1.0);
      }

      final extension = _archivoSeleccionado!.path.split('.').last.toLowerCase();
      String tipoAudio = 'mp3';
      if (extension == 'mp3') tipoAudio = 'mp3';
      else if (extension == 'm4a') tipoAudio = 'm4a';
      else if (extension == 'wav') tipoAudio = 'wav';
      else if (extension == 'ogg') tipoAudio = 'ogg';
      else if (extension == 'aac') tipoAudio = 'aac';

      final libroData = {
        'id': libroId,
        'libroId': libroId,
        'titulo': nombreLibro,
        'autores': _autorController.text.trim().isNotEmpty 
            ? [_autorController.text.trim()] 
            : ['Usuario'],
        'descripcion': 'Audiolibro subido por el usuario',
        'urlMiniatura': null,
        'fechaPublicacion': null,
        'numeroPaginas': null,
        'categorias': [],
        'urlLectura': urlAudio,
        'esAudiolibro': true,
        'urlAudioSubido': urlAudio,
        'tipoAudio': tipoAudio,
        'nombreAudio': _nombreArchivo,
        'fechaSubida': FieldValue.serverTimestamp(),
        'fechaGuardado': FieldValue.serverTimestamp(),
        'estado': 'guardado',
        'favorito': false,
      };

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(libroId)
          .set(libroData);

      if (mounted) {
        widget.onAudioSubido();
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audiolibro subido exitosamente a Firebase Storage'),
            backgroundColor: AppColores.secundario,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _mensajeError = 'Error al subir audio: $e';
          _subiendo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Subir Audiolibro'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.tituloLibro == null) ...[
              TextField(
                controller: _nombreLibroController,
                decoration: InputDecoration(
                  labelText: 'Nombre del libro',
                  hintText: 'Ej: El Hobbit, La Odisea',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.book),
                  errorText: _mensajeError != null && _nombreLibroController.text.trim().isEmpty ? 'Campo requerido' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _autorController,
                decoration: const InputDecoration(
                  labelText: 'Autor (opcional)',
                  hintText: 'Ej: J.R.R. Tolkien',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                widget.tituloLibro!,
                style: EstilosApp.tituloPequeno(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            
            if (_archivoSeleccionado == null) ...[
              ElevatedButton.icon(
                onPressed: _subiendo ? null : _seleccionarAudio,
                icon: const Icon(Icons.audiotrack),
                label: const Text('Seleccionar Audio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.primario,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Formatos soportados: MP3, M4A, WAV, OGG, AAC',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los audiolibros se almacenan en Firebase Storage y se pueden reproducir offline',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.audiotrack, color: Colors.green, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      _nombreArchivo ?? 'Archivo seleccionado',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _subiendo ? null : _seleccionarAudio,
                      child: const Text('Cambiar archivo'),
                    ),
                  ],
                ),
              ),
            ],
            
            if (_subiendo) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progresoSubida),
              const SizedBox(height: 8),
              Text(
                'Subiendo a Firebase Storage... ${(_progresoSubida * 100).toStringAsFixed(1)}%',
                style: EstilosApp.cuerpoPequeno(context),
              ),
            ],
            
            if (_mensajeError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _mensajeError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _subiendo ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (_archivoSeleccionado != null || widget.tituloLibro != null)
          ElevatedButton(
            onPressed: _subiendo ? null : _subirAudio,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.primario,
            ),
            child: _subiendo
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Subir a Firebase Storage'),
          ),
      ],
    );
  }
}