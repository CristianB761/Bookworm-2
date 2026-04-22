import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'diseno.dart';

class LectorPDF extends StatefulWidget {
  final String titulo;
  final String pdfUrl;

  const LectorPDF({
    super.key,
    required this.titulo,
    required this.pdfUrl,
  });

  @override
  State<LectorPDF> createState() => _LectorPDFState();
}

class _LectorPDFState extends State<LectorPDF> {
  bool _isLoading = true;
  String? _error;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _descargarYMostrarPDF();
  }

  Future<void> _descargarYMostrarPDF() async {
    if (widget.pdfUrl.isEmpty) {
      setState(() {
        _error = 'No se ha cargado un PDF para este libro. Por favor, sube un PDF.';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _progress = 0.0;
        _error = null;
      });

      final tempDir = await getTemporaryDirectory();
      final fileName = '${widget.titulo.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$fileName');

      final response = await http.Client().send(
        http.Request('GET', Uri.parse(widget.pdfUrl))
      );

      final totalBytes = response.contentLength;
      var bytesReceived = 0;

      final sink = file.openWrite();
      await response.stream.listen((chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (totalBytes != null && mounted) {
          setState(() {
            _progress = bytesReceived / totalBytes;
          });
        }
      }).asFuture();
      await sink.close();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        await OpenFile.open(file.path);
        
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar el PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _abrirConNavegador() async {
    final url = Uri.parse(widget.pdfUrl);
    await OpenFile.open(url.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: _abrirConNavegador,
              tooltip: 'Abrir con navegador',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _descargarYMostrarPDF,
            tooltip: 'Reintentar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Descargando PDF... ${(_progress * 100).toStringAsFixed(0)}%',
                    style: EstilosApp.cuerpoMedio(context),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se puede cargar el PDF',
                          style: EstilosApp.tituloMedio(context),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Text(
                            _error!,
                            style: EstilosApp.cuerpoMedio(context),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _descargarYMostrarPDF,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColores.primario,
                          ),
                          child: const Text('Reintentar'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Volver'),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 64,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'PDF descargado correctamente',
                        style: EstilosApp.tituloMedio(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Abriendo el visor de PDF...',
                        style: EstilosApp.cuerpoMedio(context),
                      ),
                    ],
                  ),
                ),
    );
  }
}