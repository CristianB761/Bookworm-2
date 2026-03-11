import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'diseno.dart';
import 'API/modelos.dart';
import 'theme_provider.dart';

class BotonesBarraApp extends StatelessWidget {
  final String rutaActual;

  const BotonesBarraApp({super.key, required this.rutaActual});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.esModoOscuro;

    final rutas = {
      'Inicio': {'ruta': '/home', 'icono': Icons.home},
      'Buscar': {'ruta': '/search', 'icono': Icons.search},
      'Clubs': {'ruta': '/clubs', 'icono': Icons.group},
      'Perfil': {'ruta': '/perfil', 'icono': Icons.person},
    };

    return Row(
      children: rutas.entries.map((e) => _construirBotonBarraApp(
        context,
        e.key,
        e.value['ruta'] as String,
        e.value['icono'] as IconData,
        isDark,
      )).toList(),
    );
  }

  Widget _construirBotonBarraApp(BuildContext context, String texto, String ruta, IconData icono, bool isDark) {
    final estaActivo = rutaActual == ruta;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () {
          if (ModalRoute.of(context)?.settings.name != ruta) {
            Navigator.pushReplacementNamed(context, ruta);
          }
        },
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.resolveWith((states) {
            if (estaActivo) return const Color(0xFFf8f8ff);
            if (states.contains(MaterialState.hovered)) return const Color(0xFFd3d3d3);
            return const Color(0xFFf8f8ff).withOpacity(0.7);
          }),
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (estaActivo) return Colors.white.withOpacity(0.2);
            if (states.contains(MaterialState.hovered)) return const Color(0xFF008080);
            return Colors.transparent;
          }),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 18),
            const SizedBox(width: 6),
            Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: estaActivo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BotonSeccion extends StatelessWidget {
  final String texto;
  final bool estaSeleccionado;
  final IconData icono;
  final VoidCallback alPresionar;

  const BotonSeccion({
    super.key,
    required this.texto,
    required this.estaSeleccionado,
    required this.icono,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: alPresionar,
      style: ElevatedButton.styleFrom(
        backgroundColor: estaSeleccionado ? AppColores.primario : Colors.transparent,
        foregroundColor: estaSeleccionado ? Colors.white : AppColores.primario,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: estaSeleccionado ? AppColores.primario : Theme.of(context).dividerColor,
          ),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 18),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFF5F5F5)
            : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icono, size: 48, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            Text(titulo, style: EstilosApp.cuerpoPequeno(context)),
            const SizedBox(height: 8),
            Text(descripcion, style: EstilosApp.cuerpoPequeno(context)),
          ],
        ),
      ),
    );
  }
}

class BarraBusquedaPersonalizada extends StatelessWidget {
  final TextEditingController controlador;
  final String textoHint;
  final VoidCallback alBuscar;

  const BarraBusquedaPersonalizada({
    super.key,
    required this.controlador,
    required this.textoHint,
    required this.alBuscar,
  });

  @override
  Widget build(BuildContext context) {
    final esModoOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorTexto = esModoOscuro ? Colors.white : Colors.black87;
    final colorFondo = esModoOscuro ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final colorBorde = esModoOscuro ? const Color(0xFF444444) : const Color(0xFFDDDDDD);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: colorFondo,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorBorde),
            ),
            child: TextField(
              controller: controlador,
              decoration: InputDecoration(
                hintText: textoHint,
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: esModoOscuro ? const Color(0xFF888888) : const Color(0xFFAAAAAA),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                prefixIcon: Icon(Icons.search, color: AppColores.primario),
              ),
              style: TextStyle(
                fontSize: 16,
                color: colorTexto,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: alBuscar,
            style: EstilosApp.botonPrimario(context),
            child: const Text('Buscar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class FiltroDesplegable extends StatelessWidget {
  final String? valor;
  final List<String> items;
  final String hint;
  final ValueChanged<String?> alCambiar;

  const FiltroDesplegable({
    super.key,
    required this.valor,
    required this.items,
    required this.hint,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    final esModoOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorFondo = esModoOscuro ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final colorTexto = esModoOscuro ? Colors.white : Colors.black87;
    final colorBorde = esModoOscuro ? const Color(0xFF444444) : const Color(0xFFDDDDDD);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBorde),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(
            color: esModoOscuro ? const Color(0xFF888888) : const Color(0xFFAAAAAA),
            fontSize: 16,
          )),
          dropdownColor: colorFondo,
          style: TextStyle(
            color: colorTexto,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          icon: const Icon(Icons.arrow_drop_down, color: AppColores.primario),
          items: items.map((valor) => DropdownMenuItem<String>(
            value: valor,
            child: Text(valor, style: TextStyle(color: colorTexto)),
          )).toList(),
          onChanged: alCambiar,
        ),
      ),
    );
  }
}

class TarjetaLibro extends StatelessWidget {
  final Libro libro;
  final VoidCallback? alPresionar;

  const TarjetaLibro({
    super.key,
    required this.libro,
    this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alPresionar,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: EstilosApp.tarjetaPlana(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _construirPortadaLibro(),
            const SizedBox(width: 16),
            Expanded(child: _construirInfoLibro(context)),
          ],
        ),
      ),
    );
  }

  Widget _construirPortadaLibro() {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFEEEEEE),
      ),
      child: libro.urlMiniatura != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                libro.urlMiniatura!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progresoCarga) {
                  if (progresoCarga == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progresoCarga.expectedTotalBytes != null
                          ? progresoCarga.cumulativeBytesLoaded / progresoCarga.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.book, size: 40, color: Color(0xFF9E9E9E));
                },
              ),
            )
          : const Icon(Icons.book, size: 40, color: Color(0xFF9E9E9E)),
    );
  }

  Widget _construirInfoLibro(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          libro.titulo,
          style: EstilosApp.tituloPequeno(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),

        if (libro.autores.isNotEmpty)
          Text(
            'Por ${libro.autores.join(', ')}',
            style: EstilosApp.cuerpoMedio(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

        if (libro.fechaPublicacion != null) ...[
          const SizedBox(height: 4),
          Text(
            'Publicado: ${libro.fechaPublicacion}',
            style: EstilosApp.cuerpoPequeno(context),
          ),
        ],

        if (libro.calificacionPromedio != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${libro.calificacionPromedio!.toStringAsFixed(1)} (${libro.numeroCalificaciones ?? 0})',
                style: EstilosApp.cuerpoPequeno(context),
              ),
            ],
          ),
        ],

        if (libro.descripcion != null) ...[
          const SizedBox(height: 8),
          Text(
            libro.descripcion!,
            style: EstilosApp.cuerpoPequeno(context),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class ElementoConfiguracion extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final bool tieneSwitch;
  final bool valorSwitch;
  final ValueChanged<bool>? alCambiarSwitch;
  final VoidCallback? alPresionar;

  const ElementoConfiguracion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    this.tieneSwitch = false,
    this.valorSwitch = false,
    this.alCambiarSwitch,
    this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColores.primario.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 20, color: AppColores.primario),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: EstilosApp.cuerpoGrande(context)),
                const SizedBox(height: 4),
                Text(subtitulo, style: EstilosApp.cuerpoMedio(context)),
              ],
            ),
          ),
          if (tieneSwitch)
            Switch(
              value: valorSwitch,
              onChanged: alCambiarSwitch,
              activeColor: AppColores.primario,
            )
          else
            Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
        ],
      ),
    );

    if (alPresionar != null) {
      return InkWell(
        onTap: alPresionar,
        child: content,
      );
    }

    return content;
  }
}

class IndicadorCarga extends StatelessWidget {
  final String mensaje;

  const IndicadorCarga({
    super.key,
    this.mensaje = 'Cargando...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColores.primario)),
          const SizedBox(height: 16),
          Text(mensaje, style: EstilosApp.cuerpoMedio(context)),
        ],
      ),
    );
  }
}

class BotonAccionRapida extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback alPresionar;

  const BotonAccionRapida({
    super.key,
    required this.texto,
    required this.icono,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: alPresionar,
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) {
            return const Color(0xFFd3d3d3);
          }
          return const Color(0xFFf8f8ff);
        }),
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.hovered)) {
            return const Color(0xFF008080);
          }
          return Colors.white.withOpacity(0.2);
        }),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}