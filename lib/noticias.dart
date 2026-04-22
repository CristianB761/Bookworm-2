import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../diseno.dart';
import '../API/news_service.dart';

class NoticiasWidget extends StatefulWidget {
  final int limite;

  const NoticiasWidget({super.key, this.limite = 6});

  @override
  State<NoticiasWidget> createState() => _NoticiasWidgetState();
}

class _NoticiasWidgetState extends State<NoticiasWidget> {
  final NewsService _newsService = NewsService();
  List<NoticiaLibro> _noticias = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarNoticias();
  }

  Future<void> _cargarNoticias() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final noticias = await _newsService.obtenerNoticiasLibros(limite: widget.limite);
      if (mounted) {
        setState(() {
          _noticias = noticias;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar las noticias';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _abrirNoticia(String url) async {
    if (url.isEmpty) return;
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);
    
    if (diferencia.inDays > 7) {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    } else if (diferencia.inDays > 0) {
      return 'Hace ${diferencia.inDays} día${diferencia.inDays > 1 ? 's' : ''}';
    } else if (diferencia.inHours > 0) {
      return 'Hace ${diferencia.inHours} hora${diferencia.inHours > 1 ? 's' : ''}';
    } else if (diferencia.inMinutes > 0) {
      return 'Hace ${diferencia.inMinutes} minuto${diferencia.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Ahora mismo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColores.primario.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.newspaper,
                  color: AppColores.primario,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Noticias del Mundo Literario',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _cargarNoticias,
                style: TextButton.styleFrom(
                  foregroundColor: AppColores.primario,
                ),
                child: const Text('Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mantente al día con las últimas novedades sobre libros y autores',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          
          if (_cargando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _cargarNoticias,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColores.primario,
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else if (_noticias.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('No hay noticias disponibles en este momento'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _noticias.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final noticia = _noticias[index];
                return _construirTarjetaNoticia(noticia, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _construirTarjetaNoticia(NoticiaLibro noticia, bool isDark) {
    return GestureDetector(
      onTap: () => _abrirNoticia(noticia.url),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade200,
              ),
              child: noticia.urlImagen.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        noticia.urlImagen,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.newspaper,
                              size: 30,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.newspaper,
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    noticia.titulo,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (noticia.descripcion.isNotEmpty)
                    Text(
                      noticia.descripcion,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatearFecha(noticia.fechaPublicacion),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.account_circle,
                        size: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          noticia.fuente,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ],
        ),
      ),
    );
  }
}