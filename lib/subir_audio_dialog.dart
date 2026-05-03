import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../diseno.dart';
import '../API/firebase_storage_service.dart';

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
  
  final TextEditingController _nombreLibroController = TextEditingController();
  final TextEditingController _autorController = TextEditingController();

  @override
  void dispose() {
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
          if (_nombreLibroController.text.trim().isEmpty && widget.tituloLibro == null) {
            _nombreLibroController.text = nombreSinExtension;
          }
        });
      }
    } catch (e) {
      setState(() => _mensajeError = 'Error al seleccionar archivo: $e');
    }
  }

  Future<void> _subirAudio() async {
    final titulo = _nombreLibroController.text.trim();
    if (titulo.isEmpty && widget.tituloLibro == null) {
      setState(() => _mensajeError = 'Por favor ingresa el nombre del libro');
      return;
    }
    if (_archivoSeleccionado == null) {
      setState(() => _mensajeError = 'Primero selecciona un archivo de audio');
      return;
    }

    setState(() {
      _subiendo = true;
      _progresoSubida = 0;
      _mensajeError = null;
    });

    Timer? timer;
    timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (mounted && _subiendo && _progresoSubida < 0.95) {
        setState(() => _progresoSubida += 0.05);
      }
    });

    try {
      final usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) throw Exception('No autenticado');

      final nombreLibro = widget.tituloLibro ?? titulo;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final libroId = widget.libroId ?? 'audio_${nombreLibro.replaceAll(' ', '_')}_$timestamp';
      final nombreAudio = '${nombreLibro.replaceAll(' ', '_')}_$timestamp';

      final urlAudio = await FirebaseStorageService.subirAudio(
        archivo: _archivoSeleccionado!,
        nombreLibro: nombreLibro,
        nombreAudio: nombreAudio,
      );

      timer?.cancel();
      if (mounted) setState(() => _progresoSubida = 1.0);

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
            content: Text('Audiolibro subido exitosamente'),
            backgroundColor: AppColores.secundario,
          ),
        );
      }
    } catch (e) {
      timer?.cancel();
      setState(() => _mensajeError = 'Error al subir: $e');
    } finally {
      if (mounted) setState(() => _subiendo = false);
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
              TextFormField(
                controller: _nombreLibroController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del libro',
                  hintText: 'Ej: El hobbit, La odisea',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book),
                ),
              ),
              const SizedBox(height: 12),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.tituloLibro!,
                  style: EstilosApp.tituloPequeno(context),
                  textAlign: TextAlign.center,
                ),
              ),

            TextFormField(
              controller: _autorController,
              decoration: const InputDecoration(
                labelText: 'Autor (opcional)',
                hintText: 'Ej: J.R.R. Tolkien',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            if (_archivoSeleccionado == null)
              ElevatedButton.icon(
                onPressed: _subiendo ? null : _seleccionarAudio,
                icon: const Icon(Icons.audiotrack),
                label: const Text('Seleccionar Audio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.primario,
                ),
              )
            else
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
                    Text(_nombreArchivo!,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _subiendo ? null : _seleccionarAudio,
                      child: const Text('Cambiar archivo'),
                    ),
                  ],
                ),
              ),

            if (_subiendo) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progresoSubida),
              const SizedBox(height: 8),
              Text('Subiendo... ${(_progresoSubida * 100).toStringAsFixed(0)}%'),
            ],

            if (_mensajeError != null) ...[
              const SizedBox(height: 16),
              Text(_mensajeError!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _subiendo ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_archivoSeleccionado != null && !_subiendo) ? _subirAudio : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppColores.primario),
          child: _subiendo
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Subir'),
        ),
      ],
    );
  }
}