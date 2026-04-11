import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../diseno.dart';
import 'API/supabase_storage_service.dart';

class SubirPDFDialog extends StatefulWidget {
  final String libroId;
  final String tituloLibro;
  final VoidCallback onPDFSubido;

  const SubirPDFDialog({
    super.key,
    required this.libroId,
    required this.tituloLibro,
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

  Future<void> _seleccionarPDF() async {
    try {
      FilePickerResult? resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (resultado != null && resultado.files.single.path != null) {
        setState(() {
          _archivoSeleccionado = File(resultado.files.single.path!);
          _nombreArchivo = resultado.files.single.name;
          _mensajeError = null;
        });
      }
    } catch (e) {
      setState(() {
        _mensajeError = 'Error al seleccionar archivo: $e';
      });
    }
  }

  Future<void> _subirPDF() async {
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

    // Simular progreso
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _progresoSubida = 0.3);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _progresoSubida = 0.6);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _progresoSubida = 0.8);
    });

    try {
      final usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) {
        throw Exception('Usuario no autenticado');
      }

      // Generar nombre único para el PDF
      final nombrePDF = '${widget.tituloLibro.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

      // Subir a Supabase Storage
      final urlPDF = await SupabaseStorageService.subirPDF(
        archivo: _archivoSeleccionado!,
        nombreLibro: widget.tituloLibro,
        nombrePDF: nombrePDF,
      );

      setState(() => _progresoSubida = 1.0);

      // Actualizar URL en Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('libros_guardados')
          .doc(widget.libroId)
          .set({
        'id': widget.libroId,
        'titulo': widget.tituloLibro,
        'urlPDFSubido': urlPDF,
        'fechaSubida': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        widget.onPDFSubido();
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF subido exitosamente a Supabase'),
            backgroundColor: AppColores.secundario,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _mensajeError = 'Error al subir PDF: $e';
        _subiendo = false;
      });
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
            Text(
              widget.tituloLibro,
              style: EstilosApp.tituloPequeno(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
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
                    const Icon(Icons.check_circle, color: Colors.green, size: 40),
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
                'Subiendo a Supabase... ${(_progresoSubida * 100).toStringAsFixed(1)}%',
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
        if (_archivoSeleccionado != null)
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
                : const Text('Subir a Supabase'),
          ),
      ],
    );
  }
}