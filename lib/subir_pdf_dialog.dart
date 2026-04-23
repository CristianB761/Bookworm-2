import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'diseno.dart';
import 'API/firebase_storage_service.dart';

class SubirPDFDialog extends StatefulWidget {
  final String? libroId;
  final String? tituloLibro;
  final VoidCallback onPDFSubido;

  const SubirPDFDialog({
    super.key,
    this.libroId,
    this.tituloLibro,
    required this.onPDFSubido,
  });

  @override
  State<SubirPDFDialog> createState() => _SubirPDFDialogState();
}

class _SubirPDFDialogState extends State<SubirPDFDialog> {
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

  Future<void> _seleccionarPDF() async {
    try {
      FilePickerResult? resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (resultado != null && resultado.files.single.path != null) {
        final archivo = File(resultado.files.single.path!);
        final nombreCompleto = resultado.files.single.name;
        // Limpiar nombre del archivo: quitar extensión .pdf
        String nombreSinExtension = nombreCompleto;
        if (nombreSinExtension.toLowerCase().endsWith('.pdf')) {
          nombreSinExtension = nombreSinExtension.substring(0, nombreSinExtension.length - 4);
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

  Future<void> _subirPDF() async {
    final titulo = _nombreLibroController.text.trim();
    
    if (titulo.isEmpty) {
      setState(() {
        _mensajeError = 'Por favor ingresa el nombre del libro';
      });
      return;
    }
    
    if (_archivoSeleccionado == null) {
      setState(() {
        _mensajeError = 'Por favor, selecciona un archivo PDF primero';
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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final libroId = widget.libroId ?? 'pdf_${titulo.replaceAll(' ', '_')}_$timestamp';
      final nombrePDF = '${titulo.replaceAll(' ', '_')}_$timestamp';

      final urlPDF = await FirebaseStorageService.subirPDF(
        archivo: _archivoSeleccionado!,
        nombreLibro: titulo,
        nombrePDF: nombrePDF,
      );

      _timer?.cancel();
      if (mounted) {
        setState(() => _progresoSubida = 1.0);
      }

      final libroData = {
        'id': libroId,
        'libroId': libroId,
        'titulo': titulo,
        'autores': _autorController.text.trim().isNotEmpty 
            ? [_autorController.text.trim()] 
            : ['Usuario'],
        'descripcion': 'Libro subido por el usuario',
        'urlMiniatura': null,
        'fechaPublicacion': null,
        'numeroPaginas': null,
        'categorias': [],
        'urlLectura': null,
        'esAudiolibro': false,
        'urlPDFSubido': urlPDF,
        'nombrePDF': _nombreArchivo,
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
        widget.onPDFSubido();
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF subido exitosamente a Firebase Storage'),
            backgroundColor: AppColores.secundario,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _mensajeError = 'Error al subir PDF: $e';
          _subiendo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Subir PDF del Libro'),
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
                onPressed: _subiendo ? null : _seleccionarPDF,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Seleccionar PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.primario,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona un archivo PDF de tu dispositivo',
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
                        'Los PDFs se almacenan en Firebase Storage de forma segura',
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
                    const Icon(Icons.picture_as_pdf, color: Colors.green, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      _nombreArchivo ?? 'Archivo seleccionado',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _subiendo ? null : _seleccionarPDF,
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
        ElevatedButton(
          onPressed: _subiendo ? null : _subirPDF,
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