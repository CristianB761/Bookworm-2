import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'diseño.dart';
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
  List<double> _datosMensuales = [4, 6, 8, 5, 7, 9, 6, 8, 7, 10, 8, 9];

  List<BarChartGroupData> _construirDatosBarrasLibros() {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    return List.generate(12, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: _datosMensuales[index],
            color: AppColores.primario,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    });
  }

  List<PieChartSectionData> _construirDatosTortaGeneros() {
    final datosGeneros = {
      'Ficción': 30,
      'Ciencia Ficción': 25,
      'Fantasía': 20,
      'No Ficción': 15,
      'Romance': 10,
    };

    final colores = [
      AppColores.primario,
      AppColores.secundario,
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF45B7D1),
    ];

    final keysList = datosGeneros.keys.toList();
    return datosGeneros.entries.map((entry) {
      final index = keysList.indexOf(entry.key);
      return PieChartSectionData(
        color: colores[index % colores.length],
        value: entry.value.toDouble(),
        title: '${entry.value}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.6,
      );
    }).toList();
  }

  Widget _construirGraficoBarras() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: EstilosApp.tarjetaPlana,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 12,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => AppColores.primario,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final mes = _obtenerMes(group.x.toInt());
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
                  final mes = _obtenerMes(value.toInt());
                  if (mes.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        mes,
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
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          barGroups: _construirDatosBarrasLibros(),
        ),
      ),
    );
  }

  String _obtenerMes(int index) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    if (index >= 0 && index < meses.length) {
      return meses[index];
    }
    return '';
  }

  Widget _construirGraficoTorta() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: EstilosApp.tarjetaPlana,
      child: PieChart(
        PieChartData(
          sections: _construirDatosTortaGeneros(),
          centerSpaceRadius: 40,
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

  Widget _construirGraficoLineas() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: EstilosApp.tarjetaPlana,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => AppColores.primario,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  final textStyle = TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  );
                  return LineTooltipItem(
                    '${touchedSpot.y.toInt()} páginas\nDía ${touchedSpot.x.toInt() + 1}',
                    textStyle,
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() % 5 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Día ${value.toInt() + 1}',
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
                interval: 20,
                reservedSize: 40,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          minX: 0,
          maxX: 29,
          minY: 0,
          maxY: 120,
          lineBarsData: [
            LineChartBarData(
              spots: [
                const FlSpot(0, 40),
                const FlSpot(5, 60),
                const FlSpot(10, 80),
                const FlSpot(15, 70),
                const FlSpot(20, 90),
                const FlSpot(25, 100),
                const FlSpot(29, 110),
              ],
              isCurved: true,
              color: AppColores.primario,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColores.primario.withOpacity(0.1),
              ),
            ),
          ],
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
        return _construirGraficoLineas();
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
                  if (widget.datosEstadisticas['tiempoLectura'] != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _construirEstadisticaResumen('Tiempo lectura', '${widget.datosEstadisticas['tiempoLectura']} min'),
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
            color: AppColores.primario.withOpacity(0.1),
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