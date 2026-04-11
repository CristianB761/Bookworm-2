import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  bool _urlInvalida = false;

  @override
  void initState() {
    super.initState();
    // Validar que la URL no esté vacía
    if (widget.pdfUrl.isEmpty) {
      _error = 'No se ha cargado un PDF para este libro. Por favor, sube un PDF.';
      _urlInvalida = true;
    } else {
      _inicializarWebView();
    }
  }

  void _inicializarWebView() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _isLoading = false;
                _error = 'No se pudo cargar el PDF. El archivo podría no existir o la URL es inválida.\n\nDetalles: ${error.description}';
                _urlInvalida = true;
              });
            },
          ),
        )
        ..loadRequest(
          Uri.parse(_getEmbeddedPDFUrl(widget.pdfUrl)),
        );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error al configurar el lector de PDF: $e';
        _urlInvalida = true;
      });
    }
  }

  String _getEmbeddedPDFUrl(String url) {
    // Si la URL ya es de Google Drive, usa el embed
    if (url.contains('drive.google.com')) {
      final fileId = _extractGoogleDriveId(url);
      if (fileId != null) {
        return 'https://drive.google.com/file/d/$fileId/preview';
      }
    }
    
    // Para URLs directas de PDF, usa Google Docs Viewer como fallback
    return 'https://docs.google.com/viewer?embedded=true&url=${Uri.encodeComponent(url)}';
  }

  String? _extractGoogleDriveId(String url) {
    final patterns = [
      RegExp(r'/file/d/([a-zA-Z0-9_-]+)'),
      RegExp(r'id=([a-zA-Z0-9_-]+)'),
      RegExp(r'/d/([a-zA-Z0-9_-]+)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return null;
  }

  void _recargar() {
    setState(() {
      _isLoading = true;
      _error = null;
      _inicializarWebView();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        actions: [
          if (_error == null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _recargar,
              tooltip: 'Recargar',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _mostrarInfoPDF,
            tooltip: 'Información',
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: SingleChildScrollView(
                child: Padding(
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
                      if (_urlInvalida)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.info, color: Colors.blue),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Soluciones:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '• Intenta recargar la página\n'
                                    '• El archivo podría haber sido eliminado\n'
                                    '• Sube un nuevo PDF para este libro',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      if (!_urlInvalida)
                        ElevatedButton(
                          onPressed: _recargar,
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
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
    );
  }

  void _mostrarInfoPDF() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información del PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Título: ${widget.titulo}'),
            const SizedBox(height: 8),
            const Text('Usa los gestos táctiles para:'),
            const SizedBox(height: 4),
            const Text('• Pellizcar para hacer zoom'),
            const SizedBox(height: 4),
            const Text('• Deslizar para cambiar de página'),
            const SizedBox(height: 12),
            const Divider(),
            const Text(
              'Nota: Los PDFs se muestran usando el visor integrado del navegador.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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
}