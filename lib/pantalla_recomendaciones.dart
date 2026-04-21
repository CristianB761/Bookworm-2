import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'diseno.dart';
import 'API/servicio_recomendaciones.dart';
import 'recomendaciones_widget.dart';
import 'theme_provider.dart';
import 'componentes.dart';

class PantallaRecomendaciones extends StatefulWidget {
  const PantallaRecomendaciones({super.key});

  @override
  State<PantallaRecomendaciones> createState() => _PantallaRecomendacionesState();
}

class _PantallaRecomendacionesState extends State<PantallaRecomendaciones>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recomendaciones'),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Personalizadas', icon: Icon(Icons.person)),
            Tab(text: 'Para ti', icon: Icon(Icons.favorite)),
            Tab(text: 'Populares', icon: Icon(Icons.trending_up)),
          ],
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.esModoOscuro ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: themeProvider.alternarTema,
                tooltip: themeProvider.esModoOscuro ? 'Modo claro' : 'Modo oscuro',
              );
            },
          ),
          const BotonesBarraApp(rutaActual: '/recomendaciones'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _construirSeccionPersonalizada(),
          _construirSeccionParaTi(),
          _construirSeccionPopulares(),
        ],
      ),
    );
  }

  Widget _construirSeccionPersonalizada() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColores.primario.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb, color: AppColores.primario, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recomendaciones basadas en tus gustos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estas recomendaciones se generan a partir de los libros que has guardado y tus géneros favoritos',
                        style: EstilosApp.cuerpoPequeno(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: RecomendacionesWidget(
              mostrarTodas: true,
              limite: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionParaTi() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColores.secundario.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: AppColores.secundario, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Basado en tu historial de lectura',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Libros similares a los que has leído y completado',
                        style: EstilosApp.cuerpoPequeno(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _construirListaParaTi(),
          ),
        ],
      ),
    );
  }

  Widget _construirListaParaTi() {
    return FutureBuilder<List<Recomendacion>>(
      future: ServicioRecomendaciones().obtenerRecomendacionesParaTi(limite: 30),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final recomendaciones = snapshot.data ?? [];

        if (recomendaciones.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, size: 48, color: Color(0xFF9E9E9E)),
                SizedBox(height: 16),
                Text('Completa algunos libros para obtener recomendaciones'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: recomendaciones.length,
          itemBuilder: (context, index) {
            final rec = recomendaciones[index];
            return _construirTarjetaRecomendacionCompleta(rec);
          },
        );
      },
    );
  }

  Widget _construirSeccionPopulares() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF39C12).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Color(0xFFF39C12), size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tendencias actuales',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Libros más populares entre los lectores',
                        style: EstilosApp.cuerpoPequeno(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: RecomendacionesWidget(
              mostrarTodas: true,
              limite: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaRecomendacionCompleta(Recomendacion recomendacion) {
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
      onTap: () {
        Navigator.pushNamed(
          context,
          '/detalles_libro',
          arguments: libro,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
                      width: 70,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 70,
                          height: 100,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.book, size: 35),
                        );
                      },
                    )
                  : Container(
                      width: 70,
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.book, size: 35),
                    ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorTipo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconoTipo, size: 14, color: colorTipo),
                        const SizedBox(width: 6),
                        Text(
                          recomendacion.razon,
                          style: TextStyle(fontSize: 12, color: colorTipo),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (libro.calificacionPromedio != null) ...[
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          libro.calificacionPromedio!.toStringAsFixed(1),
                          style: EstilosApp.cuerpoPequeno(context),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (libro.precio == 0.0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Gratis',
                            style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
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