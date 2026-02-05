import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'diseno.dart';
import 'componentes.dart';

class GraficosEstadisticas extends StatefulWidget {
  final Map<String, dynamic> datosEstadisticas;

  const GraficosEstadisticas({
    super.key,
    required this.datosEstadisticas,
  });

  @override
  State<GraficosEstadisticas> createState() => _GraficosEstadisticasState();
}

class _GraficosEstadisticasState extends State<GraficosEstadisticas> {
  int _graficoSeleccionado = 0;

  List<BarChartGroupData> _construirDatosBarrasLibros() {
    final Map<String, dynamic> librosPorMes = widget.datosEstadisticas['librosPorMes'] ?? {};
    if (librosPorMes.isEmpty) return [];

    int index = 0;
    return librosPorMes.entries.map((entry) {
      final valor = (entry.value as num).toDouble();
      final group = BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: valor,
            color: AppColores.primario,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        showingTooltipIndicators: [0],
      );
      index++;
      return group;
    }).toList();
  }

  String _traducirGenero(String generoOriginal) {
    String texto = generoOriginal.toLowerCase();
    
    if (texto.contains('non-fiction') || texto.contains('no ficción')) return 'No Ficción';
    if (texto.contains('science fiction') || texto.contains('sci-fi')) return 'Ciencia Ficción';
    
    texto = texto.replaceAll('fiction', '').replaceAll('ficción', '').trim();
    
    // Traducciones comunes
    if (texto.contains('fantasy')) return 'Fantasía';
    if (texto.contains('mystery')) return 'Misterio';
    if (texto.contains('thriller')) return 'Suspense';
    if (texto.contains('horror')) return 'Terror';
    if (texto.contains('romance')) return 'Romance';
    if (texto.contains('historical')) return 'Histórica';
    if (texto.contains('history')) return 'Historia';
    if (texto.contains('biography')) return 'Biografía';
    if (texto.contains('adventure')) return 'Aventura';
    if (texto.contains('poetry')) return 'Poesía';
    if (texto.contains('drama')) return 'Drama';
    if (texto.contains('children')) return 'Infantil';
    if (texto.contains('juvenile')) return 'Juvenil';
    if (texto.contains('young adult')) return 'Juvenil';
    if (texto.contains('philosophy')) return 'Filosofía';
    if (texto.contains('psychology')) return 'Psicología';
    if (texto.contains('science')) return 'Ciencia';
    if (texto.contains('classic')) return 'Clásicos';
    if (texto.contains('comic')) return 'Cómics';
    
    if (texto.isEmpty) return 'General';
    
    return texto.length > 0 ? '${texto[0].toUpperCase()}${texto.substring(1)}' : texto;
  }

  List<PieChartSectionData> _construirDatosTortaGeneros() {
    final Map<String, dynamic> generosRaw = widget.datosEstadisticas['generos'] ?? {};
    
    if (generosRaw.isEmpty) {
      return [];
    }

    final Map<String, int> generosAgrupados = {};
    generosRaw.forEach((key, value) {
      final nombre = _traducirGenero(key);
      generosAgrupados[nombre] = (generosAgrupados[nombre] ?? 0) + (value as num).toInt();
    });

    final total = generosAgrupados.values.fold(0, (sum, item) => sum + item);
    final colores = [
      AppColores.primario,
      AppColores.secundario,
      AppColores.acento,
      const Color(0xFFE74C3C),
      const Color(0xFF9B59B6),
      const Color(0xFF1ABC9C),
    ];

    int index = 0;
    return generosAgrupados.entries.map((entry) {
      final cantidad = entry.value;
      final porcentaje = total > 0 ? (cantidad / total * 100) : 0.0;
      final color = colores[index % colores.length];
      index++;

      return PieChartSectionData(
        color: color,
        value: cantidad.toDouble(),
        title: '${entry.key}\n${porcentaje.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
        titlePositionPercentageOffset: 0.6,
      );
    }).toList();
  }

  Widget _construirGraficoBarras() {
    final Map<String, dynamic> librosPorMes = widget.datosEstadisticas['librosPorMes'] ?? {};
    final mesesKeys = librosPorMes.keys.toList();
    double maxY = 0;
    if (librosPorMes.isNotEmpty) {
      maxY = librosPorMes.values.map((e) => (e as num).toDouble()).reduce((curr, next) => curr > next ? curr : next);
    }
    maxY = (maxY < 5) ? 5 : maxY + 2;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: EstilosApp.tarjetaPlana,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => AppColores.primario,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final index = group.x.toInt();
                final mes = index < mesesKeys.length ? mesesKeys[index] : '';
                return BarTooltipItem(
                  '$mes\n${rod.toY.toInt()} libros',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < mesesKeys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        mesesKeys[index],
                        style: EstilosApp.cuerpoPequeno,
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      value.toInt().toString(),
                      style: EstilosApp.cuerpoPequeno,
                    ),
                  );
                },
                interval: 2,
                reservedSize: 40,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xFF9E9E9E).withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xFF9E9E9E).withValues(alpha: 0.2)),
          ),
          barGroups: _construirDatosBarrasLibros(),
        ),
      ),
    );
  }

  Widget _construirGraficoTorta() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: EstilosApp.tarjetaPlana,
      child: PieChart(
        PieChartData(
          sections: _construirDatosTortaGeneros(),
          centerSpaceRadius: 30,
          sectionsSpace: 2,
          startDegreeOffset: 270,
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  return;
                }
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _construirGraficoProgreso() {
    final Map<String, dynamic> progreso = widget.datosEstadisticas['progreso'] ?? {};
    
    final datos = [
      {'label': 'Leyendo', 'valor': progreso['Leyendo'] ?? 0, 'color': AppColores.primario},
      {'label': 'Completado', 'valor': progreso['Completado'] ?? 0, 'color': AppColores.secundario},
      {'label': 'Por Leer', 'valor': progreso['Por Leer'] ?? 0, 'color': Colors.orange},
    ];

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: EstilosApp.tarjetaPlana,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: datos.map((e) => (e['valor'] as int).toDouble()).reduce((curr, next) => curr > next ? curr : next) + 2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => datos[group.x.toInt()]['color'] as Color,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toInt()}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < datos.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(datos[index]['label'] as String, style: EstilosApp.cuerpoPequeno),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true, 
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: datos.asMap().entries.map((e) {
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(toY: (e.value['valor'] as int).toDouble(), color: e.value['color'] as Color, width: 20, borderRadius: BorderRadius.circular(4))
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _construirGraficoTiempo() {
    final Map<String, dynamic> lecturaDiaria = widget.datosEstadisticas['lecturaDiaria'] ?? {};
    final now = DateTime.now();
    final List<Map<String, dynamic>> datos = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final minutos = lecturaDiaria[key] ?? 0;
      
      datos.add({
        'dia': ['L', 'M', 'X', 'J', 'V', 'S', 'D'][date.weekday - 1],
        'valor': minutos,
        'fecha': '${date.day}/${date.month}',
      });
    }

    double maxY = datos.map((e) => (e['valor'] as num).toDouble()).reduce((curr, next) => curr > next ? curr : next);
    maxY = (maxY < 30) ? 30 : maxY + 10;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: EstilosApp.tarjetaPlana,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => AppColores.primario,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${datos[group.x.toInt()]['fecha']}\n${rod.toY.toInt()} min',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < datos.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(datos[index]['dia'] as String, style: EstilosApp.cuerpoPequeno),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: maxY > 100 ? 50 : 10)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: datos.asMap().entries.map((e) {
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                toY: (e.value['valor'] as num).toDouble(),
                color: AppColores.primario,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              )
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _construirGraficoActual() {
    switch (_graficoSeleccionado) {
      case 0:
        return _construirGraficoBarras();
      case 1:
        return _construirGraficoTorta();
      case 2:
        return _construirGraficoProgreso();
      case 3:
        return _construirGraficoTiempo();
      default:
        return _construirGraficoBarras();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas Detalladas'),
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: true,
        actions: const [BotonesBarraApp(rutaActual: '/perfil')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: EstilosApp.tarjeta,
              child: Row(
                children: [
                  Expanded(
                    child: BotonSeccion(
                      texto: 'Libros/Mes',
                      estaSeleccionado: _graficoSeleccionado == 0,
                      icono: Icons.bar_chart,
                      alPresionar: () => setState(() => _graficoSeleccionado = 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BotonSeccion(
                      texto: 'Géneros',
                      estaSeleccionado: _graficoSeleccionado == 1,
                      icono: Icons.pie_chart,
                      alPresionar: () => setState(() => _graficoSeleccionado = 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BotonSeccion(
                      texto: 'Progreso',
                      estaSeleccionado: _graficoSeleccionado == 2,
                      icono: Icons.trending_up,
                      alPresionar: () => setState(() => _graficoSeleccionado = 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BotonSeccion(
                      texto: 'Tiempo',
                      estaSeleccionado: _graficoSeleccionado == 3,
                      icono: Icons.timer,
                      alPresionar: () => setState(() => _graficoSeleccionado = 3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _construirGraficoActual(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: EstilosApp.tarjeta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen Estadístico',
                    style: EstilosApp.tituloMedio,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _construirEstadisticaResumen('Libros leídos', '${widget.datosEstadisticas['librosLeidos'] ?? 0}'),
                      _construirEstadisticaResumen('Páginas totales', '${widget.datosEstadisticas['paginasTotales'] ?? 0}'),
                      _construirEstadisticaResumen('Días racha', '${widget.datosEstadisticas['rachaActual'] ?? 0}'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _construirEstadisticaResumen('Tiempo lectura', '${widget.datosEstadisticas['tiempoLectura'] ?? 0} min'),
                      _construirEstadisticaResumen('Libros en progreso', '${widget.datosEstadisticas['librosEnProgreso'] ?? 0}'),
                      _construirEstadisticaResumen('Meta mensual', '${widget.datosEstadisticas['objetivoMensual'] ?? 1}'),
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

  Widget _construirEstadisticaResumen(String titulo, String valor) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: AppColores.primario.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AppColores.primario, width: 2),
          ),
          child: Center(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColores.primario,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          titulo,
          style: EstilosApp.cuerpoPequeno,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}