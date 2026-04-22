import 'package:flutter/material.dart';

import '../diseno.dart';
import '../API/modelos.dart';
import '../API/servicio_recomendaciones.dart';

class RecomendacionesWidget extends StatefulWidget {
  final bool mostrarTodas;
  final int limite;

  const RecomendacionesWidget({
    super.key,
    this.mostrarTodas = false,
    this.limite = 10,
  });

  @override
  State<RecomendacionesWidget> createState() => _RecomendacionesWidgetState();
}

class _RecomendacionesWidgetState extends State<RecomendacionesWidget> {
  final ServicioRecomendaciones _servicioRecomendaciones = ServicioRecomendaciones();
  
  List<Recomendacion> _recomendaciones = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarRecomendaciones();
  }

  Future<void> _cargarRecomendaciones() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final resultados = await _servicioRecomendaciones.obtenerRecomendacionesPersonalizadas(
        limite: widget.limite,
      );
      
      if (mounted) {
        setState(() {
          _recomendaciones = resultados;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  void _mostrarDetallesLibro(Libro libro) {
    Navigator.pushNamed(
      context,
      '/detalles_libro',
      arguments: libro,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error', style: EstilosApp.cuerpoMedio(context), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarRecomendaciones,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_recomendaciones.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.lightbulb_outline, size: 48, color: Color(0xFF9E9E9E)),
            const SizedBox(height: 16),
            Text(
              'No hay recomendaciones disponibles',
              style: EstilosApp.tituloPequeno(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Guarda más libros para obtener recomendaciones personalizadas',
              style: EstilosApp.cuerpoPequeno(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (widget.mostrarTodas) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recomendaciones.length,
        itemBuilder: (context, index) => _construirTarjetaRecomendacionHorizontal(_recomendaciones[index]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.recommend, color: AppColores.primario),
              const SizedBox(width: 8),
              Text(
                'Recomendaciones para ti',
                style: EstilosApp.tituloMedio(context),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/recomendaciones');
                },
                child: const Text('Ver todas'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recomendaciones.length > 5 ? 5 : _recomendaciones.length,
            itemBuilder: (context, index) {
              final recomendacion = _recomendaciones[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                child: _construirTarjetaRecomendacionVertical(recomendacion),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaRecomendacionHorizontal(Recomendacion recomendacion) {
    final libro = recomendacion.libro;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color colorTipo = AppColores.primario;
    IconData iconoTipo = Icons.recommend;
    
    switch (recomendacion.tipo) {
      case RecomendacionTipo.basadaEnGenero:
        colorTipo = AppColores.primario;
        iconoTipo = Icons.category;
        break;
      case RecomendacionTipo.similares:
        colorTipo = const Color(0xFF9B59B6);
        iconoTipo = Icons.compare_arrows;
        break;
      case RecomendacionTipo.paraTi:
        colorTipo = const Color(0xFFE74C3C);
        iconoTipo = Icons.favorite;
        break;
      case RecomendacionTipo.tendencia:
        colorTipo = const Color(0xFFF39C12);
        iconoTipo = Icons.trending_up;
        break;
      case RecomendacionTipo.nuevo:
        colorTipo = const Color(0xFF1ABC9C);
        iconoTipo = Icons.fiber_new;
        break;
    }
    
    return GestureDetector(
      onTap: () => _mostrarDetallesLibro(libro),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: libro.urlMiniatura != null
                  ? Image.network(
                      libro.urlMiniatura!,
                      width: 60,
                      height: 85,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 85,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.book, size: 30),
                        );
                      },
                    )
                  : Container(
                      width: 60,
                      height: 85,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.book, size: 30),
                    ),
            ),
            const SizedBox(width: 12),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorTipo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconoTipo, size: 12, color: colorTipo),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            recomendacion.razon,
                            style: TextStyle(fontSize: 11, color: colorTipo),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (libro.calificacionPromedio != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          libro.calificacionPromedio!.toStringAsFixed(1),
                          style: EstilosApp.cuerpoPequeno(context),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (libro.precio == 0.0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Gratis',
                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _construirTarjetaRecomendacionVertical(Recomendacion recomendacion) {
    final libro = recomendacion.libro;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => _mostrarDetallesLibro(libro),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: libro.urlMiniatura != null
                    ? Image.network(
                        libro.urlMiniatura!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.book, size: 40),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.book, size: 40),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    libro.titulo,
                    style: EstilosApp.cuerpoPequeno(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (libro.precio == 0.0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Gratis',
                        style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
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